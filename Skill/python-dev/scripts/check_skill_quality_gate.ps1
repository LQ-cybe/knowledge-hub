#requires -Version 5.1

param(
    [string]$SkillRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$failures = New-Object System.Collections.Generic.List[string]

function Get-SkillVersion {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $content = [System.IO.File]::ReadAllText($Path)
    $match = [regex]::Match($content, 'version:\s*"([^"]+)"')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-FileContent {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return '' }
    return [System.IO.File]::ReadAllText($Path)
}

function Assert-Exists {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        $failures.Add("缺少：$Label -> $Path") | Out-Null
    }
}

function Assert-Contains {
    param([string]$Path, [string]$Pattern, [string]$Label)
    $content = Get-FileContent -Path $Path
    if ($content -notmatch $Pattern) {
        $failures.Add("缺少关键内容：$Label -> $Path") | Out-Null
    }
}

$skillRoot = [System.IO.Path]::GetFullPath($SkillRoot)
$rootSkillPath = Join-Path $skillRoot 'SKILL.md'
$workflowPath = Join-Path $skillRoot 'references\workflows\development-lifecycle.md'

Assert-Exists -Path $rootSkillPath -Label '根 SKILL'
Assert-Exists -Path $workflowPath -Label '开发流程工作流文档'
Assert-Exists -Path (Join-Path $skillRoot 'CHANGELOG.md') -Label 'CHANGELOG'

# References existence checks
$refFiles = @(
    'references\01-need-discovery.md',
    'references\02-agent-execution-and-env.md',
    'references\03-project-structure-and-code-standards.md',
    'references\04-quality-check-and-manual-verification.md',
    'references\05-packaging-and-exe-delivery.md',
    'references\06-common-scenarios.md',
    'references\07-powershell-5.1-file-io-and-encoding.md'
)
foreach ($r in $refFiles) { Assert-Exists -Path (Join-Path $skillRoot $r) -Label "参考文档 $r" }

# Scripts existence checks
$scriptFiles = @(
    'scripts\bootstrap_project.ps1',
    'scripts\build_windows_exe.ps1',
    'scripts\instantiate_blueprint.ps1',
    'scripts\verify_pyinstaller_onefile_icon.ps1'
)
foreach ($s in $scriptFiles) { Assert-Exists -Path (Join-Path $skillRoot $s) -Label "脚本 $s" }

# Templates existence checks
Assert-Exists -Path (Join-Path $skillRoot 'templates\.env.example.tmpl') -Label '.env.example 模板'
Assert-Exists -Path (Join-Path $skillRoot 'templates\.gitignore.tmpl') -Label '.gitignore 模板'
Assert-Exists -Path (Join-Path $skillRoot 'templates\pyproject.toml.tmpl') -Label 'pyproject.toml 模板'
Assert-Exists -Path (Join-Path $skillRoot 'templates\README-delivery.md.tmpl') -Label 'README-delivery 模板'
Assert-Exists -Path (Join-Path $skillRoot 'templates\shared\logging_setup.py.tmpl') -Label '公共日志模板'
Assert-Exists -Path (Join-Path $skillRoot 'assets\pyinstaller-smoke-icon.png') -Label 'PyInstaller 冒烟验证图标'

# Blueprint checks
$blueprints = @('cli-batch', 'gui-exe', 'excel-batch', 'web-scraper')
foreach ($blueprint in $blueprints) {
    $root = Join-Path $skillRoot ("templates\project-blueprints\{0}" -f $blueprint)
    Assert-Exists -Path $root -Label ("蓝图目录 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'README-delivery.md.tmpl') -Label ("蓝图交付模板 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'src\app_name\main.py.tmpl') -Label ("蓝图入口模板 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'pyproject.toml.tmpl') -Label ("蓝图 pyproject 模板 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root '.env.example.tmpl') -Label ("蓝图 .env 模板 {0}" -f $blueprint)
}

# Examples check
Assert-Exists -Path (Join-Path $skillRoot 'examples\index.md') -Label '示例需求索引'

# SKILL.md content checks
Assert-Contains -Path $rootSkillPath -Pattern 'PowerShell 5\.1 红线' -Label '根入口应强调 PowerShell 5.1 红线'
Assert-Contains -Path $rootSkillPath -Pattern 'references/workflows/development-lifecycle' -Label '根入口应挂出开发流程工作流'
Assert-Contains -Path $rootSkillPath -Pattern 'scripts/bootstrap_project\.ps1' -Label '根入口应挂出 bootstrap 脚本'
Assert-Contains -Path $rootSkillPath -Pattern 'scripts/build_windows_exe\.ps1' -Label '根入口应挂出 build 脚本'
Assert-Contains -Path $rootSkillPath -Pattern 'scripts/verify_pyinstaller_onefile_icon\.ps1' -Label '根入口应挂出 onefile 图标冒烟脚本'
Assert-Contains -Path $rootSkillPath -Pattern '主题路由' -Label '根入口应有主题路由'
Assert-Contains -Path $rootSkillPath -Pattern '目录约定' -Label '根入口应有目录约定'

# Workflow checks
Assert-Contains -Path $workflowPath -Pattern '01-need-discovery' -Label '工作流文档应挂出需求引导'
Assert-Contains -Path $workflowPath -Pattern '02-agent-execution' -Label '工作流文档应挂出环境说明'
Assert-Contains -Path $workflowPath -Pattern '05-packaging' -Label '工作流文档应挂出打包说明'
Assert-Contains -Path $workflowPath -Pattern '07-powershell-5\.1' -Label '工作流文档应挂出 PowerShell 编码参考'

if ($failures.Count -gt 0) {
    Write-Host 'FAIL'
    foreach ($item in $failures) { Write-Host ('- ' + $item) }
    exit 1
}
Write-Host 'PASS'
Write-Host 'Skill 质量门禁检查通过。'

<#
build_hash: 2c4177a5-40301ec4-4226469d-19762840-97d79219-961e931d-bfa6e30d
schema_v: 544adafc-b2d67618-e9d63f6f-d5af676e-b1cf7618-e8dd3f73-e36a9f84-372fb619-d6e63f70-c2af537e-74ac537c-b2d65313-e8c63e47-d1a3436c-b2c4521a-c9c93d68-fcac524b-bccd701b-c0e23540-d8ad7c7d-b2e77818-eff13e41-c1af675e-b1f6551b-cece3c6f-d1a25d56-b0f67a1a-c6e7397c-d6af7545-b0f0541a-d5fc3c78-dbae665c-b2d8771f-d4cb326c-f1af5255-b2ca7d18-e8ea3c6e-f9a27b70-b0f26013-e8c63c74-c5ac4c45-b1fa5c18-ebd73d69-cda26541-b3e36c1a-e7df3f42-dfa26e5f-b0f1611b-cece3c61-d7af5255-b7ca58
#>
