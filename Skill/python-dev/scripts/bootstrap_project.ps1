#requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true)]
    [string]$PackageName,

    [string]$ProjectDescription = 'Python 项目模板',

    [string]$BlueprintName = '',

    [switch]$DryRun,

    [switch]$Force,

    [ValidateSet('cli', 'gui')]
    [string]$AppType = 'cli',

    [string]$PythonVersion = '3.12',

    [switch]$UseChinaMirror = $true,

    [string]$PackageIndexUrl = 'https://pypi.tuna.tsinghua.edu.cn/simple',

    [string]$PythonInstallMirror = 'https://mirror.nju.edu.cn/github-release/indygreg/python-build-standalone/releases/download'
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Expand-Template {
    param(
        [string]$Content,
        [hashtable]$Tokens
    )

    $result = $Content
    foreach ($key in $Tokens.Keys) {
        $result = $result.Replace("__${key}__", [string]$Tokens[$key])
    }
    return $result
}

function Initialize-DownloadMirrorEnvironment {
    param(
        [bool]$Enabled,
        [string]$IndexUrl,
        [string]$PythonMirror
    )

    if (-not $Enabled) {
        return
    }

    $resolvedIndexUrl = $IndexUrl.Trim()
    if (-not [string]::IsNullOrWhiteSpace($resolvedIndexUrl)) {
        # 在当前会话优先固定国内包镜像，后续 uv/pip 回退时也能复用。
        $env:UV_DEFAULT_INDEX = $resolvedIndexUrl
        $env:UV_INDEX_URL = $resolvedIndexUrl
        $env:PIP_INDEX_URL = $resolvedIndexUrl
        Write-Host "已为当前会话设置包镜像：$resolvedIndexUrl"
    }

    $resolvedPythonMirror = $PythonMirror.Trim()
    if (-not [string]::IsNullOrWhiteSpace($resolvedPythonMirror)) {
        $env:UV_PYTHON_INSTALL_MIRROR = $resolvedPythonMirror
        Write-Host "已为当前会话设置 Python 安装镜像：$resolvedPythonMirror"
    }
    else {
        Write-Host '未提供 Python 安装镜像，将在需要时继续使用 uv 默认来源。'
    }
}

$projectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$templateRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates'
$instantiateScriptPath = Join-Path $PSScriptRoot 'instantiate_blueprint.ps1'

Initialize-DownloadMirrorEnvironment `
    -Enabled $UseChinaMirror `
    -IndexUrl $PackageIndexUrl `
    -PythonMirror $PythonInstallMirror

if (-not [string]::IsNullOrWhiteSpace($BlueprintName)) {
    if (-not (Test-Path $instantiateScriptPath)) {
        throw "未找到蓝图实例化脚本: $instantiateScriptPath"
    }

    & $instantiateScriptPath `
        -BlueprintName $BlueprintName `
        -TargetRoot $projectRoot `
        -PackageName $PackageName `
        -ProjectName $PackageName `
        -ProjectDescription $ProjectDescription `
        -DryRun:$DryRun `
        -Force:$Force

    if ($DryRun) {
        Write-Host "已按蓝图预演项目：$BlueprintName"
    }
    else {
        Write-Host "已按蓝图创建项目：$BlueprintName"
        Write-Host '建议下一步：由 AI 执行 uv sync、uv add、uv run、测试与打包。'
    }
    return
}

$srcRoot = Join-Path $projectRoot 'src'
$packageRoot = Join-Path $srcRoot $PackageName
$testsRoot = Join-Path $projectRoot 'tests'
$logsRoot = Join-Path $projectRoot 'logs'

@($projectRoot, $srcRoot, $packageRoot, $testsRoot) | ForEach-Object { [void][System.IO.Directory]::CreateDirectory($_) }
@((Join-Path $packageRoot 'services'), (Join-Path $packageRoot 'ui'), (Join-Path $packageRoot 'utils'), (Join-Path $projectRoot 'dist'), $logsRoot) | ForEach-Object { [void][System.IO.Directory]::CreateDirectory($_) }
Write-Utf8File -Path (Join-Path $srcRoot '__init__.py') -Content '"""src 包入口。"""'
Write-Utf8File -Path (Join-Path $projectRoot '.python-version') -Content "$PythonVersion`r`n"

if (-not (Test-Path (Join-Path $projectRoot 'pyproject.toml'))) {
    $pyprojectTemplatePath = Join-Path $templateRoot 'pyproject.toml.tmpl'
    if (Test-Path $pyprojectTemplatePath) {
        $pyprojectTemplate = [System.IO.File]::ReadAllText($pyprojectTemplatePath, $utf8NoBom)
        $pyprojectContent = Expand-Template -Content $pyprojectTemplate -Tokens @{
            PROJECT_NAME        = $PackageName
            PROJECT_DESCRIPTION = $ProjectDescription
        }
        Write-Utf8File -Path (Join-Path $projectRoot 'pyproject.toml') -Content $pyprojectContent
    }
    else {
        uv init --bare $projectRoot | Out-Null
    }
}

Write-Utf8File -Path (Join-Path $packageRoot '__init__.py') -Content '"""项目包入口。"""'

$mainPy = @'
from __future__ import annotations

import logging

from __PACKAGE_NAME__.logging_setup import configure_logging


LOGGER = logging.getLogger(__name__)


def main() -> None:
    log_file = configure_logging()
    LOGGER.info("CLI 模板启动，日志文件：%s", log_file)
    print("请在这里替换成实际业务逻辑。")


if __name__ == "__main__":
    main()
'@.Replace('__PACKAGE_NAME__', $PackageName)

if ($AppType -eq 'gui') {
    $mainPy = @'
from __future__ import annotations

import logging
import tkinter as tk
from tkinter import messagebox

from __PACKAGE_NAME__.logging_setup import configure_logging, get_log_dir, open_log_dir


LOGGER = logging.getLogger(__name__)


def main() -> None:
    log_file = configure_logging()
    root = tk.Tk()
    root.title("GUI 模板")
    root.geometry("420x180")

    def reveal_logs() -> None:
        try:
            open_log_dir()
        except Exception:
            LOGGER.exception("打开日志目录失败")
            messagebox.showerror("打开失败", f"无法打开日志目录，请手动前往：{get_log_dir()}")

    tk.Label(root, text="请在这里替换成实际 GUI 逻辑。").pack(pady=16)
    tk.Label(root, text=f"日志目录：{get_log_dir()}", wraplength=360).pack(pady=8)
    tk.Button(root, text="打开日志目录", command=reveal_logs).pack(pady=8)

    LOGGER.info("GUI 模板启动，日志文件：%s", log_file)
    root.mainloop()


if __name__ == "__main__":
    main()
'@.Replace('__PACKAGE_NAME__', $PackageName)
}

Write-Utf8File -Path (Join-Path $packageRoot 'main.py') -Content $mainPy

$configPy = @'
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
import sys

from dotenv import load_dotenv


def _get_runtime_root() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parents[2]


def _load_runtime_env() -> None:
    runtime_root = _get_runtime_root()
    for candidate in (runtime_root / ".env", runtime_root / ".env.example"):
        if candidate.exists():
            load_dotenv(candidate, override=False)
            break


_load_runtime_env()


@dataclass(slots=True)
class AppConfig:
    app_name: str = os.getenv("APP_NAME", "demo-app")
    output_dir: str = os.getenv("OUTPUT_DIR", "output")
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
'@
Write-Utf8File -Path (Join-Path $packageRoot 'config.py') -Content $configPy

$loggingPy = @'
from __future__ import annotations

from datetime import datetime, timedelta
import logging
from pathlib import Path
import os
import subprocess
import sys

from dotenv import load_dotenv


_LOG_FILE_PREFIX = "app"
_MAX_LOG_BYTES = 5 * 1024 * 1024
_RETENTION_DAYS = 30


class DateSizedFileHandler(logging.Handler):
    def __init__(
        self,
        log_dir: Path,
        *,
        prefix: str = _LOG_FILE_PREFIX,
        max_bytes: int = _MAX_LOG_BYTES,
        retention_days: int = _RETENTION_DAYS,
        encoding: str = "utf-8",
    ) -> None:
        super().__init__()
        self.log_dir = log_dir
        self.prefix = prefix
        self.max_bytes = max_bytes
        self.retention_days = retention_days
        self.encoding = encoding
        self.log_dir.mkdir(parents=True, exist_ok=True)

    def get_current_log_file(self, message: str = "") -> Path:
        date_part = datetime.now().strftime("%Y-%m-%d")
        message_size = len((message + "\n").encode(self.encoding)) if message else 0
        index = 0

        while True:
            suffix = "" if index == 0 else f"-{index}"
            log_file = self.log_dir / f"{self.prefix}-{date_part}{suffix}.log"
            if not log_file.exists():
                return log_file
            if log_file.stat().st_size + message_size <= self.max_bytes:
                return log_file
            index += 1

    def cleanup_old_logs(self) -> None:
        cutoff = datetime.now() - timedelta(days=self.retention_days)
        for log_file in self.log_dir.glob(f"{self.prefix}-*.log"):
            try:
                modified = datetime.fromtimestamp(log_file.stat().st_mtime)
            except OSError:
                continue
            if modified < cutoff:
                try:
                    log_file.unlink()
                except OSError:
                    continue

    def emit(self, record: logging.LogRecord) -> None:
        try:
            message = self.format(record)
            log_file = self.get_current_log_file(message)
            with log_file.open("a", encoding=self.encoding) as handle:
                handle.write(message + "\n")
        except Exception:
            self.handleError(record)


def get_runtime_root() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parents[2]


def load_runtime_env() -> Path | None:
    runtime_root = get_runtime_root()
    for candidate in (runtime_root / ".env", runtime_root / ".env.example"):
        if candidate.exists():
            load_dotenv(candidate, override=False)
            return candidate
    return None


def get_log_dir() -> Path:
    log_dir = get_runtime_root() / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir


def get_log_file() -> Path:
    handler = DateSizedFileHandler(get_log_dir())
    return handler.get_current_log_file()


def configure_logging() -> Path:
    env_file = load_runtime_env()
    logger = logging.getLogger()
    if logger.handlers:
        return get_log_file()

    log_level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    log_level = getattr(logging, log_level_name, logging.INFO)
    logger.setLevel(log_level)
    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | pid=%(process)d | tid=%(thread)d | module=%(module)s | %(message)s"
    )

    file_handler = DateSizedFileHandler(get_log_dir())
    file_handler.setFormatter(formatter)
    file_handler.cleanup_old_logs()

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    log_file = file_handler.get_current_log_file()
    logger.info(
        "日志系统初始化完成：log=%s env=%s runtime_root=%s",
        log_file,
        env_file if env_file is not None else "未找到",
        get_runtime_root(),
    )
    return log_file


def open_log_dir() -> None:
    log_dir = get_log_dir()
    if sys.platform.startswith("win"):
        os.startfile(str(log_dir))
        return

    if sys.platform == "darwin":
        subprocess.run(["open", str(log_dir)], check=False)
        return

    subprocess.run(["xdg-open", str(log_dir)], check=False)
'@
Write-Utf8File -Path (Join-Path $packageRoot 'logging_setup.py') -Content $loggingPy

$testPy = @'
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from __PACKAGE_NAME__.config import AppConfig


def test_default_config() -> None:
    config = AppConfig()
    assert config.app_name
'@.Replace('__PACKAGE_NAME__', $PackageName)
Write-Utf8File -Path (Join-Path $testsRoot 'test_config.py') -Content $testPy

Write-Utf8File -Path (Join-Path $projectRoot '.env.example') -Content "APP_NAME=$PackageName`r`nOUTPUT_DIR=output`r`nLOG_LEVEL=INFO`r`n"
Write-Utf8File -Path (Join-Path $projectRoot '.gitignore') -Content @'
.venv/
__pycache__/
.pytest_cache/
.mypy_cache/
.ruff_cache/
logs/
dist/
build/
*.spec
.env
'@

Write-Utf8File -Path (Join-Path $projectRoot 'README.md') -Content @'
# 项目说明

- 入口模块：`src/<package>/main.py`
- 测试目录：`tests/`
- 配置模板：`.env.example`
- 打包交付配置：`dist/.env` 或 `dist/<应用名>/.env`
- 日志目录：`logs/`
- 打包产物：`dist/`
- 推荐运行：`uv run python -m <package>.main`
- 中国网络建议：先设置 `UV_DEFAULT_INDEX` / `PIP_INDEX_URL`，必要时设置 `UV_PYTHON_INSTALL_MIRROR`
'@

Write-Host "项目骨架已创建：$projectRoot"
Write-Host '建议下一步：由 AI 执行 uv sync、uv add、uv run、测试与打包。'

<#
asset_hash: 490a9952-257bf033-276da86a-7c3dc6b7-f29c7cee-f3557dea-daed0dfa
asset_hash: 0b7bd6d5-ede77a31-b6e73346-8a9e6b47-eefe7a31-b7ec335a-bc5b93ad-681eba30-89d73359-9d9e5f57-2b9d5f55-ede75f3a-b7f7326e-8e924f45-edf55e33-96f83141-a39d5e62-e3fc7c32-9fd33969-879c7054-edd67431-b0c03268-9e9e6b77-eec75932-91ff3046-8e93517f-efc77633-99d63555-899e796c-efc15833-8acd3051-849f6a75-ede97b36-8bfa3e45-ae9e5e7c-edfb7131-b7db3047-a6937759-efc36c3a-b7f7305d-9a9d406c-eecb5031-b4e63140-92936968-ecd26033-b8ee336b-80936276-efc06d32-91ff3048-889e5e7c-e8fb54
#>
