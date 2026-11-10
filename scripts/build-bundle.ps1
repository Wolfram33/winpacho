# Build the all-in-one bundle (plain zip): Uniform Server ZeroXV base
# package + freshly built WinpachoController/WinpachoService + PHP 8.4/8.5 modules +
# the MariaDB module as the active database engine (replaces the base's MySQL) +
# the MySQL module as the second engine on standby (core\db_standby\mysql) +
# the newest Adminer as the database tool (replaces the base's phpMyAdmin).
#
# Expects (as laid out by actions/download-artifact):
#   artifacts/uniserver-binaries/WinpachoController/WinpachoController.exe
#   artifacts/uniserver-binaries/WinpachoService/WinpachoService.exe
#   artifacts/php-module-*/winpacho_php8*_module.zip
#   artifacts/mariadb-module/winpacho_mariadb_module.zip
#   artifacts/mysql-module/winpacho_mysql_module.zip
#
# Produces: dist/winpacho.zip (plus a .7z twin). Unlike the upstream 15_0_2_ZeroXV.exe it
# is FLAT: the server files land directly in the folder the user extracts to,
# without a UniServerZ subfolder. No self-extracting exe any more: unsigned
# SFX archives are quarantined by Windows Defender (Wacatac.B!ml false
# positive), and a zip needs no extra tool on Windows anyway.
$ErrorActionPreference = 'Stop'

# --- Fork version: single source of truth is WinpachoController/reload_version.inc
$versionInc = Get-Content 'WinpachoController\reload_version.inc' -Raw
if ($versionInc -notmatch "US_RELOAD_VERSION\s*=\s*'([^']+)'") { throw 'US_RELOAD_VERSION not found in WinpachoController\reload_version.inc' }
$reloadVersion = $Matches[1]
$baseVersion = '15.0.2'   # Uniform Server ZeroXV base package the bundle builds on
Write-Host "==> Building winpacho $reloadVersion (base package $baseVersion)"

# Time limits for every download: a hanging server must not block the CI job
# until GitHub kills it. Pages and API answers are small, archives are not.
$CURL_PAGE     = @('--connect-timeout', '30', '--max-time', '120', '--retry', '3')
$CURL_DOWNLOAD = @('--connect-timeout', '30', '--max-time', '900', '--retry', '3')
# Requests to the smoke test's own Apache on localhost: answers at once or hangs
$CURL_LOCAL    = @('--max-time', '30')

$sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
if (-not (Test-Path $sevenZip))  { throw "7z.exe not found at $sevenZip" }

# --- Fetch and unpack the base package ---------------------------------------
# Preferred source is our own mirror (assets of the base-package release) so
# builds do not depend on SourceForge availability; SourceForge is the fallback.
$mirrorUrl = 'https://github.com/Wolfram33/winpacho/releases/download/base-package/15_0_2_ZeroXV.exe'
$baseUrl = 'https://downloads.sourceforge.net/project/miniserver/Uniform%20Server%20ZeroXV/15_0_2_ZeroXV/15_0_2_ZeroXV.exe'
Write-Host '==> Downloading Uniform Server ZeroXV 15.0.2 base package (mirror)'
& curl.exe -fsSL @CURL_DOWNLOAD -o base.exe $mirrorUrl
if ($LASTEXITCODE -ne 0) {
  Write-Host '==> Mirror not available, falling back to SourceForge'
  # curl.exe instead of Invoke-WebRequest: SourceForge serves browser-like
  # clients an HTML mirror-selection page instead of the file.
  & curl.exe -fsSL @CURL_DOWNLOAD -o base.exe $baseUrl
  if ($LASTEXITCODE -ne 0) { throw "Base package download failed ($LASTEXITCODE)" }
}
$size = (Get-Item base.exe).Length
if ($size -lt 40MB) { throw "Base package download too small ($size bytes) - got an HTML page instead of the installer?" }

Write-Host '==> Extracting base package'
& $sevenZip x -y -obase base.exe | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z extraction failed ($LASTEXITCODE)" }

$root = 'base\UniServerZ'
# The upstream package names its own controller UniController.exe - proof of the expected layout
if (-not (Test-Path "$root\UniController.exe")) { throw "Unexpected base package layout - UniServerZ\UniController.exe not found" }

# --- Upgrade Apache to the latest Apache Lounge build ------------------------
# The base package ships Apache 2.4.58 (Oct 2023). Scrape the Apache Lounge
# download page for the newest 2.4.x win64 build and swap the binary
# directories while keeping the Uniform Server configuration.
# Floor for the patch level: a lower find means the scrape fell back to an
# outdated build (releases up to 1.3.12 shipped 2.4.66 this way) - fail loudly.
# Raise it with every Apache security release.
$MinApachePatch = 70
Write-Host '==> Checking for latest Apache Lounge build'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
function Find-HttpdZip([string]$html) {
  # Accept anything between the patch level and -win64 (build dates, openssl
  # tags, ...) and any compiler tag: newest patch, then newest VS wins.
  # Case-insensitive: Lounge spells it "Win64-VS18" as well as "win64-vs18".
  [regex]::Matches($html, 'httpd-2\.4\.(\d+)[\w.-]*?-win64-VS(\d+)\.zip', 'IgnoreCase') |
    ForEach-Object { [pscustomobject]@{ Patch = [int]$_.Groups[1].Value; VS = [int]$_.Groups[2].Value; Name = $_.Value } } |
    Sort-Object Patch, VS -Descending | Select-Object -First 1
}
$dlHtml = (& curl.exe -fsSL @CURL_PAGE -A $UA 'https://www.apachelounge.com/download/') -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Could not fetch Apache Lounge download page' }
$found = Find-HttpdZip $dlHtml
if (-not $found) {
  # Zips may live on per-compiler subpages (e.g. /download/VS18/): follow the
  # newest one referenced on the main page
  $vsPages = [regex]::Matches($dlHtml, 'download/VS(\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique -Descending
  foreach ($vs in $vsPages) {
    Write-Host "==> Scanning subpage /download/VS$vs/"
    $subHtml = (& curl.exe -fsSL @CURL_PAGE -A $UA "https://www.apachelounge.com/download/VS$vs/") -join "`n"
    if ($LASTEXITCODE -eq 0) { $found = Find-HttpdZip $subHtml }
    if ($found) { break }
  }
}
if (-not $found) {
  Write-Host '--- No match. All .zip references on the main page: ---'
  [regex]::Matches($dlHtml, '[\w/.-]*\.zip') | ForEach-Object { $_.Value } | Sort-Object -Unique | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
  Write-Host '--- All href values: ---'
  [regex]::Matches($dlHtml, 'href="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique | Select-Object -First 60 | ForEach-Object { Write-Host $_ }
  throw 'No httpd win64 zip found on Apache Lounge page'
}
if ($found.Patch -lt $MinApachePatch) { throw "Newest Apache found is 2.4.$($found.Patch) ($($found.Name)), below the floor 2.4.$MinApachePatch - Lounge page layout changed?" }
$apVer = "2.4.$($found.Patch)"
Write-Host "==> Downloading Apache $apVer ($($found.Name))"
& curl.exe -fsSL @CURL_DOWNLOAD -A $UA -e 'https://www.apachelounge.com/download/' -o apache.zip "https://www.apachelounge.com/download/VS$($found.VS)/binaries/$($found.Name)"
if ($LASTEXITCODE -ne 0) { throw 'Apache download failed' }
if ((Get-Item apache.zip).Length -lt 8MB) { throw 'Apache download suspiciously small - HTML page instead of ZIP?' }
Expand-Archive apache.zip -DestinationPath apachedist
if (-not (Test-Path 'apachedist\Apache24\bin\httpd.exe')) { throw 'Unexpected Apache archive layout' }
foreach ($d in 'bin', 'modules', 'error', 'icons', 'include', 'lib') {
  if (Test-Path "$root\core\apache2\$d") { Remove-Item "$root\core\apache2\$d" -Recurse -Force }
  if (Test-Path "apachedist\Apache24\$d") { Copy-Item "apachedist\Apache24\$d" "$root\core\apache2\$d" -Recurse }
}
Move-Item "$root\core\apache2\bin\httpd.exe" "$root\core\apache2\bin\httpd_z.exe" -Force
Write-Host "==> Apache upgraded to $apVer"

# --- Replace controllers with the fork builds --------------------------------
# Since 2.1.0 the programs carry the winpacho names; the upstream
# UniController.exe / UniService.exe must not ship next to them, a second
# controller under the old name would compete for the same servers.
# The service module lives in utils\ since 1.3.0: it is launched from the
# controller menu (Extra > Run Apache/MySQL as Windows service) instead of
# sitting next to the controller, where it invited accidental double-clicks.
Write-Host '==> Installing fork WinpachoController/WinpachoService'
Copy-Item 'artifacts\uniserver-binaries\WinpachoController\WinpachoController.exe' "$root\WinpachoController.exe" -Force
New-Item -ItemType Directory -Force "$root\utils" | Out-Null
Copy-Item 'artifacts\uniserver-binaries\WinpachoService\WinpachoService.exe' "$root\utils\WinpachoService.exe" -Force
foreach ($old in 'UniController.exe', 'UniService.exe', 'utils\UniService.exe') {
  if (Test-Path "$root\$old") { Remove-Item "$root\$old" -Force }
}
# The upstream read-me describes the original ZeroXV package; it moves next
# to the upstream license instead of greeting users at the archive root.
$upstreamDocs = "$root\docs\licenses\Uniform Server"
New-Item -ItemType Directory -Force $upstreamDocs | Out-Null
Get-ChildItem $root -File -Filter '*_ZeroXV_read_me.txt' | Move-Item -Destination $upstreamDocs -Force

# --- Database engine: MariaDB replaces the base package's MySQL (1.3.6) ------
# The engine is the MariaDB module built by package-mariadb-module.ps1 in the
# same CI run, so bundle and module are identical. The base's core\mysql
# (MySQL 8.2 with its data directory) goes completely: the two engines'
# data formats are incompatible, a mix of files corrupts the data directory.
$dbModule = Get-ChildItem -Path 'artifacts' -Recurse -Filter 'winpacho_mariadb_module.zip' | Select-Object -First 1
if (-not $dbModule) { throw 'MariaDB module ZIP not found in artifacts (package-mariadb-module job)' }
Write-Host "==> Replacing MySQL with MariaDB ($($dbModule.Name))"
Remove-Item "$root\core\mysql" -Recurse -Force
Expand-Archive -Path $dbModule.FullName -DestinationPath $root -Force
foreach ($f in 'core\mysql\bin\mysqld_z.exe', 'core\mysql\bin\mysql.exe', 'core\mysql\bin\mysqladmin.exe',
               'core\mysql\bin\mysqldump.exe', 'core\mysql\my.ini', 'core\mysql\us_opt.ini',
               'core\mysql\data\mysql', 'htpasswd\mysql\passwd.txt') {
  if (-not (Test-Path "$root\$f")) { throw "MariaDB module incomplete: $f missing after merge" }
}
$dbVersionLine = ((& "$root\core\mysql\bin\mysqld_z.exe" --no-defaults --version 2>&1) | ForEach-Object { "$_" }) -join ' '
if ($dbVersionLine -notmatch '(\d+\.\d+\.\d+)-MariaDB') { throw "core\mysql\bin\mysqld_z.exe is not a MariaDB server: $dbVersionLine" }
$dbVersion = $Matches[1]
if ((Get-Content "$root\core\mysql\us_opt.ini" -Raw) -notmatch '(?m)^text = MariaDB') { throw 'core\mysql\us_opt.ini does not name MariaDB' }
Write-Host "==> Database engine: MariaDB $dbVersion"

# --- Second database engine: MySQL on standby (2.4.0) -------------------------
# Apps and hosting that need MySQL itself get it without installing anything:
# the controller's "Switch database engine" swaps core\mysql with the waiting
# engine by renaming the two folders (us_db_engine.pas). The standby folder
# holds the complete module core\mysql - binaries, my.ini, its own data
# folder - plus its root password in standby_root_password.txt.
$standbyRoot = "$root\core\db_standby"
$mysqlStandby = "$standbyRoot\mysql"
$STANDBY_PWD_FILE = 'standby_root_password.txt'   # codeguard-ignore: a file NAME (as in us_db_engine.pas), no secret - the password inside is the shipped default 'root'
$mysqlModule = Get-ChildItem -Path 'artifacts' -Recurse -Filter 'winpacho_mysql_module.zip' | Select-Object -First 1
if (-not $mysqlModule) { throw 'MySQL module ZIP not found in artifacts (package-mysql-module job)' }
Write-Host "==> Adding MySQL on standby ($($mysqlModule.Name))"
if (Test-Path 'mysqlmodule') { Remove-Item 'mysqlmodule' -Recurse -Force }
Expand-Archive -Path $mysqlModule.FullName -DestinationPath 'mysqlmodule' -Force
if (-not (Test-Path 'mysqlmodule\core\mysql\bin\mysqld_z.exe')) { throw 'MySQL module incomplete: core\mysql\bin\mysqld_z.exe missing' }
New-Item -ItemType Directory -Force $standbyRoot | Out-Null
Move-Item 'mysqlmodule\core\mysql' $mysqlStandby
Copy-Item 'mysqlmodule\htpasswd\mysql\passwd.txt' "$mysqlStandby\$STANDBY_PWD_FILE"
if (Test-Path 'mysqlmodule\docs\licenses\mysql') {
  New-Item -ItemType Directory -Force "$root\docs\licenses" | Out-Null
  Copy-Item 'mysqlmodule\docs\licenses\mysql' "$root\docs\licenses\mysql" -Recurse -Force
}
foreach ($f in 'bin\mysqld_z.exe', 'bin\mysql.exe', 'bin\mysqladmin.exe', 'bin\mysqldump.exe', 'my.ini', 'us_opt.ini', 'data\mysql', $STANDBY_PWD_FILE) {
  if (-not (Test-Path "$mysqlStandby\$f")) { throw "MySQL standby incomplete: core\db_standby\mysql\$f missing" }
}
$mysqlVersionLine = ((& "$mysqlStandby\bin\mysqld_z.exe" --no-defaults --version 2>&1) | ForEach-Object { "$_" }) -join ' '
if ($mysqlVersionLine -notmatch 'Ver (\d+\.\d+\.\d+).*MySQL Community Server') { throw "core\db_standby\mysql\bin\mysqld_z.exe is not a MySQL server: $mysqlVersionLine" }
$mysqlVersion = $Matches[1]
if ((Get-Content "$mysqlStandby\us_opt.ini" -Raw) -notmatch '(?m)^text = MySQL') { throw 'core\db_standby\mysql\us_opt.ini does not name MySQL' }
# Users find the folder in Explorer: it must not look like leftovers
@'
This folder holds the database engine that is NOT active right now
(MariaDB or MySQL - the other one runs from core\mysql).

Do not delete, move or rename anything here by hand: it holds that
engine's own databases. Switch engines in WinpachoController, last entry
of the database menu: "Switch database engine to ...". The controller
then swaps this engine with the one in core\mysql.
'@ -replace "`r?`n", "`r`n" | Set-Content "$standbyRoot\README.txt" -NoNewline
Write-Host "==> Second engine: MySQL $mysqlVersion on standby in core\db_standby\mysql"

# --- Database tool: Adminer replaces phpMyAdmin (2.2.0) ----------------------
# phpMyAdmin 5.2.1 from the base package (54 MB, 4,100 files, plus the 'pma'
# control user and its storage database) gives way to Adminer: one PHP file
# that also opens SQLite databases. The newest release comes from GitHub
# unmodified; bundle\adminer adds the winpacho entry page (automatic root
# login, SQLite login, no version check) and the controller's button text.
# The tag comes from the redirect of /releases/latest - no API call, so no
# rate limit on shared CI runners.
Write-Host '==> Looking up the latest Adminer release'
$adminerTagUrl = & curl.exe -fsSLI @CURL_PAGE -o NUL -w '%{url_effective}' 'https://github.com/vrana/adminer/releases/latest'
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the latest Adminer release on GitHub' }
if ($adminerTagUrl -notmatch '/releases/tag/v(\d+\.\d+\.\d+)$') { throw "Unexpected Adminer release URL: $adminerTagUrl" }
$adminerVer = $Matches[1]
Write-Host "==> Downloading Adminer $adminerVer"
& curl.exe -fsSL @CURL_PAGE -o adminer.php "https://github.com/vrana/adminer/releases/download/v$adminerVer/adminer-$adminerVer.php"
if ($LASTEXITCODE -ne 0) { throw 'Adminer download failed' }
# All drivers and languages: about 580 KB; the MySQL-only build is a third of that
if ((Get-Item adminer.php).Length -lt 300KB) { throw 'Adminer download suspiciously small - not the full build?' }
if (((Get-Content adminer.php -TotalCount 12) -join "`n") -notmatch "@version $([regex]::Escape($adminerVer))") { throw "adminer.php does not carry the header '@version $adminerVer'" }
$opt1 = "$root\home\us_opt1"
if (-not (Test-Path "$opt1\libraries\classes")) { throw 'Unexpected base package layout: phpMyAdmin not found in home\us_opt1' }
Remove-Item $opt1 -Recurse -Force
New-Item -ItemType Directory -Force $opt1 | Out-Null
Copy-Item adminer.php "$opt1\adminer.php"
foreach ($f in 'index.php', 'winpacho-adminer.php', 'us_opt.ini') { Copy-Item "bundle\adminer\$f" "$opt1\$f" }
# Upload folder of the old phpMyAdmin config, nothing else uses it
if (Test-Path "$root\etc\phpmyadmin") { Remove-Item "$root\etc\phpmyadmin" -Recurse -Force }
# The base's us_user.ini lists the start-up pages; name the tool that is there
$userIni = "$root\home\us_config\us_user.ini"
$u = Get-Content $userIni -Raw
$u = $u -replace '(/us_opt1/index\.php\s+)-- phpMyAdmin', '$1-- Adminer'
$u = $u -replace '(?m)^;\s+/us_opt2/\?username=\s+-- Adminer\r?\n', ''
Set-Content $userIni -Value $u -NoNewline
if ((Get-Content $userIni -Raw) -match 'phpMyAdmin') { throw 'us_user.ini still mentions phpMyAdmin' }
Write-Host "==> Database tool: Adminer $adminerVer in home\us_opt1"

# --- Stamp the fork version --------------------------------------------------
# AppVersion carries the fork version (splash page and controller read it);
# BaseVersion records the ZeroXV base package the bundle was built from.
Write-Host "==> Stamping version $reloadVersion"
$cfg = "$root\home\us_config\us_config.ini"
$c = Get-Content $cfg -Raw
$c = $c -replace '(?m)^AppVersion=.*?(\r?)$', "AppVersion=$reloadVersion`$1"
if ($c -notmatch '(?m)^BaseVersion=') {
  $c = $c -replace '(?m)^(AppVersion=.*?\r?)$', "`$1`nBaseVersion=$baseVersion"
}
# (No DatabaseVersion stamp since 2.4.0: the splash page reads name and version
# from core\mysql\us_opt.ini, which moves with the engine when it is switched.)
# Window title / tray hover text still carries the upstream name in the stock ini
$c = $c -replace '(?m)^ServerTypeText1=Uniform Server Zero(\r?)$', 'ServerTypeText1=winpacho$1'
# Minimize stays on the taskbar like any other program; the tray is opt-in
# (General > Minimize button minimizes to system tray). Stock ini: True.
$c = $c -replace '(?m)^;--Default true(\r?\n)TrayIconEnabled=', ';--Default false (stay on the taskbar)$1TrayIconEnabled='
$c = $c -replace '(?m)^TrayIconEnabled=.*?(\r?)$', 'TrayIconEnabled=False$1'
# Minimum VC++ runtime per PHP version: WinpachoController warns (with download
# link) before an Apache start that would die on module load (issue #3).
# VS18 Apache Lounge builds need the 2017-2026 redistributable 14.51+.
$apRuntime = if ($found.VS -ge 18) { "apache=14.51`r`n" } else { '' }
if ($c -notmatch '(?m)^\[VCRUNTIME\]') {
  $c = $c.TrimEnd() + "`r`n`r`n[VCRUNTIME]`r`n; Minimum Microsoft Visual C++ runtime (x64) for Apache and per PHP version (major.minor).`r`n; WinpachoController warns before starting Apache when the installed runtime is older.`r`n$($apRuntime)php85=14.44`r`n"
}
Set-Content $cfg -Value $c -NoNewline
if ((Get-Content $cfg -Raw) -notmatch "(?m)^AppVersion=$([regex]::Escape($reloadVersion))") { throw 'us_config.ini version stamp failed' }
if ((Get-Content $cfg -Raw) -notmatch '(?m)^ServerTypeText1=winpacho') { throw 'us_config.ini ServerTypeText1 stamp failed' }
if ((Get-Content $cfg -Raw) -notmatch '(?m)^TrayIconEnabled=False') { throw 'us_config.ini TrayIconEnabled stamp failed' }
if ((Get-Content $cfg -Raw) -notmatch '(?m)^php85=14\.44') { throw 'us_config.ini VCRUNTIME stamp failed' }
if ($apRuntime -and (Get-Content $cfg -Raw) -notmatch '(?m)^apache=14\.51') { throw 'us_config.ini VCRUNTIME apache stamp failed' }
Set-Content "$root\home\version.txt" -Value "winpacho $reloadVersion (base package Uniform Server ZeroXV $baseVersion)"

# --- Merge the PHP modules ---------------------------------------------------
# Every PHP version comes fresh from windows.php.net, php83 included: the base
# package's own php83 is 8.3.0 from 2023 and misses two years of security
# fixes (among them PHP2Shell, CVE-2026-109618/-109619). It is moved out of
# the bundle tree first, so no stale file of it can survive the merge.
$modules = Get-ChildItem -Path 'artifacts' -Recurse -Filter 'winpacho_php8*_module.zip'
if ($modules.Count -eq 0) { throw 'No PHP module ZIPs found in artifacts' }
if (-not ($modules | Where-Object Name -eq 'winpacho_php83_module.zip')) { throw 'PHP 8.3 module missing in artifacts' }
if (Test-Path "$root\core\php83") {
  Write-Host '==> Replacing the base package php83 (8.3.0) with the current PHP 8.3 module'
  Move-Item "$root\core\php83" 'base\php83-from-base-package'
}
foreach ($m in $modules) {
  Write-Host "==> Merging $($m.Name)"
  Expand-Archive -Path $m.FullName -DestinationPath $root -Force
}
foreach ($p in 'php83', 'php84', 'php85') {
  if (-not (Test-Path "$root\core\$p\php.exe")) { throw "core\$p\php.exe missing after merge" }
}

# --- Default PHP version: the newest one shipped -------------------------------
# The base package's us_user.ini selects php83 (its only version). With newer
# versions bundled, a fresh install should start on the newest, not the oldest.
$phpVersions = Get-ChildItem "$root\core" -Directory -Filter 'php8*' | ForEach-Object { $_.Name } | Sort-Object
$defaultPhp = $phpVersions | Select-Object -Last 1
$userIni = "$root\home\us_config\us_user.ini"
(Get-Content $userIni -Raw) -replace '(?m)^PHP_SELECT=php\d+', "PHP_SELECT=$defaultPhp" | Set-Content $userIni -NoNewline
if ((Get-Content $userIni -Raw) -notmatch "(?m)^PHP_SELECT=$defaultPhp") { throw "us_user.ini PHP_SELECT=$defaultPhp stamp failed" }
Write-Host "==> Default PHP version: $defaultPhp (installed: $($phpVersions -join ', '))"

# --- Patch httpd.conf --------------------------------------------------------
# The stock config only has <IfDefine> include blocks up to php83; without
# them Apache serves .php files as plain text for php84/php85.
$conf = "$root\core\apache2\conf\httpd.conf"
$text = Get-Content $conf -Raw
if ($text -notmatch '<IfDefine php84>') {
  Write-Host '==> Adding php84/php85 include blocks to httpd.conf'
  $block = @'


<IfDefine php84>
   Include ${US_ROOTF}/core/apache2/conf/extra_us/php84.conf
</IfDefine>

<IfDefine php85>
   Include ${US_ROOTF}/core/apache2/conf/extra_us/php85.conf
</IfDefine>
'@
  $anchor = $text.IndexOf('<IfDefine php83>')
  if ($anchor -lt 0) { throw 'php83 IfDefine block not found in httpd.conf' }
  $insertAt = $text.IndexOf('</IfDefine>', $anchor) + '</IfDefine>'.Length
  $text = $text.Insert($insertAt, $block)
  Set-Content -Path $conf -Value $text -NoNewline
}
if ((Get-Content $conf -Raw) -notmatch '<IfDefine php85>') { throw 'httpd.conf patch failed' }

# Ensure mod_rewrite works out of the box: the module must be loaded and the
# served directories need FollowSymLinks, without which Apache rejects
# RewriteRule in directory/.htaccess context (WordPress-style rewrites).
$text = Get-Content $conf -Raw
if ($text -notmatch '(?m)^LoadModule rewrite_module') { throw 'mod_rewrite is not enabled in the stock httpd.conf' }
$patched = $text -replace '(?m)^(\s*)Options Indexes Includes(\r?)$', '$1Options Indexes Includes FollowSymLinks$2'
if ($patched -ne $text) {
  Write-Host '==> Adding FollowSymLinks to Options directives'
  Set-Content -Path $conf -Value $patched -NoNewline
}
if ((Get-Content $conf -Raw) -notmatch 'Options Indexes Includes FollowSymLinks') { throw 'FollowSymLinks patch failed' }

# Database tool slots answer on this computer only: Adminer in us_opt1 logs
# in as root by itself, and Apache listens on every network interface. (The
# base's phpMyAdmin logged in the same way and was open to the network.)
# us_opt2/us_opt3 are empty slots meant for the same kind of tool.
$text = Get-Content $conf -Raw
foreach ($slot in 'us_opt1', 'us_opt2', 'us_opt3') {
  $block = '(?s)(<Directory "\$\{US_ROOTF\}/home/' + $slot + '/">.*?)Require all granted(.*?</Directory>)'
  if ($text -notmatch $block) { throw "httpd.conf: <Directory> block of $slot with 'Require all granted' not found" }
  $text = $text -replace $block, '$1Require local$2'
}
$text = $text -replace '#== Default phpMyAdmin', '#== Adminer (winpacho database tool) - this computer only'
$text = $text -replace '#opt1>phpMyAdmin opt2>Adminer opt3>phpMyBackupPro', '#opt1>Adminer (winpacho), opt2/opt3>free slots for further tools (this computer only)'
Set-Content -Path $conf -Value $text -NoNewline
$text = Get-Content $conf -Raw
foreach ($slot in 'us_opt1', 'us_opt2', 'us_opt3') {
  if ($text -notmatch ('(?s)<Directory "\$\{US_ROOTF\}/home/' + $slot + '/">[^<]*?Require local\s*</Directory>')) { throw "httpd.conf: $slot is not limited to Require local" }
}
if ($text -match 'phpMyAdmin') { throw 'httpd.conf still mentions phpMyAdmin' }
Write-Host '==> Database tool folders limited to this computer (Require local)'

# --- Modern mail setup: CA bundle, secure msmtp template, header wrapper -----
# The stock msmtprc disables certificate checks and PHP mail() via msmtp
# lacks Date/Message-ID headers (spam-filter penalties). Ship the Mozilla
# CA bundle, a certcheck-on template and the header-adding sendmail shim.
Write-Host '==> Installing mail setup (CA bundle, msmtp template, header wrapper)'
& curl.exe -fsSL @CURL_PAGE -o "$root\core\msmtp\cacert.pem" 'https://curl.se/ca/cacert.pem'
if ($LASTEXITCODE -ne 0) { throw 'cacert.pem download failed' }
if ((Get-Item "$root\core\msmtp\cacert.pem").Length -lt 100KB) { throw 'cacert.pem suspiciously small' }
Copy-Item 'bundle\msmtp\msmtprc.ini' "$root\core\msmtp\msmtprc.ini" -Force
Copy-Item 'bundle\msmtp\mail_wrapper.php' "$root\core\msmtp\mail_wrapper.php" -Force
# Normalize the bat to CRLF while copying
Get-Content 'bundle\msmtp\sendmail.bat' | Set-Content "$root\core\msmtp\sendmail.bat"
# (The php83/84/85 module inis are generated with the header wrapper as
# sendmail_path and the default extensions already enabled.)

# (The database my.ini needs no patching here: the MariaDB module ships
# bundle\db\mariadb-my.ini with the development and server-load values
# already in, and tune-server-config.ps1 below recognises it.)

# --- Serve the same document root over HTTP and HTTPS ------------------------
# Upstream serves https from a separate ssl folder, which surprises users
# whose apps live in www ('works on http, 404 on https'). Point the SSL root
# at www; the classic split can be restored via US_ROOTF_SSL=./ssl.
$userIni = "$root\home\us_config\us_user.ini"
(Get-Content $userIni -Raw) -replace 'US_ROOTF_SSL=\./ssl', 'US_ROOTF_SSL=./www' | Set-Content $userIni -NoNewline
if ((Get-Content $userIni -Raw) -notmatch [regex]::Escape('US_ROOTF_SSL=./www')) { throw 'us_user.ini SSL root patch failed' }

# --- Console look -------------------------------------------------------------
# Server Console / MySQL Console open in Windows Terminal with a translucent
# acrylic background (WinpachoController reads CONSOLE_OPACITY, default 50).
# Document the knob in the shipped ini right next to RUN_CONSOLE.
$consoleDoc = 'RUN_CONSOLE=yes$1;$1;--Console windows (Server Console, MySQL Console): opacity in percent, 50-100. 100 = classic opaque cmd window$1CONSOLE_OPACITY=50$1'
(Get-Content $userIni -Raw) -replace 'RUN_CONSOLE=yes(\r?\n)', $consoleDoc | Set-Content $userIni -NoNewline
if ((Get-Content $userIni -Raw) -notmatch 'CONSOLE_OPACITY=50') { throw 'us_user.ini console opacity patch failed' }

# --- Default SSL vhost -------------------------------------------------------
# The stock httpd-vhosts.conf only carries a default vhost for the http port.
# Once user vhosts exist, requests with unknown host names (e.g. access by IP)
# on the SSL port would be answered by the first user vhost instead of www.
# Mirror the default block for the SSL port so both ports behave identically.
$vhostConf = "$root\core\apache2\conf\extra\httpd-vhosts.conf"
$v = Get-Content $vhostConf -Raw
if ($v -notmatch '_default_:\$\{AP_SSL_PORT\}') {
  $sslBlock = @'


# Same shallow duplicate for the SSL port: keeps requests with unknown host
# names on https in the main document root instead of the first user vhost.
# No log lines: the block inherits the main logs (tune-server-config.ps1
# strips them from the stock http block as well).
<IfModule ssl_module>
<VirtualHost _default_:${AP_SSL_PORT}>
  DocumentRoot ${US_ROOTF_SSL}
  ServerName ${US_SERVERNAME}
  SSLEngine on
  SSLCertificateFile "${US_ROOTF}/core/apache2/server_certs/server.crt"
  SSLCertificateKeyFile "${US_ROOTF}/core/apache2/server_certs/server.key"
</VirtualHost>
</IfModule>
'@
  $idx = $v.IndexOf('</VirtualHost>')
  if ($idx -lt 0) { throw 'httpd-vhosts.conf: default vhost block not found' }
  $v = $v.Insert($idx + '</VirtualHost>'.Length, $sslBlock)
  Set-Content $vhostConf -Value $v -NoNewline
}
if ((Get-Content $vhostConf -Raw) -notmatch '_default_:\$\{AP_SSL_PORT\}') { throw 'httpd-vhosts.conf SSL default vhost patch failed' }
Write-Host '==> Default SSL vhost added to httpd-vhosts.conf'

# --- Server tuning: rotating logs, OPcache, load limits ----------------------
# One script for the bundle and for existing installations (see README):
# Apache logs rotate with bounded disk use, OPcache is on in every PHP
# version, Apache/MySQL limits are sized for a small-business server. Runs
# after the vhost/SSL patches above because it rewrites their log lines.
& "$PSScriptRoot\tune-server-config.ps1" -Root $root

# --- Install fork splash page ------------------------------------------------
# Replaces the stock splash page (stale version list, upstream download links)
# with the fork's version-aware page. The stock static index.html must go:
# DirectoryIndex prefers index.html over index.php, so it would shadow the
# fork page (with a stale version) for anyone browsing /us_splash/.
Copy-Item 'bundle\us_splash\index.php' "$root\home\us_splash\index.php" -Force
if (Test-Path "$root\home\us_splash\index.html") { Remove-Item "$root\home\us_splash\index.html" -Force }
# Fork stylesheet: flex header keeps the status block below the banner instead
# of the stock CSS absolutely positioning it over the banner text.
Copy-Item 'bundle\us_splash\css\style.css' "$root\home\us_splash\css\style.css" -Force
if (Test-Path "$root\home\us_splash\images\branding_bg.png") { Remove-Item "$root\home\us_splash\images\branding_bg.png" -Force }

# --- Brand bundled documentation ---------------------------------------------
# header.js/footer.js are included by every manual page: the fork header adds
# a notice that the manual describes the original 15.0.2 release. The manual
# landing page gets corrected install instructions.
Copy-Item 'bundle\us_docs\header.js' "$root\docs\manual\common\header.js" -Force
Copy-Item 'bundle\us_docs\footer.js' "$root\docs\manual\common\footer.js" -Force
Copy-Item 'bundle\us_docs\index.html' "$root\docs\manual\index.html" -Force
# The fork controller adds restart/status commands and exit codes: ship the
# matching manual page instead of the stock one.
Copy-Item 'bundle\us_docs\command_line_parameters.html' "$root\docs\manual\command_line_parameters.html" -Force

# --- Reload branding: banner, favicon, www test page -------------------------
Copy-Item 'bundle\branding\banner.png' "$root\home\us_splash\images\logo.png" -Force
Copy-Item 'bundle\branding\banner.png' "$root\docs\manual\common\images\us_zero_logo.png" -Force
Copy-Item 'bundle\branding\favicon.ico' "$root\home\us_splash\favicon.ico" -Force
if (Test-Path "$root\www\favicon.ico") { Copy-Item 'bundle\branding\favicon.ico' "$root\www\favicon.ico" -Force }
# Branded www test page: replaces the stock ZeroXV page; the banner doubles as
# its header logo and the old background tile becomes obsolete (CSS gradient).
Copy-Item 'bundle\www\index.php' "$root\www\index.php" -Force
Copy-Item 'bundle\www\css\style.css' "$root\www\css\style.css" -Force
Copy-Item 'bundle\branding\banner.png' "$root\www\images\logo.png" -Force
if (Test-Path "$root\www\images\branding_bg.png") { Remove-Item "$root\www\images\branding_bg.png" -Force }

# --- Smoke test: every PHP version must execute and load the default exts ----
# Starts Apache once per installed PHP version and verifies PHP is executed
# (not served as source) and that the extensions the fork guarantees are
# actually loaded. Catches ini regressions per version for good.
Write-Host '==> Smoke test: verifying every PHP version'
$rootAbs = (Resolve-Path $root).Path
$env:US_ROOTF        = $rootAbs -replace '\\', '/'
$env:US_ROOTF_WWW    = "$env:US_ROOTF/www"
$env:US_SERVERNAME   = 'localhost'
$env:AP_PORT         = '8088'
$env:PHP_INI_SELECT  = 'php_test.ini'
$REQUIRED_EXT = @('pdo_sqlite', 'sqlite3', 'fileinfo', 'curl', 'mbstring', 'gd', 'openssl', 'Zend OPcache')

# Expected PHP version per folder, from the module packaging ("PHP 8.4.27 (php84)").
# Apache must run exactly this version: a php8x folder without a freshly
# packaged module (like the base package's 8.3.0 before 1.3.16) fails here.
# The suffix of a windows.php.net version ("PHP 8.3.36-1 (php83)") is not kept:
# the smoke test accepts PHP_VERSION with or without it.
$expectedPhp = @{}
Get-ChildItem -Path 'artifacts' -Recurse -Filter 'module-versions.txt' | Get-Content |
  ForEach-Object { if ($_ -match '^PHP (\d+\.\d+\.\d+)(?:-\d+)? \((php\d+)\)') { $expectedPhp[$Matches[2]] = $Matches[1] } }

# Probe page: prints a marker, the OPcache switch and the loaded extensions
@'
<?php echo "USR-PROBE ", PHP_VERSION, " OPC:", ini_get("opcache.enable"), " EXT:", implode(",", get_loaded_extensions());
'@ | Set-Content "$root\www\_ci_probe.php" -NoNewline

$httpd = "$rootAbs\core\apache2\bin\httpd_z.exe"
& $httpd -t -f "$rootAbs\core\apache2\conf\httpd.conf" -d "$rootAbs\core\apache2"
if ($LASTEXITCODE -ne 0) { throw 'Apache configuration syntax check failed' }

# Stops the test Apache. Its piped log writers (rotatelogs_z.exe) must exit on
# their own once httpd closes the pipe - an orphan here would mean an orphan
# after every controller stop as well.
function Stop-SmokeApache {
  & taskkill /F /IM httpd_z.exe 2>$null | Out-Null
  foreach ($i in 1..40) {
    if (-not (Get-Process -Name rotatelogs, rotatelogs_z -ErrorAction SilentlyContinue)) { break }
    Start-Sleep -Milliseconds 250
  }
  if (Get-Process -Name rotatelogs, rotatelogs_z -ErrorAction SilentlyContinue) {
    & taskkill /F /IM rotatelogs_z.exe 2>$null | Out-Null
    & taskkill /F /IM rotatelogs.exe 2>$null | Out-Null
    throw 'Smoke test: rotatelogs_z.exe did not exit after Apache was stopped'
  }
}

$versions = Get-ChildItem "$root\core" -Directory -Filter 'php8*' | ForEach-Object { $_.Name } | Sort-Object
foreach ($ver in $versions) {
  $env:PHP_SELECT = $ver
  Start-Process -FilePath $httpd -ArgumentList '-f', "$rootAbs\core\apache2\conf\httpd.conf", '-d', "$rootAbs\core\apache2" | Out-Null
  $resp = $null
  foreach ($i in 1..30) {
    Start-Sleep -Seconds 1
    $resp = & curl.exe -fsS @CURL_LOCAL 'http://localhost:8088/_ci_probe.php' 2>$null
    if ($LASTEXITCODE -eq 0 -and $resp) { break }
  }
  Stop-SmokeApache
  $text = ($resp -join "`n")
  if ($text -match '<\?php') { throw "Smoke test ($ver): PHP served as source instead of executing" }
  if ($text -notmatch 'USR-PROBE') { throw "Smoke test ($ver): Apache did not serve the PHP probe" }
  if (-not $expectedPhp.ContainsKey($ver)) { throw "Smoke test ($ver): no packaged module for this PHP folder (stale PHP from the base package?)" }
  if ($text -notmatch ('USR-PROBE ' + [regex]::Escape($expectedPhp[$ver]) + '(?:-\d+)? ')) {
    throw "Smoke test ($ver): Apache runs a different PHP than the packaged $($expectedPhp[$ver]): $($text.Substring(0, [Math]::Min(40, $text.Length)))"
  }
  if ($text -notmatch ' OPC:1 ') { throw "Smoke test ($ver): opcache.enable is not 1" }
  $loaded = @()
  if ($text -match 'EXT:(.*)$') { $loaded = $Matches[1] -split ',' }
  $missing = $REQUIRED_EXT | Where-Object { $_ -notin $loaded }
  if ($missing) { throw "Smoke test ($ver): required extensions not loaded: $($missing -join ', ')" }
  Write-Host "   $ver OK - PHP $($expectedPhp[$ver]) executes, OPcache on, extensions loaded"
}
Remove-Item "$root\www\_ci_probe.php" -Force

# Piped logging works: rotatelogs wrote the access log (hard link in logs\,
# ring part in logs\rotated\) and the probe requests are in it
$accessLog = "$rootAbs\core\apache2\logs\access.log"
if (-not (Test-Path $accessLog)) { throw 'Smoke test: logs\access.log was not created by rotatelogs' }
if (-not (Test-Path "$rootAbs\core\apache2\logs\rotated\access.log")) { throw 'Smoke test: logs\rotated\access.log (rotation ring) is missing' }
if ((Get-Content $accessLog -Raw) -notmatch '_ci_probe\.php') { throw 'Smoke test: probe requests are missing from the rotated access log' }
# The writer must be the windowless copy (GUI subsystem), or every log opens
# a terminal window on the user's desktop (1.3.3)
$rz = [IO.File]::ReadAllBytes("$rootAbs\core\apache2\bin\rotatelogs_z.exe")
$peOff = [BitConverter]::ToInt32($rz, 0x3C)
if ([BitConverter]::ToUInt16($rz, $peOff + 4 + 20 + 68) -ne 2) { throw 'Smoke test: bin\rotatelogs_z.exe is not a GUI-subsystem executable' }
Write-Host '   log rotation OK - access log written through the windowless rotatelogs_z.exe'

# --- Smoke test: each database engine starts, PHP reaches it, Adminer logs in -
# Started the way the controller starts it: --defaults-file only, the port
# in MYSQL_TCP_PORT (server, client tools and Adminer's winpacho-adminer.php
# all read that variable), data directory implied by the exe location.
# $VersionSuffix: what follows the version in SELECT VERSION() ('-MariaDB';
# MySQL reports the bare number).
function Test-DbEngine([string]$Engine, [string]$Version, [string]$VersionSuffix) {
  Write-Host "==> Smoke test: database engine $Engine $Version"
  $env:MYSQL_TCP_PORT = '33306'
  $mysqld   = "$rootAbs\core\mysql\bin\mysqld_z.exe"
  $mysqladm = "$rootAbs\core\mysql\bin\mysqladmin.exe"
  $dbErrLog = "$rootAbs\core\mysql\data\mysql.err"
  $dbProc = Start-Process -FilePath $mysqld -ArgumentList "--defaults-file=`"$rootAbs\core\mysql\my.ini`"" -PassThru -NoNewWindow
  $dbReady = $false
  foreach ($i in 1..120) {
    Start-Sleep -Milliseconds 500
    if ($dbProc.HasExited) { break }
    $ping = & $mysqladm --host=127.0.0.1 --port=$env:MYSQL_TCP_PORT --user=root --password=root ping 2>&1
    if ($LASTEXITCODE -eq 0 -and (($ping | ForEach-Object { "$_" }) -join ' ') -match 'alive') { $dbReady = $true; break }
  }
  if (-not $dbReady) {
    if (-not $dbProc.HasExited) { $dbProc.Kill() }
    if (Test-Path $dbErrLog) { Get-Content $dbErrLog | Select-Object -Last 40 | ForEach-Object { Write-Host "   mysql.err: $_" } }
    throw "Smoke test: $Engine did not become ready"
  }
  # The error log must be where the controller's "error log" menu looks
  if (-not (Test-Path $dbErrLog)) { throw "Smoke test ($Engine): core\mysql\data\mysql.err was not written (log_error in my.ini)" }

  # Probe page: connects as root the way apps and Adminer do (TCP to
  # 127.0.0.1, port from MYSQL_TCP_PORT) and writes a small SQLite database
  # for the Adminer SQLite login below
  $sqliteProbe = Join-Path ([IO.Path]::GetTempPath()) 'winpacho_ci_probe.sqlite'
  if (Test-Path $sqliteProbe) { Remove-Item $sqliteProbe -Force }
  @'
<?php
mysqli_report(MYSQLI_REPORT_OFF);
$db = new mysqli('127.0.0.1', 'root', 'root', 'mysql', (int) getenv('MYSQL_TCP_PORT'));
if ($db->connect_errno) { echo 'USR-DBPROBE FAIL root: ', $db->connect_error; exit; }
$version = $db->query('SELECT VERSION()')->fetch_row();
$lite = new SQLite3('__SQLITE__');
$lite->exec("CREATE TABLE ci_probe (id INTEGER PRIMARY KEY, name TEXT); INSERT INTO ci_probe (name) VALUES ('winpacho');");
$lite->close();
echo 'USR-DBPROBE OK root=', $version[0];
'@.Replace('__SQLITE__', ($sqliteProbe -replace "'", '')) | Set-Content "$root\www\_ci_dbprobe.php" -NoNewline

  $env:PHP_SELECT = $defaultPhp
  Start-Process -FilePath $httpd -ArgumentList '-f', "$rootAbs\core\apache2\conf\httpd.conf", '-d', "$rootAbs\core\apache2" | Out-Null
  $resp = $null
  foreach ($i in 1..30) { Start-Sleep -Seconds 1; $resp = & curl.exe -fsS @CURL_LOCAL 'http://localhost:8088/_ci_dbprobe.php' 2>$null; if ($LASTEXITCODE -eq 0 -and $resp) { break } }
  # The controller's button opens the bare page: Adminer must log in as root by
  # itself and land on the server overview, which names the server version
  $jar = Join-Path ([IO.Path]::GetTempPath()) 'winpacho_ci_adminer.jar'
  if (Test-Path $jar) { Remove-Item $jar -Force }
  $adminerHtml = & curl.exe -fsS @CURL_LOCAL -L -c $jar -b $jar 'http://localhost:8088/us_opt1/' 2>$null
  # SQLite login: Adminer's own form with its CSRF token, password = root password
  $jarLite = "$jar-sqlite"
  $formHeaders = "$jar-headers"
  if (Test-Path $jarLite) { Remove-Item $jarLite -Force }
  $loginForm = (& curl.exe -sS @CURL_LOCAL -D $formHeaders -c $jarLite -b $jarLite 'http://localhost:8088/us_opt1/index.php?sqlite=' 2>$null) -join "`n"
  $adminerHeaders = if (Test-Path $formHeaders) { Get-Content $formHeaders } else { @() }
  $token = if ($loginForm -match "name=['""]token['""] value=['""]([^'""]+)") { $Matches[1] } else { '' }
  $liteHtml = & curl.exe -sS -L @CURL_LOCAL -c $jarLite -b $jarLite --data-urlencode 'auth[driver]=sqlite' --data-urlencode 'auth[username]=' `
    --data-urlencode 'auth[password]=root' --data-urlencode "auth[db]=$sqliteProbe" --data-urlencode "token=$token" `
    'http://localhost:8088/us_opt1/index.php?sqlite=' 2>$null
  Stop-SmokeApache
  $text = ($resp -join "`n")
  if ($text -notmatch "USR-DBPROBE OK root=$([regex]::Escape($Version))$VersionSuffix") { throw "Smoke test: PHP could not use the database (want $Engine $Version): $text" }
  $adminerText = ($adminerHtml -join "`n")
  if ($adminerText -notmatch 'Adminer') { throw "Smoke test ($Engine): Adminer page did not render" }
  if ($adminerText -match 'auth\[password\]') { throw "Smoke test ($Engine): Adminer showed the login form instead of logging in as root" }
  if ($adminerText -notmatch [regex]::Escape($Version)) { throw "Smoke test ($Engine): Adminer page does not show server version $Version" }
  # The login form's hints name the active engine (read from core\mysql\us_opt.ini)
  if ($loginForm -notmatch "winpacho - $Engine`:") { throw "Smoke test ($Engine): Adminer's login hints do not name $Engine" }
  $csp = ($adminerHeaders | Where-Object { $_ -match '^Content-Security-Policy:' }) -join ' '
  if (-not $csp) { throw 'Smoke test: Adminer sent no Content-Security-Policy header' }
  if ($csp -match 'adminer\.org') { throw "Smoke test: Adminer's CSP still allows adminer.org (version check): $csp" }
  if (-not $token) { throw 'Smoke test: no CSRF token in the Adminer login form' }
  if ((($liteHtml -join "`n") -notmatch 'ci_probe')) { throw 'Smoke test: Adminer SQLite login with the root password failed' }
  Remove-Item $sqliteProbe, $jar, $jarLite, $formHeaders -Force -ErrorAction SilentlyContinue
  # The Adminer logins left PHP sessions (and maybe Adminer's own files) in tmp - they must not ship
  if (Test-Path "$root\tmp") {
    Get-ChildItem "$root\tmp" -File | Where-Object { $_.Name -like 'sess_*' -or $_.Name -like 'adminer*' } | Remove-Item -Force
  }

  & $mysqladm --host=127.0.0.1 --port=$env:MYSQL_TCP_PORT --user=root --password=root shutdown
  if ($LASTEXITCODE -ne 0) { throw "Smoke test ($Engine): mysqladmin shutdown failed" }
  if (-not $dbProc.WaitForExit(60000)) { $dbProc.Kill(); throw "Smoke test: $Engine did not stop within 60 s after shutdown" }
  Remove-Item "$root\www\_ci_dbprobe.php" -Force
  Remove-Item Env:\MYSQL_TCP_PORT
  # The run's error log and pid file must not ship. MySQL also generated a TLS
  # key pair (*.pem) and its server UUID (auto.cnf) on this first start - each
  # installation must create its own, not share the build machine's.
  foreach ($f in 'mysql.err', 'mysql.pid', 'auto.cnf') { Remove-Item "$root\core\mysql\data\$f" -Force -ErrorAction SilentlyContinue }
  Get-ChildItem "$root\core\mysql\data" -File -Filter '*.pem' | Remove-Item -Force
  if (Get-ChildItem "$root\core\mysql\data" -File -Filter '*.pem') { throw "Smoke test ($Engine): TLS key files (*.pem) left in core\mysql\data" }
  Write-Host "   $Engine $Version OK - PHP connects, Adminer $adminerVer logs in as root and opens SQLite, clean shutdown"
}

# Swaps core\mysql and core\db_standby\<engine> exactly as the controller's
# Switch database engine does (us_db_engine.pas): rename the folders.
function Switch-DbEngine([string]$From, [string]$To) {
  Move-Item "$root\core\mysql" (Join-Path $standbyRoot $From.ToLower()) -ErrorAction Stop
  Move-Item (Join-Path $standbyRoot $To.ToLower()) "$root\core\mysql" -ErrorAction Stop
}

Test-DbEngine -Engine 'MariaDB' -Version $dbVersion -VersionSuffix '-MariaDB'
Switch-DbEngine -From 'MariaDB' -To 'MySQL'
try {
  Test-DbEngine -Engine 'MySQL' -Version $mysqlVersion -VersionSuffix '$'
} finally {
  # A failed test may leave MySQL (or Apache) running with its files open: stop
  # them first, or the swap back fails and hides the real error
  Get-Process -Name mysqld_z -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$rootAbs\*" } | Stop-Process -Force
  Stop-SmokeApache
  Start-Sleep -Seconds 2
  # MariaDB is the engine a fresh installation starts with
  Move-Item "$root\core\mysql" $mysqlStandby -ErrorAction Stop
  Move-Item "$standbyRoot\mariadb" "$root\core\mysql" -ErrorAction Stop
}
if ((Get-Content "$root\core\mysql\us_opt.ini" -Raw) -notmatch '(?m)^text = MariaDB') { throw 'After the smoke test core\mysql does not hold MariaDB' }
if (Test-Path "$standbyRoot\mariadb") { throw 'After the smoke test core\db_standby\mariadb still exists' }

# Splash page and www test page render (fork content) under the shipped default version
$env:PHP_SELECT = $defaultPhp
Start-Process -FilePath $httpd -ArgumentList '-f', "$rootAbs\core\apache2\conf\httpd.conf", '-d', "$rootAbs\core\apache2" | Out-Null
$resp = $null
foreach ($i in 1..30) { Start-Sleep -Seconds 1; $resp = & curl.exe -fsS @CURL_LOCAL 'http://localhost:8088/us_splash/index.php' 2>$null; if ($LASTEXITCODE -eq 0 -and $resp) { break } }
$respWww = & curl.exe -fsS @CURL_LOCAL 'http://localhost:8088/index.php' 2>$null
Stop-SmokeApache
if (($resp -join "`n") -notmatch 'winpacho') { throw 'Smoke test: splash page did not render fork content' }
if (($respWww -join "`n") -notmatch 'winpacho') { throw 'Smoke test: www test page did not render fork content' }
Write-Host "==> Smoke test passed: Apache $apVer, all PHP versions execute with OPcache and required extensions, MariaDB $dbVersion and MySQL $mysqlVersion serve PHP and Adminer"

# The smoke test's logs must not ship: empty log folder, rotation ring gone
Remove-Item "$root\core\apache2\logs\rotated" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($f in 'access.log', 'error.log', 'access_ssl.log', 'error_ssl.log', 'httpd.pid') {
  Remove-Item "$root\core\apache2\logs\$f" -Force -ErrorAction SilentlyContinue
}

# --- Pack as plain zip -------------------------------------------------------
# Flat layout (since 1.3.0): the archive carries the server files at its
# root, so extraction puts them directly into the folder the user picks -
# no UniServerZ nesting any more. 7z's dir\* form keeps empty directories
# (Apache log folders) and dot-files (.htaccess).
Write-Host '==> Packing bundle zip'
New-Item -ItemType Directory -Force dist | Out-Null
& $sevenZip a -tzip -mx=5 'dist\winpacho.zip' '.\base\UniServerZ\*'
if ($LASTEXITCODE -ne 0) { throw "7z zip packing failed ($LASTEXITCODE)" }

# Guard the flat layout: the controller must sit at the archive root and no
# stray UniServerZ folder may sneak back in.
$listing = & $sevenZip l -slt 'dist\winpacho.zip'
if ($LASTEXITCODE -ne 0) { throw 'Could not list bundle zip' }
if ($listing -notcontains 'Path = WinpachoController.exe') { throw 'Bundle layout broken: WinpachoController.exe is not at the archive root' }
if ($listing | Where-Object { $_ -like 'Path = UniServerZ*' }) { throw 'Bundle layout broken: unexpected UniServerZ folder in the archive' }
foreach ($old in 'UniController.exe', 'UniService.exe', 'utils\UniService.exe', 'WinpachoService.exe') {
  if ($listing -contains "Path = $old") { throw "Bundle layout broken: $old must not be in the archive (old name or wrong folder)" }
}
if ($listing -notcontains 'Path = utils\WinpachoService.exe') { throw 'Bundle layout broken: utils\WinpachoService.exe is missing' }
if ($listing -notcontains 'Path = core\mysql\bin\mysqld_z.exe') { throw 'Bundle layout broken: core\mysql\bin\mysqld_z.exe (MariaDB) is missing' }
foreach ($f in 'core\db_standby\mysql\bin\mysqld_z.exe', "core\db_standby\mysql\$STANDBY_PWD_FILE", 'core\db_standby\README.txt') {
  if ($listing -notcontains "Path = $f") { throw "Bundle layout broken: $f (MySQL on standby) is missing" }
}
if ($listing | Where-Object { $_ -match '^Path = core\\(mysql|db_standby\\mysql)\\data\\.*\.pem$' }) { throw 'Bundle layout broken: TLS key files (*.pem) in a database data folder' }
foreach ($f in 'adminer.php', 'index.php', 'winpacho-adminer.php', 'us_opt.ini') {
  if ($listing -notcontains "Path = home\us_opt1\$f") { throw "Bundle layout broken: home\us_opt1\$f (Adminer) is missing" }
}
if ($listing | Where-Object { $_ -like 'Path = home\us_opt1\libraries*' }) { throw 'Bundle layout broken: phpMyAdmin files left in home\us_opt1' }

# Second flavour: a plain .7z (LZMA, solid) - roughly half the size of the zip,
# the footprint the old self-extracting exe had, minus the exe stub Defender
# flagged. Windows 11 23H2+ extracts it natively, older Windows needs 7-Zip;
# the zip stays the recommended download.
Write-Host '==> Packing bundle 7z'
& $sevenZip a -t7z -mx=7 'dist\winpacho.7z' '.\base\UniServerZ\*'
if ($LASTEXITCODE -ne 0) { throw "7z packing failed ($LASTEXITCODE)" }
$listing7z = & $sevenZip l -slt 'dist\winpacho.7z'
if ($LASTEXITCODE -ne 0) { throw 'Could not list bundle 7z' }
if ($listing7z -notcontains 'Path = WinpachoController.exe') { throw 'Bundle layout broken (7z): WinpachoController.exe is not at the archive root' }

Add-Content 'dist\module-versions.txt' "winpacho $reloadVersion (base ZeroXV $baseVersion)"
Add-Content 'dist\module-versions.txt' "Apache $apVer (bundle)"
Add-Content 'dist\module-versions.txt' "MariaDB $dbVersion (bundle)"
Add-Content 'dist\module-versions.txt' "MySQL $mysqlVersion (bundle)"
Add-Content 'dist\module-versions.txt' "Adminer $adminerVer (bundle)"

Get-Item 'dist\winpacho.zip', 'dist\winpacho.7z' | Format-List Name, Length
