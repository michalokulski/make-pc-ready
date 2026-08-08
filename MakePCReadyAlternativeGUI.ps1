param(
  [string]$LogPath = $(if (Test-Path "$env:USERPROFILE\Desktop") { "$env:USERPROFILE\Desktop\MakePCReady.log" } else { "$env:TEMP\MakePCReady.log" }),
  [switch]$SkipInteractiveSelection
)

# ============================================================================
# MakePCReadyAlternativeGUI.ps1 — WPF GUI App Installer
# ============================================================================
# Dot-sources lib\PCSetup.Common.psm1 for all shared logic.
# Only defines the WPF GUI selector; everything else is shared.
# ============================================================================

$script:logFile = $LogPath
$script:logStartTime = Get-Date

# Import shared module
Import-Module -Force (Join-Path -Path $PSScriptRoot -ChildPath "lib\PCSetup.Common.psm1")

# ============================================================================
# WPF GUI Selector
# ============================================================================

function Show-InteractiveAppSelector {
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Catalog
  )

  Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

  $selection = @($Catalog | ForEach-Object {
      [pscustomobject]@{
        Group = $_.Group
        SubGroup = $_.SubGroup
        Action = $_.Action
        Id = $_.Id
        Name = $_.Name
        Selected = [bool]$_.DefaultSelected
        IsInstalled = [bool]$_.IsInstalled
      }
    })

  $sync = [hashtable]::Synchronized(@{ Result = $null })

  $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="MakePCReady - Setup Studio" Height="700" Width="900"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip">
    <DockPanel Margin="10">
        <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
            <TextBlock Text="Select applications to install:" FontSize="16" FontWeight="Bold" Margin="0,0,0,5"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="SearchBox" Grid.Column="0" Margin="0,0,10,0"
                         TextChanged="SearchBox_TextChanged"/>
                <CheckBox x:Name="HideInstalledCheck" Grid.Column="1"
                          Content="Hide installed" VerticalAlignment="Center" Margin="0,0,10,0"
                          Checked="HideInstalledCheck_Changed" Unchecked="HideInstalledCheck_Changed"/>
                <StackPanel Grid.Column="2" Orientation="Horizontal">
                    <Button x:Name="SelectAllBtn" Content="All" Width="40" Margin="0,0,5,0"
                            Click="SelectAllBtn_Click"/>
                    <Button x:Name="SelectNoneBtn" Content="None" Width="50"
                            Click="SelectNoneBtn_Click"/>
                </StackPanel>
            </Grid>
        </StackPanel>

        <ScrollViewer DockPanel.Dock="Top" Height="480" VerticalScrollBarVisibility="Auto">
            <TreeView x:Name="AppTree" VirtualizingPanel.IsVirtualizing="True"/>
        </ScrollViewer>

        <StackPanel DockPanel.Dock="Bottom" Margin="0,10,0,0">
            <TextBlock x:Name="StatusText" Text="Ready." Foreground="Gray" Margin="0,0,0,5"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="CountText" Grid.Column="0" VerticalAlignment="Center"
                           Text="0 items selected" Foreground="Gray"/>
                <Button x:Name="CancelBtn" Grid.Column="1" Content="Cancel" Width="80"
                        Margin="0,0,10,0" Click="CancelBtn_Click"/>
                <Button x:Name="InstallBtn" Grid.Column="2" Content="Install" Width="80"
                        IsDefault="True" Click="InstallBtn_Click"/>
            </Grid>
        </StackPanel>
    </DockPanel>
</Window>
'@

  $window = [Windows.Markup.XamlReader]::Parse($xaml)
  $tree = $window.FindName("AppTree")
  $searchBox = $window.FindName("SearchBox")
  $hideCheck = $window.FindName("HideInstalledCheck")
  $countText = $window.FindName("CountText")

  # Build tree
  $groups = [ordered]@{}
  foreach ($item in $selection) {
    if (-not $groups.Contains($item.Group)) {
      $groups[$item.Group] = [ordered]@{}
    }
    if (-not $groups[$item.Group].Contains($item.SubGroup)) {
      $groups[$item.Group][$item.SubGroup] = @()
    }
    $groups[$item.Group][$item.SubGroup] += $item
  }

  function Update-Count {
    $sel = @($selection | Where-Object { $_.Selected }).Count
    $countText.Text = "$sel / $($selection.Count) items selected"
  }

  function Refresh-Tree {
    param([string]$Filter = "")

    $tree.Items.Clear()
    $filterLower = $Filter.ToLowerInvariant()
    $hideInstalled = $hideCheck.IsChecked -eq $true

    foreach ($groupName in $groups.Keys) {
      $groupNode = New-Object Windows.Controls.TreeViewItem
      $groupNode.Header = $groupName
      $groupNode.IsExpanded = $true
      $groupVisible = $false

      foreach ($sgName in $groups[$groupName].Keys) {
        $sgNode = New-Object Windows.Controls.TreeViewItem
        $sgNode.Header = $sgName
        $sgNode.IsExpanded = $true
        $sgVisible = $false

        foreach ($item in $groups[$groupName][$sgName]) {
          if ($filterLower -and
            $item.Name.ToLowerInvariant() -notmatch $filterLower -and
            $item.Group.ToLowerInvariant() -notmatch $filterLower -and
            $item.SubGroup.ToLowerInvariant() -notmatch $filterLower) {
            continue
          }
          if ($hideInstalled -and $item.IsInstalled) { continue }

          $cb = New-Object Windows.Controls.CheckBox
          $cb.Content = $item.Name
          $cb.IsChecked = $item.Selected
          if ($item.IsInstalled) {
            $cb.Content = "$($item.Name) (Installed)"
            $cb.Foreground = [Windows.Media.Brushes]::Gray
          }
          elseif ($item.Action) {
            $cb.Content = "$($item.Name) (Action)"
          }

          $cb.Tag = $item
          $cb.Add_Click({
              $item.Selected = $cb.IsChecked -eq $true
              Update-Count
            })

          $itemNode = New-Object Windows.Controls.TreeViewItem
          $itemNode.Header = $cb
          [void]$sgNode.Items.Add($itemNode)
          $sgVisible = $true
        }

        if ($sgVisible) {
          [void]$groupNode.Items.Add($sgNode)
          $groupVisible = $true
        }
      }

      if ($groupVisible) {
        [void]$tree.Items.Add($groupNode)
      }
    }

    Update-Count
  }

  Refresh-Tree

  $searchBox.Add_TextChanged({ Refresh-Tree -Filter $searchBox.Text })
  $hideCheck.Add_Checked({ Refresh-Tree -Filter $searchBox.Text })
  $hideCheck.Add_Unchecked({ Refresh-Tree -Filter $searchBox.Text })

  $window.FindName("SelectAllBtn").Add_Click({
      foreach ($item in $selection) { $item.Selected = $true }
      Refresh-Tree -Filter $searchBox.Text
    })

  $window.FindName("SelectNoneBtn").Add_Click({
      foreach ($item in $selection) { $item.Selected = $false }
      Refresh-Tree -Filter $searchBox.Text
    })

  $window.FindName("InstallBtn").Add_Click({
      $sync.Result = @($selection | Where-Object { $_.Selected })
      $window.Close()
    })

  $window.FindName("CancelBtn").Add_Click({
      $sync.Result = $null
      $window.Close()
    })

  $window.Add_Closing({
      if ($null -eq $sync.Result) {
        Write-Log "User canceled application selection. Exiting..." -Level "WARNING"
        exit 0
      }
    })

  $window.ShowDialog() | Out-Null

  if ($null -eq $sync.Result) {
    Write-Log "User canceled application selection. Exiting..." -Level "WARNING"
    exit 0
  }

  return $sync.Result
}

# ============================================================================
# Entry Point
# ============================================================================

Invoke-PCSetup -SkipInteractiveSelection:$SkipInteractiveSelection -ShowSelector ${function:Show-InteractiveAppSelector}
