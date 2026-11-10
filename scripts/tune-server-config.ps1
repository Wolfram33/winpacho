# Server tuning for winpacho: rotating Apache logs with bounded disk
# use, OPcache on in every PHP version, Apache limits sized for a small
# business server instead of a developer laptop.
#
# build-bundle.ps1 runs this for every bundle. It also works stand-alone on an
# existing installation (with Apache stopped):
#
#   powershell -ExecutionPolicy Bypass -File tune-server-config.ps1 -Root C:\winpacho
#
# Idempotent: running it again changes nothing. Every change is verified and
# the script stops with a clear message when a file does not look as expected.
#
# What it changes
#   core\apache2\bin\rotatelogs_z.exe
#       Copy of Apache's rotatelogs.exe with the PE subsystem set to GUI.
#       Apache spawns piped log programs without console flags, so when it
#       runs without a console (as started by WinpachoController) every console
#       rotatelogs gets a window of its own - a Windows Terminal window per
#       log on Windows 11 (1.3.3 shipped that). A GUI-subsystem process never
#       gets a console and still reads the log pipe. WinpachoController creates
#       the same file at Apache start when it is missing.
#   core\apache2\conf\httpd.conf, extra\httpd-ssl.conf, extra\httpd-vhosts.conf
#       ErrorLog/CustomLog go through bin\rotatelogs_z.exe: logs\<name> stays
#       the current file (hard link), logs\rotated\ holds a ring of older parts
#       (access: 10 x 20M, error: 5 x 10M) - the logs can never fill the disk.
#       Every writer runs twice (Apache's parent and worker process open all
#       logs), so pipes are kept to a minimum: vhosts get one error log shared
#       by their http and https block (Apache shares error-log pipes with the
#       same command, but never access-log pipes) and no access log of their
#       own - their requests go to logs\access.log tagged "host:port"
#       (vhost_combined format). The default vhost blocks inherit the main
#       logs instead of opening the same pipes a second time.
#   core\apache2\conf\extra\httpd-mpm.conf
#       400 worker threads (was 150) and an 8 MB thread stack for PHP.
#   core\php8x\php_production.ini, php_development.ini, php_test.ini
#       OPcache enabled with 256M cache / 20000 files, realpath cache on.
#       The zend_extension line uses the php_opcache.dll form the controller's
#       PHP > Accelerator toggle understands.
#   core\apache2\conf\httpd.conf, <Directory> blocks of home\us_opt1..3
#       'Require local' instead of 'Require all granted': the database tool
#       Adminer logs in by itself and must not be reachable from the network.
#   core\mysql\my.ini is left alone: the MariaDB and MySQL modules ship it
#       tuned (both engines since 2.4.0; the MySQL one is recognised by its
#       "second database engine" header). The my.ini of an older MySQL
#       installation (bundles up to 1.3.5, MySQL module up to 2.1.x) stays as
#       it is, with a note.
param([Parameter(Mandatory = $true)][string]$Root)
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path $Root).Path
$apache = Join-Path $Root 'core\apache2'
if (-not (Test-Path (Join-Path $apache 'conf\httpd.conf'))) { throw "No winpacho installation at $Root (core\apache2\conf\httpd.conf missing)" }

# Rotating log settings: the ring of older parts lives in logs\rotated\
$ACCESS_FILES = 10; $ACCESS_SIZE = '20M'
$ERROR_FILES  = 5;  $ERROR_SIZE  = '10M'

function Read-Text([string]$path) { Get-Content $path -Raw }
function Write-Text([string]$path, [string]$text) { Set-Content $path -Value $text -NoNewline }

# Newline style of a file (the stock files mix CRLF and LF between files)
function Get-Newline([string]$text) { if ($text -match "`r`n") { "`r`n" } else { "`n" } }

# Piped log program for one log file: keeps logs\<name> as the current file
# (-L hard link) and rotates through logs\rotated\<name>[.1 .. .N-1].
function Get-RotatingLog([string]$name, [int]$files, [string]$size) {
  "|bin/rotatelogs_z.exe -n $files -D -L logs/$name logs/rotated/$name $size"
}

# PE subsystem field of an exe (3 = console, 2 = GUI): the optional header
# follows the 4-byte PE signature and the 20-byte COFF header, Subsystem is
# the WORD at optional header + 68.
function Get-PeSubsystemOffset([byte[]]$b) {
  if ($b.Length -lt 0x40 -or $b[0] -ne 0x4D -or $b[1] -ne 0x5A) { throw 'not an executable (no MZ header)' }
  $pe = [BitConverter]::ToInt32($b, 0x3C)
  if ($pe -le 0 -or $pe + 96 -gt $b.Length -or [BitConverter]::ToUInt32($b, $pe) -ne 0x4550) { throw 'not a PE executable' }
  return $pe + 4 + 20 + 68
}

# Writes bin\rotatelogs_z.exe: rotatelogs.exe with the subsystem set to GUI so
# it never opens a console window (see the header). Idempotent.
function New-WindowlessRotatelogs([string]$bin) {
  $src = Join-Path $bin 'rotatelogs.exe'
  $dst = Join-Path $bin 'rotatelogs_z.exe'
  if (Test-Path $dst) {
    $d = [IO.File]::ReadAllBytes($dst)
    if ([BitConverter]::ToUInt16($d, (Get-PeSubsystemOffset $d)) -eq 2) { return }
  }
  $b = [IO.File]::ReadAllBytes($src)
  $off = Get-PeSubsystemOffset $b
  $sub = [BitConverter]::ToUInt16($b, $off)
  if ($sub -ne 3 -and $sub -ne 2) { throw "rotatelogs.exe: unexpected PE subsystem $sub" }
  $b[$off] = 2; $b[$off + 1] = 0
  [IO.File]::WriteAllBytes($dst, $b)
  $d = [IO.File]::ReadAllBytes($dst)
  if ([BitConverter]::ToUInt16($d, (Get-PeSubsystemOffset $d)) -ne 2) { throw 'rotatelogs_z.exe: subsystem patch failed' }
}

# Replaces the first match of $pattern (one whole line) with $replacement and
# comments out every later match, so a setting is never active twice.
# Returns the new text and the number of matches. (A plain loop instead of a
# MatchEvaluator: a scriptblock delegate cannot report a count back reliably.)
function Set-FirstMatch([string]$text, [string]$pattern, [string]$replacement, [string]$comment) {
  $hits = [regex]::Matches($text, $pattern)
  if ($hits.Count -eq 0) { return @($text, 0) }
  $sb = New-Object System.Text.StringBuilder
  $pos = 0
  for ($i = 0; $i -lt $hits.Count; $i++) {
    $m = $hits[$i]
    [void]$sb.Append($text.Substring($pos, $m.Index - $pos))
    if ($i -eq 0) { [void]$sb.Append($replacement) }
    else { [void]$sb.Append($comment + ($m.Value -replace '^[;#\t ]*', '')) }
    $pos = $m.Index + $m.Length
  }
  [void]$sb.Append($text.Substring($pos))
  return @($sb.ToString(), $hits.Count)
}

# Makes "$line" (key = value or key=value) the active setting for its key:
# the first occurrence of the key - commented out or not - becomes $line,
# later occurrences are commented out, a missing key is appended.
# $comment is the comment character of the file (';' php.ini, '#' my.ini).
function Set-IniLine([string]$text, [string]$line, [string]$comment = ';') {
  $key = ($line -split '=', 2)[0].Trim()
  $r = Set-FirstMatch $text ('(?m)^[;#\t ]*' + [regex]::Escape($key) + '[\t ]*=.*?(?=\r?$)') $line $comment
  if ($r[1] -eq 0) { $nl = Get-Newline $text; return $text.TrimEnd() + $nl + $line + $nl }
  return $r[0]
}

function Assert-IniLine([string]$text, [string]$line, [string]$file) {
  if ($text -notmatch ('(?m)^' + [regex]::Escape($line) + '[\t ]*\r?$')) { throw "$file`: failed to set '$line'" }
}

# --- Servers must be stopped: the files below are open while they run ---------
# (MariaDB may keep running: its my.ini is not touched any more.)
foreach ($p in 'httpd_z', 'rotatelogs', 'rotatelogs_z') {
  if (Get-Process -Name $p -ErrorAction SilentlyContinue) { throw "$p.exe is running - stop Apache (WinpachoController or the Windows service) before running this script" }
}

# =============================================================================
# Apache: rotating logs
# =============================================================================
if (-not (Test-Path (Join-Path $apache 'bin\rotatelogs.exe'))) { throw 'core\apache2\bin\rotatelogs.exe is missing - the Apache build in this installation has no rotatelogs, log rotation cannot be enabled' }
New-WindowlessRotatelogs (Join-Path $apache 'bin')
$logs = Join-Path $apache 'logs'
New-Item -ItemType Directory -Force (Join-Path $logs 'rotated') | Out-Null

# 1.3.3 pointed the pipes at the console rotatelogs.exe (a terminal window per
# log): move every such line, including user vhosts, to the windowless copy.
foreach ($c in 'conf\httpd.conf', 'conf\extra\httpd-ssl.conf', 'conf\extra\httpd-vhosts.conf') {
  $f = Join-Path $apache $c
  if (-not (Test-Path $f)) { continue }
  $t = Read-Text $f
  $u = $t.Replace('|bin/rotatelogs.exe ', '|bin/rotatelogs_z.exe ')
  if ($u -ne $t) { Write-Text $f $u; Write-Host "   $c`: log pipes moved to rotatelogs_z.exe" }
}

# Existing plain log files become part 0 of their ring so no history is lost
# (rotatelogs appends to an existing part 0 and would otherwise delete the
# plain file when it creates the hard link).
foreach ($name in 'access.log', 'error.log', 'access_ssl.log', 'error_ssl.log') {
  $plain = Join-Path $logs $name
  $part0 = Join-Path $logs "rotated\$name"
  if (-not (Test-Path $plain)) { continue }
  $links = (& fsutil.exe hardlink list $plain | Measure-Object).Count
  if ($links -gt 1) { continue }                        # already a rotation link
  $old = Get-Content $plain -Raw
  if (-not $old) { Remove-Item $plain -Force; continue }
  if (Test-Path $part0) { Add-Content $part0 -Value $old -NoNewline; Remove-Item $plain -Force }
  else { Move-Item $plain $part0 -Force }
  Write-Host "   kept existing $name as logs\rotated\$name"
}

$accessPipe = Get-RotatingLog 'access.log' $ACCESS_FILES $ACCESS_SIZE
$errorPipe  = Get-RotatingLog 'error.log'  $ERROR_FILES  $ERROR_SIZE

# httpd.conf: main error log and access log. The access log carries the
# vhost name and port in front of every line (vhost_combined) because the
# vhosts have no access log of their own (see the header).
$VHOST_FORMAT = 'LogFormat "%v:%p %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined'
$conf = Join-Path $apache 'conf\httpd.conf'
$t = Read-Text $conf
$nl = Get-Newline $t
$note = "# winpacho: logs rotate in place through bin\rotatelogs_z.exe (rotatelogs$nl" +
        "# without a console window). logs\<name> is always the current file (hard link);$nl" +
        "# logs\rotated\ keeps a ring of older parts ($ACCESS_FILES x $ACCESS_SIZE access, $ERROR_FILES x $ERROR_SIZE error),$nl" +
        "# so the logs can never fill the disk. The access log takes the requests of every$nl" +
        "# vhost too, tagged host:port (vhost_combined); vhosts only keep their own error log.$nl"
$t = $t -replace '(?m)^ErrorLog "logs/error\.log"(\r?)$', ('ErrorLog "' + $errorPipe + '"$1')
$t = $t -replace '(?m)^([\t ]*)CustomLog "logs/access\.log" combined(\r?)$', ('$1CustomLog "' + $accessPipe + '" vhost_combined$2')
# 1.3.3/1.3.4 wrote the pipe with the plain combined format
$t = $t -replace ('(?m)^([\t ]*)CustomLog "' + [regex]::Escape($accessPipe) + '" combined(\r?)$'), ('$1CustomLog "' + $accessPipe + '" vhost_combined$2')
if ($t -notmatch '(?m)^[\t ]*LogFormat .* vhost_combined[\t ]*\r?$') {
  # right after the stock "combined" format line, same indentation
  $t = $t -replace '(?m)^([\t ]*)(LogFormat .* combined)(\r?)$', ('$1$2$3' + $nl + '$1' + $VHOST_FORMAT.Replace('$', '$$') + '$3')
}
# Replace the whole note (earlier versions described the previous layout):
# it sits directly above the ErrorLog line, so every comment line that
# follows its first line belongs to it. Up to 2.0.0 it started with
# "UniServer Reload:", it is replaced by the current wording then too.
$t = $t -replace '(?m)^# (UniServer Reload|winpacho): logs rotate in place through bin\\rotatelogs(_z)?\.exe[^\r\n]*\r?\n(#[^\r\n]*\r?\n)*', ''
if ($t -notmatch 'winpacho: logs rotate in place') { $t = $t -replace '(?m)^(ErrorLog ")', ($note + '$1') }
Write-Text $conf $t
$t = Read-Text $conf
if ($t -notmatch ('(?m)^ErrorLog "' + [regex]::Escape($errorPipe) + '"'))                        { throw 'httpd.conf: ErrorLog rotation patch failed' }
if ($t -notmatch ('(?m)^\s*CustomLog "' + [regex]::Escape($accessPipe) + '" vhost_combined'))    { throw 'httpd.conf: CustomLog rotation patch failed' }
if ($t -notmatch '(?m)^[\t ]*LogFormat "%v:%p .* vhost_combined[\t ]*\r?$')                       { throw 'httpd.conf: vhost_combined LogFormat missing' }
if (([regex]::Matches($t, '(?m)^[\t ]*LogFormat .* vhost_combined[\t ]*\r?$')).Count -ne 1)      { throw 'httpd.conf: vhost_combined LogFormat duplicated' }

# httpd-vhosts.conf
#  - the default vhost blocks (unknown host names) inherit the main logs:
#    their own ErrorLog/CustomLog lines only opened the same pipes again
#  - user vhosts: one rotated error log shared by the http and https block
#    (1.3.3/1.3.4 gave the https block its own -ssl- pair, older versions
#    plain files), no access log of their own - the requests are in
#    logs\access.log tagged host:port
$vconf = Join-Path $apache 'conf\extra\httpd-vhosts.conf'
$t = Read-Text $vconf
$nl = Get-Newline $t
$t = [regex]::Replace($t, '(?m)^[\t ]*(ErrorLog|CustomLog|TransferLog) "?(\|bin/rotatelogs(_z)?\.exe [^"\r\n]*)?logs/(error|access)\.log[^\r\n]*\r?\n', '')
$t = [regex]::Replace($t, '(?m)^[\t ]*CustomLog [^\r\n]*logs/[^\s"/]+-(ssl-)?access\.log[^\r\n]*\r?\n', '')
$t = $t -replace '-ssl-error\.log', '-error.log'
$t = $t -replace '(?m)^([\t ]*)ErrorLog "?\|bin/rotatelogs\.exe ([^\r\n]*-error\.log)', '$1ErrorLog "|bin/rotatelogs_z.exe $2'
$t = [regex]::Replace($t, '(?m)^([\t ]*)ErrorLog "?logs/([^\s"/]+-error\.log)"?[\t ]*(?=\r?$)', ('$1ErrorLog "|bin/rotatelogs_z.exe -n ' + $ERROR_FILES + ' -D -L logs/$2 logs/rotated/$2 ' + $ERROR_SIZE + '"'))
# Say where the access lines went, once per ErrorLog line that has no such note yet
$accessNote = '# Access lines of this host go to logs/access.log, tagged "host:port" (vhost_combined)'
$t = [regex]::Replace($t, '(?m)^([\t ]*)(ErrorLog "\|bin/rotatelogs_z\.exe [^\r\n]*-error\.log[^\r\n]*)(\r?)$(?!\r?\n[\t ]*# Access lines of this host)', ('$1$2$3' + $nl + '$1' + $accessNote + '$3'))
Write-Text $vconf $t
$t = Read-Text $vconf
if ($t -match '(?m)^[\t ]*(CustomLog|TransferLog)\b')          { throw 'httpd-vhosts.conf: a CustomLog line survived - vhosts must inherit the main access log' }
if ($t -match '(?m)^[\t ]*ErrorLog "?logs/')                   { throw 'httpd-vhosts.conf: a plain error log file survived the rotation patch' }
if ($t -match '\|bin/rotatelogs\.exe |-ssl-error\.log')         { throw 'httpd-vhosts.conf: a console rotatelogs.exe pipe or an -ssl- log name survived' }

# httpd-ssl.conf: the SSL default host keeps its own log names
$sconf = Join-Path $apache 'conf\extra\httpd-ssl.conf'
$sslErrorPipe  = Get-RotatingLog 'error_ssl.log'  $ERROR_FILES  $ERROR_SIZE
$sslAccessPipe = Get-RotatingLog 'access_ssl.log' $ACCESS_FILES $ACCESS_SIZE
$t = Read-Text $sconf
$t = $t -replace '(?m)^ErrorLog "\$\{US_ROOTF\}/core/apache2/logs/error_ssl\.log"(\r?)$',      ('ErrorLog "' + $sslErrorPipe + '"$1')
$t = $t -replace '(?m)^TransferLog "\$\{US_ROOTF\}/core/apache2/logs/access_ssl\.log"(\r?)$', ('TransferLog "' + $sslAccessPipe + '"$1')
Write-Text $sconf $t
$t = Read-Text $sconf
if ($t -notmatch ('(?m)^ErrorLog "' + [regex]::Escape($sslErrorPipe) + '"'))       { throw 'httpd-ssl.conf: ErrorLog rotation patch failed' }
if ($t -notmatch ('(?m)^TransferLog "' + [regex]::Escape($sslAccessPipe) + '"'))   { throw 'httpd-ssl.conf: TransferLog rotation patch failed' }
foreach ($c in 'conf\httpd.conf', 'conf\extra\httpd-ssl.conf', 'conf\extra\httpd-vhosts.conf') {
  if ((Read-Text (Join-Path $apache $c)) -match '\|bin/rotatelogs\.exe ') { throw "$c`: a log pipe still uses the console rotatelogs.exe" }
}
Write-Host "==> Apache logs rotate: logs\<name> current, logs\rotated\ ring ($ACCESS_FILES x $ACCESS_SIZE access, $ERROR_FILES x $ERROR_SIZE error), writer bin\rotatelogs_z.exe (no console window)"

# =============================================================================
# Apache: worker threads for server load
# =============================================================================
# mpm_winnt serves every connection from one thread pool. 150 threads are
# fine for one developer; chat apps that keep long-polling connections open
# for every user eat them quickly. 8 MB thread stacks are the PHP-on-Windows
# recommendation against stack overflows in deep framework call chains
# (reserved address space only - committed as used).
$mpmConf = Join-Path $apache 'conf\extra\httpd-mpm.conf'
$t = Read-Text $mpmConf
$nl = Get-Newline $t
$winnt = '(?s)(<IfModule mpm_winnt_module>.*?</IfModule>)'
if ($t -notmatch $winnt) { throw 'httpd-mpm.conf: mpm_winnt block not found' }
$block = $Matches[1]
$new = $block -replace '(?m)^([\t ]*)ThreadsPerChild[\t ]+\d+(\r?)$', '$1ThreadsPerChild        400$2'
if ($new -notmatch 'ThreadStackSize') { $new = $new -replace '(?m)^([\t ]*)(ThreadsPerChild[\t ]+400)(\r?)$', ('$1$2$3' + $nl + '$1ThreadStackSize    8388608$3') }
if ($new -ne $block) { Write-Text $mpmConf ($t.Replace($block, $new)) }
$t = Read-Text $mpmConf
if ($t -notmatch '(?s)<IfModule mpm_winnt_module>.*?ThreadsPerChild\s+400.*?ThreadStackSize\s+8388608.*?</IfModule>') { throw 'httpd-mpm.conf: mpm_winnt tuning failed' }
Write-Host '==> Apache mpm_winnt: 400 worker threads, 8 MB thread stack'

# =============================================================================
# PHP: OPcache on in every version
# =============================================================================
# Without OPcache every request recompiles every PHP file - the classic
# bottleneck once several people work at the same time. PHP 8.5 has OPcache
# built in (no DLL, on by default); older versions need the zend_extension
# line, written in the php_opcache.dll form the controller's toggle expects.
$OPCACHE_LINES = @(
  'opcache.enable=1',
  'opcache.enable_cli=0',
  'opcache.memory_consumption=256',
  'opcache.interned_strings_buffer=16',
  'opcache.max_accelerated_files=20000',
  'opcache.validate_timestamps=1',
  'realpath_cache_size = 4096k',
  'realpath_cache_ttl = 120'
)
$phpDirs = Get-ChildItem (Join-Path $Root 'core') -Directory -Filter 'php8*' | Sort-Object Name
if (-not $phpDirs) { throw 'No core\php8x folder found' }
foreach ($dir in $phpDirs) {
  $ver = $dir.Name
  $dll = Join-Path $dir.FullName 'extensions\php_opcache.dll'
  $hasDll = Test-Path $dll
  foreach ($iniName in 'php_production.ini', 'php_test.ini', 'php_development.ini') {
    $ini = Join-Path $dir.FullName $iniName
    if (-not (Test-Path $ini)) { continue }
    $t = Read-Text $ini
    $nl = Get-Newline $t
    if ($hasDll) {
      $zendLine = 'zend_extension=${US_ROOTF}/core/' + $ver + '/extensions/php_opcache.dll'
      # Replace whatever OPcache zend_extension line exists (";zend_extension=opcache"
      # from php.ini-production, the upstream DLL path form, or an active one)
      $r = Set-FirstMatch $t '(?m)^[;\t ]*zend_extension[\t ]*=[\t ]*\S*opcache\S*[\t ]*(?=\r?$)' $zendLine ';'
      $t = $r[0]
      if ($r[1] -eq 0) { $t = $t.TrimEnd() + $nl + $nl + '; winpacho - OPcache' + $nl + $zendLine + $nl }
    }
    else {
      # Built-in OPcache (PHP 8.5+): a zend_extension line would only produce a
      # startup warning about a missing DLL
      $t = $t -replace '(?m)^zend_extension[\t ]*=[\t ]*(\S*opcache\S*)[\t ]*(?=\r?$)', ';zend_extension=$1'
    }
    foreach ($line in $OPCACHE_LINES) { $t = Set-IniLine $t $line }
    # Development: pick up file changes immediately; production/test: every 2 s
    $freq = if ($iniName -eq 'php_development.ini') { 'opcache.revalidate_freq=0' } else { 'opcache.revalidate_freq=2' }
    $t = Set-IniLine $t $freq
    Write-Text $ini $t
    $t = Read-Text $ini
    foreach ($line in $OPCACHE_LINES + @($freq)) { Assert-IniLine $t $line "$ver\$iniName" }
    if ($hasDll) {
      Assert-IniLine $t $zendLine "$ver\$iniName"
      if ($t -notmatch '(?m)^zend_extension=.*php_opcache\.dll') { throw "$ver\$iniName`: OPcache zend_extension line not active" }
    }
    elseif ($t -match '(?m)^zend_extension=.*opcache') { throw "$ver\$iniName`: zend_extension line present although $ver has no php_opcache.dll" }
  }
  # Prove it with the interpreter itself when it is there (it is in every bundle)
  $php = Join-Path $dir.FullName 'php.exe'
  if (Test-Path $php) {
    $env:US_ROOTF = $Root -replace '\\', '/'
    # Single quotes only: the argument must survive both PowerShell editions
    $probe = "exit((extension_loaded('Zend OPcache') && ini_get('opcache.enable') === '1') ? 0 : 1);"
    & $php -n -c (Join-Path $dir.FullName 'php_production.ini') -r $probe
    if ($LASTEXITCODE -ne 0) { throw "$ver`: OPcache does not load with php_production.ini" }
  }
  Write-Host "==> $ver`: OPcache on (256M, 20000 files), realpath cache on$(if (-not $hasDll) { ' - built into this PHP' })"
}

# =============================================================================
# Database tool folders: this computer only
# =============================================================================
# Adminer (home\us_opt1, since 2.2.0) logs in as root by itself, and Apache
# listens on every network interface. The bundle ships these blocks with
# 'Require local'; older installations get it here. A block the user set to
# something else than the stock 'Require all granted' stays as it is.
$conf = Join-Path $apache 'conf\httpd.conf'
$t = Read-Text $conf
$limited = @()
foreach ($slot in 'us_opt1', 'us_opt2', 'us_opt3') {
  $block = '(?s)(<Directory "\$\{US_ROOTF\}/home/' + $slot + '/">[^<]*?)Require all granted([^<]*?</Directory>)'
  if ($t -match $block) { $t = $t -replace $block, '$1Require local$2'; $limited += $slot }
}
if ($limited) {
  Write-Text $conf $t
  foreach ($slot in $limited) {
    if ((Read-Text $conf) -notmatch ('(?s)<Directory "\$\{US_ROOTF\}/home/' + $slot + '/">[^<]*?Require local')) { throw "httpd.conf: $slot could not be limited to Require local" }
  }
  Write-Host "==> httpd.conf: $($limited -join ', ') answer on this computer only (Require local)"
} else {
  Write-Host '==> httpd.conf: database tool folders already limited (or changed by hand) - nothing to do'
}

# =============================================================================
# Database: both engines ship tuned
# =============================================================================
# The my.ini of the MariaDB and the MySQL module already carries the
# server-load values (500 connections for 400 Apache threads, larger caches).
# Only the engine in core\mysql is looked at; the one on standby in
# core\db_standby comes from the same modules.
$myIni = Join-Path $Root 'core\mysql\my.ini'
if (-not (Test-Path $myIni)) {
  Write-Host '==> core\mysql\my.ini not found - no database engine installed, nothing to do'
}
elseif ((Read-Text $myIni) -match 'MariaDB configuration for (Uniform Server Reload|winpacho)') {   # header before / after the 2.0 rename
  Write-Host '==> MariaDB my.ini of winpacho detected - it ships tuned, nothing to do'
}
elseif ((Read-Text $myIni) -match "MySQL is the bundle's second database engine") {   # MySQL module since 2.4.0
  Write-Host '==> MySQL my.ini of winpacho 2.4.0 or later detected - it ships tuned, nothing to do'
}
else {
  Write-Host '==> core\mysql\my.ini comes from an older MySQL installation (bundles up to 1.3.5, MySQL module'
  Write-Host '    up to 2.1.x). It stays unchanged. For the tuned engines of the current bundle back up your'
  Write-Host '    databases, replace core\mysql with the MariaDB or MySQL module and restore the backups'
  Write-Host '    (README, "Databases").'
}

Write-Host "==> Server tuning applied to $Root"
