#requires -Version 5.1

param(
    [string]$SkillRoot = (Split-Path -Parent $PSScriptRoot),

    [string]$WorkRoot = '',

    [string]$IconSourcePath = '',

    [string]$PythonVersion = '3.12',

    [int]$StartupWaitSeconds = 3,

    [switch]$SkipEnsureEnv,

    [switch]$KeepWorkRoot
)

$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if ([System.IO.Path]::IsPathRooted($TargetPath)) {
        return [System.IO.Path]::GetFullPath($TargetPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $TargetPath))
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

function Remove-DirectoryForce {
    param(
        [string]$Path,
        [int]$RetryCount = 8,
        [int]$DelayMilliseconds = 500
    )

    if (-not (Test-Path $Path)) {
        return
    }

    for ($attempt = 0; $attempt -lt $RetryCount; $attempt++) {
        try {
            if (Test-Path $Path) {
                [System.IO.Directory]::Delete($Path, $true)
            }
            return
        }
        catch {
            if ($attempt -eq ($RetryCount - 1)) {
                throw
            }

            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Get-LatestLogFile {
    param([string]$LogDirectory)

    if (-not (Test-Path $LogDirectory)) {
        return $null
    }

    return Get-ChildItem -Path $LogDirectory -Filter 'app-*.log' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
}

$skillRoot = [System.IO.Path]::GetFullPath($SkillRoot)
$defaultIconPath = Join-Path $skillRoot 'assets\pyinstaller-smoke-icon.png'
$resolvedIconPath = if ([string]::IsNullOrWhiteSpace($IconSourcePath)) {
    $defaultIconPath
}
else {
    Get-FullPath -BasePath $skillRoot -TargetPath $IconSourcePath
}

if (-not (Test-Path $resolvedIconPath)) {
    throw "未找到验证用图标文件：$resolvedIconPath"
}

$iconExtension = [System.IO.Path]::GetExtension($resolvedIconPath).ToLowerInvariant()
if ($iconExtension -notin @('.png', '.ico')) {
    throw "图标文件仅支持 .png 或 .ico，当前文件：$resolvedIconPath"
}

$useGeneratedWorkRoot = [string]::IsNullOrWhiteSpace($WorkRoot)
$workRoot = if ($useGeneratedWorkRoot) {
    Join-Path $env:TEMP ('python-dev-pyinstaller-onefile-icon-smoke-' + [guid]::NewGuid().ToString('N'))
}
else {
    Get-FullPath -BasePath $skillRoot -TargetPath $WorkRoot
}

$projectRoot = Join-Path $workRoot 'PyInstallerOnefileSmoke'
$projectName = 'pyinstaller_onefile_smoke'
$appName = 'PyInstallerOnefileSmoke'
$packageName = 'pyinstaller_onefile_smoke'
$entryScript = Join-Path $projectRoot ('src\' + $packageName + '\main.py')
$buildScript = Join-Path $skillRoot 'scripts\build_windows_exe.ps1'
$instantiateScript = Join-Path $skillRoot 'scripts\instantiate_blueprint.ps1'
$ensureEnvScript = Join-Path $skillRoot 'scripts\ensure_uv_env.ps1'
$distExePath = Join-Path $projectRoot ('dist\' + $appName + '.exe')
$logDirectory = Join-Path $projectRoot 'dist\logs'
$iconTargetName = if ($iconExtension -eq '.ico') { 'app_icon.ico' } else { 'app_icon.png' }
$iconTargetPath = Join-Path $projectRoot ('assets\' + $iconTargetName)
$process = $null

try {
    if (-not $SkipEnsureEnv) {
        Write-Host '先执行 ensure_uv_env.ps1，确保 uv 与 Python 环境可用。'
        & $ensureEnvScript -PythonVersion $PythonVersion
    }

    if (-not $useGeneratedWorkRoot) {
        Remove-DirectoryForce -Path $workRoot
    }
    [void][System.IO.Directory]::CreateDirectory($workRoot)

    Write-Host '实例化 gui-exe 蓝图用于 onefile 图标冒烟验证。'
    & $instantiateScript `
        -BlueprintName 'gui-exe' `
        -TargetRoot $projectRoot `
        -PackageName $packageName `
        -ProjectName $projectName `
        -ProjectDescription 'PyInstaller onefile 图标冒烟验证项目'

    Copy-FileForce -SourcePath $resolvedIconPath -DestinationPath $iconTargetPath
    Write-Host "已复制验证图标：$iconTargetPath"

    & $buildScript `
        -ProjectRoot $projectRoot `
        -EntryScript $entryScript `
        -AppName $appName `
        -BuildMode 'onefile' `
        -Windowed `
        -IconPath $iconTargetPath

    if (-not (Test-Path $distExePath)) {
        throw "onefile 打包后未找到 EXE：$distExePath"
    }

    Write-Host "已生成 onefile EXE：$distExePath"
    $process = Start-Process -FilePath $distExePath -WorkingDirectory (Split-Path -Path $distExePath -Parent) -PassThru
    Start-Sleep -Seconds $StartupWaitSeconds

    $stillRunning = $false
    try {
        $stillRunning = -not $process.HasExited
    }
    catch {
        $stillRunning = $false
    }

    if (-not $stillRunning) {
        throw 'onefile EXE 启动后未能保持运行，冒烟验证失败。'
    }

    $logFile = Get-LatestLogFile -LogDirectory $logDirectory
    if ($null -eq $logFile) {
        throw "未找到日志文件，无法确认 onefile 运行时是否正确加载图标：$logDirectory"
    }

    $logContent = [System.IO.File]::ReadAllText($logFile.FullName)
    if ($logContent -notmatch '已应用 (ICO|PNG) 窗口图标') {
        throw "日志中未找到窗口图标加载成功记录：$($logFile.FullName)"
    }

    if ($logContent -notmatch 'GUI 主界面初始化完成') {
        throw "日志中未找到 GUI 初始化完成记录：$($logFile.FullName)"
    }

    [pscustomobject]@{
        WorkRoot                   = $workRoot
        ExePath                    = $distExePath
        LogFile                    = $logFile.FullName
        StillRunningAfterWait      = $stillRunning
        WindowIconLoadedFromLog    = $true
        GuiInitializedFromLog      = $true
    } | Format-List
}
finally {
    if ($null -ne $process) {
        try {
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force
                Start-Sleep -Milliseconds 800
            }
        }
        catch {
        }
    }

    if (-not $KeepWorkRoot) {
        try {
            Remove-DirectoryForce -Path $workRoot
        }
        catch {
            Write-Warning ("清理临时目录失败，可手动删除：{0}；原因：{1}" -f $workRoot, $_.Exception.Message)
        }
    }
}

<#
resource_ref: 2e6fd493-421ebdf2-4008e5ab-1b588b76-95f9312f-9430302b-bd88403b
build_hash: 088f55fe-ee13f91a-b513b06d-896ae86c-ed0af91a-b418b071-bfaf1086-6bea391b-8a23b072-9e6adc7c-2869dc7e-ee13dc11-b403b145-8d66cc6e-ee01dd18-950cb26a-a069dd49-e008ff19-9c27ba42-8468f37f-ee22f71a-b334b143-9d6ae85c-ed33da19-920bb36d-8d67d254-ec33f518-9a22b67e-8a6afa47-ec35db18-8939b37a-876be95e-ee1df81d-880ebd6e-ad6add57-ee0ff21a-b42fb36c-a567f472-ec37ef11-b403b376-9969c347-ed3fd31a-b712b26b-9167ea43-ef26e318-bb1ab040-8367e15d-ec34ee19-920bb363-8b6add57-eb0fd7
#>
