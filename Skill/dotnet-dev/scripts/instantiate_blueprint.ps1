#requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$BlueprintName,

    [Parameter(Mandatory = $true)]
    [string]$TargetRoot,

    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [string]$ProjectDescription = '.NET 项目模板',

    [string]$SolutionName = '',

    [string]$TargetFramework = 'net6.0',

    [string]$GuiIconSourcePath = '',

    [switch]$NeedWin7Support,

    [switch]$AddRecommendedPackages = $true,

    [switch]$DryRun,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$utf8Bom = [System.Text.UTF8Encoding]::new($true)

function Read-Utf8File {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, $utf8NoBom)
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path $parent)) {
        [void][System.IO.Directory]::CreateDirectory($parent)
    }

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $encoding = if ($ext -in @('.cs', '.csproj', '.xaml', '.props', '.config', '.sln', '.slnx', '.xml')) {
        $utf8Bom
    }
    else {
        $utf8NoBom
    }

    [System.IO.File]::WriteAllText($Path, $Content.TrimEnd() + "`r`n", $encoding)
}

function Expand-Template {
    param([string]$Content, [hashtable]$Tokens)
    $result = $Content
    foreach ($key in $Tokens.Keys) {
        $result = $result.Replace("__${key}__", [string]$Tokens[$key])
    }
    return $result
}

function Assert-DotnetAvailable {
    $command = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw '未检测到 dotnet CLI。请先安装对应版本的 .NET SDK，或先让 AI 帮你完成环境准备。'
    }
}

function Get-RecommendedPackages {
    param([string]$ResolvedBlueprintName)

    switch ($ResolvedBlueprintName) {
        'excel-batch' {
            return @([pscustomobject]@{ Name = 'ClosedXML'; Version = '0.104.2' })
        }
        'web-scraper' {
            return @([pscustomobject]@{ Name = 'HtmlAgilityPack'; Version = '1.11.71' })
        }
        default {
            return @()
        }
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

function Resolve-SolutionFilePath {
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

    return $null
}

function Get-RootReadme {
    param(
        [string]$ResolvedProjectName,
        [string]$ResolvedDescription,
        [string]$ResolvedBlueprintName,
        [string]$ResolvedFramework,
        [string]$ResolvedSolutionName,
        [bool]$Win7Enabled
    )

    $win7Text = if ($Win7Enabled) { '需要兼容 Win7，因此默认使用 .NET 6。' } else { '默认先从 .NET 6 起步；如果后续确认 .NET 6 不够，再升级到 .NET 8；只有明确需要且环境可控时才考虑 .NET 10。' }
    return @"
# $ResolvedProjectName

$ResolvedDescription

## 项目摘要

- 蓝图：`$ResolvedBlueprintName`
- 目标框架：`$ResolvedFramework`
- 解决方案：由当前 dotnet SDK 生成 `$ResolvedSolutionName.sln` 或 `$ResolvedSolutionName.slnx`
- 版本决策：$win7Text

## 常用命令

```powershell
dotnet restore .\$ResolvedSolutionName.sln
dotnet build .\$ResolvedSolutionName.sln -c Debug
dotnet test .\$ResolvedSolutionName.sln
dotnet run --project .\src\$ResolvedProjectName\$ResolvedProjectName.csproj
```

## 目录说明

- `src\$ResolvedProjectName\`：主项目
- `tests\$ResolvedProjectName.Tests\`：测试项目
- `dist\`：发布产物
- `logs\`：运行日志
"@
}

$scriptRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'gui_icon_asset_tools.ps1')

$blueprintRoot = Join-Path $scriptRoot ('templates\project-blueprints\' + $BlueprintName)
if (-not (Test-Path $blueprintRoot)) {
    throw "未找到蓝图: $BlueprintName"
}

$targetRoot = [System.IO.Path]::GetFullPath($TargetRoot)
$resolvedSolutionName = if ([string]::IsNullOrWhiteSpace($SolutionName)) { $ProjectName } else { $SolutionName.Trim() }
$rootNamespace = ($ProjectName -replace '[^0-9A-Za-z_]', '')
if ([string]::IsNullOrWhiteSpace($rootNamespace)) {
    throw 'ProjectName 处理后为空，请改用包含字母或数字的项目名。'
}

$framework = $TargetFramework.Trim().ToLowerInvariant()

$testFramework = if ($framework -eq 'net10.0') { 'net10.0' } elseif ($framework -eq 'net8.0') { 'net8.0' } else { 'net6.0' }
$targetFrameworkValue = if ($BlueprintName -eq 'gui-exe') { $framework + '-windows' } else { $framework }
$testTargetFrameworkValue = if ($BlueprintName -eq 'gui-exe') { $framework + '-windows' } else { $testFramework }
$solutionPath = Join-Path $targetRoot ($resolvedSolutionName + '.sln')
$projectRelativePath = Join-Path 'src' (Join-Path $ProjectName ($ProjectName + '.csproj'))
$testProjectRelativePath = Join-Path 'tests' (Join-Path ($ProjectName + '.Tests') ($ProjectName + '.Tests.csproj'))
$projectFilePath = Join-Path $targetRoot $projectRelativePath
$testProjectFilePath = Join-Path $targetRoot $testProjectRelativePath
$projectRootPath = Join-Path $targetRoot (Join-Path 'src' $ProjectName)
$guiIconAssetTargetPath = Join-Path $projectRootPath 'Assets\AppIcon'

$tokens = @{
    PROJECT_NAME          = $ProjectName
    PROJECT_DESCRIPTION   = $ProjectDescription
    ROOT_NAMESPACE        = $rootNamespace
    APP_NAME              = $ProjectName
    BLUEPRINT_NAME        = $BlueprintName
    TARGET_FRAMEWORK      = $targetFrameworkValue
    TEST_TARGET_FRAMEWORK = $testTargetFrameworkValue
    WIN7_NOTE             = $(if ($NeedWin7Support) { '需要兼容 Win7，已切到 .NET 6。' } else { '当前模板默认使用 .NET 6；如果后续确认低版本不够，再升级到 .NET 8 或 .NET 10。' })
}

$plan = New-Object System.Collections.Generic.List[object]

$commonFiles = @(
    [pscustomobject]@{
        RelativePath = '.gitignore'
        TemplatePath = Join-Path $scriptRoot 'templates\.gitignore.tmpl'
    },
    [pscustomobject]@{
        RelativePath = 'NuGet.config'
        TemplatePath = Join-Path $scriptRoot 'templates\NuGet.config.tmpl'
    },
    [pscustomobject]@{
        RelativePath = 'Directory.Build.props'
        TemplatePath = Join-Path $scriptRoot 'templates\Directory.Build.props.tmpl'
    },
    [pscustomobject]@{
        RelativePath = 'README.md'
        Content      = (Get-RootReadme -ResolvedProjectName $ProjectName -ResolvedDescription $ProjectDescription -ResolvedBlueprintName $BlueprintName -ResolvedFramework $targetFrameworkValue -ResolvedSolutionName $resolvedSolutionName -Win7Enabled $NeedWin7Support.IsPresent)
    }
)

foreach ($file in $commonFiles) {
    if ($file.PSObject.Properties.Name -contains 'TemplatePath') {
        $content = Expand-Template -Content (Read-Utf8File $file.TemplatePath) -Tokens $tokens
    }
    else {
        $content = $file.Content
    }

    $targetPath = Join-Path $targetRoot $file.RelativePath
    $plan.Add([pscustomobject]@{
            RelativePath = $file.RelativePath
            TargetPath   = $targetPath
            Exists       = (Test-Path $targetPath)
            Content      = $content
        }) | Out-Null
}

$files = Get-ChildItem -Path $blueprintRoot -Recurse -File
foreach ($file in $files) {
    $relative = $file.FullName.Substring($blueprintRoot.Length).TrimStart('\')
    if ($relative.StartsWith('tests\')) {
        $relative = $relative.Substring(6)
        if ($relative -eq 'app_name.Tests.csproj.tmpl') {
            $relative = Join-Path ('tests\' + $ProjectName + '.Tests') ($ProjectName + '.Tests.csproj.tmpl')
        }
        else {
            $relative = Join-Path ('tests\' + $ProjectName + '.Tests') $relative
        }
    }
    else {
        $relative = $relative.Replace('app_name', $ProjectName)
    }
    if ($relative.EndsWith('.tmpl')) {
        $relative = $relative.Substring(0, $relative.Length - 5)
        $content = Expand-Template -Content (Read-Utf8File $file.FullName) -Tokens $tokens
    }
    else {
        $content = Read-Utf8File $file.FullName
    }

    $targetPath = Join-Path $targetRoot $relative
    $plan.Add([pscustomobject]@{
            RelativePath = $relative
            TargetPath   = $targetPath
            Exists       = (Test-Path $targetPath)
            Content      = $content
        }) | Out-Null
}

$plan.Add([pscustomobject]@{
        RelativePath = $resolvedSolutionName + '.sln / .slnx'
        TargetPath   = $solutionPath
        Exists       = ((Test-Path $solutionPath) -or (Test-Path (Join-Path $targetRoot ($resolvedSolutionName + '.slnx'))))
        Content      = '[dotnet new sln 自动生成]'
    }) | Out-Null

if ($DryRun) {
    Write-Host "蓝图预演：$BlueprintName -> $targetRoot"
    foreach ($item in $plan) {
        $status = if ($item.Exists) { '已存在' } else { '新建' }
        Write-Host ("[{0}] {1}" -f $status, $item.RelativePath)
    }

    Write-Host ('[命令] dotnet new sln -n ' + $resolvedSolutionName)
    Write-Host ('[命令] dotnet sln <' + $resolvedSolutionName + '.sln|.slnx> add ' + $projectRelativePath)
    Write-Host ('[命令] dotnet sln <' + $resolvedSolutionName + '.sln|.slnx> add ' + $testProjectRelativePath)
    if ($BlueprintName -eq 'gui-exe') {
        $dryRunIconSource = if ([string]::IsNullOrWhiteSpace($GuiIconSourcePath)) { '<dotnet-dev 内置图标>' } else { $GuiIconSourcePath }
        Write-Host ('[资源] GUI 图标来源：' + $dryRunIconSource)
        Write-Host ('[资源] GUI 图标目标：' + $guiIconAssetTargetPath)
    }
    if ($AddRecommendedPackages) {
        foreach ($pkg in (Get-RecommendedPackages -ResolvedBlueprintName $BlueprintName)) {
            $message = '[命令] dotnet add ' + $projectRelativePath + ' package ' + $pkg.Name
            if (-not [string]::IsNullOrWhiteSpace($pkg.Version)) {
                $message += ' --version ' + $pkg.Version
            }
            Write-Host $message
        }
    }
    return
}

Assert-DotnetAvailable

$conflicts = @($plan | Where-Object { $_.Exists })
if ($conflicts.Count -gt 0 -and -not $Force) {
    $preview = ($conflicts | Select-Object -First 10 | ForEach-Object { $_.RelativePath }) -join ', '
    throw "目标目录已有同名文件，请先清理或使用 -Force 覆盖。示例冲突：$preview"
}

foreach ($item in ($plan | Where-Object { $_.RelativePath -ne ($resolvedSolutionName + '.sln') })) {
    Write-Utf8File -Path $item.TargetPath -Content $item.Content
}

if ($BlueprintName -eq 'gui-exe') {
    $resolvedGuiIconSourcePath = if ([string]::IsNullOrWhiteSpace($GuiIconSourcePath)) {
        Get-DefaultGuiIconSourcePath -SkillRoot $scriptRoot
    }
    else {
        [System.IO.Path]::GetFullPath($GuiIconSourcePath)
    }

    if ([string]::IsNullOrWhiteSpace($resolvedGuiIconSourcePath)) {
        throw 'gui-exe 蓝图缺少默认图标资产。请先执行 scripts\update_gui_blueprint_icon.ps1 或传入 -GuiIconSourcePath。'
    }

    [void](Install-GuiIconAssets -SourceIconPath $resolvedGuiIconSourcePath -TargetDirectory $guiIconAssetTargetPath)
}

foreach ($candidate in @($solutionPath, (Join-Path $targetRoot ($resolvedSolutionName + '.slnx')))) {
    if (Test-Path $candidate) {
        [System.IO.File]::Delete($candidate)
    }
}

Invoke-DotnetCommand -WorkingDirectory $targetRoot -Arguments @('new', 'sln', '-n', $resolvedSolutionName, '--force')
$resolvedSolutionPath = Resolve-SolutionFilePath -RootPath $targetRoot -ResolvedSolutionName $resolvedSolutionName
if ($null -eq $resolvedSolutionPath) {
    throw 'dotnet new sln 执行后未找到解决方案文件。'
}
Invoke-DotnetCommand -WorkingDirectory $targetRoot -Arguments @('sln', $resolvedSolutionPath, 'add', $projectFilePath)
Invoke-DotnetCommand -WorkingDirectory $targetRoot -Arguments @('sln', $resolvedSolutionPath, 'add', $testProjectFilePath)

if ($AddRecommendedPackages) {
    foreach ($pkg in (Get-RecommendedPackages -ResolvedBlueprintName $BlueprintName)) {
        $arguments = @('add', $projectFilePath, 'package', $pkg.Name)
        if (-not [string]::IsNullOrWhiteSpace($pkg.Version)) {
            $arguments += @('--version', $pkg.Version)
        }
        Invoke-DotnetCommand -WorkingDirectory $targetRoot -Arguments $arguments
    }
}

Write-Host "蓝图已实例化：$BlueprintName -> $targetRoot"
Write-Host "目标框架：$framework"
Write-Host "解决方案：$resolvedSolutionPath"

<#
data_uid: f736598a-9b4730eb-995168b2-c201066f-4ca0bc36-4d69bd32-64d1cd22
env_hash: 620442df-8498ee3b-df98a74c-e3e1ff4d-8781ee3b-de93a750-d52407a7-01612e3a-e0a8a753-f4e1cb5d-42e2cb5f-8498cb30-de88a664-e7eddb4f-848aca39-ff87a54b-cae2ca68-8a83e838-f6acad63-eee3e45e-84a9e03b-d9bfa662-f7e1ff7d-87b8cd38-f880a44c-e7ecc575-86b8e239-f0a9a15f-e0e1ed66-86becc39-e3b2a45b-ede0fe7f-8496ef3c-e285aa4f-c7e1ca76-8484e53b-dea4a44d-cfece353-86bcf830-de88a457-f3e2d466-87b4c43b-dd99a54a-fbecfd62-85adf439-d191a761-e9ecf67c-86bff938-f880a442-e1e1ca76-8184c0
#>
