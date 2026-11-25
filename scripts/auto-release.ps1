# Monthly auto release. When a build started now would ship a newer Apache,
# PHP, MariaDB, MySQL or Adminer than the latest release, this script raises
# the version, commits, tags, starts the release build and waits for it.
# Run by .github/workflows/auto-release.yml (1st of each month, or by hand:
# GitHub > Actions > "Monthly auto release" > Run workflow). It needs what a
# GitHub runner has: a checkout of the branch to release from with push
# rights, and the GitHub CLI (gh) with GH_TOKEN.
#
# Version scheme: a component update is a PATCH release (2.4.0 -> 2.4.1).
# MINOR and MAJOR stand for changes to winpacho itself and are only ever
# raised by hand.
#
# What it does, depending on WinpachoController/reload_version.inc:
#   = latest release            raise PATCH, commit, tag, build
#   > latest release, tagged    that release build failed: build the tag again
#   anything else               a release in preparation: do nothing, say so
#
# -DryRun: report what would happen, change nothing.
# Exit codes: 0 = released, or nothing to do; other = failed (reason in the output).
param(
  [string]$Repo = 'Wolfram33/winpacho',
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$VERSION_FILE = 'WinpachoController/reload_version.inc'
$BUNDLE_SCRIPT = 'scripts/build-bundle.ps1'
$BUILD_WORKFLOW = 'build.yml'
$BOT_NAME = 'github-actions[bot]'
$BOT_EMAIL = '41898282+github-actions[bot]@users.noreply.github.com'
# The started build needs a moment to show up in the run list (2 minutes at most)
$RUN_LOOKUP_TRIES = 12
$RUN_LOOKUP_PAUSE_SEC = 10
# Waiting for the build to finish (90 minutes at most; it takes well under an hour)
$BUILD_WAIT_TRIES = 90
$BUILD_WAIT_PAUSE_SEC = 60

function Write-Summary([string[]]$lines) {
  $lines | ForEach-Object { Write-Host $_ }
  if ($env:GITHUB_STEP_SUMMARY) { $lines | Add-Content -Path $env:GITHUB_STEP_SUMMARY }
}

# A failed git/gh call must stop the release instead of being stepped over
function Invoke-Tool([string]$exe, [string[]]$toolArgs) {
  & $exe @toolArgs
  if ($LASTEXITCODE -ne 0) { throw "$exe $($toolArgs -join ' ') failed (exit code $LASTEXITCODE)" }
}

# Replaces the single match of $pattern; none or several mean the file no
# longer looks the way this script expects
function Set-FileValue([string]$path, [string]$pattern, [string]$value) {
  $text = Get-Content $path -Raw
  $count = [regex]::Matches($text, $pattern).Count
  if ($count -ne 1) { throw "$path`: expected exactly one match of $pattern, found $count - adjust scripts/auto-release.ps1 to the new file layout" }
  Set-Content $path -Value ([regex]::Replace($text, $pattern, $value)) -NoNewline
}

# Id of the newest Build run that was started by hand or by this script;
# empty when there is none yet
function Get-NewestBuildRunId {
  Invoke-Tool gh @('run', 'list', '--repo', $Repo, '--workflow', $BUILD_WORKFLOW, '--event', 'workflow_dispatch',
                   '--limit', '1', '--json', 'databaseId', '--jq', '.[].databaseId')
}

# --- Is there anything to release? ---------------------------------------------
$check = & "$PSScriptRoot/check-upstream-versions.ps1" -Repo $Repo -Buildable -PassThru
$checkExit = $LASTEXITCODE
if ($checkExit -eq 0) {
  Write-Summary '', '**No release needed:** the latest release already ships what a build would fetch today.'
  exit 0
}
if ($checkExit -ne 1) {
  Write-Summary '', '**No release started:** a version check failed (listed above), so it is unknown what a build would ship.',
                'Nothing was changed. Run this workflow again later: GitHub > Actions > "Monthly auto release" > Run workflow.'
  exit 2
}
$shipping = ($check.Updates | ForEach-Object { "$(($_.Component -split ' ')[0]) $($_.Upstream)" }) -join ', '

# --- Which version? --------------------------------------------------------------
$released = $check.Release -replace '^v', ''
if ((Get-Content $VERSION_FILE -Raw) -notmatch "US_RELOAD_VERSION\s*=\s*'(\d+\.\d+\.\d+)'") { throw "US_RELOAD_VERSION = 'X.Y.Z' not found in $VERSION_FILE" }
$source = $Matches[1]
$branch = Invoke-Tool git @('branch', '--show-current')
if (-not $branch) { throw 'This checkout is not on a branch (detached HEAD), so there is nowhere to push the version bump to. Run the workflow on the default branch.' }

if ($source -eq $released) {
  $v = [version]$source
  $target = "$($v.Major).$($v.Minor).$($v.Build + 1)"
  $bump = $true
  $plan = "raise the version $source -> $target on branch $branch, tag v$target and build it"
} elseif ([version]$source -lt [version]$released) {
  Write-Summary '', "**No release started:** $VERSION_FILE on branch $branch says $source, but $released is already released.",
                "The branch is behind the latest release. Bring it up to date (it must contain the commit of tag v$released), then run this workflow again."
  exit 0
} elseif (Invoke-Tool git @('ls-remote', '--tags', 'origin', "refs/tags/v$source")) {
  $target = $source
  $bump = $false
  $plan = "build the existing tag v$target again (it has no release yet: its build failed or never ran)"
} else {
  Write-Summary '', "**No release started:** $VERSION_FILE says $source, the latest release is $released, and there is no tag v$source.",
                'That is a release in preparation; the auto release only continues from a released state.',
                "Release $source by hand (commit, git tag v$source, push branch and tag) - the updates ($shipping) ride along,",
                'because the build always fetches the newest components.'
  exit 0
}
$tag = "v$target"
if ($DryRun) {
  Write-Summary '', "**Dry run - nothing was changed.** A real run would ship $shipping`: $plan."
  exit 0
}

# --- Bump, commit, tag, push -----------------------------------------------------
if ($bump) {
  Set-FileValue $VERSION_FILE "(?<=US_RELOAD_VERSION\s*=\s*')\d+\.\d+\.\d+(?=')" $target
  $apache = $check.Updates | Where-Object Component -eq 'Apache'
  # The floor makes the build fail loudly should the Lounge scrape fall back to an older Apache
  if ($apache) { Set-FileValue $BUNDLE_SCRIPT '(?m)(?<=^\$MinApachePatch\s*=\s*)\d+' ($apache.Upstream -split '\.')[2] }
  Invoke-Tool git @('-c', "user.name=$BOT_NAME", '-c', "user.email=$BOT_EMAIL", 'commit', '-m', "Ship $shipping - version $target", '--', $VERSION_FILE, $BUNDLE_SCRIPT)
  Invoke-Tool git @('tag', $tag)
  # --atomic: branch and tag arrive together or not at all (e.g. when the branch moved meanwhile)
  Invoke-Tool git @('push', '--atomic', 'origin', "HEAD:refs/heads/$branch", "refs/tags/$tag")
}

# --- Build the release and wait for it -------------------------------------------
# A push made with the workflow token starts no other workflow, so the build
# is started explicitly; build.yml publishes a release for a started v* tag.
$runBefore = Get-NewestBuildRunId
Invoke-Tool gh @('workflow', 'run', $BUILD_WORKFLOW, '--repo', $Repo, '--ref', $tag)
$runId = $null
foreach ($try in 1..$RUN_LOOKUP_TRIES) {
  Start-Sleep -Seconds $RUN_LOOKUP_PAUSE_SEC
  $newest = Get-NewestBuildRunId
  if ($newest -and "$newest" -ne "$runBefore") { $runId = "$newest"; break }
}
if (-not $runId) { throw "The release build for $tag was started but did not show up in the run list. Look at GitHub > Actions > Build: when it succeeds the release is published, when it fails run this workflow again." }
$runUrl = "https://github.com/$Repo/actions/runs/$runId"
Write-Host "==> Waiting for the release build: $runUrl"

$conclusion = $null
foreach ($try in 1..$BUILD_WAIT_TRIES) {
  Start-Sleep -Seconds $BUILD_WAIT_PAUSE_SEC
  $run = Invoke-Tool gh @('run', 'view', $runId, '--repo', $Repo, '--json', 'status,conclusion') | ConvertFrom-Json
  if ($run.status -eq 'completed') { $conclusion = $run.conclusion; break }
}
if (-not $conclusion) {
  Write-Summary '', "**Release $target is still building** after $($BUILD_WAIT_TRIES * $BUILD_WAIT_PAUSE_SEC / 60) minutes of waiting - $runUrl",
                'Only the waiting ended: the build goes on and publishes the release when it succeeds.',
                'Do not start this workflow again while that build runs.'
  exit 2
}
if ($conclusion -eq 'success') {
  # A green build is not yet a release: the build.yml of an older tag skips
  # its release job when started this way
  $null = & gh release view $tag --repo $Repo --json tagName 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Summary '', "**Release $target did not come out:** the build for tag $tag succeeded, but published no release - $runUrl",
                  "The latest release is still $released. Its job 'Publish release' did not run or left nothing behind;",
                  'building this tag again will not change that. Release the next version by hand instead.'
    exit 2
  }
}
if ($conclusion -ne 'success') {
  Write-Summary '', "**Release $target did not come out:** the build for tag $tag ended as '$conclusion' - $runUrl",
                "Nothing was published; the latest release is still $released. Once the cause is gone, run this workflow again:",
                "it builds tag $tag again without raising the version. If the fix needs a code change, release the next",
                'version by hand instead (a tag stays on its commit).'
  exit 2
}
Write-Summary '', "**Released winpacho $target** ($shipping): https://github.com/$Repo/releases/tag/$tag"
if ($bump) { Write-Summary "The version bump is a new commit on branch $branch - run git pull before your next commit." }
exit 0
