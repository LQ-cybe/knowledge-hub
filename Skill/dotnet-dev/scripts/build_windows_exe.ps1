#requires -Version 5.1

param(
    [string]$ProjectRoot = (Get-Location).Path,

    [Parameter(Mandatory = $true)]
    [string]$ProjectFile,

    [string]$AppName = '',

    [string]$RuntimeIdentifier = 'win-x64',

    [string]$Configuration = 'Release',

    [switch]$SelfContained = $true,

    [switch]$SingleFile = $true,

    [switch]$ReadyToRun,

    [ValidateSet('none', 'partial', 'full')]
    [string]$TrimMode = 'none',

    [switch]$SkipRestore,

    [switch]$ZipOutput,

    [switch]$Slim = $true,

    [string]$LicenseId = '',

    [string]$WatermarkText = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$projectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$projectFile = [System.IO.Path]::GetFullPath($ProjectFile)

function Get-Utf8BomEncoding {
    return [System.Text.UTF8Encoding]::new($true)
}

function Write-TextFileUtf8Bom {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content.TrimEnd() + "`r`n", (Get-Utf8BomEncoding))
}

function Write-JsonFileUtf8Bom {
    param(
        [string]$Path,
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (Get-Utf8BomEncoding))
}

function Assert-DotnetAvailable {
    $command = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw '未检测到 dotnet CLI。请先安装对应版本的 .NET SDK，或先让 AI 帮你完成环境准备。'
    }
}

function Invoke-DotnetCommand {
    param(
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        Write-Host ('执行命令: dotnet ' + ($Arguments -join ' '))
        & dotnet @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "命令执行失败：dotnet $($Arguments -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

function Get-ProjectMetadata {
    param([string]$ProjectPath)

    [xml]$xml = [System.IO.File]::ReadAllText($ProjectPath, [System.Text.Encoding]::UTF8)
    $targetFramework = ''
    $assemblyName = ''

    foreach ($group in @($xml.Project.PropertyGroup)) {
        if (-not [string]::IsNullOrWhiteSpace($group.TargetFramework)) {
            $targetFramework = [string]$group.TargetFramework
        }
        if (-not [string]::IsNullOrWhiteSpace($group.AssemblyName)) {
            $assemblyName = [string]$group.AssemblyName
        }
    }

    if ([string]::IsNullOrWhiteSpace($assemblyName)) {
        $assemblyName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
    }

    return [pscustomobject]@{
        TargetFramework = $targetFramework
        AssemblyName    = $assemblyName
    }
}

function Write-DistributionArtifacts {
    param(
        [string]$PublishRoot,
        [string]$ResolvedAppName,
        [string]$ResolvedFramework,
        [string]$ResolvedRuntimeIdentifier,
        [bool]$ResolvedSelfContained,
        [bool]$ResolvedSingleFile,
        [string]$ResolvedTrimMode,
        [bool]$ResolvedReadyToRun,
        [bool]$ResolvedSlim,
        [string]$ResolvedLicenseId,
        [string]$ResolvedWatermarkText
    )

    $deliveryReadmePath = Join-Path $PublishRoot 'README-delivery.md'
    $noticePath = Join-Path $PublishRoot 'LICENSE_NOTICE.txt'
    $tracePath = Join-Path $PublishRoot 'distribution-license.json'
    $exeHint = Join-Path $PublishRoot ($ResolvedAppName + '.exe')

    $readmeLines = @(
        '# ' + $ResolvedAppName + ' 交付说明',
        '',
        '- 启动入口：`' + $exeHint + '`',
        '- 目标框架：`' + $ResolvedFramework + '`',
        '- 运行平台：`' + $ResolvedRuntimeIdentifier + '`',
        '- 自包含发布：' + $ResolvedSelfContained,
        '- 单文件发布：' + $ResolvedSingleFile,
        '- Trim 模式：' + $ResolvedTrimMode,
        '- ReadyToRun：' + $ResolvedReadyToRun,
        '- 瘦身发布：' + $ResolvedSlim,
        '- 日志目录：`' + (Join-Path $PublishRoot 'logs') + '`',
        '- 输出目录：`' + (Join-Path $PublishRoot 'output') + '`'
    )
    Write-TextFileUtf8Bom -Path $deliveryReadmePath -Content ($readmeLines -join "`r`n")

    if (-not [string]::IsNullOrWhiteSpace($ResolvedLicenseId) -or -not [string]::IsNullOrWhiteSpace($ResolvedWatermarkText)) {
        $noticeLines = @(
            '本交付包仅限授权用户自用，禁止任何形式的擅自传播、转卖或商用。',
            'LicenseId: ' + $ResolvedLicenseId,
            'WatermarkText: ' + $ResolvedWatermarkText,
            '本交付包已写入授权追踪信息，请勿绕过原作者进行二次分发。'
        )
        Write-TextFileUtf8Bom -Path $noticePath -Content ($noticeLines -join "`r`n")

        $traceData = [ordered]@{
            appName           = $ResolvedAppName
            framework         = $ResolvedFramework
            runtimeIdentifier = $ResolvedRuntimeIdentifier
            selfContained     = $ResolvedSelfContained
            singleFile        = $ResolvedSingleFile
            trimMode          = $ResolvedTrimMode
            readyToRun        = $ResolvedReadyToRun
            slim              = $ResolvedSlim
            licenseId         = $ResolvedLicenseId
            watermarkText     = $ResolvedWatermarkText
            traceGeneratedAt  = (Get-Date).ToString('s')
            traceType         = 'dotnet-dev-delivery'
        }
        Write-JsonFileUtf8Bom -Path $tracePath -Data $traceData
    }
}

Assert-DotnetAvailable

if (-not (Test-Path $projectFile)) {
    throw "项目文件不存在: $projectFile"
}

$metadata = Get-ProjectMetadata -ProjectPath $projectFile

$resolvedAppName = if ([string]::IsNullOrWhiteSpace($AppName)) { $metadata.AssemblyName } else { $AppName.Trim() }
$distRoot = Join-Path $projectRoot 'dist'
$publishRoot = Join-Path $distRoot $resolvedAppName
$exePath = Join-Path $publishRoot ($resolvedAppName + '.exe')
$publishSingleFileArg = '/p:PublishSingleFile=' + $(if ($SingleFile) { 'true' } else { 'false' })
$publishReadyToRunArg = '/p:PublishReadyToRun=' + $(if ($ReadyToRun) { 'true' } else { 'false' })

$publishArgs = @(
    'publish',
    $projectFile,
    '-c', $Configuration,
    '-r', $RuntimeIdentifier,
    '--self-contained', $(if ($SelfContained) { 'true' } else { 'false' }),
    $publishSingleFileArg,
    $publishReadyToRunArg,
    '-o', $publishRoot
)

if ($Slim) {
    $publishArgs += '/p:EnableCompressionInSingleFile=true'
    $publishArgs += '/p:DebugType=none'
    $publishArgs += '/p:DebugSymbols=false'
    $publishArgs += '/p:IncludeNativeLibrariesForSelfExtract=true'
}

if ($TrimMode -ne 'none') {
    $publishArgs += '/p:PublishTrimmed=true'
    $publishArgs += '/p:TrimMode=' + $TrimMode
}
else {
    $publishArgs += '/p:PublishTrimmed=false'
}

if (-not $SkipRestore) {
    Invoke-DotnetCommand -WorkingDirectory $projectRoot -Arguments @('restore', $projectFile)
}

if (Test-Path $publishRoot) {
    [System.IO.Directory]::Delete($publishRoot, $true)
}

Invoke-DotnetCommand -WorkingDirectory $projectRoot -Arguments $publishArgs

if (-not (Test-Path $publishRoot)) {
    throw '发布完成后未找到 dist 目录。'
}

if (-not (Test-Path $exePath)) {
    throw "发布完成后未找到可执行文件：$exePath"
}

$resolvedSelfContained = [bool]$SelfContained
$resolvedSingleFile = [bool]$SingleFile
$resolvedReadyToRun = [bool]$ReadyToRun
$resolvedSlim = [bool]$Slim

Write-DistributionArtifacts `
    -PublishRoot $publishRoot `
    -ResolvedAppName $resolvedAppName `
    -ResolvedFramework $metadata.TargetFramework `
    -ResolvedRuntimeIdentifier $RuntimeIdentifier `
    -ResolvedSelfContained $resolvedSelfContained `
    -ResolvedSingleFile $resolvedSingleFile `
    -ResolvedTrimMode $TrimMode `
    -ResolvedReadyToRun $resolvedReadyToRun `
    -ResolvedSlim $resolvedSlim `
    -ResolvedLicenseId $LicenseId `
    -ResolvedWatermarkText $WatermarkText

if ($ZipOutput) {
    $zipPath = Join-Path $distRoot ($resolvedAppName + '.zip')
    if (Test-Path $zipPath) {
        [System.IO.File]::Delete($zipPath)
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($publishRoot, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    Write-Host "已生成压缩包：$zipPath"
}

Write-Host "发布完成，产物目录：$publishRoot"
Write-Host "可执行文件：$exePath"

<#
env_hash: 77b6a38e-1bc7caef-19d192b6-4281fc6b-cc204632-cde94736-e4513726
commit_ref: 7a1cea25-9c8046c1-c7800fb6-fbf957b7-9f9946c1-c68b0faa-cd3caf5d-197986c0-f8b00fa9-ecf963a7-5afa63a5-9c8063ca-c6900e9e-fff573b5-9c9262c3-e79f0db1-d2fa6292-929b40c2-eeb40599-f6fb4ca4-9cb148c1-c1a70e98-eff95787-9fa065c2-e0980cb6-fff46d8f-9ea04ac3-e8b109a5-f8f9459c-9ea664c3-fbaa0ca1-f5f85685-9c8e47c6-fa9d02b5-dff9628c-9c9c4dc1-c6bc0cb7-d7f44ba9-9ea450ca-c6900cad-ebfa7c9c-9fac6cc1-c5810db0-e3f45598-9db55cc3-c9890f9b-f1f45e86-9ea751c2-e0980cb8-f9f9628c-999c68
#>
