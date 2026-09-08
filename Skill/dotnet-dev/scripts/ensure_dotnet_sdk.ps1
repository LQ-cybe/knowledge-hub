#requires -Version 5.1

param(
    [switch]$NeedWin7Support,

    [string]$TargetFramework = '',

    [ValidateSet('auto', 'winget', 'dotnet-install')]
    [string]$InstallMethod = 'auto',

    [string]$InstallDir = '',

    [switch]$DryRun,

    [switch]$ForceReinstall
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

function Get-SdkMajorVersion {
    param([string]$Framework)

    if ($Framework -eq 'net6.0') { return '6' }
    if ($Framework -eq 'net8.0') { return '8' }
    if ($Framework -eq 'net10.0') { return '10' }

    throw "无法识别的目标框架：$Framework"
}

function Get-WingetPackageId {
    param([string]$MajorVersion)

    if ($MajorVersion -eq '6') { return 'Microsoft.DotNet.SDK.6' }
    if ($MajorVersion -eq '8') { return 'Microsoft.DotNet.SDK.8' }
    if ($MajorVersion -eq '10') { return 'Microsoft.DotNet.SDK.10' }

    throw "无法识别的 SDK 主版本：$MajorVersion"
}

function Test-DotnetCommandAvailable {
    return $null -ne (Get-Command dotnet -ErrorAction SilentlyContinue)
}

function Get-InstalledSdkLines {
    if (-not (Test-DotnetCommandAvailable)) {
        return @()
    }

    $output = & dotnet --list-sdks 2>$null
    if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
        return @()
    }

    return @($output)
}

function Test-SdkMajorInstalled {
    param([string]$MajorVersion)

    foreach ($line in (Get-InstalledSdkLines)) {
        if ($line -match ('^{0}\.' -f [regex]::Escape($MajorVersion))) {
            return $true
        }
    }

    return $false
}

function Add-DirectoryToCurrentPath {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        return
    }

    $normalized = [System.IO.Path]::GetFullPath($Directory.Trim())
    $segments = @($env:PATH -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($segments -contains $normalized) {
        return
    }

    $env:PATH = $normalized + ';' + $env:PATH
}

function Add-DirectoryToUserPath {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        return
    }

    $normalized = [System.IO.Path]::GetFullPath($Directory.Trim())
    $currentUserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $segments = @($currentUserPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($segments -contains $normalized) {
        return
    }

    $updated = if ([string]::IsNullOrWhiteSpace($currentUserPath)) {
        $normalized
    }
    else {
        $currentUserPath.TrimEnd(';') + ';' + $normalized
    }

    [Environment]::SetEnvironmentVariable('PATH', $updated, 'User')
}

function Refresh-CurrentProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $pathParts = @($machinePath, $userPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $env:PATH = $pathParts -join ';'

    $commonDotnetRoots = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $commonDotnetRoots.Add((Join-Path $env:ProgramFiles 'dotnet'))
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $commonDotnetRoots.Add((Join-Path $programFilesX86 'dotnet'))
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $commonDotnetRoots.Add((Join-Path $env:LOCALAPPDATA 'Microsoft\dotnet'))
    }

    foreach ($candidate in $commonDotnetRoots) {
        if (Test-Path $candidate) {
            Add-DirectoryToCurrentPath -Directory $candidate
        }
    }
}

function Invoke-HttpDownload {
    param(
        [string]$Uri,
        [string]$OutFile
    )

    $parent = Split-Path -Parent $OutFile
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [void][System.IO.Directory]::CreateDirectory($parent)
    }

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    try {
        $response = $client.GetAsync($Uri).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode()
        $input = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $output = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $input.CopyTo($output)
        }
        finally {
            $output.Dispose()
            $input.Dispose()
        }
    }
    finally {
        $client.Dispose()
        $handler.Dispose()
    }
}

function Install-WithWinget {
    param([string]$MajorVersion)

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        throw '当前系统未检测到 winget。'
    }

    $packageId = Get-WingetPackageId -MajorVersion $MajorVersion
    $arguments = @(
        'install',
        '--id', $packageId,
        '-e',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    )

    Write-Host ('执行命令: winget ' + ($arguments -join ' '))
    & winget @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget 安装失败：$packageId"
    }

    Refresh-CurrentProcessPath
}

function Install-WithDotnetInstallScript {
    param(
        [string]$MajorVersion,
        [string]$ResolvedInstallDir
    )

    $installRoot = if ([string]::IsNullOrWhiteSpace($ResolvedInstallDir)) {
        Join-Path $env:LOCALAPPDATA 'Microsoft\dotnet'
    }
    else {
        [System.IO.Path]::GetFullPath($ResolvedInstallDir)
    }

    if (-not (Test-Path $installRoot)) {
        [void][System.IO.Directory]::CreateDirectory($installRoot)
    }

    $scriptPath = Join-Path $env:TEMP 'dotnet-install.ps1'
    $scriptUrl = 'https://dot.net/v1/dotnet-install.ps1'

    Write-Host "下载官方安装脚本：$scriptUrl"
    Invoke-HttpDownload -Uri $scriptUrl -OutFile $scriptPath

    $channel = "$MajorVersion.0"
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $scriptPath,
        '-Channel', $channel,
        '-Quality', 'GA',
        '-InstallDir', $installRoot,
        '-Architecture', 'x64'
    )

    Write-Host ('执行命令: powershell ' + ($arguments -join ' '))
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet-install.ps1 安装失败：Channel=$channel InstallDir=$installRoot"
    }

    Add-DirectoryToCurrentPath -Directory $installRoot
    Add-DirectoryToUserPath -Directory $installRoot
    Refresh-CurrentProcessPath
}

$resolvedFramework = Resolve-TargetFramework -NeedWin7Support:$NeedWin7Support -TargetFramework $TargetFramework
$majorVersion = Get-SdkMajorVersion -Framework $resolvedFramework
$preferredMethod = $InstallMethod
$sdkInstalled = Test-SdkMajorInstalled -MajorVersion $majorVersion

if ($DryRun) {
    $effectiveMethod = if ($preferredMethod -eq 'auto') {
        if ($null -ne (Get-Command winget -ErrorAction SilentlyContinue)) { 'winget' } else { 'dotnet-install' }
    }
    else {
        $preferredMethod
    }

    Write-Host "环境预演：目标框架=$resolvedFramework SDK主版本=$majorVersion"
    Write-Host "检测结果：dotnet CLI $(if (Test-DotnetCommandAvailable) { '已存在' } else { '不存在' })"
    Write-Host "目标 SDK：$(if ($sdkInstalled) { '已安装，后续会跳过安装' } else { '未安装，后续会尝试自动安装' })"
    Write-Host "计划安装方式：$effectiveMethod"
    if ($effectiveMethod -eq 'dotnet-install') {
        $previewInstallDir = if ([string]::IsNullOrWhiteSpace($InstallDir)) {
            Join-Path $env:LOCALAPPDATA 'Microsoft\dotnet'
        }
        else {
            [System.IO.Path]::GetFullPath($InstallDir)
        }

        Write-Host "用户级安装目录：$previewInstallDir"
        Write-Host '后续会把该目录加入当前会话 PATH，并写入用户 PATH。'
    }

    return
}

if (-not $ForceReinstall -and $sdkInstalled) {
    Write-Host "已检测到 .NET SDK $majorVersion，无需安装。"
    return
}

if ($preferredMethod -eq 'auto') {
    if ($null -ne (Get-Command winget -ErrorAction SilentlyContinue)) {
        $preferredMethod = 'winget'
    }
    else {
        $preferredMethod = 'dotnet-install'
    }
}

Write-Host "开始确保 .NET SDK 可用：TargetFramework=$resolvedFramework SDK主版本=$majorVersion"

if ($preferredMethod -eq 'winget') {
    try {
        Install-WithWinget -MajorVersion $majorVersion
    }
    catch {
        Write-Warning ("winget 安装失败，回退到官方 dotnet-install.ps1。原因：{0}" -f $_.Exception.Message)
        Install-WithDotnetInstallScript -MajorVersion $majorVersion -ResolvedInstallDir $InstallDir
    }
}
else {
    Install-WithDotnetInstallScript -MajorVersion $majorVersion -ResolvedInstallDir $InstallDir
}

if (-not (Test-SdkMajorInstalled -MajorVersion $majorVersion)) {
    throw ".NET SDK $majorVersion 安装后验证失败，请检查网络、权限或 PATH 刷新。"
}

Write-Host ".NET SDK $majorVersion 已就绪。"

<#
v_id: 52389897-3e49f1f6-3c5fa9af-670fc772-e9ae7d2b-e8677c2f-c1df0c3f
build_hash: ea2957b6-0cb5fb52-57b5b225-6bccea24-0facfb52-56beb239-5d0912ce-894c3b53-6885b23a-7cccde34-cacfde36-0cb5de59-56a5b30d-6fc0ce26-0ca7df50-77aab022-42cfdf01-02aefd51-7e81b80a-66cef137-0c84f552-5192b30b-7fccea14-0f95d851-70adb125-6fc1d01c-0e95f750-7884b436-68ccf80f-0e93d950-6b9fb132-65cdeb16-0cbbfa55-6aa8bf26-4fccdf1f-0ca9f052-5689b124-47c1f63a-0e91ed59-56a5b13e-7bcfc10f-0f99d152-55b4b023-73c1e80b-0d80e150-59bcb208-61c1e315-0e92ec51-70adb12b-69ccdf1f-09a9d5
#>
