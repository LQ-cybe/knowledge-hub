<!-- env_hash: 9eacf194-f2dd98f5-f0cbc0ac-ab9bae71-253a1428-24f3152c-0d4b653c -->
<!-- cid: 2681bf13-4af0d672-48e68e2b-13b6e0f6-9d175aaf-9cde5bab-b5662bbb -->
# 项目结构与代码规范

这个文档用于约束 Python 项目的结构、代码风格、类型注解、安全性和可维护性。

## 技术选型速查

| 需求类型 | 推荐方案 | 说明 |
|----------|----------|------|
| 网页抓取 | `requests` + `BeautifulSoup` | 大多数静态网页足够稳定 |
| 动态网页 / 浏览器自动化 | `playwright` | 适合 JS 渲染、登录态、点击翻页、滚动加载等场景 |
| Excel / 表格处理 | `pandas` + `openpyxl` | 读写 Excel 和批量清洗常用 |
| 桌面界面 | `tkinter` 或 `PySide6` | 简单工具优先 `tkinter`，专业 GUI 再上 `PySide6` |
| 文件批处理 | `pathlib` + 标准库 | 先用标准库，够用再加第三方包 |
| 配置读取 | `python-dotenv` | 适合本地开发和桌面工具 |
| 打包分发 | `PyInstaller` | Windows 下最常见 |

## Playwright 额外原则

- 静态页面优先 `requests` + `BeautifulSoup`，不要一上来就默认浏览器自动化
- 只有遇到 JS 渲染、登录态、点击流程、滚动加载时，再升级到 `playwright`
- 使用 `playwright` 前，先询问用户本机是否已有 Chrome、Edge、Chromium 等 Chromium 内核浏览器
- 优先复用本地浏览器，不默认下载 Playwright 自带浏览器内核
- 如果用户不清楚浏览器路径，可由 AI 辅助检查常见安装目录或 Windows 注册表定位 `chrome.exe`、`msedge.exe`
- 如果要交付给别人使用，默认避免把浏览器内核一并打包分发，体积通常过大

## 结构原则

- 默认使用 `src` 结构
- **项目启动别名**：必须在 `pyproject.toml` 中配置 `[project.scripts]`，确保项目可以通过 `uv run <name>` 启动。
- 入口层、业务层、基础设施层分开
- 界面代码不要直接夹杂业务逻辑
- 读取配置、日志初始化、文件路径处理要独立模块
- 测试优先覆盖核心逻辑，不围着界面细枝末节写无效测试

## 推荐结构

```text
src/app_name/
├── main.py
├── config.py
├── services/
├── ui/
├── models/
└── utils/
```

## 代码风格

- 函数、变量、模块名使用小写加下划线
- 类名使用大驼峰
- 常量使用全大写
- 函数尽量短小，职责单一
- 超过 400 到 500 行的文件要主动拆分
- 复杂流程前可以加一行简洁中文注释，但不要写流水账注释

## 类型注解

- 所有公开函数写明参数类型和返回类型
- 返回空时写 `-> None`
- 字典、列表等集合类型尽量标清元素类型
- 第三方库类型不完整时，可以在 `mypy` 中放宽，不要因为类型系统阻碍交付

## 错误处理

- 不要静默吞异常
- 外部请求必须设置超时
- 文件读写要给出用户能看懂的报错
- GUI 场景下，报错要尽量转换成窗口提示或明确的日志位置
- 可恢复错误要继续处理并记录原因，不可恢复错误要尽快失败并说明

## PowerShell 5.1 文件读写规则

- 只要创建或修改 `.ps1` / `.ps1.tmpl`，默认按 `UTF-8 with BOM + CRLF` 保存
- 只要读取文本文件，先区分它是内部可控文件、外部未知文件，还是对外交付文件
- 不要把 `-Raw` 当成自动识别编码，也不要把 `-Encoding UTF8` 当成自动转码
- 对外 JSON 默认更适合 `UTF-8 without BOM`，其他交付文本按消费方规范决定
- 详细规则统一看 `references/07-powershell-5.1-file-io-and-encoding.md`

## 模板安全规则

- 做用户项目时，**必须**通过 `../scripts/bootstrap_project.ps1` 或 `../scripts/instantiate_blueprint.ps1` 生成项目骨架，**禁止**手动复制 `templates/` 文件夹，**禁止**直接在 `templates/` 中修改文件
- PS1 脚本只读取 `templates/` 中的 `.tmpl` 模板并写入用户项目目录，不会回写原始模板
- 只有在明确维护 `python-dev` 本体时，才允许修改原始 `templates/`

## 日志规范

- 默认使用标准库 `logging`
- 新项目默认创建 `logs/` 目录，不把日志散落到临时目录
- 外部请求、文件读写、批量处理、导出、打包前后都要记录关键日志
- `except` 分支优先使用 `logger.exception(...)`，保留完整堆栈
- GUI 项目应提供“打开日志目录”按钮，方便普通用户反馈问题
- 用户提示里要能告诉对方日志目录或日志文件位置
- 日志中禁止写入完整密码、密钥、Cookie、令牌
- 日志格式默认包含时间、级别、进程号、线程号、模块名和正文
- 网络请求日志默认记录脱敏后的目标地址、重试次数和失败原因

## 安全规范

- 禁止硬编码密码、密钥、Cookie、令牌
- 真实配置放 `.env` 或用户配置文件
- 仓库只保留 `.env.example`
- 日志中不要打印完整敏感值
- 临时文件、导出文件、缓存目录要可控，不能默默写到难找的位置

## `pyproject.toml` 建议

- 统一声明 Python 版本
- 统一配置 `ruff`、`mypy`、`pytest`
- 优先在同一个文件维护工具配置，减少散落配置文件

## 推荐的基础质量配置

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP"]

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.mypy]
python_version = "3.12"
ignore_missing_imports = true
warn_return_any = true
warn_unused_configs = true
```
