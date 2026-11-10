# Package MySQL (the current 8.4 LTS line) as the winpacho MySQL module.
#
# Since 2.4.0 the bundle ships both engines: MariaDB active in core\mysql,
# this MySQL in core\db_standby\mysql, swapped in by the controller's menu
# entry "Switch database engine". build-bundle.ps1 takes the zip this script
# produces, so bundle and module are identical. MySQL is there for apps and
# hosting that need MySQL itself - test locally against the engine the live
# server runs. A MariaDB data directory cannot be opened by MySQL and vice
# versa, so each engine keeps its own databases, see README "Databases".
#
# Layout (the core\mysql structure WinpachoController expects, same as the
# MariaDB module):
#   core/mysql/bin/        mysqld_z.exe (= mysqld) + mysql.exe, mysqladmin.exe,
#                          mysqldump.exe + required DLLs
#   core/mysql/lib/plugin  server plugins/components (validate_password, ...)
#   core/mysql/lib/private ICU data the regex functions need
#   core/mysql/share/      error messages, charsets
#   core/mysql/data/       initialized system tables, root password 'root'
#   core/mysql/my.ini      from bundle/db/mysql-my.ini
#   core/mysql/us_opt.ini  flavour info for the controller
#   htpasswd/mysql/passwd.txt  password file read by controller and Adminer
#
# Which MySQL: the newest 8.4.x patch (8.4 is the long-term-support series).
# dev.mysql.com refuses scripted clients, so the patch level comes from the
# mysql-server git tags and the zip from the cdn.mysql.com mirror, which
# serves plain downloads.
#
# -Zip <file>: use an already downloaded mysql-<version>-winx64.zip instead
#              of querying/downloading (local builds, tests).
param(
  [string]$OutDir = 'dist',
  [string]$Zip = ''
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\db-module-common.ps1"
$repo = Split-Path $PSScriptRoot -Parent
$flavor = 'MySQL'
$series = '8.4'
$rootPassword = 'root'
$MIN_DOWNLOAD_SIZE = 100MB   # the full zip is ~250 MB; less means an error page
# A hanging tag listing must not block the CI job (downloads: $CURL_DOWNLOAD
# from db-module-common.ps1)
$GIT_LIMITS  = @('-c', 'http.lowSpeedLimit=1000', '-c', 'http.lowSpeedTime=60')
Assert-ShortWorkingDirectory

# --- Find the release ---------------------------------------------------------
if ($Zip) {
  if (-not (Test-Path $Zip)) { throw "Zip not found: $Zip" }
  if ((Split-Path $Zip -Leaf) -notmatch '^mysql-(\d+\.\d+\.\d+)-winx64\.zip$') { throw 'Zip name must be mysql-<version>-winx64.zip' }
  $ver = $Matches[1]
  $zipFile = (Resolve-Path $Zip).Path
  Write-Host "==> Using local $zipFile (MySQL $ver)"
} else {
  $tags = & git @GIT_LIMITS ls-remote --tags 'https://github.com/mysql/mysql-server' "refs/tags/mysql-$series.*"
  if ($LASTEXITCODE -ne 0) { throw 'Could not list mysql-server tags' }
  $patch = $tags | ForEach-Object { if ($_ -match "refs/tags/mysql-$([regex]::Escape($series))\.(\d+)$") { [int]$Matches[1] } } |
    Sort-Object -Descending | Select-Object -First 1
  if ($null -eq $patch) { throw "No mysql-$series.x tag found" }
  $ver = "$series.$patch"
  $url = "https://cdn.mysql.com/Downloads/MySQL-$series/mysql-$ver-winx64.zip"
  Write-Host "==> Downloading mysql-$ver-winx64.zip"
  & curl.exe -fsSL @CURL_DOWNLOAD -o mysql.zip $url
  if ($LASTEXITCODE -ne 0) { throw "MySQL download failed ($url) - a tag can appear before its download; retry later" }
  if ((Get-Item mysql.zip).Length -lt $MIN_DOWNLOAD_SIZE) { throw 'MySQL download suspiciously small' }
  $zipFile = 'mysql.zip'
}

# --- Unpack the parts the module needs ------------------------------------------
# The full zip unpacks to over a gigabyte, most of it debug DLLs, symbol
# files and static libraries the server never loads.
Write-Host '==> Extracting'
if (Test-Path 'mysqldist') { Remove-Item 'mysqldist' -Recurse -Force }
$top = "mysql-$ver-winx64"
Expand-VendorZip -ZipFile $zipFile -Target 'mysqldist' -Exclude @('debug', '*.pdb', '*-debug.dll') -Include @(
  "$top\bin\*", "$top\lib\plugin\*", "$top\lib\private\*", "$top\share\*", "$top\LICENSE")
$dist = (Get-ChildItem mysqldist -Directory | Select-Object -First 1).FullName
if (-not (Test-Path "$dist\bin\mysqld.exe")) { throw 'Unexpected MySQL archive layout: bin\mysqld.exe missing' }

# --- Initialize the data directory ----------------------------------------------
# --initialize-insecure gives root an empty password; the first start below
# sets 'root' through --init-file, the documented way to set a root password
# on Windows without a client login. No binary log during packaging: the
# data directory must not ship the build machine's binlog files.
Write-Host '==> Initializing data directory'
& "$dist\bin\mysqld.exe" --no-defaults --initialize-insecure --console "--basedir=$dist" "--datadir=$dist\data" --skip-log-bin
if ($LASTEXITCODE -ne 0) { throw "mysqld --initialize-insecure failed ($LASTEXITCODE)" }
if (-not (Test-Path "$dist\data\mysql")) { throw 'Data directory initialization incomplete' }
$initFile = "$dist\init-root.sql"
Set-Content $initFile -Value "ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPassword';" -NoNewline

# --- First start: root password and version check ---------------------------
$client = "$dist\bin\mysql.exe"
$admin  = "$dist\bin\mysqladmin.exe"
$port = Get-FreeTcpPort
Write-Host "==> Temporary server on port $port for the first-start setup"
# X Plugin off: it would grab port 33060 on the build machine for nothing.
# Name resolution stays on, as in the shipped my.ini: the account is
# 'root'@'localhost', and Adminer connects to 127.0.0.1 - that only
# matches 'localhost' with reverse lookup enabled.
$server = Start-TempDbServer -ServerExe "$dist\bin\mysqld.exe" -AdminExe $admin -Port $port -Password $rootPassword -Arguments @(
  '--no-defaults', "--basedir=$dist", "--datadir=$dist\data", "--port=$port", '--bind-address=127.0.0.1',
  '--skip-log-bin', '--mysqlx=OFF', "--init-file=$initFile", "--log-error=$dist\data\packaging.err")
try {
  $reported = Invoke-DbQuery -ClientExe $client -Port $port -Password $rootPassword -Sql 'SELECT VERSION()'
  if ($reported -notmatch [regex]::Escape($ver)) { throw "Server reports version '$reported', expected $ver" }
} finally {
  Stop-TempDbServer -AdminExe $admin -Port $port -Password $rootPassword -Process $server
  Remove-Item $initFile -Force -ErrorAction SilentlyContinue
}
Clear-DbDataDirRunFiles -DataDir "$dist\data"
# The first start generated a TLS key pair and certificates (*.pem) and the
# server UUID (auto.cnf) in the data folder. Shipped, every installation
# would share the same private key and UUID; without them each installation
# generates its own on its first start.
Get-ChildItem -Path "$dist\data" -File | Where-Object { $_.Name -like '*.pem' -or $_.Name -eq 'auto.cnf' } | Remove-Item -Force
if (Get-ChildItem -Path "$dist\data" -File -Filter '*.pem') { throw 'TLS key files (*.pem) left in the data directory' }

# --- Assemble the module layout -------------------------------------------------
Write-Host '==> Assembling module'
$m = 'module'
if (Test-Path $m) { Remove-Item $m -Recurse -Force }
New-Item -ItemType Directory -Force "$m\core\mysql\bin", "$m\core\mysql\lib", "$m\docs\licenses\mysql" | Out-Null

Copy-Item "$dist\bin\mysqld.exe" "$m\core\mysql\bin\mysqld_z.exe"
foreach ($tool in 'mysql.exe', 'mysqladmin.exe', 'mysqldump.exe') {
  if (-not (Test-Path "$dist\bin\$tool")) { throw "Client tool $tool not found in distribution" }
  Copy-Item "$dist\bin\$tool" "$m\core\mysql\bin\$tool"
}
Copy-Item "$dist\bin\*.dll" "$m\core\mysql\bin\"
Copy-Item "$dist\lib\plugin"  "$m\core\mysql\lib\plugin"  -Recurse
Copy-Item "$dist\lib\private" "$m\core\mysql\lib\private" -Recurse
Copy-Item "$dist\share" "$m\core\mysql\share" -Recurse
Copy-Item "$dist\data"  "$m\core\mysql\data"  -Recurse
Write-DbModuleConfig -ModuleDir $m -RepoRoot $repo -Flavor $flavor -Version $ver -MyIniName 'mysql-my.ini'
if (Test-Path "$dist\LICENSE") { Copy-Item "$dist\LICENSE" "$m\docs\licenses\mysql\LICENSE" }

# --- Package --------------------------------------------------------------------
Compress-DbModule -ModuleDir $m -OutDir $OutDir -ZipName 'winpacho_mysql_module.zip' -Flavor $flavor -Version $ver
