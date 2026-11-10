# Helpers for the database module packaging scripts
# (package-mariadb-module.ps1, package-mysql-module.ps1). Dot-source it:
#   . "$PSScriptRoot\db-module-common.ps1"
#
# The recipe: unpack the vendor zip, initialize a data directory, run a
# temporary server once to check the root login, shut it down cleanly,
# then arrange the files in the core\mysql layout the controller expects
# and zip them as a winpacho module. The engine-specific parts (download
# source, init command, which binaries) stay in the packaging scripts.
# Both engines use the same layout (the folder keeps the historic name
# core\mysql): the bundle ships both since 2.4.0, the active one in
# core\mysql and the other in core\db_standby\<engine>.

# Time limits for every download: a hanging server must not block the CI job
# until GitHub kills it. Pages and API answers are small, archives are not.
$CURL_PAGE     = @('--connect-timeout', '30', '--max-time', '120', '--retry', '3')
$CURL_DOWNLOAD = @('--connect-timeout', '30', '--max-time', '900', '--retry', '3')

# The engines create files such as
# data\sys\x@0024statements_with_runtimes_in_95th_percentile.frm~ during
# initialization; from a deep working directory that runs past the Windows
# MAX_PATH limit (260) and the installer dies with a bare "Errcode: 2".
function Assert-ShortWorkingDirectory {
  $cwd = (Get-Location).Path
  if ($cwd.Length -gt 120) {
    throw "Working directory is too long for the database installers ($($cwd.Length) characters, at most 120): run this script from a short path such as C:\build (Windows MAX_PATH limit)"
  }
}

# The 7-Zip that ships on GitHub's windows runners; Expand-Archive/
# Compress-Archive are far slower on the 100-300 MB engine zips and
# Compress-Archive drops empty directories.
function Get-SevenZip {
  $exe = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
  if (-not (Test-Path $exe)) { throw "7z.exe not found at $exe (7-Zip is required)" }
  return $exe
}

# Unpacks $ZipFile into $Target (created if missing). $Include limits the
# extraction to the given archive paths, $Exclude drops matching entries
# (7-Zip -x syntax, e.g. '*.pdb').
function Expand-VendorZip([string]$ZipFile, [string]$Target, [string[]]$Include = @(), [string[]]$Exclude = @()) {
  $argList = @('x', '-y', "-o$Target", $ZipFile) + $Include
  foreach ($e in $Exclude) { $argList += "-xr!$e" }
  & (Get-SevenZip) @argList | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "7z extraction of $ZipFile failed ($LASTEXITCODE)" }
}

# A TCP port nobody listens on right now, for the temporary server.
function Get-FreeTcpPort {
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $port = $listener.LocalEndpoint.Port
  $listener.Stop()
  return $port
}

# Runs the admin tool's "ping" until the server answers "alive".
function Wait-DbServerReady([string]$AdminExe, [int]$Port, [string]$Password, [int]$TimeoutSec = 90) {
  foreach ($i in 1..($TimeoutSec * 2)) {
    Start-Sleep -Milliseconds 500
    $out = & $AdminExe --no-defaults --host=127.0.0.1 --port=$Port --user=root "--password=$Password" ping 2>&1
    if ($LASTEXITCODE -eq 0 -and (($out | ForEach-Object { "$_" }) -join ' ') -match 'alive') { return $true }
  }
  return $false
}

# Starts the server binary with the given arguments and waits until it
# accepts root connections on $Port. Returns the process (for the shutdown).
function Start-TempDbServer([string]$ServerExe, [string[]]$Arguments, [string]$AdminExe, [int]$Port, [string]$Password) {
  # Start-Process joins the list with spaces and quotes nothing itself
  $quoted = $Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
  $proc = Start-Process -FilePath $ServerExe -ArgumentList $quoted -PassThru -NoNewWindow
  if (-not (Wait-DbServerReady -AdminExe $AdminExe -Port $Port -Password $Password)) {
    if (-not $proc.HasExited) { $proc.Kill() }
    throw "Temporary database server did not become ready on port $Port"
  }
  if ($proc.HasExited) { throw "Temporary database server exited right after start (exit code $($proc.ExitCode))" }
  return $proc
}

# Runs one statement and returns its output without column headers.
function Invoke-DbQuery([string]$ClientExe, [int]$Port, [string]$Password, [string]$Sql, [string]$User = 'root') {
  $out = & $ClientExe --no-defaults --host=127.0.0.1 --port=$Port "--user=$User" "--password=$Password" --batch --skip-column-names "--execute=$Sql"
  if ($LASTEXITCODE -ne 0) { throw "Query failed as $User (exit code $LASTEXITCODE): $Sql" }
  return (($out | ForEach-Object { "$_" }) -join "`n").Trim()
}

# Clean shutdown through the admin tool; a server killed mid-write would
# ship a data directory that needs crash recovery on the user's first start.
function Stop-TempDbServer([string]$AdminExe, [int]$Port, [string]$Password, [System.Diagnostics.Process]$Process) {
  & $AdminExe --no-defaults --host=127.0.0.1 --port=$Port --user=root "--password=$Password" shutdown
  if ($LASTEXITCODE -ne 0) { throw "shutdown command failed ($LASTEXITCODE)" }
  if (-not $Process.WaitForExit(120000)) {
    $Process.Kill()
    throw 'Temporary database server did not stop within 120 s'
  }
}

# Files the temporary run leaves behind that must not ship: the error log
# of the build machine, pid files, an option file written by the installer.
function Clear-DbDataDirRunFiles([string]$DataDir) {
  foreach ($pattern in '*.err', '*.pid', 'my.ini', 'my.cnf') {
    Get-ChildItem -Path $DataDir -Filter $pattern -File -ErrorAction SilentlyContinue | Remove-Item -Force
  }
}

# The flavour files the controller reads: my.ini, us_opt.ini (server name
# and major version for captions and menus, full version for the splash
# page), the root password file.
function Write-DbModuleConfig([string]$ModuleDir, [string]$RepoRoot, [string]$Flavor, [string]$Version, [string]$MyIniName) {
  $core = Join-Path $ModuleDir 'core\mysql'
  Copy-Item (Join-Path $RepoRoot "bundle\db\$MyIniName") (Join-Path $core 'my.ini') -Force
  $major = ($Version -split '\.')[0]
  $opt = Get-Content (Join-Path $RepoRoot 'bundle\db\us_opt.ini') -Raw
  $opt = $opt -replace '\{TEXT\}', $Flavor -replace '\{MAJOR\}', $major -replace '\{VERSION\}', $Version
  Set-Content (Join-Path $core 'us_opt.ini') -Value $opt -NoNewline
  New-Item -ItemType Directory -Force (Join-Path $ModuleDir 'htpasswd\mysql') | Out-Null
  Set-Content (Join-Path $ModuleDir 'htpasswd\mysql\passwd.txt') -Value 'root' -NoNewline
}

# Sanity checks every module must pass before it is zipped, then the zip
# plus the version line the release notes list.
function Compress-DbModule([string]$ModuleDir, [string]$OutDir, [string]$ZipName, [string]$Flavor, [string]$Version) {
  foreach ($f in 'core\mysql\bin\mysqld_z.exe', 'core\mysql\bin\mysql.exe', 'core\mysql\bin\mysqladmin.exe',
                 'core\mysql\bin\mysqldump.exe', 'core\mysql\my.ini', 'core\mysql\us_opt.ini',
                 'core\mysql\data\mysql', 'htpasswd\mysql\passwd.txt') {
    if (-not (Test-Path (Join-Path $ModuleDir $f))) { throw "Module layout incomplete: $f missing" }
  }
  $ver = & (Join-Path $ModuleDir 'core\mysql\bin\mysqld_z.exe') --no-defaults --version 2>&1
  if (($ver | ForEach-Object { "$_" }) -join ' ' -notmatch [regex]::Escape($Version)) { throw "mysqld_z.exe --version does not report $Version : $ver" }
  New-Item -ItemType Directory -Force $OutDir | Out-Null
  $zip = Join-Path (Resolve-Path $OutDir).Path $ZipName
  if (Test-Path $zip) { Remove-Item $zip -Force }
  Push-Location $ModuleDir
  try {
    & (Get-SevenZip) a -tzip -mx=5 $zip 'core' 'htpasswd' 'docs' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7z packing failed ($LASTEXITCODE)" }
  } finally { Pop-Location }
  Add-Content (Join-Path $OutDir 'module-versions.txt') "$Flavor $Version (module)"
  Write-Host "==> Created $zip ($Flavor $Version, $([math]::Round((Get-Item $zip).Length / 1MB)) MB)"
}
