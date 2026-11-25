# Finds the newest Apache 2.4.x win64 build on Apache Lounge - the build the
# bundle ships. Dot-source it:
#   . "$PSScriptRoot/apache-lounge.ps1"
# Shared by build-bundle.ps1 (downloads that build) and
# check-upstream-versions.ps1 -Buildable (asks whether a release would ship a
# newer Apache), so both always agree on what the newest build is.

$APACHE_LOUNGE_URL = 'https://www.apachelounge.com/download/'
# Browser User-Agent for the page and the download
$APACHE_LOUNGE_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'

function Find-HttpdZip([string]$html) {
  # Accept anything between the patch level and -win64 (build dates, openssl
  # tags, ...) and any compiler tag: newest patch, then newest VS wins.
  # Case-insensitive: Lounge spells it "Win64-VS18" as well as "win64-vs18".
  [regex]::Matches($html, 'httpd-2\.4\.(\d+)[\w.-]*?-win64-VS(\d+)\.zip', 'IgnoreCase') |
    ForEach-Object { [pscustomobject]@{ Patch = [int]$_.Groups[1].Value; VS = [int]$_.Groups[2].Value; Name = $_.Value } } |
    Sort-Object Patch, VS -Descending | Select-Object -First 1
}

# Returns the newest build: Patch (the 71 of 2.4.71), VS (compiler tag, part
# of the download path) and Name (zip file name). Throws when the page cannot
# be read or lists no build.
function Get-ApacheLoungeBuild {
  # curl.exe on Windows: in Windows PowerShell plain "curl" is an alias of Invoke-WebRequest
  $curl = if ($env:OS -eq 'Windows_NT') { 'curl.exe' } else { 'curl' }
  # Time limits: a hanging server must not block the CI job until GitHub kills it
  $curlArgs = @('-fsSL', '--connect-timeout', '30', '--max-time', '120', '--retry', '3', '-A', $APACHE_LOUNGE_UA)
  $dlHtml = (& $curl @curlArgs $APACHE_LOUNGE_URL) -join "`n"
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch Apache Lounge download page' }
  $found = Find-HttpdZip $dlHtml
  if (-not $found) {
    # Zips may live on per-compiler subpages (e.g. /download/VS18/): follow the
    # newest one referenced on the main page
    $vsPages = [regex]::Matches($dlHtml, 'download/VS(\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique -Descending
    foreach ($vs in $vsPages) {
      Write-Host "==> Scanning subpage /download/VS$vs/"
      $subHtml = (& $curl @curlArgs "${APACHE_LOUNGE_URL}VS$vs/") -join "`n"
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
  return $found
}
