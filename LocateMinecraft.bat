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
  제작: 스티브코딩
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

# Label : 화면에 보이는 이름 (예: "베드락 (현재)")
# Group : 같은 게임끼리 묶는 키. 같은 그룹에 현재 폴더가 있으면 이전 버전 폴더는 숨김
# Order : 화면에 보여줄 순서
function New-Root($label, $path, $group, $order, $legacy) {
    [pscustomobject]@{
        Edition = $label; Path = $path; Group = $group; Order = $order
        Legacy = [bool]$legacy; Hidden = $false
    }
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

# ...\Users\<계정ID>\games\... 경로에서 계정을 짧게 표시할 이름을 만듭니다.
function Get-AccountLabel($path) {
    if ($path -match '\\Users\\([^\\]+)\\') {
        $id = $Matches[1]
        if ($id.Length -gt 4) { return "계정 …$($id.Substring($id.Length - 4))" }
        return "계정 $id"
    }
    return $null
}

function Get-WorldRoots {
    $roots = @()
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA

    # --- 자바에디션 -------------------------------------------------------
    if ($appData) {
        $dotMc = Join-Path $appData '.minecraft'
        $roots += New-Root '자바에디션' (Join-Path $dotMc 'saves') 'java' 10

        # 런처 설정에서 사용자가 바꾼 게임 폴더(gameDir)도 확인
        foreach ($name in 'launcher_profiles.json', 'launcher_profiles_microsoft_store.json') {
            $profileFile = Join-Path $dotMc $name
            if (Test-Path -LiteralPath $profileFile) {
                $json = Get-Content -LiteralPath $profileFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($json -and $json.profiles) {
                    foreach ($p in $json.profiles.PSObject.Properties) {
                        $gameDir = $p.Value.gameDir
                        if (-not $gameDir) { continue }
                        $profileName = $p.Value.name
                        if (-not $profileName) { $profileName = '사용자 지정' }
                        $roots += New-Root "자바 ($profileName)" (Join-Path $gameDir 'saves') 'java' 11
                    }
                }
            }
        }
    }

    # --- 베드락 / 교육용 ----------------------------------------------------
    # Base 'L' = %LOCALAPPDATA%\Packages\... (Microsoft Store 앱 패키지)
    # Base 'A' = %APPDATA%\...
    # 베드락은 2025년 말 업데이트(GDK 전환)로 저장 위치가 Packages -> %APPDATA%\Minecraft Bedrock 로
    # 바뀌었고, 예전 폴더가 지워지지 않고 남는 경우가 많아 '이전 버전'으로 구분합니다.
    # 교육용은 스토어판과 설치판(설치 파일로 설치)의 저장 위치가 달라 둘 다 찾습니다.
    $sources = @(
        @{ Base = 'A'; Dir = 'Minecraft Bedrock';                                 Label = '베드락 (현재)';         Group = 'bedrock';     Order = 20 },
        @{ Base = 'L'; Dir = 'Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe';            Label = '베드락 (이전 버전)';    Group = 'bedrock';     Order = 25; Legacy = $true },
        @{ Base = 'A'; Dir = 'Minecraft Bedrock Preview';                         Label = '베드락 프리뷰 (현재)';    Group = 'bedrock-pre'; Order = 30 },
        @{ Base = 'L'; Dir = 'Packages\Microsoft.MinecraftWindowsBeta_8wekyb3d8bbwe';    Label = '베드락 프리뷰 (이전 버전)'; Group = 'bedrock-pre'; Order = 35; Legacy = $true },
        @{ Base = 'L'; Dir = 'Packages\Microsoft.MinecraftEducationEdition_8wekyb3d8bbwe'; Label = '교육용 (스토어판)';     Group = 'edu';         Order = 40 },
        @{ Base = 'A'; Dir = 'Minecraft Education Edition';                       Label = '교육용 (설치판)';       Group = 'edu';         Order = 41 },
        @{ Base = 'L'; Dir = 'Packages\Microsoft.MinecraftEducationPreview_8wekyb3d8bbwe'; Label = '교육용 프리뷰 (스토어판)'; Group = 'edu-pre';    Order = 50 },
        @{ Base = 'A'; Dir = 'Minecraft Education Edition Preview';               Label = '교육용 프리뷰 (설치판)';  Group = 'edu-pre';     Order = 51 }
    )
    foreach ($src in $sources) {
        if ($src.Base -eq 'A') { $baseDir = $appData } else { $baseDir = $localAppData }
        if (-not $baseDir) { continue }
        $base = Join-Path $baseDir $src.Dir
        foreach ($d in (Find-MinecraftWorldsDirs $base 6)) {
            $label = $src.Label
            $order = $src.Order
            # Users\Shared 는 특정 계정이 아니라 PC의 모든 계정이 같이 쓰는 폴더
            # (주로 리소스팩/행동팩용이라 월드는 대개 비어 있음)
            if ($d -match '\\Users\\Shared\\') {
                if (@(Get-ChildItem -LiteralPath $d -Directory -Force).Count -eq 0) { continue }
                if ($label -match '\(현재\)$') { $label = $label -replace '\(현재\)$', '(공유)' }
                else { $label = $label -replace '\)$', ', 공유)' }
                $order += 0.5
            }
            $roots += New-Root $label $d $src.Group $order $src.Legacy
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
        $r.Path = $full
        $result += $r
    }

    # 같은 이름이 여러 개면(여러 계정으로 로그인한 경우) 계정을 붙여 구분
    foreach ($g in ($result | Group-Object -Property Edition | Where-Object { $_.Count -gt 1 })) {
        $i = 1
        foreach ($r in $g.Group) {
            $account = Get-AccountLabel $r.Path
            if (-not $account) { $account = "$i" }
            $r.Edition = "$($r.Edition) - $account"
            $i++
        }
    }

    # 같은 게임의 현재 폴더가 있으면 이전 버전 폴더는 숨김
    foreach ($r in $result) {
        if (-not $r.Legacy) { continue }
        $hasCurrent = @($result | Where-Object { $_.Group -eq $r.Group -and -not $_.Legacy }).Count -gt 0
        if ($hasCurrent) { $r.Hidden = $true }
    }

    return $result | Sort-Object -Property Order, Edition
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

            # 썸네일: 베드락/교육용은 world_icon.jpeg, 자바는 icon.png
            $icon = $null
            foreach ($iconName in 'world_icon.jpeg', 'world_icon.jpg', 'world_icon.png', 'icon.png') {
                $candidate = Join-Path $dir.FullName $iconName
                if (Test-Path -LiteralPath $candidate) { $icon = $candidate; break }
            }

            $worlds += [pscustomobject]@{
                Edition  = $root.Edition
                Name     = $name
                Modified = $modified
                Path     = $dir.FullName
                Root     = $root.Path
                Icon     = $icon
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
    $roots | Format-Table -AutoSize Edition, @{ Name = '비고'; Expression = { if ($_.Hidden) { '창에서는 숨김 (이전 버전)' } } }, Path |
        Out-String -Width 400 | Write-Output
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
$form.Text = '마인크래프트 월드 폴더 찾기 - 제작: 스티브코딩'
$form.Size = New-Object System.Drawing.Size(1080, 640)
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
[void]$listView.Columns.Add('에디션', 280)
[void]$listView.Columns.Add('월드 이름', 220)
[void]$listView.Columns.Add('마지막 수정', 150)
[void]$listView.Columns.Add('폴더 경로', 400)

# 목록에 보여줄 월드 썸네일 크기 (16:9)
$thumbW = 80
$thumbH = 45

# 이미지를 비율을 유지한 채 썸네일 크기 안에 맞춰 그립니다. 이미지가 없으면 회색 칸만 그립니다.
function New-Thumbnail($file) {
    $bmp = New-Object System.Drawing.Bitmap($thumbW, $thumbH)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(225, 225, 225))
    if ($file) {
        try {
            # 파일을 잠그지 않도록 메모리로 읽어서 엶
            $ms = New-Object System.IO.MemoryStream(, [System.IO.File]::ReadAllBytes($file))
            $img = [System.Drawing.Image]::FromStream($ms)
            $scale = [Math]::Min($thumbW / $img.Width, $thumbH / $img.Height)
            $w = [int]($img.Width * $scale)
            $h = [int]($img.Height * $scale)
            $g.InterpolationMode = 'HighQualityBicubic'
            $g.DrawImage($img, [int](($thumbW - $w) / 2), [int](($thumbH - $h) / 2), $w, $h)
            $img.Dispose()
            $ms.Dispose()
        } catch { }
    }
    $g.Dispose()
    return $bmp
}

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

    $allRoots = @(Get-WorldRoots)
    $hiddenCount = @($allRoots | Where-Object { $_.Hidden }).Count
    $roots = @($allRoots | Where-Object { $chkLegacy.Checked -or -not $_.Hidden })
    $chkLegacy.Visible = ($hiddenCount -gt 0)
    foreach ($root in $roots) {
        $p = $root.Path
        $b = New-Button "$($root.Edition) 월드 폴더 열기" { Open-Folder $this.Tag }
        $b.Tag = $p
        $tip = New-Object System.Windows.Forms.ToolTip
        $tip.SetToolTip($b, $p)
        $topPanel.Controls.Add($b)
    }

    $worlds = @(Get-Worlds $roots)

    $oldImages = $listView.SmallImageList
    $images = New-Object System.Windows.Forms.ImageList
    $images.ColorDepth = 'Depth32Bit'
    $images.ImageSize = New-Object System.Drawing.Size($thumbW, $thumbH)
    $listView.SmallImageList = $images
    if ($oldImages) { $oldImages.Dispose() }

    $errors = @()
    foreach ($w in $worlds) {
        try {
            $images.Images.Add((New-Thumbnail $w.Icon))
            $imageIndex = $images.Images.Count - 1
            $item = New-Object System.Windows.Forms.ListViewItem -ArgumentList $w.Edition, $imageIndex
            [void]$item.SubItems.Add($w.Name)
            [void]$item.SubItems.Add($w.Modified.ToString('yyyy-MM-dd HH:mm'))
            [void]$item.SubItems.Add($w.Path)
            $item.Tag = $w
            [void]$listView.Items.Add($item)
        } catch {
            $errors += "$($w.Path): $($_.Exception.Message)"
        }
    }
    $listView.EndUpdate()

    if ($roots.Count -eq 0) {
        $status.Text = '마인크래프트 월드 폴더를 찾지 못했습니다. 게임을 한 번 실행해 월드를 만든 뒤 다시 시도하세요.'
    } else {
        $status.Text = "월드 폴더 $($roots.Count)곳, 월드 $($worlds.Count)개를 찾았습니다. (더블클릭하면 폴더가 열립니다)"
        if ($hiddenCount -gt 0 -and -not $chkLegacy.Checked) {
            $status.Text += " 지금 쓰지 않는 이전 버전 폴더 $($hiddenCount)곳은 숨겼습니다."
        }
    }
    if ($errors.Count -gt 0) {
        $status.Text += " (월드 $($errors.Count)개는 표시하지 못했습니다)"
        [System.Windows.Forms.MessageBox]::Show(
            "일부 월드를 목록에 표시하지 못했습니다.`n`n" + (($errors | Select-Object -First 5) -join "`n"),
            '마인크래프트 월드 폴더 찾기') | Out-Null
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

# 베드락 예전(업데이트 전) 폴더는 기본으로 숨기고, 체크하면 함께 보여줌
$chkLegacy = New-Object System.Windows.Forms.CheckBox
$chkLegacy.Text = '이전 버전 폴더도 보기'
$chkLegacy.AutoSize = $true
$chkLegacy.Padding = New-Object System.Windows.Forms.Padding(8, 4, 0, 0)
$chkLegacy.Visible = $false
$chkLegacy.Add_CheckedChanged({ Refresh-All })

$bottomPanel.Controls.AddRange(@($btnOpen, $btnCopy, $btnRefresh, $chkLegacy, $status))

$listView.Add_DoubleClick({
    $w = Get-SelectedWorld
    if ($w) { Open-Folder $w.Path }
})

# Fill 컨트롤을 먼저 추가해야 Top/Bottom 패널과 겹치지 않음
$form.Controls.Add($listView)
$form.Controls.Add($topPanel)
$form.Controls.Add($bottomPanel)

# 맨 아래 오른쪽 제작자 표시
$credit = New-Object System.Windows.Forms.Label
$credit.Text = '제작: 스티브코딩'
$credit.Dock = 'Bottom'
$credit.Height = 22
$credit.TextAlign = 'MiddleRight'
$credit.ForeColor = [System.Drawing.Color]::Gray
$credit.Padding = New-Object System.Windows.Forms.Padding(0, 0, 10, 4)
$form.Controls.Add($credit)

$form.Add_Shown({ Refresh-All })
[void]$form.ShowDialog()
