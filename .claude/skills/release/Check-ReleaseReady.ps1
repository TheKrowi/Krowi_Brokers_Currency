<#
.SYNOPSIS
Preflight checks before running the Krowi Addon Manager "Full Package" for Krowi_Brokers_Currency.

.DESCRIPTION
Exits 0 when the repo is ready to release, 1 when something blocks it. Warnings do not block.

.PARAMETER Version
Expected release version (e.g. 9.1). When given, the TOC and changelog must match it.

.PARAMETER AllowUntracked
Do not fail on untracked files. Only use when the user has confirmed they belong in the release commit.
#>
param(
    [string]$Version,
    [switch]$AllowUntracked
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$addonManager = 'E:\World of Warcraft Addon Development\Krowi_AddonManager'
$python = Join-Path $addonManager '.venv\Scripts\python.exe'
$mainPy = Join-Path $addonManager 'Krowi_AddonManager_Python\main.py'
$toc = Join-Path $repo 'Krowi_Brokers_Currency.toc'
$changelog = Join-Path $repo '_Packaging\Changelog.md'
$today = Get-Date -Format 'yyyy-MM-dd'

$failures = 0
function Pass($msg) { Write-Host "  OK    $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  WARN  $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "  FAIL  $msg" -ForegroundColor Red; $script:failures++ }

Write-Host "Release preflight for $repo"

# --- Branch -----------------------------------------------------------------
$branch = (git -C $repo rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq 'dev') { Pass "On branch dev" } else { Fail "On branch '$branch'; releases are made from dev" }

git -C $repo fetch origin dev --quiet 2>$null
$behind = [int](git -C $repo rev-list --count HEAD..origin/dev)
$ahead = [int](git -C $repo rev-list --count origin/dev..HEAD)
if ($behind -gt 0) { Fail "Behind origin/dev by $behind commit(s); pull first" } else { Pass "Not behind origin/dev (ahead by $ahead)" }

# --- Working tree -----------------------------------------------------------
$status = @(git -C $repo status --porcelain --untracked-files=all)
$untracked = @($status | Where-Object { $_ -match '^\?\?' } | ForEach-Object { $_.Substring(3) })
$modified = @($status | Where-Object { $_ -notmatch '^\?\?' } | ForEach-Object { $_.Substring(3) })

if ($modified.Count -gt 0) {
    Warn "Modified files that will be included in the release commit:"
    $modified | ForEach-Object { Write-Host "          $_" }
}
if ($untracked.Count -gt 0) {
    $embedded = @($untracked | Where-Object {
        $full = Join-Path $repo $_
        (Test-Path -LiteralPath $full -PathType Container) -and
        (Get-ChildItem -LiteralPath $full -Recurse -Force -Filter '.git' -ErrorAction SilentlyContinue | Select-Object -First 1)
    })
    $msg = "Untracked files present; 'git add .' will commit them:"
    if ($AllowUntracked) { Warn $msg } else { Fail $msg }
    $untracked | ForEach-Object { Write-Host "          $_" }
    if ($embedded.Count -gt 0) { Fail "Untracked path(s) contain a .git entry (embedded repo or worktree): $($embedded -join ', ')" }
} else {
    Pass "No untracked files"
}

# --- Submodules (Libs/) -----------------------------------------------------
# The zip is built from the working tree, so every Libs/ submodule must be checked out.
# 'git add .' commits whatever commit each submodule is on, so a drifted pointer ships silently.
$subs = @(git -C $repo submodule status)
if ($subs.Count -eq 0) {
    Warn "No submodules reported; expected Libs/Krowi_Util, Krowi_Menu, Krowi_Currency, Krowi_Brokers"
}
foreach ($line in $subs) {
    $flag = $line.Substring(0, 1)
    $parts = ($line.Substring(1).Trim() -split '\s+', 3)
    $path = $parts[1]
    $desc = if ($parts.Count -ge 3) { $parts[2] } else { '' }
    switch ($flag) {
        '-' { Fail "Submodule $path is not initialized; run 'git submodule update --init --recursive' or the zip will ship without it" }
        '+' { Warn "Submodule $path is on a different commit than recorded in HEAD $desc; 'git add .' will commit the new pointer" }
        'U' { Fail "Submodule $path has merge conflicts" }
        default { Pass "Submodule $path $desc" }
    }
    if ($flag -ne '-') {
        $dirty = @(git -C (Join-Path $repo $path) status --porcelain 2>$null)
        if ($dirty.Count -gt 0) { Warn "Submodule $path has local changes; they will be zipped but not committed anywhere" }
    }
}

# --- Changelog --------------------------------------------------------------
$clText = Get-Content $changelog -Raw
$header = [regex]::Match($clText, '(?m)^## (\S+)(?: - (\d{4}-\d{2}-\d{2}))?\s*$')
$clVersion = $null
if (-not $header.Success) {
    Fail "No '## <version>' header found in _Packaging/Changelog.md"
} else {
    $clVersion = $header.Groups[1].Value
    $clDate = $header.Groups[2].Value
    if (-not $clDate) {
        Fail "Top changelog entry '## $clVersion' has no date; needs '## $clVersion - $today'"
    } elseif ($clDate -ne $today) {
        Fail "Top changelog entry is dated $clDate but today is $today; the release date must be the day the release is made"
    } else {
        Pass "Top changelog entry: $clVersion - $clDate"
    }
    $body = $clText.Substring($header.Index + $header.Length)
    $next = [regex]::Match($body, '(?m)^## ')
    if ($next.Success) { $body = $body.Substring(0, $next.Index) }
    $bullets = @($body -split "`n" | Where-Object { $_ -match '^\s*- \S' })
    if ($bullets.Count -eq 0) { Fail "Top changelog entry has no bullet points" }
}

# --- TOC version ------------------------------------------------------------
$tocVersion = (Select-String -Path $toc -Pattern '^## Version:\s*(\S+)').Matches[0].Groups[1].Value
if ($clVersion -and $tocVersion -ne $clVersion) {
    Fail "TOC version is $tocVersion but changelog top entry is $clVersion; bump '## Version:' in the TOC"
} else {
    Pass "TOC version: $tocVersion"
}
if ($Version -and $tocVersion -ne $Version) { Fail "Expected version $Version, TOC has $tocVersion" }
if ($Version -and $clVersion -and $clVersion -ne $Version) { Fail "Expected version $Version, changelog has $clVersion" }

$interface = (Select-String -Path $toc -Pattern '^## Interface:\s*(.+)$').Matches[0].Groups[1].Value
Warn "TOC Interface: $interface  (multi-flavor list: Retail, Mists Classic, TBC Anniversary, Classic Era; confirm each matches the live game builds)"

foreach ($key in 'X-CurseForge-ID', 'X-Wago-ID') {
    $m = Select-String -Path $toc -Pattern "^## ${key}:\s*(\S+)"
    if ($m) { Pass "$key present" } else { Fail "$key missing from TOC; the addon manager refuses to upload without it" }
}

# --- Tag --------------------------------------------------------------------
$tag = $tocVersion
if (git -C $repo tag -l $tag) { Fail "Tag $tag already exists locally" }
elseif (git -C $repo ls-remote --tags origin "refs/tags/$tag") { Fail "Tag $tag already exists on origin" }
else { Pass "Tag $tag does not exist yet" }

# --- Tooling ----------------------------------------------------------------
if (Test-Path $python) { Pass "Python venv found" } else { Fail "Python venv missing: $python" }
if (Test-Path $mainPy) { Pass "Addon manager found" } else { Fail "Addon manager missing: $mainPy" }

# --- Result -----------------------------------------------------------------
Write-Host ""
if ($failures -eq 0) {
    Write-Host "READY. Run from $(Split-Path $mainPy):" -ForegroundColor Green
    Write-Host "  & `"$python`" main.py --addon Krowi_Brokers_Currency --operation package --stability stable"
    exit 0
} else {
    Write-Host "NOT READY: $failures blocking issue(s)." -ForegroundColor Red
    exit 1
}
