<#
.SYNOPSIS
检查 PNG / ICO 导出所需环境是否可用。

.DESCRIPTION
验证 Microsoft Edge 定位、无头截图能力，以及当前用户对临时目录和目标输出目录的写入权限。

.PARAMETER EdgePath
可选。显式指定 msedge.exe 路径。

.PARAMETER OutputDirectory
可选。要验证写入权限的输出目录。默认仅检查系统临时目录。

.EXAMPLE
./check_icon_export_environment.ps1

.EXAMPLE
./check_icon_export_environment.ps1 -EdgePath "C:\Program Files\Microsoft\Edge\Application\msedge.exe" -OutputDirectory "D:\MyProject\assets"
#>
param(
    [string]$EdgePath = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-EdgeExecutablePath {
    param(
        [string]$ExplicitEdgePath = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitEdgePath)) {
        $resolvedPath = [System.IO.Path]::GetFullPath($ExplicitEdgePath)
        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            throw "指定的 EdgePath 无效，文件不存在: $resolvedPath"
        }

        return $resolvedPath
    }

    $command = Get-Command msedge.exe -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        $command = Get-Command msedge -ErrorAction SilentlyContinue
    }

    if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
        return $command.Source
    }

    $candidatePaths = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path $env:LocalAppData "Microsoft\Edge\Application\msedge.exe")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($path in $candidatePaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe"
    )

    foreach ($registryPath in $registryPaths) {
        try {
            $appPath = (Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop)."(default)"
            if (-not [string]::IsNullOrWhiteSpace($appPath) -and (Test-Path -LiteralPath $appPath -PathType Leaf)) {
                return $appPath
            }
        }
        catch {
        }
    }

    throw "未找到 Microsoft Edge，可执行文件 `msedge.exe` 不存在或无法从命令行定位。"
}

function Test-DirectoryWritable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    $fullDirectoryPath = [System.IO.Path]::GetFullPath($DirectoryPath)
    if (-not (Test-Path -LiteralPath $fullDirectoryPath)) {
        [void][System.IO.Directory]::CreateDirectory($fullDirectoryPath)
    }

    $probePath = Join-Path $fullDirectoryPath ("write-test-{0}.tmp" -f ([System.Guid]::NewGuid().ToString("N")))
    try {
        [System.IO.File]::WriteAllText($probePath, "ok", (New-Object System.Text.UTF8Encoding $true))
        return $true
    }
    finally {
            [System.IO.File]::Delete($probePath)
            [System.IO.File]::Delete($probePath)
        }
    }
}

function Test-EdgeHeadlessScreenshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedEdgePath
    )

    $testHtml = "data:text/html,<html><body style='margin:0;background:transparent'><div style='width:64px;height:64px;background:#2563eb'></div></body></html>"
    $screenshotPath = Join-Path ([System.IO.Path]::GetTempPath()) ("edge-check-{0}.png" -f ([System.Guid]::NewGuid().ToString("N")))
    $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("edge-check-{0}.stderr.log" -f ([System.Guid]::NewGuid().ToString("N")))

    try {
        $null = & $ResolvedEdgePath --headless --disable-gpu --hide-scrollbars "--window-size=96,96" "--screenshot=$screenshotPath" $testHtml 2> $stderrPath
        $exitCode = $LASTEXITCODE
        $screenshotExists = Test-Path -LiteralPath $screenshotPath -PathType Leaf
        $stderr = ""

        if (Test-Path -LiteralPath $stderrPath) {
            try {
                $stderr = ([System.IO.File]::ReadAllText($stderrPath)).Trim()
            }
            catch {
                $stderr = ""
            }
        }

        return [pscustomobject]@{
            ok              = $screenshotExists
            exitCode        = $exitCode
            screenshotPath  = $screenshotPath
            stderr          = $stderr
        }
    }
    finally {
        if (Test-Path -LiteralPath $screenshotPath) {
            [System.IO.File]::Delete($screenshotPath)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            [System.IO.File]::Delete($stderrPath)
        }
    }
}

$tempDirectory = [System.IO.Path]::GetTempPath()
$resolvedOutputDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    ""
}
else {
    [System.IO.Path]::GetFullPath($OutputDirectory)
}

$result = [ordered]@{
    status          = "ok"
    edgePath        = $null
    tempDirectory   = $tempDirectory
    outputDirectory = $resolvedOutputDirectory
    checks          = @()
    note            = "通过后，export_icon_asset.ps1 可继续导出 PNG / ICO；若 Edge 不在默认位置，可在导出时传 -EdgePath。"
}

try {
    $resolvedEdgePath = Resolve-EdgeExecutablePath -ExplicitEdgePath $EdgePath
    $result.edgePath = $resolvedEdgePath
    $result.checks += [pscustomobject]@{
        name   = "edge_path"
        ok     = $true
        detail = $resolvedEdgePath
    }
}
catch {
    $result.status = "failed"
    $result.checks += [pscustomobject]@{
        name   = "edge_path"
        ok     = $false
        detail = $_.Exception.Message
    }
}

try {
    $tempWritable = Test-DirectoryWritable -DirectoryPath $tempDirectory
    $result.checks += [pscustomobject]@{
        name   = "temp_directory_write"
        ok     = $tempWritable
        detail = $tempDirectory
    }
}
catch {
    $result.status = "failed"
    $result.checks += [pscustomobject]@{
        name   = "temp_directory_write"
        ok     = $false
        detail = $_.Exception.Message
    }
}

if (-not [string]::IsNullOrWhiteSpace($resolvedOutputDirectory)) {
    try {
        $outputWritable = Test-DirectoryWritable -DirectoryPath $resolvedOutputDirectory
        $result.checks += [pscustomobject]@{
            name   = "output_directory_write"
            ok     = $outputWritable
            detail = $resolvedOutputDirectory
        }
    }
    catch {
        $result.status = "failed"
        $result.checks += [pscustomobject]@{
            name   = "output_directory_write"
            ok     = $false
            detail = $_.Exception.Message
        }
    }
}

if ($result.edgePath) {
    $screenshotCheck = Test-EdgeHeadlessScreenshot -ResolvedEdgePath $result.edgePath
    if (-not $screenshotCheck.ok) {
        $result.status = "failed"
    }

    $detail = "ExitCode={0}" -f $screenshotCheck.exitCode
    if (-not [string]::IsNullOrWhiteSpace($screenshotCheck.stderr)) {
        $detail = "{0}; EdgeError={1}" -f $detail, $screenshotCheck.stderr
    }

    $result.checks += [pscustomobject]@{
        name   = "edge_headless_screenshot"
        ok     = $screenshotCheck.ok
        detail = $detail
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)

<#
manifest_ref: 0102955b-6d73fc3a-6f65a463-3435cabe-ba9470e7-bb5d71e3-92e501f3
cid: 6fd3815c-894f2db8-d24f64cf-ee363cce-8a562db8-d34464d3-d8f3c424-0cb6edb9-ed7f64d0-f93608de-4f3508dc-894f08b3-d35f65e7-ea3a18cc-895d09ba-f25066c8-c73509eb-87542bbb-fb7b6ee0-e33427dd-897e23b8-d46865e1-fa363cfe-8a6f0ebb-f55767cf-ea3b06f6-8b6f21ba-fd7e62dc-ed362ee5-8b690fba-ee6567d8-e0373dfc-89412cbf-ef5269cc-ca3609f5-895326b8-d37367ce-c23b20d0-8b6b3bb3-d35f67d4-fe3517e5-8a6307b8-d04e66c9-f63b3ee1-887a37ba-dc4664e2-e43b35ff-8b683abb-f55767c1-ec3609f5-8c5303
#>
