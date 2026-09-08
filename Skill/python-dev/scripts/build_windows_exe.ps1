#requires -Version 5.1

param(
    [string]$ProjectRoot = (Get-Location).Path,

    [Parameter(Mandatory = $true)]
    [string]$EntryScript,

    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [ValidateSet('onefile', 'onedir')]
    [string]$BuildMode = 'onedir',

    [switch]$Windowed,

    [string]$IconPath = '',

    [string]$LicenseId = '',

    [string]$WatermarkText = ''
)

$ErrorActionPreference = 'Stop'
$entryScript = [System.IO.Path]::GetFullPath($EntryScript)
$projectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$modeArg = if ($BuildMode -eq 'onefile') { '--onefile' } else { '--onedir' }
$windowArg = if ($Windowed) { '--windowed' } else { '' }

function Get-Utf8BomEncoding {
    return [System.Text.UTF8Encoding]::new($true)
}

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function Write-TextFileUtf8Bom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8BomEncoding))
}

function Write-TextFileUtf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function Write-JsonFileUtf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (Get-Utf8NoBomEncoding))
}

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Convert-TextToBase64Segments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [int]$SegmentCount = 6
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @('')
    }

    $base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Text))
    $segmentLength = [Math]::Ceiling($base64.Length / [double]$SegmentCount)
    $segments = [System.Collections.Generic.List[string]]::new()

    for ($index = 0; $index -lt $SegmentCount; $index++) {
        $start = $index * $segmentLength
        if ($start -ge $base64.Length) {
            $segments.Add('') | Out-Null
            continue
        }

        $length = [Math]::Min($segmentLength, $base64.Length - $start)
        $segments.Add($base64.Substring($start, $length)) | Out-Null
    }

    return $segments.ToArray()
}

function Get-DefaultDistributionStatement {
    return @'
本表单申请提交即为同意获取到的资料，仅限授权用户自用，禁止任何形式的擅自传播。
对于恶意传播、营利性传播行为，我方将保留追究法律责任的权利。
本人已明晰本脚本版权归 Excel 催化剂所有，承诺仅作为授权用户个人使用，绝不擅自转发、分享、传播。
保证不以任何形式用于商业牟利，若违反上述约定，自愿承担相应法律责任。
'@.Trim()
}

function Get-DefaultReferralText {
    return @'
需要承诺自用，不对外二次分发。
有朋友想要，可以直接转介绍其向原作者获取一手授权版本。
觉得有价值可以帮忙分享传播，但不要绕过原作者私下转发成品。
'@.Trim()
}

function Get-DeliveryTargetDirectories {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistPath,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    $targetDirectories = [System.Collections.Generic.List[string]]::new()
    if ($Mode -eq 'onedir') {
        $appDistPath = Join-Path $DistPath $ApplicationName
        if (Test-Path $appDistPath) {
            $targetDirectories.Add($appDistPath) | Out-Null
        }
    }

    if ($targetDirectories.Count -eq 0) {
        $targetDirectories.Add($DistPath) | Out-Null
    }

    return $targetDirectories.ToArray()
}

function Get-ConfigSourcePath {
    param([string]$RootPath)

    $envPath = Join-Path $RootPath '.env'
    if (Test-Path $envPath) {
        return $envPath
    }

    $envExamplePath = Join-Path $RootPath '.env.example'
    if (Test-Path $envExamplePath) {
        return $envExamplePath
    }

    return $null
}

function Get-ResolvedIconPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [string]$RawIconPath
    )

    if ([string]::IsNullOrWhiteSpace($RawIconPath)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($RawIconPath)) {
        return [System.IO.Path]::GetFullPath($RawIconPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RootPath $RawIconPath))
}

function Copy-FileForce {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $parent = Split-Path -Path $DestinationPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        [void][System.IO.Directory]::CreateDirectory($parent)
    }

    [System.IO.File]::Copy($SourcePath, $DestinationPath, $true)
}

function Convert-PngToIco {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePngPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetIcoPath,

        [Parameter(Mandatory = $true)]
        [string]$WorkingRoot
    )

    $converterScriptPath = Join-Path $WorkingRoot 'convert_png_to_ico.py'
    $converterScript = @'
from pathlib import Path
import sys

from PIL import Image


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: convert_png_to_ico.py <source_png> <target_ico>")

    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    resampling = getattr(Image, "Resampling", Image).LANCZOS
    sizes = [256, 128, 64, 48, 32, 16]
    icon_frames = []

    with Image.open(source) as image:
        image = image.convert("RGBA")
        for size in sizes:
            frame = image.copy()
            frame.thumbnail((size, size), resampling)
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            offset = ((size - frame.width) // 2, (size - frame.height) // 2)
            canvas.paste(frame, offset, frame)
            icon_frames.append(canvas)

    target.parent.mkdir(parents=True, exist_ok=True)
    icon_frames[0].save(
        target,
        format="ICO",
        sizes=[frame.size for frame in icon_frames],
        append_images=icon_frames[1:],
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

    Write-TextFileUtf8NoBom -Path $converterScriptPath -Content $converterScript
    & uv run python $converterScriptPath $SourcePngPath $TargetIcoPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $TargetIcoPath)) {
        throw "PNG 转 ICO 失败：$SourcePngPath"
    }
}

function Resolve-IconBuildInputs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [string]$RawIconPath
    )

    $emptyResult = [pscustomobject]@{
        IconArgument              = ''
        AdditionalPyInstallerArgs = @()
    }

    if ([string]::IsNullOrWhiteSpace($RawIconPath)) {
        return $emptyResult
    }

    $resolvedIconPath = Get-ResolvedIconPath -RootPath $RootPath -RawIconPath $RawIconPath
    if (-not (Test-Path $resolvedIconPath)) {
        throw "图标文件不存在: $resolvedIconPath"
    }

    $iconExtension = [System.IO.Path]::GetExtension($resolvedIconPath).ToLowerInvariant()
    $iconWorkRoot = Join-Path $RootPath '.pyinstaller\icon-assets'
    if (-not (Test-Path $iconWorkRoot)) {
        [void][System.IO.Directory]::CreateDirectory($iconWorkRoot)
    }

    $standardIcoPath = Join-Path $iconWorkRoot 'app_icon.ico'
    $extraArgs = [System.Collections.Generic.List[string]]::new()

    switch ($iconExtension) {
        '.png' {
            $standardPngPath = Join-Path $iconWorkRoot 'app_icon.png'
            Copy-FileForce -SourcePath $resolvedIconPath -DestinationPath $standardPngPath

            Write-Host '检测到 PNG 图标，准备安装 Pillow 并自动转换为 ICO。'
            uv add --dev pillow
            Convert-PngToIco -SourcePngPath $standardPngPath -TargetIcoPath $standardIcoPath -WorkingRoot $iconWorkRoot

            $extraArgs.Add('--add-data') | Out-Null
            $extraArgs.Add("$standardPngPath;assets") | Out-Null
            $extraArgs.Add('--add-data') | Out-Null
            $extraArgs.Add("$standardIcoPath;assets") | Out-Null

            Write-Host "PNG 图标已转换为 ICO：$standardIcoPath"
            return [pscustomobject]@{
                IconArgument              = $standardIcoPath
                AdditionalPyInstallerArgs = $extraArgs.ToArray()
            }
        }
        '.ico' {
            Copy-FileForce -SourcePath $resolvedIconPath -DestinationPath $standardIcoPath
            $extraArgs.Add('--add-data') | Out-Null
            $extraArgs.Add("$standardIcoPath;assets") | Out-Null

            return [pscustomobject]@{
                IconArgument              = $standardIcoPath
                AdditionalPyInstallerArgs = $extraArgs.ToArray()
            }
        }
        default {
            throw "IconPath 仅支持 .png 或 .ico，当前文件：$resolvedIconPath"
        }
    }
}

function Copy-DeliveryEnvFile {
    param(
        [string]$RootPath,
        [string]$DistPath,
        [string]$ApplicationName,
        [string]$Mode
    )

    $configSource = Get-ConfigSourcePath -RootPath $RootPath
    if ($null -eq $configSource) {
        Write-Warning '未找到 .env 或 .env.example，已跳过 dist 配置文件生成。'
        return
    }

    $targetDirectories = Get-DeliveryTargetDirectories -DistPath $DistPath -ApplicationName $ApplicationName -Mode $Mode
    foreach ($targetDirectory in $targetDirectories) {
        $targetPath = Join-Path $targetDirectory '.env'
        Copy-FileForce -SourcePath $configSource -DestinationPath $targetPath
        Write-Host "已生成交付配置文件：$targetPath"
    }
}

function Write-DistributionArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistPath,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [Parameter(Mandatory = $true)]
        [string]$Mode,

        [string]$LicenseId,

        [string]$WatermarkText
    )

    if ([string]::IsNullOrWhiteSpace($LicenseId) -and [string]::IsNullOrWhiteSpace($WatermarkText)) {
        return
    }

    $distributionStatement = Get-DefaultDistributionStatement
    $referralText = Get-DefaultReferralText
    $targetDirectories = Get-DeliveryTargetDirectories -DistPath $DistPath -ApplicationName $ApplicationName -Mode $Mode

    $traceData = [ordered]@{
        licenseId                  = $LicenseId
        watermarkText              = $WatermarkText
        statementSegments          = Convert-TextToBase64Segments -Text $distributionStatement -SegmentCount 8
        statementSha256            = Get-Sha256Hex -Text $distributionStatement
        referralSegments           = Convert-TextToBase64Segments -Text $referralText -SegmentCount 4
        referralSha256             = Get-Sha256Hex -Text $referralText
        traceGeneratedAt           = (Get-Date).ToString('s')
        traceType                  = 'python-dev-delivery'
        noticeFile                 = 'LICENSE_NOTICE.txt'
        generator                  = 'scripts/build_windows_exe.ps1'
    }

    $noticeLines = [System.Collections.Generic.List[string]]::new()
    $noticeLines.Add('本交付包仅限授权用户自用，禁止任何形式的擅自传播、转卖或商用。') | Out-Null
    $noticeLines.Add("LicenseId: $LicenseId") | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($WatermarkText)) {
        $noticeLines.Add("WatermarkText: $WatermarkText") | Out-Null
    }
    $noticeLines.Add('本交付包已写入授权追踪信息与分发说明，请勿绕过原作者进行二次分发。') | Out-Null
    $noticeLines.Add('如朋友需要，请直接转介绍其向原作者获取一手授权版本。') | Out-Null

    foreach ($targetDirectory in $targetDirectories) {
        $noticePath = Join-Path $targetDirectory 'LICENSE_NOTICE.txt'
        $tracePath = Join-Path $targetDirectory 'distribution-license.json'

        Write-TextFileUtf8Bom -Path $noticePath -Content (($noticeLines -join "`r`n") + "`r`n")
        Write-JsonFileUtf8NoBom -Path $tracePath -Data $traceData

        Write-Host "已写入授权说明：$noticePath"
        Write-Host "已写入授权追踪信息：$tracePath"
    }
}

Push-Location $projectRoot
try {
    if (-not (Test-Path $entryScript)) {
        throw "入口脚本不存在: $entryScript"
    }

    $resolvedIcon = Resolve-IconBuildInputs -RootPath $projectRoot -RawIconPath $IconPath
    uv add --dev pyinstaller

    $command = [System.Collections.Generic.List[string]]::new()
    foreach ($baseArg in @(
            'uv',
            'run',
            'pyinstaller',
            '--noconfirm',
            '--clean',
            '--name',
            $AppName,
            $modeArg,
            $windowArg,
            $(if ([string]::IsNullOrWhiteSpace($resolvedIcon.IconArgument)) { '' } else { '--icon' }),
            $resolvedIcon.IconArgument
        )) {
        if (-not [string]::IsNullOrWhiteSpace($baseArg)) {
            $command.Add($baseArg) | Out-Null
        }
    }

    foreach ($extraArg in $resolvedIcon.AdditionalPyInstallerArgs) {
        if (-not [string]::IsNullOrWhiteSpace($extraArg)) {
            $command.Add([string]$extraArg) | Out-Null
        }
    }

    $command.Add($entryScript) | Out-Null

    Write-Host ('执行打包命令: ' + ($command -join ' '))
    & $command[0] $command[1..($command.Count - 1)]

    $distRoot = Join-Path $projectRoot 'dist'
    if (-not (Test-Path $distRoot)) {
        throw '打包完成后未找到 dist 目录。'
    }

    Copy-DeliveryEnvFile -RootPath $projectRoot -DistPath $distRoot -ApplicationName $AppName -Mode $BuildMode
    Write-DistributionArtifacts `
        -DistPath $distRoot `
        -ApplicationName $AppName `
        -Mode $BuildMode `
        -LicenseId $LicenseId `
        -WatermarkText $WatermarkText

    Write-Host "打包完成，产物目录：$distRoot"
}
finally {
    Pop-Location
}

<#
comp_id: 22ea30ca-4e9b59ab-4c8d01f2-17dd6f2f-997cd576-98b5d472-b10da462
rev_id: 3741fb05-d1dd57e1-8add1e96-b6a44697-d2c457e1-8bd61e8a-8061be7d-542497e0-b5ed1e89-a1a47287-17a77285-d1dd72ea-8bcd1fbe-b2a86295-d1cf73e3-aac21c91-9fa773b2-dfc651e2-a3e914b9-bba65d84-d1ec59e1-8cfa1fb8-a2a446a7-d2fd74e2-adc51d96-b2a97caf-d3fd5be3-a5ec1885-b5a454bc-d3fb75e3-b6f71d81-b8a547a5-d1d356e6-b7c01395-92a473ac-d1c15ce1-8be11d97-9aa95a89-d3f941ea-8bcd1d8d-a6a76dbc-d2f17de1-88dc1c90-aea944b8-d0e84de3-84d41ebb-bca94fa6-d3fa40e2-adc51d98-b4a473ac-d4c179
#>
