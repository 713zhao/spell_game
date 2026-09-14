<#
.SYNOPSIS
  Scans the immediate subfolders of a directory, identifies which ones are git
  repositories, reports their remote link and whether they are fully committed
  and pushed, and (optionally) deletes the ones that are up to date.

.PARAMETER Path
  Directory whose immediate subfolders will be scanned. If omitted, you will
  be prompted for it interactively.

.PARAMETER Delete
  Actually delete folders confirmed to be up to date (all changes committed
  and pushed to their remote). Without this switch the script only reports
  what it WOULD delete - nothing is removed (dry run). Each deletion prompts
  for confirmation (Yes/No/Yes to All/No to All) before it happens; pass
  -Confirm:$false to delete without prompting.

.PARAMETER ReportPath
  Where to write the markdown report. Defaults to "repo-status-report.md"
  inside Path. A JSON file and an HTML file are also written alongside it,
  using the same base file name (e.g. "repo-status-report.json/.html").

.PARAMETER SkipFetch
  Skip "git fetch" before comparing against the remote. Faster and works
  offline, but the ahead/behind comparison may be stale.

.PARAMETER SummaryPath
  Where to write the cumulative summary markdown report. Defaults to
  "C:\report\repo-status-summary.md" (the folder is created if missing).
  A JSON and HTML file are also written alongside it (same base name).
  Unlike the per-run report, the summary persists across runs: each folder
  is keyed by its full path, so re-scanning the same folder updates its
  existing row instead of duplicating it, and folders found in earlier
  runs (from other -Path scans) stay listed until scanned again.

.EXAMPLE
  .\check-repo-status.ps1
  Prompts for the folder to scan, then writes the report only (dry run).

.EXAMPLE
  .\check-repo-status.ps1 -Path "C:\ZJB\archive\spell"
  Dry run against a specific folder: writes the report, deletes nothing.

.EXAMPLE
  .\check-repo-status.ps1 -Path "C:\ZJB\archive\spell" -Delete
  Writes the report AND deletes folders that are fully committed and pushed.

.EXAMPLE
  .\check-repo-status.ps1 -Path "C:\ZJB\archive\spell" -Delete -WhatIf
  Shows which folders would be deleted without actually deleting them.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$Path,
    [switch]$Delete,
    [string]$ReportPath,
    [switch]$SkipFetch,
    [string]$SummaryPath
)

while ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Read-Host "Enter the folder path to scan (its immediate subfolders will be checked)"
}

if (-not (Test-Path $Path)) { throw "Path not found: $Path" }
$Path = (Resolve-Path $Path).Path

if (-not $ReportPath) {
    $ReportPath = Join-Path $Path "repo-status-report.md"
}

$reportDir = Split-Path $ReportPath -Parent
if (-not $reportDir) { $reportDir = $Path }
$reportBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
$JsonPath = Join-Path $reportDir "$reportBaseName.json"
$HtmlPath = Join-Path $reportDir "$reportBaseName.html"

if (-not $SummaryPath) {
    $SummaryPath = "C:\report\repo-status-summary.md"
}
$summaryDir = Split-Path $SummaryPath -Parent
if (-not $summaryDir) { $summaryDir = (Get-Location).Path }
if (-not (Test-Path $summaryDir)) { New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null }
$summaryBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SummaryPath)
$SummaryJsonPath = Join-Path $summaryDir "$summaryBaseName.json"
$SummaryHtmlPath = Join-Path $summaryDir "$summaryBaseName.html"

function Get-GitInfo {
    param([string]$FolderPath)

    $result = [ordered]@{
        Name        = Split-Path $FolderPath -Leaf
        IsRepo      = $false
        RemoteUrl   = $null
        Branch      = $null
        HasUpstream = $false
        Dirty       = $false
        Ahead       = $null
        Behind      = $null
        UpToDate    = $false
        Status      = $null
    }

    $gitMarker = Join-Path $FolderPath ".git"
    if (-not (Test-Path $gitMarker)) {
        $result.Status = "Not a git repository"
        return $result
    }

    Push-Location $FolderPath
    try {
        $insideCheck = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0 -or $insideCheck -ne "true") {
            $result.Status = "Not a valid git repository (corrupt or unreadable .git)"
            return $result
        }
        $result.IsRepo = $true

        $remoteUrl = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $remoteUrl) {
            $result.RemoteUrl = $remoteUrl.Trim()
        }

        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { $result.Branch = $branch.Trim() }

        $porcelain = git status --porcelain 2>$null
        $result.Dirty = [bool]$porcelain

        $upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $upstream) {
            $result.HasUpstream = $true

            if (-not $SkipFetch) {
                git fetch --quiet 2>$null | Out-Null
            }

            $counts = git rev-list --left-right --count "HEAD...@{u}" 2>$null
            if ($LASTEXITCODE -eq 0 -and $counts) {
                $parts = $counts.Trim() -split "\s+"
                $result.Ahead = [int]$parts[0]
                $result.Behind = [int]$parts[1]
            }
        }

        if (-not $result.RemoteUrl) {
            $result.Status = "Git repo, but no remote configured"
        }
        elseif (-not $result.HasUpstream) {
            $result.Status = "Git repo, current branch has no upstream (not pushed)"
        }
        elseif ($result.Dirty) {
            $result.Status = "Uncommitted changes"
        }
        elseif ($result.Ahead -gt 0) {
            $result.Status = "Ahead of remote by $($result.Ahead) commit(s) - not pushed"
        }
        else {
            # Everything local is committed and pushed (nothing ahead, working tree clean).
            # Being behind just means the remote has commits this checkout never pulled -
            # nothing local would be lost, so this still counts as safe to delete.
            $result.UpToDate = $true
            if ($result.Behind -gt 0) {
                $result.Status = "Up to date locally (committed and pushed); remote is $($result.Behind) commit(s) ahead"
            }
            else {
                $result.Status = "Up to date (committed and pushed)"
            }
        }
    }
    finally {
        Pop-Location
    }

    return $result
}

function Remove-FolderSafely {
    param([string]$FolderPath)

    try {
        Remove-Item -Path $FolderPath -Recurse -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Could not fully delete '$FolderPath': $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This usually means a file inside is locked by another process (Explorer, an editor, antivirus, a terminal cd'd into it, etc). Close whatever is using it and re-run the scan to finish the delete." -ForegroundColor Red
        return $false
    }
}

function Get-AutoCommitMessage {
    param([string]$FolderPath)

    $fallback = "New update"

    Push-Location $FolderPath
    try {
        $statusLines = @(git status --porcelain 2>$null)
    }
    finally {
        Pop-Location
    }

    if (-not $statusLines -or $statusLines.Count -eq 0) {
        return $fallback
    }

    $files = $statusLines | ForEach-Object {
        if ($_.Length -ge 3) { $_.Substring(3).Trim() }
    } | Where-Object { $_ }

    if (-not $files -or $files.Count -eq 0) {
        return $fallback
    }

    $sample = $files | Select-Object -First 3
    $summary = "Update " + ($sample -join ", ")
    if ($files.Count -gt 3) {
        $summary += ", +$($files.Count - 3) more"
    }

    return $summary
}

$folders = Get-ChildItem -Path $Path -Directory -Force | Where-Object { $_.Name -ne ".git" }

$rows = @()
foreach ($folder in $folders) {
    $info = Get-GitInfo -FolderPath $folder.FullName
    $remoteDisplay = if ($info.RemoteUrl) { $info.RemoteUrl } elseif ($info.IsRepo) { "(git repo, no remote configured)" } else { "(not a git repo)" }
    Write-Host "Scanning: $($folder.Name)  ->  $remoteDisplay" -ForegroundColor Cyan

    $action = "Kept"
    $needsRemediation = $Delete -and $info.IsRepo -and $info.HasUpstream -and -not $info.UpToDate -and ($info.Dirty -or $info.Ahead -gt 0)

    if ($needsRemediation) {
        $originalLocation = (Get-Location).Path

        Write-Host ""
        Write-Host "=== $($folder.Name): not fully committed/pushed ===" -ForegroundColor Yellow
        Set-Location $folder.FullName
        git status
        Write-Host ""

        $doCommit = Read-Host "Commit and push these changes now for '$($folder.Name)'? (y/N)"
        if ($doCommit -match '^(y|yes)$') {
            $commitFailed = $false
            if ($info.Dirty) {
                $commitMsg = Get-AutoCommitMessage -FolderPath $folder.FullName
                Write-Host "Auto commit message: $commitMsg" -ForegroundColor Cyan
                git add -A
                git commit -m $commitMsg | Out-Host
                if ($LASTEXITCODE -ne 0) { $commitFailed = $true }
            }

            if ($commitFailed) {
                Write-Host "Commit failed for $($folder.Name). Leaving folder in place." -ForegroundColor Red
                $action = "Kept (commit failed)"
                Set-Location $originalLocation
            }
            else {
                git push | Out-Host
                $pushExitCode = $LASTEXITCODE
                Set-Location $originalLocation

                if ($pushExitCode -ne 0) {
                    Write-Host "Push failed for $($folder.Name). Leaving folder in place." -ForegroundColor Red
                    $action = "Kept (push failed)"
                }
                else {
                    $info = Get-GitInfo -FolderPath $folder.FullName
                    if ($info.UpToDate) {
                        $doDelete = Read-Host "Push succeeded. Delete folder '$($folder.Name)' now? (y/N)"
                        if ($doDelete -match '^(y|yes)$') {
                            if (Remove-FolderSafely -FolderPath $folder.FullName) {
                                $action = "Deleted (after commit+push)"
                            }
                            else {
                                $action = "Kept (committed+pushed, delete failed - folder locked)"
                            }
                        }
                        else {
                            $action = "Kept (committed+pushed, delete declined)"
                        }
                    }
                    else {
                        $action = "Kept (still not fully synced: $($info.Status))"
                    }
                }
            }
        }
        else {
            Set-Location $originalLocation
            Write-Host "Warning: '$($folder.Name)' still has changes that are NOT committed/pushed - deleting now would lose them." -ForegroundColor Red
            $doDeleteAnyway = Read-Host "Delete folder '$($folder.Name)' anyway? (y/N)"
            if ($doDeleteAnyway -match '^(y|yes)$') {
                if (Remove-FolderSafely -FolderPath $folder.FullName) {
                    $action = "Deleted (commit/push declined - uncommitted changes lost)"
                }
                else {
                    $action = "Kept (commit/push declined, delete failed - folder locked)"
                }
            }
            else {
                $action = "Kept (commit/push declined)"
            }
        }
    }
    elseif ($info.UpToDate) {
        if ($Delete) {
            if ($PSCmdlet.ShouldProcess($folder.FullName, "Delete folder (up to date)")) {
                if (Remove-FolderSafely -FolderPath $folder.FullName) {
                    $action = "Deleted"
                }
                else {
                    $action = "Kept (delete failed - folder locked)"
                }
            }
            else {
                $action = "Would delete (skipped by -WhatIf)"
            }
        }
        else {
            $action = "Would delete (dry run - rerun with -Delete)"
        }
    }

    $rows += [pscustomobject]@{
        Name      = $info.Name
        FullPath  = $folder.FullName
        IsRepo    = $info.IsRepo
        RemoteUrl = $info.RemoteUrl
        Branch    = $info.Branch
        Status    = $info.Status
        UpToDate  = $info.UpToDate
        Action    = $action
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Git Repo Status Report")
[void]$sb.AppendLine()
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine()
[void]$sb.AppendLine("Scanned path: ``$Path``")
[void]$sb.AppendLine()
if ($Delete) {
    [void]$sb.AppendLine("Mode: **DELETE** - folders marked ``Deleted`` below were removed by this run.")
}
else {
    [void]$sb.AppendLine("Mode: **Dry run** - no folders were deleted. Re-run with ``-Delete`` to remove folders marked *up to date*.")
}
[void]$sb.AppendLine()
[void]$sb.AppendLine("| Folder | Repo? | Remote URL | Branch | Status | Action |")
[void]$sb.AppendLine("|---|---|---|---|---|---|")

foreach ($row in $rows) {
    $repoMark = if ($row.IsRepo) { "Yes" } else { "**NOT A REPO**" }
    $remote = if ($row.RemoteUrl) { $row.RemoteUrl } else { "-" }
    $branch = if ($row.Branch) { $row.Branch } else { "-" }
    $status = if ($row.IsRepo) { $row.Status } else { "**$($row.Status)**" }
    [void]$sb.AppendLine("| $($row.Name) | $repoMark | $remote | $branch | $status | $($row.Action) |")
}

[void]$sb.AppendLine()
$notRepoCount = ($rows | Where-Object { -not $_.IsRepo }).Count
$upToDateCount = ($rows | Where-Object { $_.UpToDate }).Count
[void]$sb.AppendLine("**Summary:** $($rows.Count) folder(s) scanned, $upToDateCount up to date, $notRepoCount not a valid git repo.")

$sb.ToString() | Out-File -FilePath $ReportPath -Encoding utf8

# JSON report
$reportObject = [ordered]@{
    generatedAt   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    scannedPath   = $Path
    mode          = if ($Delete) { "delete" } else { "dry-run" }
    upToDateCount = ($rows | Where-Object { $_.UpToDate }).Count
    notRepoCount  = ($rows | Where-Object { -not $_.IsRepo }).Count
    folders       = $rows
}
$reportObject | ConvertTo-Json -Depth 5 | Out-File -FilePath $JsonPath -Encoding utf8

# HTML report
function HtmlEncode([string]$text) {
    if ($null -eq $text) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($text)
}

$htmlRows = foreach ($row in $rows) {
    $rowClass = if (-not $row.IsRepo) { "not-repo" }
    elseif ($row.UpToDate) { "up-to-date" }
    elseif ($row.Action -eq "Deleted") { "deleted" }
    else { "" }

    $repoMark = if ($row.IsRepo) { "Yes" } else { "NOT A REPO" }
    $remote = if ($row.RemoteUrl) { "<a href=`"$(HtmlEncode $row.RemoteUrl)`">$(HtmlEncode $row.RemoteUrl)</a>" } else { "-" }
    $branch = if ($row.Branch) { HtmlEncode $row.Branch } else { "-" }

    "<tr class=`"$rowClass`"><td>$(HtmlEncode $row.Name)</td><td>$repoMark</td><td>$remote</td><td>$branch</td><td>$(HtmlEncode $row.Status)</td><td>$(HtmlEncode $row.Action)</td></tr>"
}

$modeText = if ($Delete) { "DELETE - folders marked 'Deleted' below were removed by this run." } else { "Dry run - no folders were deleted. Re-run with -Delete to remove folders marked up to date." }

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Git Repo Status Report</title>
<style>
  body { font-family: -apple-system, Segoe UI, Arial, sans-serif; margin: 2rem; color: #1a1a1a; background: #fff; }
  h1 { font-size: 1.4rem; }
  .meta { color: #555; margin-bottom: 1rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ddd; padding: 6px 10px; text-align: left; font-size: 0.9rem; }
  th { background: #f2f2f2; }
  tr.not-repo { background: #fdecea; font-weight: bold; color: #a4262c; }
  tr.up-to-date { background: #eaf7ea; }
  tr.deleted { background: #eee; color: #777; text-decoration: line-through; }
  .summary { margin-top: 1rem; font-weight: bold; }
</style>
</head>
<body>
<h1>Git Repo Status Report</h1>
<div class="meta">
  Generated: $(HtmlEncode (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))<br>
  Scanned path: $(HtmlEncode $Path)<br>
  Mode: $(HtmlEncode $modeText)
</div>
<table>
<thead><tr><th>Folder</th><th>Repo?</th><th>Remote URL</th><th>Branch</th><th>Status</th><th>Action</th></tr></thead>
<tbody>
$($htmlRows -join "`n")
</tbody>
</table>
<div class="summary">Summary: $($rows.Count) folder(s) scanned, $($reportObject.upToDateCount) up to date, $($reportObject.notRepoCount) not a valid git repo.</div>
</body>
</html>
"@

$html | Out-File -FilePath $HtmlPath -Encoding utf8

# --- Cumulative summary report (md/json/html) -------------------------------
# Keyed by full folder path: a folder already in the summary gets its row
# updated in place; a folder not seen before gets appended.
$summaryEntries = [ordered]@{}
if (Test-Path $SummaryJsonPath) {
    try {
        $existing = Get-Content -Path $SummaryJsonPath -Raw | ConvertFrom-Json
        foreach ($e in @($existing)) {
            if ($e.FullPath) {
                $summaryEntries[$e.FullPath] = [ordered]@{
                    FullPath    = $e.FullPath
                    Name        = $e.Name
                    ScannedPath = $e.ScannedPath
                    IsRepo      = $e.IsRepo
                    RemoteUrl   = $e.RemoteUrl
                    Branch      = $e.Branch
                    Status      = $e.Status
                    UpToDate    = $e.UpToDate
                    Action      = $e.Action
                    FirstSeen   = $e.FirstSeen
                    LastChecked = $e.LastChecked
                }
            }
        }
    }
    catch {
        Write-Host "Warning: could not parse existing summary at $SummaryJsonPath - starting a fresh summary." -ForegroundColor Yellow
    }
}

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
foreach ($row in $rows) {
    $firstSeen = $now
    if ($summaryEntries.Contains($row.FullPath)) {
        $firstSeen = $summaryEntries[$row.FullPath].FirstSeen
    }
    $summaryEntries[$row.FullPath] = [ordered]@{
        FullPath    = $row.FullPath
        Name        = $row.Name
        ScannedPath = $Path
        IsRepo      = $row.IsRepo
        RemoteUrl   = $row.RemoteUrl
        Branch      = $row.Branch
        Status      = $row.Status
        UpToDate    = $row.UpToDate
        Action      = $row.Action
        FirstSeen   = $firstSeen
        LastChecked = $now
    }
}

$summaryList = $summaryEntries.Values | Sort-Object FullPath

# Summary JSON
$summaryList | ConvertTo-Json -Depth 5 | Out-File -FilePath $SummaryJsonPath -Encoding utf8

# Summary Markdown
$ssb = New-Object System.Text.StringBuilder
[void]$ssb.AppendLine("# Git Repo Status Summary")
[void]$ssb.AppendLine()
[void]$ssb.AppendLine("Last updated: $now")
[void]$ssb.AppendLine()
[void]$ssb.AppendLine("This report accumulates results across every scan run. Each folder is keyed by its full path - rescanning a folder updates its row in place instead of duplicating it.")
[void]$ssb.AppendLine()
[void]$ssb.AppendLine("| Folder | Full Path | Repo? | Remote URL | Branch | Status | Action | First Seen | Last Checked |")
[void]$ssb.AppendLine("|---|---|---|---|---|---|---|---|---|")
foreach ($e in $summaryList) {
    $repoMark = if ($e.IsRepo) { "Yes" } else { "**NOT A REPO**" }
    $remote = if ($e.RemoteUrl) { $e.RemoteUrl } else { "-" }
    $branch = if ($e.Branch) { $e.Branch } else { "-" }
    $status = if ($e.IsRepo) { $e.Status } else { "**$($e.Status)**" }
    [void]$ssb.AppendLine("| $($e.Name) | $($e.FullPath) | $repoMark | $remote | $branch | $status | $($e.Action) | $($e.FirstSeen) | $($e.LastChecked) |")
}
[void]$ssb.AppendLine()
$summaryNotRepo = ($summaryList | Where-Object { -not $_.IsRepo }).Count
$summaryUpToDate = ($summaryList | Where-Object { $_.UpToDate }).Count
$summaryDeleted = ($summaryList | Where-Object { $_.Action -like "Deleted*" }).Count
[void]$ssb.AppendLine("**Totals:** $($summaryList.Count) folder(s) tracked, $summaryUpToDate up to date, $summaryDeleted deleted, $summaryNotRepo not a valid git repo.")
$ssb.ToString() | Out-File -FilePath $SummaryPath -Encoding utf8

# Summary HTML
$summaryHtmlRows = foreach ($e in $summaryList) {
    $rowClass = if (-not $e.IsRepo) { "not-repo" }
    elseif ($e.Action -like "Deleted*") { "deleted" }
    elseif ($e.UpToDate) { "up-to-date" }
    else { "" }

    $repoMark = if ($e.IsRepo) { "Yes" } else { "NOT A REPO" }
    $remote = if ($e.RemoteUrl) { "<a href=`"$(HtmlEncode $e.RemoteUrl)`">$(HtmlEncode $e.RemoteUrl)</a>" } else { "-" }
    $branch = if ($e.Branch) { HtmlEncode $e.Branch } else { "-" }

    "<tr class=`"$rowClass`"><td>$(HtmlEncode $e.Name)</td><td>$(HtmlEncode $e.FullPath)</td><td>$repoMark</td><td>$remote</td><td>$branch</td><td>$(HtmlEncode $e.Status)</td><td>$(HtmlEncode $e.Action)</td><td>$(HtmlEncode $e.FirstSeen)</td><td>$(HtmlEncode $e.LastChecked)</td></tr>"
}

$summaryHtml = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Git Repo Status Summary</title>
<style>
  body { font-family: -apple-system, Segoe UI, Arial, sans-serif; margin: 2rem; color: #1a1a1a; background: #fff; }
  h1 { font-size: 1.4rem; }
  .meta { color: #555; margin-bottom: 1rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ddd; padding: 6px 10px; text-align: left; font-size: 0.85rem; }
  th { background: #f2f2f2; }
  tr.not-repo { background: #fdecea; font-weight: bold; color: #a4262c; }
  tr.up-to-date { background: #eaf7ea; }
  tr.deleted { background: #eee; color: #777; text-decoration: line-through; }
  .summary { margin-top: 1rem; font-weight: bold; }
</style>
</head>
<body>
<h1>Git Repo Status Summary</h1>
<div class="meta">Last updated: $(HtmlEncode $now)<br>Accumulates results across every scan run - rescanning a folder updates its row instead of duplicating it.</div>
<table>
<thead><tr><th>Folder</th><th>Full Path</th><th>Repo?</th><th>Remote URL</th><th>Branch</th><th>Status</th><th>Action</th><th>First Seen</th><th>Last Checked</th></tr></thead>
<tbody>
$($summaryHtmlRows -join "`n")
</tbody>
</table>
<div class="summary">Totals: $($summaryList.Count) folder(s) tracked, $summaryUpToDate up to date, $summaryDeleted deleted, $summaryNotRepo not a valid git repo.</div>
</body>
</html>
"@
$summaryHtml | Out-File -FilePath $SummaryHtmlPath -Encoding utf8

Write-Host ""
Write-Host "Reports written:"
Write-Host "  Markdown: $ReportPath"
Write-Host "  JSON:     $JsonPath"
Write-Host "  HTML:     $HtmlPath"
Write-Host "Summary updated:"
Write-Host "  Markdown: $SummaryPath"
Write-Host "  JSON:     $SummaryJsonPath"
Write-Host "  HTML:     $SummaryHtmlPath"
if (-not $Delete) {
    Write-Host "Dry run only - no folders were deleted. Re-run with -Delete to remove folders marked 'Up to date'."
}
