#requires -Version 5.1

param(
    # 要安装的 Python 版本，默认 3.12
    [string]$PythonVersion = '3.12',

    # 包索引镜像地址（用于 uv add / pip）。不指定则自动探测最快的可用镜像
    [string]$PackageIndexUrl = '',

    # Python 托管安装镜像地址（用于 uv python install）。不指定则自动探测最快的可用镜像
    [string]$PythonInstallMirror = '',

    # 是否跳过 Python 安装（仅配置 uv 和镜像）
    [switch]$SkipPythonInstall,

    # 是否使用中国镜像（设为 $false 则走官方源）
    [switch]$UseChinaMirror = $true,

    # 预演模式：只检查环境，不实际安装
    [switch]$DryRun,

    # 强制重装 uv（即使已存在）
    [switch]$ForceReinstallUv,

    # uv 的备用安装方式：direct（官方安装脚本，不依赖Python）、winget、pip（需已有Python）
    [ValidateSet('auto', 'direct', 'pip', 'winget')]
    [string]$UvInstallMethod = 'auto',

    # 镜像检查超时秒数
    [int]$MirrorTimeoutSec = 5
)

$ErrorActionPreference = 'Stop'

# ============================================================
# 内置镜像候选列表（实测可达，2026-06 验证）
# 每个类型一个失败则自动尝试下一个
# ============================================================

$script:PyPIMirrorCandidates = @(
    'https://pypi.tuna.tsinghua.edu.cn/simple',     # 清华 TUNA — 最稳定，首选
    'https://pypi.mirrors.ustc.edu.cn/simple',       # 中科大 USTC — 速度快
    'https://mirrors.huaweicloud.com/pypi/simple',    # 华为云 — 可用
    'https://mirrors.aliyun.com/pypi/simple'          # 阿里云 — 可用
)

$script:PythonInstallMirrorCandidates = @(
    'https://registry.npmmirror.com/-/binary/python-build-standalone/',   # npmmirror — 速度最快
    'https://mirror.nju.edu.cn/github-release/astral-sh/python-build-standalone/', # NJU 新路径
    'https://python-standalone.org/mirror/astral-sh/python-build-standalone/',    # 官方镜像站
    'https://mirror.nju.edu.cn/github-release/indygreg/python-build-standalone/'  # NJU 旧路径（兜底，旧仓库名仍可用）
)

# ============================================================
# 工具函数
# ============================================================

function Write-Step {
    param([string]$Message)
    Write-Host ">>> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Gray
}

function Invoke-HttpRequestText {
    param(
        [string]$Method,
        [string]$Url,
        [int]$TimeoutSec = 15
    )

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $Url)
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode()
        return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    }
    finally {
        if ($request) { $request.Dispose() }
        $client.Dispose()
        $handler.Dispose()
    }
}

function Invoke-HttpDownload {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$TimeoutSec = 30
    )

    $parent = Split-Path -Parent $OutFile
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [void][System.IO.Directory]::CreateDirectory($parent)
    }

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
    try {
        $response = $client.GetAsync($Url).GetAwaiter().GetResult()
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

# ============================================================
# 检测函数
# ============================================================

function Test-UvCommandAvailable {
    return $null -ne (Get-Command uv -ErrorAction SilentlyContinue)
}

function Test-PythonCommandAvailable {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $python) {
        $python = Get-Command python3 -ErrorAction SilentlyContinue
    }
    return $null -ne $python
}

function Get-ExistingPythonPath {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $python) { return $python.Source }
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if ($null -ne $python) { return $python.Source }
    return $null
}

function Test-WingetAvailable {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

# ============================================================
# 镜像健康检查
# ============================================================

function Test-MirrorUrl {
    param(
        [string]$Url,
        [int]$TimeoutSec = $script:MirrorTimeoutSec
    )

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Invoke-HttpRequestText -Method 'HEAD' -Url $Url -TimeoutSec $TimeoutSec
        $sw.Stop()
        return @{ Url = $Url; LatencyMs = $sw.ElapsedMilliseconds; Available = $true }
    }
    catch {
        return @{ Url = $Url; LatencyMs = -1; Available = $false }
    }
}

function Find-FirstAvailableMirror {
    param(
        [string[]]$Candidates,
        [string]$MirrorType
    )

    Write-Info "探测 $MirrorType 镜像可用性（超时：${MirrorTimeoutSec}秒）..."

    $best = $null
    foreach ($candidate in $Candidates) {
        $result = Test-MirrorUrl -Url $candidate
        if ($result.Available) {
            $marker = if ($null -eq $best -or $result.LatencyMs -lt $best.LatencyMs) { ' ← 最快' } else { '' }
            Write-Ok "$($result.LatencyMs)ms - $candidate$marker"
            if ($null -eq $best -or $result.LatencyMs -lt $best.LatencyMs) {
                $best = $result
            }
        }
        else {
            Write-Warn "不可达: $candidate"
        }
    }

    if ($null -eq $best) {
        Write-Warn "$MirrorType 所有候选镜像均不可达，将回退到官方源"
        return $null
    }

    Write-Ok "选定 $MirrorType 镜像: $($best.Url) ($($best.LatencyMs)ms)"
    return $best.Url
}

# ============================================================
# 镜像环境配置
# ============================================================

function Set-ChinaMirrorEnvironment {
    param(
        [string]$IndexUrl,
        [string]$PythonMirror
    )

    Write-Step '配置中国镜像环境变量（当前会话）'

    # --- 包索引镜像 ---
    $resolvedIndexUrl = $null
    if (-not [string]::IsNullOrWhiteSpace($IndexUrl)) {
        # 用户显式指定，直接使用
        $result = Test-MirrorUrl -Url $IndexUrl
        if ($result.Available) {
            $resolvedIndexUrl = $IndexUrl
            Write-Ok "使用指定的包索引镜像: $IndexUrl ($($result.LatencyMs)ms)"
        }
        else {
            Write-Warn "指定的包索引镜像不可达: $IndexUrl，改为自动探测"
        }
    }

    if ($null -eq $resolvedIndexUrl) {
        $resolvedIndexUrl = Find-FirstAvailableMirror -Candidates $script:PyPIMirrorCandidates -MirrorType 'PyPI'
    }

    if ($null -ne $resolvedIndexUrl) {
        $env:UV_DEFAULT_INDEX = $resolvedIndexUrl
        $env:UV_INDEX_URL = $resolvedIndexUrl
        $env:PIP_INDEX_URL = $resolvedIndexUrl
    }

    # --- Python 安装镜像 ---
    $resolvedPythonMirror = $null
    if (-not [string]::IsNullOrWhiteSpace($PythonMirror)) {
        $result = Test-MirrorUrl -Url $PythonMirror
        if ($result.Available) {
            $resolvedPythonMirror = $PythonMirror
            Write-Ok "使用指定的 Python 安装镜像: $PythonMirror ($($result.LatencyMs)ms)"
        }
        else {
            Write-Warn "指定的 Python 安装镜像不可达: $PythonMirror，改为自动探测"
        }
    }

    if ($null -eq $resolvedPythonMirror) {
        $resolvedPythonMirror = Find-FirstAvailableMirror -Candidates $script:PythonInstallMirrorCandidates -MirrorType 'Python 安装'
    }

    if ($null -ne $resolvedPythonMirror) {
        $env:UV_PYTHON_INSTALL_MIRROR = $resolvedPythonMirror
    }
    else {
        Write-Info '未找到可用的 Python 安装镜像，uv python install 将使用默认来源'
    }

    # 保存到脚本作用域，供后续函数使用
    $script:effectivePyPIMirror = $resolvedIndexUrl
    $script:effectivePythonMirror = $resolvedPythonMirror

    Write-Host ''
}

# ============================================================
# uv 安装策略
# ============================================================

function Install-UvViaPip {
    $pythonPath = Get-ExistingPythonPath
    if ($null -eq $pythonPath) {
        throw '未检测到可用的 Python，无法通过 pip 安装 uv。请先安装 Python 或尝试其他安装方式。'
    }

    Write-Info "使用已有 Python 安装 uv: $pythonPath"

    # 尝试用已配置的 PyPI 镜像安装，失败则依次尝试候选镜像
    $mirrorsToTry = @()
    if ($null -ne $script:effectivePyPIMirror -and $script:effectivePyPIMirror -ne '') {
        $mirrorsToTry += $script:effectivePyPIMirror
    }
    $mirrorsToTry += $script:PyPIMirrorCandidates

    $installed = $false
    foreach ($mirror in ($mirrorsToTry | Select-Object -Unique)) {
        $pipArgs = @(
            '-m', 'pip', 'install',
            '-i', $mirror,
            'uv'
        )

        Write-Host "  尝试: python $($pipArgs -join ' ')"
        & python @pipArgs
        if ($LASTEXITCODE -eq 0) {
            $installed = $true
            Write-Ok "通过镜像 $mirror 安装成功"
            break
        }
        Write-Warn "镜像 $mirror 安装失败，尝试下一个..."
    }

    if (-not $installed) {
        throw '所有 PyPI 镜像均安装 uv 失败，请检查网络或尝试官方安装方式'
    }

    Write-Ok 'uv 安装完成'
}

function Install-UvViaOfficialScript {
    # 改为从 PyPI 镜像直接下载 uv wheel 包，解压出 uv.exe
    # 这比访问 astral.sh 官方脚本可靠得多，因为 PyPI 镜像在国内非常稳定
    Write-Info '从 PyPI 镜像下载 uv wheel 包，解压 uv.exe（无需 Python）'

    # 构建镜像候选列表
    $mirrorsToTry = @()
    if ($null -ne $script:effectivePyPIMirror -and $script:effectivePyPIMirror -ne '') {
        $mirrorsToTry += $script:effectivePyPIMirror
    }
    $mirrorsToTry += $script:PyPIMirrorCandidates

    $installDir = Join-Path $env:USERPROFILE '.local\bin'
    if (-not (Test-Path $installDir)) {
        [void][System.IO.Directory]::CreateDirectory($installDir)
    }

    $installed = $false
    foreach ($mirror in ($mirrorsToTry | Select-Object -Unique)) {
        try {
            Write-Info "尝试从镜像下载 uv wheel: $mirror"

            # 1. 获取 uv 包列表页面，找到最新 win_amd64 whl
            $listUrl = "$mirror/uv/"
            $respText = Invoke-HttpRequestText -Method 'GET' -Url $listUrl -TimeoutSec 15
            $whlMatches = [regex]::Matches($respText, 'href=\"([^\"]*uv-[0-9][^\"]*-py3-none-win_amd64\\.whl[^\"]*)\"')

            if ($whlMatches.Count -eq 0) {
                Write-Warn "镜像 $mirror 未找到 uv win_amd64 whl"
                continue
            }

            # 取最后一个（最新版本）
            $whlPath = $whlMatches[$whlMatches.Count - 1].Groups[1].Value
            # 去掉 sha256 锚点
            $whlPath = $whlPath -replace '#.*$', ''

            # 拼接完整 URL
            # 相对路径 ../../packages/... 是相对于 /simple/uv/ 的
            # 即 https://mirrors.aliyun.com/pypi/simple/uv/../../packages/...
            #   = https://mirrors.aliyun.com/pypi/packages/...
            # 需要把镜像 URL 中的 /simple 去掉
            if ($whlPath.StartsWith('../../')) {
                $packagesPath = $whlPath -replace '^\.\./\.\./', ''
                $mirrorRoot = $mirror -replace '/simple/?$', ''
                $whlUrl = $mirrorRoot.TrimEnd('/') + '/' + $packagesPath
            }
            elseif ($whlPath.StartsWith('http')) {
                $whlUrl = $whlPath
            }
            else {
                $whlUrl = $mirror.TrimEnd('/') + '/' + $whlPath.TrimStart('/')
            }

            Write-Info "下载: $whlUrl"

            # 2. 下载 whl 文件（whl 本质是 zip）
            $tmpWhl = Join-Path $env:TEMP "uv-download.whl"
            Invoke-HttpDownload -Url $whlUrl -OutFile $tmpWhl -TimeoutSec 30

            $fileSize = (Get-Item $tmpWhl).Length
            Write-Ok "下载完成: $([math]::Round($fileSize / 1MB, 1)) MB"

            # 3. 解压 whl，提取 uv.exe / uvx.exe / uvw.exe
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($tmpWhl)

            $extracted = @()
            foreach ($entry in $zip.Entries) {
                if ($entry.FullName -match '/(uv\.exe|uvx\.exe|uvw\.exe)$') {
                    $fileName = [System.IO.Path]::GetFileName($entry.FullName)
                    $destPath = Join-Path $installDir $fileName
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
                    $extracted += $fileName
                    Write-Ok "提取: $fileName -> $destPath"
                }
            }
            $zip.Dispose()
            [System.IO.File]::Delete($tmpWhl)

            if ($extracted.Count -eq 0) {
                Write-Warn "whl 中未找到 uv.exe，尝试下一个镜像"
                continue
            }

            $installed = $true
            break
        }
        catch {
            Write-Warn "镜像 $mirror 下载失败: $($_.Exception.Message)"
        }
    }

    if (-not $installed) {
        # 最后兜底：尝试 astral.sh 官方脚本
        Write-Warn '所有 PyPI 镜像下载失败，尝试 astral.sh 官方安装脚本（可能较慢）'
        $installCmd = 'powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"'
        Write-Host "  执行: $installCmd"
        Invoke-Expression $installCmd
        if ($LASTEXITCODE -ne 0) {
            throw 'uv 安装失败：所有镜像和官方脚本均不可用'
        }
    }

    # 刷新 PATH
    Refresh-SessionPath
    # 确保安装目录在 PATH 中
    if ($env:PATH -notlike "*$installDir*") {
        $env:PATH = $installDir + ';' + $env:PATH
    }
    # 写入用户 PATH
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($null -ne $userPath -and $userPath -notlike "*$installDir*") {
        $updated = $userPath.TrimEnd(';') + ';' + $installDir
        [Environment]::SetEnvironmentVariable('PATH', $updated, 'User')
    }

    Write-Ok "uv 安装到: $installDir"
}

function Install-UvViaWinget {
    if (-not (Test-WingetAvailable)) {
        throw '当前系统未检测到 winget'
    }

    Write-Info '使用 winget 安装 uv'
    $wingetArgs = @(
        'install',
        '--id', 'astral-sh.uv',
        '-e',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    )

    Write-Host "  执行: winget $($wingetArgs -join ' ')"
    & winget @wingetArgs
    if ($LASTEXITCODE -ne 0) {
        throw 'winget 安装 uv 失败'
    }

    # winget 安装后刷新 PATH
    Refresh-SessionPath
    Write-Ok 'uv 安装完成'
}

function Refresh-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $pathParts = @($machinePath, $userPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $env:PATH = $pathParts -join ';'

    # 尝试补充常见的 uv 安装目录
    $commonUvRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $commonUvRoots += Join-Path $env:USERPROFILE '.local\bin'
        $commonUvRoots += Join-Path $env:USERPROFILE '.cargo\bin'
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $commonUvRoots += Join-Path $env:LOCALAPPDATA 'Programs\uv'
    }

    foreach ($candidate in $commonUvRoots) {
        if ((Test-Path $candidate) -and ($env:PATH -notlike "*$candidate*")) {
            $env:PATH = $candidate + ';' + $env:PATH
        }
    }
}

# ============================================================
# 主流程
# ============================================================

function Invoke-Main {
    Write-Host ''
    Write-Host '============================================' -ForegroundColor Magenta
    Write-Host '  Python uv 环境安装与镜像配置' -ForegroundColor Magenta
    Write-Host '============================================' -ForegroundColor Magenta
    Write-Host ''

    # --------------------------------------------------
    # 1. 配置镜像环境变量（任何时候都先设置，确保后续命令走镜像）
    #    自动探测最快的可用镜像，一个失败则换下一个
    # --------------------------------------------------
    if ($UseChinaMirror) {
        Set-ChinaMirrorEnvironment -IndexUrl $PackageIndexUrl -PythonMirror $PythonInstallMirror
    }
    else {
        Write-Info '未启用中国镜像，将使用官方源'
        $script:effectivePyPIMirror = $null
        $script:effectivePythonMirror = $null
        Write-Host ''
    }

    # --------------------------------------------------
    # 2. DryRun 模式：仅检查环境
    # --------------------------------------------------
    if ($DryRun) {
        Write-Step '预演模式：检查当前环境'
        Write-Host ''

        $uvExists = Test-UvCommandAvailable
        Write-Host "  uv 命令: $(if ($uvExists) { '已安装' } else { '未安装' })"
        if ($uvExists) {
            $uvVersion = & uv --version 2>$null
            Write-Host "  uv 版本: $uvVersion"
        }

        $pythonExists = Test-PythonCommandAvailable
        Write-Host "  Python 命令: $(if ($pythonExists) { '已安装 (可用于 pip 安装 uv)' } else { '未安装' })"
        Write-Host "  winget: $(if (Test-WingetAvailable) { '可用' } else { '不可用' })"
        Write-Host ''

        if (-not $uvExists) {
            $method = Resolve-UvInstallMethod
            Write-Host "  计划安装方式: $method"
        }

        if (-not $SkipPythonInstall) {
            Write-Host "  目标 Python 版本: $PythonVersion"
        }

        Write-Host ''
        Write-Host '  镜像配置 (自动探测结果):'
        if ($script:effectivePyPIMirror) {
            Write-Host "    PyPI 镜像: $($script:effectivePyPIMirror)"
        }
        else {
            Write-Host "    PyPI 镜像: 未配置（将使用官方源或依次尝试候选）"
        }
        if ($script:effectivePythonMirror) {
            Write-Host "    Python 安装镜像: $($script:effectivePythonMirror)"
        }
        else {
            Write-Host "    Python 安装镜像: 未配置（将使用官方源或依次尝试候选）"
        }
        Write-Host ''
        Write-Host '预演完成，未进行任何实际安装。' -ForegroundColor Yellow
        return
    }

    # --------------------------------------------------
    # 3. 安装 uv（如需要）
    # --------------------------------------------------
    $uvAlreadyExists = Test-UvCommandAvailable

    if ($uvAlreadyExists -and -not $ForceReinstallUv) {
        $uvVersion = & uv --version 2>$null
        Write-Ok "uv 已安装: $uvVersion"
        Write-Host ''
    }
    else {
        if ($ForceReinstallUv) {
            Write-Warn 'ForceReinstallUv 已启用，将重新安装 uv'
        }

        Write-Step '开始安装 uv'
        $method = Resolve-UvInstallMethod

        try {
            switch ($method) {
                'pip' {
                    Write-Info "安装方式: pip (使用已有 Python)"
                    Install-UvViaPip
                }
                'winget' {
                    Write-Info "安装方式: winget"
                    Install-UvViaWinget
                }
                'direct' {
                    Write-Info "安装方式: 官方安装脚本（无需 Python，直接下载 uv 二进制）"
                    Install-UvViaOfficialScript
                }
                default {
                    throw "不支持的安装方式: $method"
                }
            }
        }
        catch {
            throw "uv 安装失败 (方式: $method): $($_.Exception.Message)"
        }

        # 安装后刷新 PATH 并验证
        Refresh-SessionPath

        if (-not (Test-UvCommandAvailable)) {
            throw 'uv 安装完成但命令仍不可用，请检查 PATH 或重启终端后重试'
        }

        $uvVersion = & uv --version 2>$null
        Write-Ok "uv 安装成功: $uvVersion"
        Write-Host ''
    }

    # --------------------------------------------------
    # 4. 安装 Python（uv python install）
    # --------------------------------------------------
    if (-not $SkipPythonInstall) {
        Write-Step "安装 Python $PythonVersion (通过 uv python install)"

        Write-Info '执行 uv python install，将使用已配置的镜像'

        & uv python install $PythonVersion
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Python $PythonVersion 安装可能失败或已存在，继续检查可用版本..."
        }

        # 验证 Python 是否可用
        $installedVersions = & uv python list --only-installed 2>$null
        if ($LASTEXITCODE -eq 0 -and $installedVersions -match $PythonVersion) {
            Write-Ok "Python $PythonVersion 已就绪"
        }
        else {
            Write-Warn "未能确认 Python $PythonVersion 安装状态，uv 将在首次需要时自动处理"
        }
        Write-Host ''
    }
    else {
        Write-Info '已跳过 Python 安装 (SkipPythonInstall)'
        Write-Host ''
    }

    # --------------------------------------------------
    # 5. 最终验证
    # --------------------------------------------------
    Write-Step '环境验证'

    $uvVersion = & uv --version 2>$null
    Write-Ok "uv 版本: $uvVersion"

    Write-Host ''
    Write-Host '当前会话已配置的环境变量:' -ForegroundColor Gray
    if ($env:UV_DEFAULT_INDEX) {
        Write-Host "  UV_DEFAULT_INDEX = $env:UV_DEFAULT_INDEX" -ForegroundColor Gray
    }
    if ($env:UV_INDEX_URL) {
        Write-Host "  UV_INDEX_URL = $env:UV_INDEX_URL" -ForegroundColor Gray
    }
    if ($env:PIP_INDEX_URL) {
        Write-Host "  PIP_INDEX_URL = $env:PIP_INDEX_URL" -ForegroundColor Gray
    }
    if ($env:UV_PYTHON_INSTALL_MIRROR) {
        Write-Host "  UV_PYTHON_INSTALL_MIRROR = $env:UV_PYTHON_INSTALL_MIRROR" -ForegroundColor Gray
    }

    Write-Host ''
    Write-Host '============================================' -ForegroundColor Green
    Write-Host '  uv 环境已就绪！' -ForegroundColor Green
    Write-Host '============================================' -ForegroundColor Green
    Write-Host ''
    Write-Host '后续操作提示:' -ForegroundColor Yellow
    Write-Host '  初始化项目:     uv init <项目名>'
    Write-Host '  添加依赖:       uv add <包名>'
    Write-Host '  运行程序:       uv run <别名>'
    Write-Host '  安装 Python:    uv python install <版本>'
    Write-Host ''
}

function Resolve-UvInstallMethod {
    if ($UvInstallMethod -ne 'auto') {
        return $UvInstallMethod
    }

    # auto 模式：按优先级选择安装方式
    # 原则：uv 是独立二进制，不应依赖 Python 来安装
    # 1. winget（系统包管理器）→ 2. direct（官方脚本，无需Python）→ 3. pip（仅兜底）

    if (Test-WingetAvailable) {
        Write-Info '检测到 winget，优先使用系统包管理器'
        return 'winget'
    }

    Write-Info '未检测到 winget，将使用官方安装脚本直接下载 uv（无需 Python）'
    # 不检查 Python，直接走 direct 避免假设用户有 Python 环境
    return 'direct'
}

# ============================================================
# 入口
# ============================================================

try {
    Invoke-Main
}
catch {
    Write-Host ''
    Write-Host '============================================' -ForegroundColor Red
    Write-Host "  安装失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '============================================' -ForegroundColor Red
    Write-Host ''
    Write-Host '建议排查步骤:' -ForegroundColor Yellow
    Write-Host '  1. 确认网络连接正常'
    Write-Host '  2. 尝试使用 -DryRun 参数预演检查'
    Write-Host '  3. 脚本会自动从 PyPI 镜像下载 uv wheel 包并解压 uv.exe，无需 Python'
    Write-Host '  4. 如果有 winget，可手动执行: winget install astral-sh.uv'
    Write-Host '  5. 访问 https://github.com/astral-sh/uv/releases 手动下载 uv-x86_64-pc-windows-msvc.zip'
    Write-Host ''
    exit 1
}

<#
dist_id: da5be3e4-b62a8a85-b43cd2dc-ef6cbc01-61cd0658-6004075c-49bc774c
trace_ref: ea5834b8-0cc4985c-57c4d12b-6bbd892a-0fdd985c-56cfd137-5d7871c0-893d585d-68f4d134-7cbdbd3a-cabebd38-0cc4bd57-56d4d003-6fb1ad28-0cd6bc5e-77dbd32c-42bebc0f-02df9e5f-7ef0db04-66bf9239-0cf5965c-51e3d005-7fbd891a-0fe4bb5f-70dcd22b-6fb0b312-0ee4945e-78f5d738-68bd9b01-0ee2ba5e-6beed23c-65bc8818-0cca995b-6ad9dc28-4fbdbc11-0cd8935c-56f8d22a-47b09534-0ee08e57-56d4d230-7bbea201-0fe8b25c-55c5d32d-73b08b05-0df1825e-59cdd106-61b0801b-0ee38f5f-70dcd225-69bdbc11-09d8b6
#>
