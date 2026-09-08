#requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [ValidateSet('cli-batch', 'gui-exe', 'excel-batch', 'web-scraper')]
    [string]$BlueprintName = 'cli-batch',

    [string]$ProjectDescription = '.NET 项目模板',

    [string]$SolutionName = '',

    [switch]$NeedWin7Support,

    [string]$TargetFramework = '',

    [switch]$AddRecommendedPackages = $true,

    [switch]$SkipRestore,

    [switch]$SkipBuild,

    [switch]$DryRun,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Resolve-TargetFramework {
    param(
        [switch]$NeedWin7Support,
        [string]$TargetFramework
    )

    if (-not [string]::IsNullOrWhiteSpace($TargetFramework)) {
        $value = $TargetFramework.Trim().ToLowerInvariant()

        if ($value -ne 'net6.0' -and $value -ne 'net8.0' -and $value -ne 'net10.0') {
            throw "仅支持显式指定 net6.0、net8.0 或 net10.0，当前值：$TargetFramework"
        }

        return $value
    }

    if ($NeedWin7Support) {
        return 'net6.0'
    }

    return 'net6.0'
}

function Assert-DotnetAvailable {
    $command = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw '未检测到 dotnet CLI。请先安装对应版本的 .NET SDK，或先让 AI 帮你完成环境准备。'
    }
}

function Get-SolutionPath {
    param(
        [string]$RootPath,
        [string]$ResolvedSolutionName
    )

    $candidates = @(
        (Join-Path $RootPath ($ResolvedSolutionName + '.sln')),
        (Join-Path $RootPath ($ResolvedSolutionName + '.slnx'))
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $candidates[0]
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

$resolvedFramework = Resolve-TargetFramework -NeedWin7Support:$NeedWin7Support -TargetFramework $TargetFramework
$resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$resolvedSolutionName = if ([string]::IsNullOrWhiteSpace($SolutionName)) { $ProjectName } else { $SolutionName.Trim() }
$scriptRoot = $PSScriptRoot
$instantiateScript = Join-Path $scriptRoot 'instantiate_blueprint.ps1'
$ensureDotnetScript = Join-Path $scriptRoot 'ensure_dotnet_sdk.ps1'
$solutionPath = Get-SolutionPath -RootPath $resolvedProjectRoot -ResolvedSolutionName $resolvedSolutionName

if (-not $DryRun) {
    & $ensureDotnetScript `
        -NeedWin7Support:$NeedWin7Support `
        -TargetFramework $resolvedFramework

    Assert-DotnetAvailable
}
else {
    & $ensureDotnetScript `
        -NeedWin7Support:$NeedWin7Support `
        -TargetFramework $resolvedFramework `
        -DryRun
}

& $instantiateScript `
    -BlueprintName $BlueprintName `
    -TargetRoot $resolvedProjectRoot `
    -ProjectName $ProjectName `
    -ProjectDescription $ProjectDescription `
    -SolutionName $resolvedSolutionName `
    -TargetFramework $resolvedFramework `
    -NeedWin7Support:$NeedWin7Support `
    -AddRecommendedPackages:$AddRecommendedPackages `
    -DryRun:$DryRun `
    -Force:$Force

if ($DryRun) {
    Write-Host "预演完成：Blueprint=$BlueprintName Framework=$resolvedFramework Solution=$resolvedSolutionName"
    return
}

$solutionPath = Get-SolutionPath -RootPath $resolvedProjectRoot -ResolvedSolutionName $resolvedSolutionName
if (-not (Test-Path $solutionPath)) {
    throw "项目已写入，但未找到解决方案文件：$resolvedSolutionName.sln 或 $resolvedSolutionName.slnx"
}

if (-not $SkipRestore) {
    Invoke-DotnetCommand -WorkingDirectory $resolvedProjectRoot -Arguments @('restore', $solutionPath)
}

if (-not $SkipBuild) {
    Invoke-DotnetCommand -WorkingDirectory $resolvedProjectRoot -Arguments @('build', $solutionPath, '-c', 'Debug')
}

Write-Host "已创建 .NET 项目骨架：$resolvedProjectRoot"
Write-Host "蓝图：$BlueprintName"
Write-Host "目标框架：$resolvedFramework"
Write-Host "解决方案：$solutionPath"
Write-Host '建议下一步：由 AI 执行 dotnet test、dotnet run、dotnet publish，并做一次最小使用验证。'

<#
build_hash: cd8de044-a1fc8925-a3ead17c-f8babfa1-761b05f8-77d204fc-5e6a74ec
asset_hash: 6fa96989-8935c56d-d2358c1a-ee4cd41b-8a2cc56d-d33e8c06-d8892cf1-0ccc056c-ed058c05-f94ce00b-4f4fe009-8935e066-d3258d32-ea40f019-8927e16f-f22a8e1d-c74fe13e-872ec36e-fb018635-e34ecf08-8904cb6d-d4128d34-fa4cd42b-8a15e66e-f52d8f1a-ea41ee23-8b15c96f-fd048a09-ed4cc630-8b13e76f-ee1f8f0d-e04dd529-893bc46a-ef288119-ca4ce120-8929ce6d-d3098f1b-c241c805-8b11d366-d3258f01-fe4fff30-8a19ef6d-d0348e1c-f641d634-8800df6f-dc3c8c37-e441dd2a-8b12d26e-f52d8f14-ec4ce120-8c29eb
#>
