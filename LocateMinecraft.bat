<# : batch part - runs the PowerShell code below from this same file
@echo off
setlocal
set "LM_SELF=%~f0"
set "LM_RUN=& ([scriptblock]::Create((Get-Content -LiteralPath $env:LM_SELF -Raw -Encoding UTF8)))"
if "%~1"=="" (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "%LM_RUN%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "%LM_RUN% %*"
)
exit /b
#>
<#
  마인크래프트 월드 폴더 찾기
  자바에디션 / 베드락에디션 / 교육용에디션의 월드 폴더를 찾아 목록으로 보여주고,
  선택한 월드 폴더를 탐색기로 열어줍니다.

  사용법:
    LocateMinecraft.bat 더블클릭      -> 창(GUI) 실행
    LocateMinecraft.bat -List         -> 콘솔에 목록만 출력

  이 파일 하나에 배치 실행부와 PowerShell 코드가 함께 들어 있습니다.
#>
param(
    [switch]$List
)

$ErrorActionPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# 월드 폴더(상위 폴더) 찾기
# ---------------------------------------------------------------------------

function New-Root($edition, $path) {
    [pscustomobject]@{ Edition = $edition; Path = $path }
}

# 지정한 폴더 아래에서 'minecraftWorlds' 폴더를 깊이 제한을 두고 찾습니다.
function Find-MinecraftWorldsDirs($dir, $maxDepth) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }
    if ((Split-Path -Leaf $dir) -eq 'minecraftWorlds') { return @($dir) }
    if ($maxDepth -le 0) { return @() }
    $found = @()
    foreach ($child in (Get-ChildItem -LiteralPath $dir -Directory -Force)) {
        foreach ($d in (Find-MinecraftWorldsDirs $child.FullName ($maxDepth - 1))) { $found += $d }
    }
    return $found
}

function Get-WorldRoots {
    $roots = @()
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA

    # --- 자바에디션 -------------------------------------------------------
    if ($appData) {
        $dotMc = Join-Path $appData '.minecraft'
        $roots += New-Root '자바에디션' (Join-Path $dotMc 'saves')

        # 런처 설정에서 사용자가 바꾼 게임 폴더(gameDir)도 확인
        foreach ($name in 'launcher_profiles.json', 'launcher_profiles_microsoft_store.json') {
            $profileFile = Join-Path $dotMc $name
            if (Test-Path -LiteralPath $profileFile) {
                $json = Get-Content -LiteralPath $profileFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($json -and $json.profiles) {
                    foreach ($p in $json.profiles.PSObject.Properties) {
                        $gameDir = $p.Value.gameDir
                        if ($gameDir) { $roots += New-Root '자바에디션' (Join-Path $gameDir 'saves') }
                    }
                }
            }
        }
    }

    # --- 베드락 / 교육용 (Microsoft Store 앱 패키지 폴더) -------------------
    $packages = @(
        @{ Name = 'Microsoft.MinecraftUWP_8wekyb3d8bbwe';            Edition = '베드락에디션' },
        @{ Name = 'Microsoft.MinecraftWindowsBeta_8wekyb3d8bbwe';    Edition = '베드락 프리뷰' },
        @{ Name = 'Microsoft.MinecraftEducationEdition_8wekyb3d8bbwe'; Edition = '교육용에디션' },
        @{ Name = 'Microsoft.MinecraftEducationPreview_8wekyb3d8bbwe'; Edition = '교육용 프리뷰' }
    )
    if ($localAppData) {
        foreach ($pkg in $packages) {
            $base = Join-Path $localAppData "Packages\$($pkg.Name)"
            foreach ($d in (Find-MinecraftWorldsDirs $base 6)) { $roots += New-Root $pkg.Edition $d }
        }
    }

    # --- 베드락 (새 버전, %APPDATA%\Minecraft Bedrock\Users\<계정>\...) ------
    # --- 교육용 (설치 프로그램 버전, %APPDATA%\Minecraft Education Edition\...) -
    if ($appData) {
        $appDataDirs = @(
            @{ Name = 'Minecraft Bedrock';                 Edition = '베드락에디션' },
            @{ Name = 'Minecraft Bedrock Preview';         Edition = '베드락 프리뷰' },
            @{ Name = 'Minecraft Education Edition';       Edition = '교육용에디션' },
            @{ Name = 'Minecraft Education Edition Preview'; Edition = '교육용 프리뷰' }
        )
        foreach ($a in $appDataDirs) {
            $base = Join-Path $appData $a.Name
            foreach ($d in (Find-MinecraftWorldsDirs $base 6)) { $roots += New-Root $a.Edition $d }
        }
    }

    # 존재하는 폴더만, 중복 없이
    $seen = @{}
    $result = @()
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r.Path -PathType Container)) { continue }
        $full = (Resolve-Path -LiteralPath $r.Path).ProviderPath.TrimEnd('\', '/')
        $key = $full.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $result += New-Root $r.Edition $full
    }
    return $result
}

# ---------------------------------------------------------------------------
# 개별 월드 목록
# ---------------------------------------------------------------------------

function Get-Worlds($roots) {
    $worlds = @()
    foreach ($root in $roots) {
        foreach ($dir in (Get-ChildItem -LiteralPath $root.Path -Directory -Force)) {
            # 베드락/교육용 월드는 폴더 이름이 무작위 문자열이라 levelname.txt에서 실제 이름을 읽음
            $name = $dir.Name
            $levelName = Join-Path $dir.FullName 'levelname.txt'
            if (Test-Path -LiteralPath $levelName) {
                $text = (Get-Content -LiteralPath $levelName -Raw -Encoding UTF8)
                if ($text -and $text.Trim()) { $name = $text.Trim() }
            }

            $levelDat = Join-Path $dir.FullName 'level.dat'
            if (Test-Path -LiteralPath $levelDat) {
                $modified = (Get-Item -LiteralPath $levelDat -Force).LastWriteTime
            } else {
                $modified = $dir.LastWriteTime
            }

            $worlds += [pscustomobject]@{
                Edition  = $root.Edition
                Name     = $name
                Modified = $modified
                Path     = $dir.FullName
                Root     = $root.Path
            }
        }
    }
    return $worlds | Sort-Object -Property Modified -Descending
}

function Open-Folder($path) {
    if ($path -and (Test-Path -LiteralPath $path)) {
        Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$path`""
    }
}

# ---------------------------------------------------------------------------
# 콘솔 모드
# ---------------------------------------------------------------------------

if ($List) {
    $roots = Get-WorldRoots
    if (-not $roots) { Write-Output '마인크래프트 월드 폴더를 찾지 못했습니다.'; return }
    Write-Output '[월드 폴더]'
    $roots | Format-Table -AutoSize Edition, Path | Out-String -Width 400 | Write-Output
    Write-Output '[월드 목록]'
    Get-Worlds $roots | Format-Table -AutoSize Edition, Name, Modified, Path | Out-String -Width 400 | Write-Output
    return
}

# ---------------------------------------------------------------------------
# 창(GUI) 모드
# ---------------------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$font = New-Object System.Drawing.Font('Malgun Gothic', 10)

$form = New-Object System.Windows.Forms.Form
$form.Text = '마인크래프트 월드 폴더 찾기'
$form.Size = New-Object System.Drawing.Size(960, 560)
$form.MinimumSize = New-Object System.Drawing.Size(640, 360)
$form.StartPosition = 'CenterScreen'
$form.Font = $font

# 상단: 에디션별 월드 폴더 바로 열기 버튼
$topPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$topPanel.Dock = 'Top'
$topPanel.AutoSize = $true
$topPanel.Padding = New-Object System.Windows.Forms.Padding(8)

# 하단: 선택한 월드에 대한 버튼
$bottomPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$bottomPanel.Dock = 'Bottom'
$bottomPanel.AutoSize = $true
$bottomPanel.Padding = New-Object System.Windows.Forms.Padding(8)

$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $true
$status.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)

$listView = New-Object System.Windows.Forms.ListView
$listView.Dock = 'Fill'
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.MultiSelect = $false
$listView.HideSelection = $false
[void]$listView.Columns.Add('에디션', 120)
[void]$listView.Columns.Add('월드 이름', 220)
[void]$listView.Columns.Add('마지막 수정', 150)
[void]$listView.Columns.Add('폴더 경로', 440)

function New-Button($text, $onClick) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.AutoSize = $true
    $b.Padding = New-Object System.Windows.Forms.Padding(6, 2, 6, 2)
    $b.Add_Click($onClick)
    return $b
}

function Get-SelectedWorld {
    if ($listView.SelectedItems.Count -eq 0) { return $null }
    return $listView.SelectedItems[0].Tag
}

function Refresh-All {
    $form.Cursor = 'WaitCursor'
    $listView.BeginUpdate()
    $listView.Items.Clear()
    $topPanel.Controls.Clear()

    $roots = @(Get-WorldRoots)
    foreach ($root in $roots) {
        $p = $root.Path
        $b = New-Button "$($root.Edition) 월드 폴더 열기" { Open-Folder $this.Tag }
        $b.Tag = $p
        $tip = New-Object System.Windows.Forms.ToolTip
        $tip.SetToolTip($b, $p)
        $topPanel.Controls.Add($b)
    }

    $worlds = @(Get-Worlds $roots)
    foreach ($w in $worlds) {
        $item = New-Object System.Windows.Forms.ListViewItem($w.Edition)
        [void]$item.SubItems.Add($w.Name)
        [void]$item.SubItems.Add($w.Modified.ToString('yyyy-MM-dd HH:mm'))
        [void]$item.SubItems.Add($w.Path)
        $item.Tag = $w
        [void]$listView.Items.Add($item)
    }
    $listView.EndUpdate()

    if ($roots.Count -eq 0) {
        $status.Text = '마인크래프트 월드 폴더를 찾지 못했습니다. 게임을 한 번 실행해 월드를 만든 뒤 다시 시도하세요.'
    } else {
        $status.Text = "월드 폴더 $($roots.Count)곳, 월드 $($worlds.Count)개를 찾았습니다. (더블클릭하면 폴더가 열립니다)"
    }
    $form.Cursor = 'Default'
}

$btnOpen = New-Button '선택한 월드 폴더 열기' {
    $w = Get-SelectedWorld
    if ($w) { Open-Folder $w.Path }
}
$btnCopy = New-Button '경로 복사' {
    $w = Get-SelectedWorld
    if ($w) {
        [System.Windows.Forms.Clipboard]::SetText($w.Path)
        $status.Text = "복사했습니다: $($w.Path)"
    }
}
$btnRefresh = New-Button '새로고침' { Refresh-All }

$bottomPanel.Controls.AddRange(@($btnOpen, $btnCopy, $btnRefresh, $status))

$listView.Add_DoubleClick({
    $w = Get-SelectedWorld
    if ($w) { Open-Folder $w.Path }
})

# Fill 컨트롤을 먼저 추가해야 Top/Bottom 패널과 겹치지 않음
$form.Controls.Add($listView)
$form.Controls.Add($topPanel)
$form.Controls.Add($bottomPanel)

$form.Add_Shown({ Refresh-All })
[void]$form.ShowDialog()
