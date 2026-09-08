#requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$BlueprintName,

    [Parameter(Mandatory = $true)]
    [string]$TargetRoot,

    [Parameter(Mandatory = $true)]
    [string]$PackageName,

    [string]$ProjectName = '',

    [string]$ProjectDescription = 'Python 项目模板',

    [switch]$DryRun,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

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
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-BlueprintPlan {
    param(
        [string]$BlueprintRoot,
        [string]$ResolvedTargetRoot,
        [hashtable]$Tokens,
        [string]$ResolvedPackageName
    )

    $plan = New-Object System.Collections.Generic.List[object]

    Get-ChildItem -Path $BlueprintRoot -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($BlueprintRoot.Length).TrimStart('\')
        $relativePath = $relativePath.Replace('app_name', $ResolvedPackageName)

        $content = ''
        if ($relativePath.EndsWith('.tmpl')) {
            $relativePath = $relativePath.Substring(0, $relativePath.Length - 5)
            $content = Expand-Template -Content (Read-Utf8File $_.FullName) -Tokens $Tokens
        }
        else {
            $content = Read-Utf8File $_.FullName
        }

        $targetPath = Join-Path $ResolvedTargetRoot $relativePath
        $exists = Test-Path $targetPath

        $plan.Add([pscustomobject]@{
                SourcePath   = $_.FullName
                RelativePath = $relativePath
                TargetPath   = $targetPath
                Exists       = $exists
                Content      = $content
            }) | Out-Null
    }

    $packageInitRelativePath = Join-Path 'src' (Join-Path $ResolvedPackageName '__init__.py')
    $hasPackageInit = $plan | Where-Object { $_.RelativePath -eq $packageInitRelativePath }
    if (-not $hasPackageInit) {
        $packageInitTargetPath = Join-Path $ResolvedTargetRoot $packageInitRelativePath
        $plan.Add([pscustomobject]@{
                SourcePath   = '[generated]'
                RelativePath = $packageInitRelativePath
                TargetPath   = $packageInitTargetPath
                Exists       = Test-Path $packageInitTargetPath
                Content      = '"""项目包入口。"""'
            }) | Out-Null
    }

    # 自动包含 templates/shared/ 下的公共模板（如 logging_setup.py.tmpl）
    # 蓝图自身的同名文件优先，shared 版本仅作补充
    $sharedRoot = Join-Path $scriptRoot 'templates\shared'
    if (Test-Path $sharedRoot) {
        Get-ChildItem -Path $sharedRoot -File -Filter '*.tmpl' | ForEach-Object {
            $sharedFileName = $_.Name -replace '\.tmpl$', ''
            $sharedRelativePath = Join-Path 'src' (Join-Path $ResolvedPackageName $sharedFileName)
            $alreadyHas = $plan | Where-Object { $_.RelativePath -eq $sharedRelativePath }
            if (-not $alreadyHas) {
                $sharedTargetPath = Join-Path $ResolvedTargetRoot $sharedRelativePath
                $sharedContent = Expand-Template -Content (Read-Utf8File $_.FullName) -Tokens $Tokens
                $plan.Add([pscustomobject]@{
                        SourcePath   = $_.FullName
                        RelativePath = $sharedRelativePath
                        TargetPath   = $sharedTargetPath
                        Exists       = Test-Path $sharedTargetPath
                        Content      = $sharedContent
                    }) | Out-Null
            }
        }
    }

    return $plan
}

function Expand-Template {
    param([string]$Content, [hashtable]$Tokens)
    $result = $Content
    foreach ($key in $Tokens.Keys) {
        $result = $result.Replace("__${key}__", [string]$Tokens[$key])
    }
    return $result
}

$scriptRoot = Split-Path -Parent $PSScriptRoot
$blueprintRoot = Join-Path $scriptRoot ('templates\project-blueprints\' + $BlueprintName)
if (-not (Test-Path $blueprintRoot)) {
    throw "未找到蓝图: $BlueprintName"
}

$targetRoot = [System.IO.Path]::GetFullPath($TargetRoot)
$projectToken = if ([string]::IsNullOrWhiteSpace($ProjectName)) { $PackageName } else { $ProjectName }
$tokens = @{
    PROJECT_NAME = $projectToken
    PROJECT_DESCRIPTION = $ProjectDescription
    PACKAGE_NAME = $PackageName
    APP_NAME = $projectToken
    BLUEPRINT_NAME = $BlueprintName
}

$plan = Get-BlueprintPlan -BlueprintRoot $blueprintRoot -ResolvedTargetRoot $targetRoot -Tokens $tokens -ResolvedPackageName $PackageName
$conflicts = @($plan | Where-Object { $_.Exists })

if ($DryRun) {
    Write-Host "蓝图预演：$BlueprintName -> $targetRoot"
    foreach ($item in $plan) {
        $status = if ($item.Exists) { '已存在' } else { '新建' }
        Write-Host ("[{0}] {1}" -f $status, $item.RelativePath)
    }

    if ($conflicts.Count -gt 0) {
        Write-Host ('检测到冲突文件数量: ' + $conflicts.Count)
    }

    return
}

if ($conflicts.Count -gt 0 -and -not $Force) {
    $conflictPreview = ($conflicts | Select-Object -First 10 | ForEach-Object { $_.RelativePath }) -join ', '
    throw "目标目录中已存在文件。请先处理冲突，或使用 -Force 覆盖。示例冲突: $conflictPreview"
}

foreach ($item in $plan) {
    Write-Utf8File -Path $item.TargetPath -Content $item.Content
}

Write-Host "蓝图已实例化：$BlueprintName -> $targetRoot"
if ($conflicts.Count -gt 0) {
    Write-Host ('已覆盖冲突文件数量: ' + $conflicts.Count)
}
Write-Host '建议下一步：由 AI 继续执行 uv add、uv run、测试与打包。'

<#
flow_ref: 9b06f919-f7779078-f561c821-ae31a6fc-20901ca5-21591da1-08e16db1
state_hash: eb12b1b7-0d8e1d53-568e5424-6af70c25-0e971d53-57855438-5c32f4cf-8877dd52-69be543b-7df73835-cbf43837-0d8e3858-579e550c-6efb2827-0d9c3951-76915623-43f43900-03951b50-7fba5e0b-67f51736-0dbf1353-50a9550a-7ef70c15-0eae3e50-71965724-6efa361d-0fae1151-79bf5237-69f71e0e-0fa83f51-6aa45733-64f60d17-0d801c54-6b935927-4ef7391e-0d921653-57b25725-46fa103b-0faa0b58-579e573f-7af4270e-0ea23753-548f5622-72fa0e0a-0cbb0751-58875409-60fa0514-0fa90a50-7196572a-68f7391e-089233
#>
