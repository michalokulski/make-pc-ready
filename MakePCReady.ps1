param (
    [string]$LogPath = $(if (Test-Path "$env:USERPROFILE\Desktop") { "$env:USERPROFILE\Desktop\MakePCReady.log" } else { "$env:TEMP\MakePCReady.log" }),
    [switch]$SkipInteractiveSelection
)

# ============================================================================
# MakePCReady.ps1 — Console TUI App Installer
# ============================================================================
# Dot-sources lib\PCSetup.Common.psm1 for all shared logic.
# Only defines the collapsible-tree TUI selector; everything else is shared.
# ============================================================================

$script:logFile = $LogPath
$script:logStartTime = Get-Date

# Import shared module
Import-Module -Force (Join-Path -Path $PSScriptRoot -ChildPath "lib\PCSetup.Common.psm1")

# ============================================================================
# Collapsible Tree TUI Selector
# ============================================================================

function Show-InteractiveAppSelector {
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Catalog
    )

    $selection = @($Catalog | ForEach-Object {
        [PSCustomObject]@{
            Group       = $_.Group
            SubGroup    = $_.SubGroup
            Action      = $_.Action
            Id          = $_.Id
            Name        = $_.Name
            Selected    = [bool]$_.DefaultSelected
            IsInstalled = [bool]$_.IsInstalled
        }
    })

    if (-not $Host.UI.RawUI) {
        Write-Log "Interactive console features are unavailable. Falling back to defaults." -Level "WARNING"
        return $selection | Where-Object { $_.Selected }
    }

    # Build group/subgroup collapse state from catalog order
    $groupState = [ordered]@{}
    $currentGroup = ""
    $currentSubGroup = ""
    for ($i = 0; $i -lt $selection.Count; $i++) {
        $entry = $selection[$i]
        if ($entry.Group -ne $currentGroup) {
            $currentGroup = $entry.Group
            $currentSubGroup = ""
            if (-not $groupState.Contains($currentGroup)) {
                $groupState[$currentGroup] = @{ Collapsed = $false; SubGroups = [ordered]@{} }
            }
        }
        if ($entry.SubGroup -ne $currentSubGroup) {
            $currentSubGroup = $entry.SubGroup
            if (-not $groupState[$currentGroup].SubGroups.Contains($currentSubGroup)) {
                $groupState[$currentGroup].SubGroups[$currentSubGroup] = @{ Collapsed = $false }
            }
        }
    }

    $cursorRow = 0
    $statusMessage = ""
    $filterText = ""
    $hideInstalled = $false

    while ($true) {
        [Console]::CursorVisible = $false

        # Build visible rows: Group headers, SubGroup headers, and Items
        $visibleRows = [System.Collections.ArrayList]::new()
        $seenGroups = @{}
        $seenSubGroups = @{}

        # Determine which item indices pass the filter
        $filteredIndexes = @()
        for ($i = 0; $i -lt $selection.Count; $i++) {
            $entry = $selection[$i]
            $matchesFilter = [string]::IsNullOrWhiteSpace($filterText) -or
                ($entry.Name -like "*$filterText*") -or
                ($entry.Group -like "*$filterText*") -or
                ($entry.SubGroup -like "*$filterText*")
            $matchesHide = (-not $hideInstalled) -or (-not [bool]$entry.IsInstalled)
            if ($matchesFilter -and $matchesHide) {
                $filteredIndexes += $i
            }
        }

        foreach ($i in $filteredIndexes) {
            $entry = $selection[$i]
            $g = $entry.Group
            $sg = $entry.SubGroup
            $sgKey = "$g|$sg"

            if (-not $seenGroups.ContainsKey($g)) {
                [void]$visibleRows.Add(@{ Type = 'Group'; GroupName = $g })
                $seenGroups[$g] = $true
            }

            if ($groupState[$g].Collapsed) { continue }

            if (-not [string]::IsNullOrWhiteSpace($sg) -and -not $seenSubGroups.ContainsKey($sgKey)) {
                [void]$visibleRows.Add(@{ Type = 'SubGroup'; GroupName = $g; SubGroupName = $sg })
                $seenSubGroups[$sgKey] = $true
            }

            if (-not [string]::IsNullOrWhiteSpace($sg) -and
                $groupState[$g].SubGroups.Contains($sg) -and
                $groupState[$g].SubGroups[$sg].Collapsed) { continue }

            [void]$visibleRows.Add(@{ Type = 'Item'; Index = $i })
        }

        # Clamp cursor
        if ($visibleRows.Count -eq 0) { $cursorRow = 0 }
        elseif ($cursorRow -ge $visibleRows.Count) { $cursorRow = $visibleRows.Count - 1 }
        elseif ($cursorRow -lt 0) { $cursorRow = 0 }

        # Viewport calculations
        $windowHeight = [Math]::Max(22, $Host.UI.RawUI.WindowSize.Height)
        $maxVisible = [Math]::Max(6, $windowHeight - 14)
        $maxTop = [Math]::Max(0, $visibleRows.Count - $maxVisible)
        $topPos = [Math]::Min($maxTop, [Math]::Max(0, $cursorRow - [int]($maxVisible / 2)))
        $bottomPos = [Math]::Min($visibleRows.Count, $topPos + $maxVisible)

        # Stats
        $selectedCount = @($selection | Where-Object { $_.Selected }).Count
        $installedCount = @($selection | Where-Object { $_.IsInstalled }).Count
        $totalCount = $selection.Count

        # Render
        [Console]::Clear()
        Write-Host ("=" * 72) -ForegroundColor Cyan
        Write-Host "  MakePCReady - Setup Studio" -ForegroundColor Cyan
        Write-Host ("=" * 72) -ForegroundColor Cyan
        Write-Host ("  Selected: {0}/{1}  |  Installed: {2}  |  Visible: {3} rows" -f $selectedCount, $totalCount, $installedCount, $visibleRows.Count) -ForegroundColor Gray
        Write-Host ("  Filter: {0}  |  Hide installed: {1}" -f $(if ([string]::IsNullOrWhiteSpace($filterText)) { "<none>" } else { $filterText }), $(if ($hideInstalled) { "ON" } else { "OFF" })) -ForegroundColor Gray
        Write-Host ""

        if ($visibleRows.Count -eq 0) {
            Write-Host "  No items match current filter/view." -ForegroundColor Yellow
            Write-Host "  Press F to set filter, R to clear, H to toggle hide-installed." -ForegroundColor DarkYellow
        }
        else {
            for ($r = $topPos; $r -lt $bottomPos; $r++) {
                $row = $visibleRows[$r]
                $isCursor = ($r -eq $cursorRow)
                $pointer = if ($isCursor) { ">" } else { " " }

                switch ($row.Type) {
                    'Group' {
                        $gName = $row.GroupName
                        $gs = $groupState[$gName]
                        $arrow = if ($gs.Collapsed) { "+" } else { "-" }

                        $gItems = @($selection | Where-Object { $_.Group -eq $gName })
                        $gSel = @($gItems | Where-Object { $_.Selected }).Count
                        $gTotal = $gItems.Count

                        $line = " {0} [{1}] {2} ({3}/{4} selected)" -f $pointer, $arrow, $gName, $gSel, $gTotal
                        if ($isCursor) { Write-Host $line -ForegroundColor Yellow }
                        else { Write-Host $line -ForegroundColor Cyan }
                    }
                    'SubGroup' {
                        $gName = $row.GroupName
                        $sgName = $row.SubGroupName
                        $sgs = $groupState[$gName].SubGroups[$sgName]
                        $arrow = if ($sgs.Collapsed) { "+" } else { "-" }

                        $sgItems = @($selection | Where-Object { $_.Group -eq $gName -and $_.SubGroup -eq $sgName })
                        $sgSel = @($sgItems | Where-Object { $_.Selected }).Count
                        $sgTotal = $sgItems.Count

                        $line = " {0}    [{1}] {2} ({3}/{4})" -f $pointer, $arrow, $sgName, $sgSel, $sgTotal
                        if ($isCursor) { Write-Host $line -ForegroundColor Yellow }
                        else { Write-Host $line -ForegroundColor DarkCyan }
                    }
                    'Item' {
                        $entry = $selection[$row.Index]
                        $mark = if ($entry.Selected) { "[x]" } else { "[ ]" }

                        $tag = ""
                        if ($entry.IsInstalled) { $tag = "(Installed)" }
                        elseif (-not [string]::IsNullOrWhiteSpace($entry.Action)) { $tag = "(Action)" }
                        else { $tag = "(Not installed)" }

                        $line = " {0}        {1} {2}  {3}" -f $pointer, $mark, $entry.Name, $tag
                        if ($isCursor) { Write-Host $line -ForegroundColor Yellow }
                        elseif ($entry.IsInstalled) { Write-Host $line -ForegroundColor DarkGray }
                        else { Write-Host $line }
                    }
                }
            }
        }

        Write-Host ""
        Write-Host "  Up/Down/Home/End/PgUp/PgDn: Navigate   Space: Toggle item or group" -ForegroundColor DarkGray
        Write-Host "  Left/Right: Collapse/Expand   Tab: Next group   Enter: Start installation" -ForegroundColor DarkGray
        Write-Host "  A: Select all  N: Select none  F: Filter  R: Reset filter  H: Hide installed  Esc: Quit" -ForegroundColor DarkGray

        if ($visibleRows.Count -gt $maxVisible) {
            Write-Host ("  Showing rows {0}-{1} of {2}" -f ($topPos + 1), $bottomPos, $visibleRows.Count) -ForegroundColor DarkGray
        }

        if ($visibleRows.Count -gt 0 -and $cursorRow -lt $visibleRows.Count) {
            $focusRow = $visibleRows[$cursorRow]
            switch ($focusRow.Type) {
                'Group' { Write-Host ("  Focus: {0} (group)" -f $focusRow.GroupName) -ForegroundColor DarkCyan }
                'SubGroup' { Write-Host ("  Focus: {0} > {1} (subgroup)" -f $focusRow.GroupName, $focusRow.SubGroupName) -ForegroundColor DarkCyan }
                'Item' {
                    $fi = $selection[$focusRow.Index]
                    Write-Host ("  Focus: {0} | {1} > {2}" -f $fi.Name, $fi.Group, $fi.SubGroup) -ForegroundColor DarkCyan
                }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($statusMessage)) {
            Write-Host "  $statusMessage" -ForegroundColor DarkYellow
        }

        # Input
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $statusMessage = ""

        switch ($key.VirtualKeyCode) {
            38 { # Up
                if ($visibleRows.Count -gt 0) {
                    if ($cursorRow -gt 0) { $cursorRow-- }
                    else { $cursorRow = $visibleRows.Count - 1 }
                }
                continue
            }
            40 { # Down
                if ($visibleRows.Count -gt 0) {
                    if ($cursorRow -lt $visibleRows.Count - 1) { $cursorRow++ }
                    else { $cursorRow = 0 }
                }
                continue
            }
            36 { # Home
                $cursorRow = 0
                continue
            }
            35 { # End
                $cursorRow = [Math]::Max(0, $visibleRows.Count - 1)
                continue
            }
            33 { # PageUp
                $cursorRow = [Math]::Max(0, $cursorRow - $maxVisible)
                continue
            }
            34 { # PageDown
                $cursorRow = [Math]::Min([Math]::Max(0, $visibleRows.Count - 1), $cursorRow + $maxVisible)
                continue
            }
            37 { # Left - collapse current or parent group/subgroup
                if ($visibleRows.Count -gt 0 -and $cursorRow -lt $visibleRows.Count) {
                    $row = $visibleRows[$cursorRow]
                    if ($row.Type -eq 'Group') {
                        $groupState[$row.GroupName].Collapsed = $true
                    }
                    elseif ($row.Type -eq 'SubGroup') {
                        $groupState[$row.GroupName].SubGroups[$row.SubGroupName].Collapsed = $true
                    }
                    elseif ($row.Type -eq 'Item') {
                        $entry = $selection[$row.Index]
                        if (-not [string]::IsNullOrWhiteSpace($entry.SubGroup) -and
                            $groupState[$entry.Group].SubGroups.Contains($entry.SubGroup)) {
                            $groupState[$entry.Group].SubGroups[$entry.SubGroup].Collapsed = $true
                        }
                        else {
                            $groupState[$entry.Group].Collapsed = $true
                        }
                    }
                }
                continue
            }
            39 { # Right - expand group/subgroup
                if ($visibleRows.Count -gt 0 -and $cursorRow -lt $visibleRows.Count) {
                    $row = $visibleRows[$cursorRow]
                    if ($row.Type -eq 'Group') {
                        $groupState[$row.GroupName].Collapsed = $false
                    }
                    elseif ($row.Type -eq 'SubGroup') {
                        $groupState[$row.GroupName].SubGroups[$row.SubGroupName].Collapsed = $false
                    }
                }
                continue
            }
            9 { # Tab - jump to next group header
                if ($visibleRows.Count -gt 0) {
                    $found = $false
                    for ($r = $cursorRow + 1; $r -lt $visibleRows.Count; $r++) {
                        if ($visibleRows[$r].Type -eq 'Group') {
                            $cursorRow = $r
                            $found = $true
                            break
                        }
                    }
                    if (-not $found) {
                        for ($r = 0; $r -lt $cursorRow; $r++) {
                            if ($visibleRows[$r].Type -eq 'Group') {
                                $cursorRow = $r
                                break
                            }
                        }
                    }
                }
                continue
            }
            32 { # Space - toggle item, or toggle all in group/subgroup
                if ($visibleRows.Count -gt 0 -and $cursorRow -lt $visibleRows.Count) {
                    $row = $visibleRows[$cursorRow]
                    switch ($row.Type) {
                        'Group' {
                            $gName = $row.GroupName
                            $gItems = @($selection | Where-Object { $_.Group -eq $gName })
                            $allSelected = @($gItems | Where-Object { $_.Selected }).Count -eq $gItems.Count
                            $newState = -not $allSelected
                            foreach ($item in $gItems) { $item.Selected = $newState }
                        }
                        'SubGroup' {
                            $gName = $row.GroupName
                            $sgName = $row.SubGroupName
                            $sgItems = @($selection | Where-Object { $_.Group -eq $gName -and $_.SubGroup -eq $sgName })
                            $allSelected = @($sgItems | Where-Object { $_.Selected }).Count -eq $sgItems.Count
                            $newState = -not $allSelected
                            foreach ($item in $sgItems) { $item.Selected = $newState }
                        }
                        'Item' {
                            $selection[$row.Index].Selected = -not $selection[$row.Index].Selected
                        }
                    }
                }
                continue
            }
            13 { # Enter - confirm selection
                [Console]::CursorVisible = $true
                $selectedNow = @($selection | Where-Object { $_.Selected })

                [Console]::Clear()
                Write-Host ("=" * 72) -ForegroundColor Cyan
                Write-Host "  Confirm Selection" -ForegroundColor Cyan
                Write-Host ("=" * 72) -ForegroundColor Cyan

                if ($selectedNow.Count -eq 0) {
                    Write-Host "  No items selected. Select at least one item before starting." -ForegroundColor Yellow
                    Write-Host "  Press any key to return..." -ForegroundColor DarkGray
                    [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    continue
                }

                Write-Host ("  {0} item(s) selected:" -f $selectedNow.Count) -ForegroundColor Gray
                Write-Host ""
                $cg = ""
                foreach ($entry in $selectedNow) {
                    if ($entry.Group -ne $cg) {
                        $cg = $entry.Group
                        Write-Host "  $cg" -ForegroundColor Cyan
                    }
                    Write-Host ("    - {0}" -f $entry.Name)
                }

                Write-Host ""
                Write-Host "  Start installation?  Y = Yes  |  N = Go back  |  Esc = Quit" -ForegroundColor Yellow

                while ($true) {
                    $confirmKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    if ($confirmKey.VirtualKeyCode -eq 27) {
                        Write-Log "User canceled during confirmation. Exiting..." -Level "WARNING"
                        exit 0
                    }
                    $ch = $confirmKey.Character.ToString().ToUpperInvariant()
                    if ($ch -eq "Y") { return $selectedNow }
                    if ($ch -eq "N") { break }
                }
                continue
            }
            27 { # Escape
                [Console]::CursorVisible = $true
                Write-Log "User canceled application selection. Exiting..." -Level "WARNING"
                exit 0
            }
        }

        # Letter key handling
        if (-not [char]::IsControl($key.Character)) {
            switch ($key.Character.ToString().ToUpperInvariant()) {
                "A" {
                    foreach ($e in $selection) { $e.Selected = $true }
                    continue
                }
                "N" {
                    foreach ($e in $selection) { $e.Selected = $false }
                    continue
                }
                "H" {
                    $hideInstalled = -not $hideInstalled
                    $statusMessage = if ($hideInstalled) { "Hide installed: ON" } else { "Hide installed: OFF" }
                    continue
                }
                "R" {
                    $filterText = ""
                    $statusMessage = "Filter cleared."
                    continue
                }
                "F" {
                    [Console]::CursorVisible = $true
                    Write-Host ""
                    $newFilter = Read-Host "  Filter (name/group/subgroup, blank to clear)"
                    $filterText = $newFilter
                    $statusMessage = if ([string]::IsNullOrWhiteSpace($filterText)) { "Filter cleared." } else { "Filter: $filterText" }
                    continue
                }
                default {
                    $statusMessage = "Unknown key. Use arrows, Space, Enter, A, N, F, R, H, Tab, Esc."
                }
            }
        }
    }
}

# ============================================================================
# Entry Point
# ============================================================================

Invoke-PCSetup -SkipInteractiveSelection:$SkipInteractiveSelection -ShowSelector ${function:Show-InteractiveAppSelector}