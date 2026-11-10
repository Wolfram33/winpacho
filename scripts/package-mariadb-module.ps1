# Package MariaDB as the winpacho database module.
#
# Since 1.3.6 this module IS the bundle's database engine: build-bundle.ps1
# replaces the base package's core\mysql (MySQL) with the zip this script
# produces, so the all-in-one package and the module are identical. The
# module also moves an installation that still runs MySQL (bundles up to
# 1.3.5, the MySQL module up to 2.1.x) to MariaDB - fresh core\mysql only,
# see README "Databases".
#
# Layout (the core\mysql structure WinpachoController expects; the same one the
# original Uniform Server used for its database modules):
#   core/mysql/bin/       mysqld_z.exe (= mariadbd) + classic client tool
#                         names (mysql.exe, mysqladmin.exe, mysqldump.exe),
#                         mariadb-backup.exe (hot backups), required DLLs
#   core/mysql/lib/plugin optional server plugins (audit, extra engines)
#   core/mysql/share/     error messages, charsets
#   core/mysql/data/      initialized system tables, root password 'root'
#   core/mysql/my.ini     from bundle/db/mariadb-my.ini
#   core/mysql/us_opt.ini flavour info for the controller
#   htpasswd/mysql/passwd.txt  password file read by controller and Adminer
#
# Which MariaDB: the stable long-term-support series with the longest
# remaining support (release_eol_date from the MariaDB REST API), newest
# patch level. A newer LTS series wins only once its support outlasts the
# current one - a server engine should not change major version for a
# series that is retired earlier.
#
# -Zip <file>: use an already downloaded mariadb-<version>-winx64.zip
#              instead of querying/downloading (local builds, tests).
param(
  [string]$OutDir = 'dist',
  [string]$Zip = ''
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\db-module-common.ps1"
$repo = Split-Path $PSScriptRoot -Parent
$flavor = 'MariaDB'
$rootPassword = 'root'
Assert-ShortWorkingDirectory

# --- Find the release ---------------------------------------------------------
if ($Zip) {
  if (-not (Test-Path $Zip)) { throw "Zip not found: $Zip" }
  if ((Split-Path $Zip -Leaf) -notmatch '^mariadb-(\d+\.\d+\.\d+)-winx64\.zip$') { throw 'Zip name must be mariadb-<version>-winx64.zip' }
  $ver = $Matches[1]
  $zipFile = (Resolve-Path $Zip).Path
  Write-Host "==> Using local $zipFile (MariaDB $ver)"
} else {
  $majorsJson = & curl.exe -fsSL @CURL_PAGE 'https://downloads.mariadb.org/rest-api/mariadb/'
  if ($LASTEXITCODE -ne 0) { throw 'Could not query MariaDB REST API' }
  $majors = ($majorsJson | ConvertFrom-Json).major_releases
  $lts = $majors |
    Where-Object { $_.release_status -eq 'Stable' -and $_.release_support_type -eq 'Long Term Support' -and $_.release_eol_date } |
    Sort-Object @{ Expression = { [datetime]$_.release_eol_date }; Descending = $true },
                @{ Expression = { [version]$_.release_id };      Descending = $true } |
    Select-Object -First 1
  if (-not $lts) { throw 'No stable MariaDB LTS release found in REST API' }
  Write-Host "==> MariaDB LTS series $($lts.release_id) (supported until $($lts.release_eol_date))"

  $relJson = & curl.exe -fsSL @CURL_PAGE "https://downloads.mariadb.org/rest-api/mariadb/$($lts.release_id)/latest/"
  if ($LASTEXITCODE -ne 0) { throw 'Could not query MariaDB release listing' }
  $releases = ($relJson | ConvertFrom-Json).releases
  $release = $releases.PSObject.Properties.Value | Select-Object -First 1
  $ver = $release.release_id
  $file = $release.files |
    Where-Object { $_.file_name -like 'mariadb-*-winx64.zip' -and $_.file_name -notlike '*debug*' } |
    Select-Object -First 1
  if (-not $file) { throw "No winx64 ZIP found for MariaDB $ver" }

  Write-Host "==> Downloading $($file.file_name) (MariaDB $ver)"
  & curl.exe -fsSL @CURL_DOWNLOAD -o mariadb.zip $file.file_download_url
  if ($LASTEXITCODE -ne 0) { throw 'MariaDB download failed' }
  if ((Get-Item mariadb.zip).Length -lt 50MB) { throw 'MariaDB download suspiciously small' }
  $zipFile = 'mariadb.zip'
}

# --- Unpack ---------------------------------------------------------------------
Write-Host '==> Extracting'
if (Test-Path 'mariadbdist') { Remove-Item 'mariadbdist' -Recurse -Force }
Expand-VendorZip -ZipFile $zipFile -Target 'mariadbdist' -Exclude @('*.pdb')
$dist = (Get-ChildItem mariadbdist -Directory | Select-Object -First 1).FullName
if (-not (Test-Path "$dist\bin\mariadbd.exe")) { throw 'Unexpected MariaDB archive layout: bin\mariadbd.exe missing' }

# --- Initialize the data directory (root password 'root') ----------------------
# Run inside the pristine distribution so basedir-relative paths resolve.
Write-Host '==> Initializing data directory'
& "$dist\bin\mariadb-install-db.exe" --datadir="$dist\data" --password=$rootPassword | Out-Null
if ($LASTEXITCODE -ne 0) { throw "mariadb-install-db failed ($LASTEXITCODE)" }
if (-not (Test-Path "$dist\data\mysql")) { throw 'Data directory initialization incomplete' }
# install-db writes its own my.ini into the data dir - only the module's
# core\mysql\my.ini may be in effect
Remove-Item "$dist\data\my.ini" -ErrorAction SilentlyContinue

# --- First start: root login and version check -------------------------------
# Also leaves a data directory that went through one clean start and shutdown.
# (Up to 2.1.x this step created the phpMyAdmin control user 'pma' and its
# storage tables; Adminer needs neither.)
$client = if (Test-Path "$dist\bin\mysql.exe") { "$dist\bin\mysql.exe" } else { "$dist\bin\mariadb.exe" }
$admin  = if (Test-Path "$dist\bin\mysqladmin.exe") { "$dist\bin\mysqladmin.exe" } else { "$dist\bin\mariadb-admin.exe" }
$port = Get-FreeTcpPort
Write-Host "==> Temporary server on port $port for the first-start check"
# Name resolution stays on, as in the shipped my.ini: the account is
# 'root'@'localhost', and Adminer connects to 127.0.0.1 - that only
# matches 'localhost' with reverse lookup enabled.
$server = Start-TempDbServer -ServerExe "$dist\bin\mariadbd.exe" -AdminExe $admin -Port $port -Password $rootPassword -Arguments @(
  '--no-defaults', "--datadir=$dist\data", "--port=$port", '--bind-address=127.0.0.1',
  "--log-error=$dist\data\packaging.err")
try {
  $reported = Invoke-DbQuery -ClientExe $client -Port $port -Password $rootPassword -Sql 'SELECT VERSION()'
  if ($reported -notmatch [regex]::Escape($ver)) { throw "Server reports version '$reported', expected $ver" }
} finally {
  Stop-TempDbServer -AdminExe $admin -Port $port -Password $rootPassword -Process $server
}
Clear-DbDataDirRunFiles -DataDir "$dist\data"

# --- Assemble the module layout -------------------------------------------------
Write-Host '==> Assembling module'
$m = 'module'
if (Test-Path $m) { Remove-Item $m -Recurse -Force }
New-Item -ItemType Directory -Force "$m\core\mysql\bin", "$m\docs\licenses\mariadb" | Out-Null

Copy-Item "$dist\bin\mariadbd.exe" "$m\core\mysql\bin\mysqld_z.exe"
# Client tools under the classic names the controller calls. MariaDB ships
# them as copies of the mariadb-* tools in the 11.x series; later series may
# only carry the new names, hence the fallback.
foreach ($pair in @(
    @('mysql.exe',      'mariadb.exe'),
    @('mysqladmin.exe', 'mariadb-admin.exe'),
    @('mysqldump.exe',  'mariadb-dump.exe'))) {
  $classic = $pair[0]; $modern = $pair[1]
  if (Test-Path "$dist\bin\$classic")     { Copy-Item "$dist\bin\$classic" "$m\core\mysql\bin\$classic" }
  elseif (Test-Path "$dist\bin\$modern")  { Copy-Item "$dist\bin\$modern"  "$m\core\mysql\bin\$classic" }
  else { throw "Client tool $modern not found in distribution" }
}
# Hot physical backups (mariadb-backup --backup) - the free counterpart of
# MySQL Enterprise Backup; libcurl.dll below is its S3 support
if (Test-Path "$dist\bin\mariadb-backup.exe") { Copy-Item "$dist\bin\mariadb-backup.exe" "$m\core\mysql\bin\" }
# server.dll carries the server since 11.x (mariadbd.exe is a stub), the
# rest are the VC++ runtime and compression libraries
Copy-Item "$dist\bin\*.dll" "$m\core\mysql\bin\"
if (Test-Path "$dist\lib\plugin") {
  New-Item -ItemType Directory -Force "$m\core\mysql\lib\plugin" | Out-Null
  Copy-Item "$dist\lib\plugin\*.dll" "$m\core\mysql\lib\plugin\"
}
Copy-Item "$dist\share" "$m\core\mysql\share" -Recurse
Copy-Item "$dist\data"  "$m\core\mysql\data"  -Recurse
Write-DbModuleConfig -ModuleDir $m -RepoRoot $repo -Flavor $flavor -Version $ver -MyIniName 'mariadb-my.ini'
if (Test-Path "$dist\COPYING") { Copy-Item "$dist\COPYING" "$m\docs\licenses\mariadb\COPYING" }

# --- Package --------------------------------------------------------------------
Compress-DbModule -ModuleDir $m -OutDir $OutDir -ZipName 'winpacho_mariadb_module.zip' -Flavor $flavor -Version $ver
