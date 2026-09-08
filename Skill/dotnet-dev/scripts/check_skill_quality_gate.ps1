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
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Label
    )

    $content = Get-FileContent -Path $Path
    if ($content -notmatch $Pattern) {
        $failures.Add("缺少关键内容：$Label -> $Path") | Out-Null
    }
}

function Assert-NotContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Label
    )

    $content = Get-FileContent -Path $Path
    if ($content -match $Pattern) {
        $failures.Add("发现不应出现的内容：$Label -> $Path") | Out-Null
    }
}

$skillRoot = [System.IO.Path]::GetFullPath($SkillRoot)
$rootSkillPath = Join-Path $skillRoot 'SKILL.md'
$workflowPath = Join-Path $skillRoot 'references\workflows\development-lifecycle.md'
$bootstrapScriptPath = Join-Path $skillRoot 'scripts\bootstrap_project.ps1'
$ensureDotnetScriptPath = Join-Path $skillRoot 'scripts\ensure_dotnet_sdk.ps1'
$instantiateScriptPath = Join-Path $skillRoot 'scripts\instantiate_blueprint.ps1'
$buildScriptPath = Join-Path $skillRoot 'scripts\build_windows_exe.ps1'
$qualityGateScriptPath = Join-Path $skillRoot 'scripts\check_skill_quality_gate.ps1'

Assert-Exists -Path $rootSkillPath -Label '根 SKILL'
Assert-Exists -Path $workflowPath -Label '开发流程工作流文档'
Assert-Exists -Path (Join-Path $skillRoot 'CHANGELOG.md') -Label 'CHANGELOG'
Assert-Exists -Path (Join-Path $skillRoot 'references\01-need-discovery.md') -Label '需求引导说明'
Assert-Exists -Path (Join-Path $skillRoot 'references\02-agent-execution-and-env.md') -Label 'AI 代执行与环境约束说明'
Assert-Exists -Path (Join-Path $skillRoot 'references\03-project-structure-and-code-standards.md') -Label '项目结构与代码规范说明'
Assert-Exists -Path (Join-Path $skillRoot 'references\04-quality-check-and-manual-verification.md') -Label '质量检查说明'
Assert-Exists -Path (Join-Path $skillRoot 'references\05-packaging-and-exe-delivery.md') -Label '打包与交付说明'
Assert-Exists -Path (Join-Path $skillRoot 'references\13-targetframework-and-rollforward-strategy.md') -Label 'TargetFramework 与 RollForward 决策说明'

Assert-Exists -Path (Join-Path $skillRoot 'references\07-handycontrol-routing.md') -Label 'HandyControl 接入与避坑指南'
Assert-Exists -Path (Join-Path $skillRoot 'docs\handycontrol\index.md') -Label 'HandyControl 文档入口'
Assert-Exists -Path (Join-Path $skillRoot 'references\08-powershell-5.1-file-io-and-encoding.md') -Label 'PowerShell 5.1 编码说明'
Assert-Exists -Path $bootstrapScriptPath -Label '项目初始化脚本'
Assert-Exists -Path $ensureDotnetScriptPath -Label 'SDK 自举脚本'
Assert-Exists -Path $instantiateScriptPath -Label '蓝图实例化脚本'
Assert-Exists -Path $buildScriptPath -Label 'Windows 发布脚本'
Assert-Exists -Path $qualityGateScriptPath -Label '质量门禁脚本'
Assert-Exists -Path (Join-Path $skillRoot 'templates\Directory.Build.props.tmpl') -Label 'Directory.Build.props 模板'
Assert-Exists -Path (Join-Path $skillRoot 'templates\.gitignore.tmpl') -Label '.gitignore 模板'
Assert-Exists -Path (Join-Path $skillRoot 'templates\NuGet.config.tmpl') -Label 'NuGet.config 模板'

$rootVersion = Get-SkillVersion -Path $rootSkillPath

$childSkillDirectories = @('need-discovery', 'env-setup', 'code-standards', 'quality-check', 'packaging', 'powershell-encoding', 'fullstack-workflow')
foreach ($child in $childSkillDirectories) {
    $childPath = Join-Path $skillRoot $child
    if (Test-Path $childPath) {
        $failures.Add("应已迁移或删除的子 skill 目录仍存在：$childPath") | Out-Null
    }
}

$blueprints = @('cli-batch', 'gui-exe', 'excel-batch', 'web-scraper')
foreach ($blueprint in $blueprints) {
    $root = Join-Path $skillRoot ("templates\project-blueprints\{0}" -f $blueprint)
    Assert-Exists -Path $root -Label ("蓝图目录 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'README-delivery.md.tmpl') -Label ("蓝图交付模板 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'src\app_name\app_name.csproj.tmpl') -Label ("蓝图主项目模板 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'src\app_name\appsettings.json.tmpl') -Label ("蓝图配置模板 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'tests\app_name.Tests.csproj.tmpl') -Label ("蓝图测试项目模板 {0}" -f $blueprint)
    Assert-Exists -Path (Join-Path $root 'tests\SmokeTests.cs.tmpl') -Label ("蓝图测试代码模板 {0}" -f $blueprint)

    if ($blueprint -eq 'gui-exe') {
        Assert-Exists -Path (Join-Path $root 'src\app_name\App.xaml.tmpl') -Label 'gui-exe App.xaml 模板'
        Assert-Exists -Path (Join-Path $root 'src\app_name\App.xaml.cs.tmpl') -Label 'gui-exe App.xaml.cs 模板'
        Assert-Exists -Path (Join-Path $root 'src\app_name\Views\MainWindow.xaml.tmpl') -Label 'gui-exe MainWindow.xaml 模板'
        Assert-Exists -Path (Join-Path $root 'src\app_name\Views\MainWindow.xaml.cs.tmpl') -Label 'gui-exe MainWindow.xaml.cs 模板'
        Assert-Exists -Path (Join-Path $root 'src\app_name\ViewModels\MainWindowViewModel.cs.tmpl') -Label 'gui-exe ViewModel 模板'
        Assert-Exists -Path (Join-Path $root 'src\app_name\Services\IShellService.cs.tmpl') -Label 'gui-exe IShellService 模板'
        Assert-Exists -Path (Join-Path $root 'src\app_name\Services\ShellService.cs.tmpl') -Label 'gui-exe ShellService 模板'
    }
    else {
        Assert-Exists -Path (Join-Path $root 'src\app_name\Program.cs.tmpl') -Label ("蓝图入口模板 {0}" -f $blueprint)
    }
}

Assert-Contains -Path $rootSkillPath -Pattern 'Win7' -Label '根入口应说明 Win7 决策'
Assert-Contains -Path $rootSkillPath -Pattern 'Win10' -Label '根入口应说明 Win10 策略'
Assert-Contains -Path $rootSkillPath -Pattern '\.NET 8' -Label '根入口应说明 .NET 8 策略'
Assert-Contains -Path $rootSkillPath -Pattern '\.NET 10' -Label '根入口应说明 .NET 10 策略'
Assert-Contains -Path $rootSkillPath -Pattern '13-targetframework-and-rollforward-strategy' -Label '根入口应挂出 TargetFramework 与 RollForward 决策文档'
Assert-Contains -Path $rootSkillPath -Pattern 'ensure_dotnet_sdk\.ps1' -Label '根入口应挂出 SDK 自举脚本'
Assert-Contains -Path $rootSkillPath -Pattern 'powershell-5\.1-file-io-and-encoding' -Label '根入口应挂出 PowerShell 5.1 编码参考'
Assert-Contains -Path $rootSkillPath -Pattern 'PowerShell 5\.1 红线' -Label '根入口应强调 PowerShell 5.1 红线'


Assert-Contains -Path $rootSkillPath -Pattern 'references/workflows/development-lifecycle' -Label '根入口应挂出开发流程工作流'
Assert-Contains -Path $rootSkillPath -Pattern 'scripts/bootstrap_project\.ps1' -Label '根入口应挂出 bootstrap 脚本'
Assert-Contains -Path $rootSkillPath -Pattern 'scripts/build_windows_exe\.ps1' -Label '根入口应挂出 build 脚本'
Assert-NotContains -Path $rootSkillPath -Pattern 'powershell-encoding/SKILL\.md' -Label '根入口不应再引用旧子 skill 路径'

Assert-Contains -Path $workflowPath -Pattern '01-need-discovery' -Label '工作流文档应挂出需求引导'
Assert-Contains -Path $workflowPath -Pattern '13-targetframework-and-rollforward-strategy' -Label '工作流文档应挂出版本决策文档'
Assert-Contains -Path $workflowPath -Pattern 'ensure_dotnet_sdk\.ps1' -Label '工作流文档应挂出 SDK 自举脚本'
Assert-Contains -Path $workflowPath -Pattern 'bootstrap_project\.ps1' -Label '工作流文档应挂出 bootstrap 脚本'
Assert-Contains -Path $workflowPath -Pattern 'build_windows_exe\.ps1' -Label '工作流文档应挂出 build 脚本'
Assert-Contains -Path $workflowPath -Pattern '08-powershell-5\.1-file-io-and-encoding' -Label '工作流文档应挂出 PowerShell 5.1 编码参考'

Assert-Contains -Path $bootstrapScriptPath -Pattern 'NeedWin7Support' -Label 'bootstrap 应包含 Win7 决策开关'
Assert-Contains -Path $bootstrapScriptPath -Pattern "'restore'" -Label 'bootstrap 应包含 restore 流程'
Assert-Contains -Path $bootstrapScriptPath -Pattern "'build'" -Label 'bootstrap 应包含 build 流程'
Assert-Contains -Path $bootstrapScriptPath -Pattern 'net8\.0' -Label 'bootstrap 应支持 .NET 8'
Assert-Contains -Path $bootstrapScriptPath -Pattern "return 'net6\.0'" -Label 'bootstrap 默认应回到 .NET 6'
Assert-Contains -Path $bootstrapScriptPath -Pattern 'ensure_dotnet_sdk\.ps1' -Label 'bootstrap 应接入 SDK 自举脚本'

Assert-Contains -Path $ensureDotnetScriptPath -Pattern 'Microsoft\.DotNet\.SDK\.6' -Label 'SDK 自举脚本应支持 .NET 6 安装'
Assert-Contains -Path $ensureDotnetScriptPath -Pattern 'Microsoft\.DotNet\.SDK\.8' -Label 'SDK 自举脚本应支持 .NET 8 安装'
Assert-Contains -Path $ensureDotnetScriptPath -Pattern 'Microsoft\.DotNet\.SDK\.10' -Label 'SDK 自举脚本应支持 .NET 10 安装'
Assert-Contains -Path $ensureDotnetScriptPath -Pattern 'dotnet-install\.ps1' -Label 'SDK 自举脚本应支持官方安装脚本回退'
Assert-Contains -Path $ensureDotnetScriptPath -Pattern 'net8\.0' -Label 'SDK 自举脚本应支持 .NET 8'
Assert-Contains -Path $ensureDotnetScriptPath -Pattern "return 'net6\.0'" -Label 'SDK 自举脚本默认应回到 .NET 6'

Assert-Contains -Path $instantiateScriptPath -Pattern 'dotnet new sln' -Label 'instantiate 应创建解决方案'
Assert-Contains -Path $instantiateScriptPath -Pattern 'dotnet sln' -Label 'instantiate 应将项目加入解决方案'
Assert-Contains -Path $instantiateScriptPath -Pattern 'ClosedXML' -Label 'instantiate 应支持 ClosedXML 推荐包'
Assert-Contains -Path $instantiateScriptPath -Pattern 'HtmlAgilityPack' -Label 'instantiate 应支持 HtmlAgilityPack 推荐包'
Assert-Contains -Path $instantiateScriptPath -Pattern 'net8\.0' -Label 'instantiate 应支持 .NET 8'
Assert-Contains -Path $instantiateScriptPath -Pattern '\[string\]\$TargetFramework = ''net6\.0''' -Label 'instantiate 默认应使用 .NET 6'
Assert-Contains -Path $instantiateScriptPath -Pattern 'templates\\project-blueprints' -Label 'instantiate 应从 templates 读取蓝图'
Assert-Contains -Path $instantiateScriptPath -Pattern 'templates\\Directory\.Build\.props\.tmpl' -Label 'instantiate 应从 templates 读取公共配置模板'

$guiProjectTemplatePath = Join-Path $skillRoot 'templates\project-blueprints\gui-exe\src\app_name\app_name.csproj.tmpl'
 $guiAppTemplatePath = Join-Path $skillRoot 'templates\project-blueprints\gui-exe\src\app_name\App.xaml.tmpl'
 $guiMainWindowTemplatePath = Join-Path $skillRoot 'templates\project-blueprints\gui-exe\src\app_name\Views\MainWindow.xaml.tmpl'
Assert-Contains -Path $guiProjectTemplatePath -Pattern 'UseWPF' -Label 'gui-exe 应使用 WPF'
Assert-Contains -Path $guiProjectTemplatePath -Pattern 'CommunityToolkit\.Mvvm' -Label 'gui-exe 应内置 MVVM 包'
Assert-Contains -Path $guiProjectTemplatePath -Pattern 'HandyControl' -Label 'gui-exe 应内置 HandyControl 包'
Assert-NotContains -Path $guiProjectTemplatePath -Pattern 'UseWindowsForms' -Label 'gui-exe 不应再使用 WinForms'
Assert-Contains -Path $guiAppTemplatePath -Pattern '<hc:Theme' -Label 'gui-exe App.xaml 应按官方方式接入 HandyControl 主题'
Assert-NotContains -Path $guiAppTemplatePath -Pattern 'ThemeResources' -Label 'gui-exe App.xaml 不应误用 HandyControls 的 ThemeResources'
Assert-Contains -Path $guiMainWindowTemplatePath -Pattern 'ButtonPrimary' -Label 'gui-exe 主窗口应演示 HandyControl 按钮样式'
Assert-Contains -Path $guiMainWindowTemplatePath -Pattern 'BorderElement\.CornerRadius' -Label 'gui-exe 主窗口应演示 HandyControl 附加属性'

Assert-Contains -Path $buildScriptPath -Pattern "'publish'" -Label 'build 脚本应使用 dotnet publish'
Assert-Contains -Path $buildScriptPath -Pattern 'PublishSingleFile' -Label 'build 脚本应支持单文件发布'
Assert-Contains -Path $buildScriptPath -Pattern 'PublishReadyToRun' -Label 'build 脚本应支持 ReadyToRun'
Assert-Contains -Path $buildScriptPath -Pattern 'EnableCompressionInSingleFile' -Label 'build 脚本应启用单文件压缩'
Assert-Contains -Path $buildScriptPath -Pattern 'DebugType=none' -Label 'build 脚本应移除调试符号'

if ($failures.Count -gt 0) {
    Write-Host 'FAIL'
    foreach ($item in $failures) {
        Write-Host ('- ' + $item)
    }
    exit 1
}

Write-Host 'PASS'
Write-Host 'Skill 质量门禁检查通过。'

<#
node_ref: 80ed5c2a-ec9c354b-ee8a6d12-b5da03cf-3b7bb996-3ab2b892-130ac882
doc_sid: 466a3de4-a0f69100-fbf6d877-c78f8076-a3ef9100-fafdd86b-f14a789c-250f5101-c4c6d868-d08fb466-668cb464-a0f6b40b-fae6d95f-c383a474-a0e4b502-dbe9da70-ee8cb553-aeed9703-d2c2d258-ca8d9b65-a0c79f00-fdd1d959-d38f8046-a3d6b203-dceedb77-c382ba4e-a2d69d02-d4c7de64-c48f925d-a2d0b302-c7dcdb60-c98e8144-a0f89007-c6ebd574-e38fb54d-a0ea9a00-facadb76-eb829c68-a2d2870b-fae6db6c-d78cab5d-a3dabb00-f9f7da71-df828259-a1c38b02-f5ffd85a-cd828947-a2d18603-dceedb79-c58fb54d-a5eabf
#>
