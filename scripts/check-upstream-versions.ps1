# Compare the component versions of the latest winpacho release with
# the newest upstream versions. Run weekly by .github/workflows/upstream-watch.yml;
# a non-zero exit (= failed run, GitHub sends a mail) means: build a new
# release. Locally: pwsh scripts/check-upstream-versions.ps1
#
# The build scripts already fetch the newest PHP/MariaDB/MySQL/Adminer/Apache, so a
# version bump + tag is normally all an update takes. Only for Apache the
# patch-level floor $MinApachePatch in build-bundle.ps1 should be raised too.
#
# Exit codes: 0 = up to date, 1 = updates available, 2 = a check failed
# (a failed check must not look like "up to date").
#
# -Tag vX.Y.Z: compare an older release instead of the latest one.
param(
  [string]$Repo = 'Wolfram33/winpacho',
  [ValidatePattern('^(v\d+\.\d+\.\d+)?$')]
  [string]$Tag = ''
)
$ErrorActionPreference = 'Stop'
$UA = @{ 'User-Agent' = 'winpacho-upstream-watch' }
$TIMEOUT_SEC = 60

function Get-Text([string]$url) {
  (Invoke-WebRequest -Uri $url -Headers $UA -TimeoutSec $TIMEOUT_SEC -UseBasicParsing).Content
}

function Get-Json([string]$url, [hashtable]$headers = $UA) {
  Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec $TIMEOUT_SEC
}

# windows.php.net can publish a version with a suffix (8.3.36-1), which [version]
# rejects. As a fourth part it sorts after 8.3.36 and before 8.3.37.
function ConvertTo-Version([string]$v) {
  [version]($v -replace '-(\d+)$', '.$1')
}

# --- Shipped versions: "Packaged component versions" list of the latest release
$apiHeaders = $UA.Clone()
if ($env:GITHUB_TOKEN) { $apiHeaders['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
$releaseUrl = if ($Tag) { "https://api.github.com/repos/$Repo/releases/tags/$Tag" } else { "https://api.github.com/repos/$Repo/releases/latest" }
$release = Get-Json $releaseUrl $apiHeaders
$body = [string]$release.body
function Get-Shipped([string]$pattern) {
  if ($body -match "(?m)^- $pattern") { return $Matches[1] }
  return $null
}
$shipped = [ordered]@{
  'Apache'      = Get-Shipped 'Apache (\d+\.\d+\.\d+) \(bundle\)'
  'PHP 8.3'     = Get-Shipped 'PHP (\d+\.\d+\.\d+(?:-\d+)?) \(php83\)'
  'PHP 8.4'     = Get-Shipped 'PHP (\d+\.\d+\.\d+(?:-\d+)?) \(php84\)'
  'PHP 8.5'     = Get-Shipped 'PHP (\d+\.\d+\.\d+(?:-\d+)?) \(php85\)'
  'MariaDB'     = Get-Shipped 'MariaDB (\d+\.\d+\.\d+) \(bundle\)'
  'MySQL 8.4'   = Get-Shipped 'MySQL (\d+\.\d+\.\d+) \(bundle\)'
  'Adminer'     = Get-Shipped 'Adminer (\d+\.\d+\.\d+) \(bundle\)'
}
# Shipped since a later release (Adminer 2.2.0 instead of phpMyAdmin, MySQL as
# second engine 2.4.0): older releases do not list them, which is no failed check
$sinceLaterRelease = @('Adminer', 'MySQL 8.4')

# --- Upstream versions: same sources as the build scripts ---------------------
$upstream = [ordered]@{}
$errors = @()

try {
  # apache.org is the authority for releases (Apache Lounge builds follow
  # within days; build-bundle.ps1 takes the newest Lounge build)
  $html = Get-Text 'https://httpd.apache.org/download.cgi'
  $patch = [regex]::Matches($html, 'httpd-2\.4\.(\d+)\.tar') | ForEach-Object { [int]$_.Groups[1].Value } |
    Sort-Object -Descending | Select-Object -First 1
  if ($null -eq $patch) { throw 'no httpd-2.4.x tarball on the download page' }
  $upstream['Apache'] = "2.4.$patch"
} catch { $errors += "Apache: $($_.Exception.Message)" }

try {
  $php = Get-Json 'https://windows.php.net/downloads/releases/releases.json'
  foreach ($branch in '8.3', '8.4', '8.5') {
    $v = $php.$branch.version
    if (-not $v) { throw "branch $branch missing in releases.json" }
    $upstream["PHP $branch"] = $v
  }
} catch { $errors += "PHP: $($_.Exception.Message)" }

try {
  # Newest patch of the shipped series; a new LTS series is picked by the
  # build on its own, the patch level is what matters for security
  if ($shipped['MariaDB'] -notmatch '^(\d+\.\d+)\.') { throw 'shipped MariaDB version unknown' }
  $series = $Matches[1]
  $rel = Get-Json "https://downloads.mariadb.org/rest-api/mariadb/$series/latest/"
  $v = ($rel.releases.PSObject.Properties.Value | Select-Object -First 1).release_id
  if (-not $v) { throw "no release listed for series $series" }
  $upstream['MariaDB'] = $v
} catch { $errors += "MariaDB: $($_.Exception.Message)" }

# MySQL: same source as package-mysql-module.ps1 (newest 8.4.x tag)
try {
  # lowSpeed*: give up on a hanging connection like the HTTP calls' -TimeoutSec
  $tags = & git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=$TIMEOUT_SEC ls-remote --tags 'https://github.com/mysql/mysql-server' 'refs/tags/mysql-8.4.*'
  if ($LASTEXITCODE -ne 0) { throw 'git ls-remote failed' }
  $patch = $tags | ForEach-Object { if ($_ -match 'refs/tags/mysql-8\.4\.(\d+)$') { [int]$Matches[1] } } |
    Sort-Object -Descending | Select-Object -First 1
  if ($null -eq $patch) { throw 'no mysql-8.4.x tag found' }
  $upstream['MySQL 8.4'] = "8.4.$patch"
} catch { $errors += "MySQL: $($_.Exception.Message)" }

try {
  $tag = (Get-Json 'https://api.github.com/repos/vrana/adminer/releases/latest' $apiHeaders).tag_name
  if ($tag -notmatch '^v(\d+\.\d+\.\d+)$') { throw "unexpected release tag '$tag'" }
  $upstream['Adminer'] = $Matches[1]
} catch { $errors += "Adminer: $($_.Exception.Message)" }

# --- Compare and report --------------------------------------------------------
$rows = @()
$updates = 0
foreach ($name in $shipped.Keys) {
  $have = $shipped[$name]
  $new = $upstream[$name]
  $state = 'ok'
  if (-not $have -and $name -in $sinceLaterRelease) { $state = 'not shipped in this release yet' }
  elseif (-not $have) { $state = 'not in release notes'; $errors += "$name`: shipped version not found in release $($release.tag_name)" }
  elseif (-not $new) { $state = 'check failed' }
  else {
    # Uncaught, this would exit 1 and read as "updates available"
    try { if ((ConvertTo-Version $new) -gt (ConvertTo-Version $have)) { $state = 'UPDATE AVAILABLE'; $updates++ } }
    catch { $state = 'check failed'; $errors += "$name`: cannot compare versions '$have' and '$new'" }
  }
  $rows += [pscustomobject]@{ Component = $name; Shipped = $have; Upstream = $new; State = $state }
}

$report = @("## Upstream versions vs. release $($release.tag_name)", '',
            '| Component | Shipped | Upstream | State |', '|---|---|---|---|')
$report += $rows | ForEach-Object { "| $($_.Component) | $($_.Shipped) | $($_.Upstream) | $($_.State) |" }
if ($updates) {
  $report += '', "**$updates update(s) available.** Bump WinpachoController/reload_version.inc, commit, tag and push -",
             'the build fetches the newest versions. For a new Apache also raise $MinApachePatch in scripts/build-bundle.ps1.'
}
if ($errors) { $report += '', '**Checks that failed:**'; $report += $errors | ForEach-Object { "- $_" } }

$report | ForEach-Object { Write-Host $_ }
if ($env:GITHUB_STEP_SUMMARY) { $report | Add-Content -Path $env:GITHUB_STEP_SUMMARY }

if ($errors) { exit 2 }
if ($updates) { exit 1 }
exit 0
