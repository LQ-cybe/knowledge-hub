<!-- audit_id: 7b6d8989-171ce0e8-150ab8b1-4e5ad66c-c0fb6c35-c1326d31-e88a1d21 -->
# AI 代执行与环境约束

这个文档规定：涉及 Python 项目的命令执行、环境搭建、依赖安装、运行和调试时，默认由 AI 发起，不把终端操作转给普通用户。

## 核心原则

- 优先由 AI 执行命令，用户只负责授权
- 项目统一使用 `uv`
- **环境安装必须通过脚本**：在用户机器上首次搭建 Python 开发环境时，必须运行 `../scripts/ensure_uv_env.ps1`，禁止 AI 逐条手动执行 `uv init`、`uv python install`、设置环境变量等零散命令
- 优先在项目目录内创建独立环境，不污染全局 Python
- 中国网络环境下，默认优先使用国内镜像或本地可达下载源
- 命令执行后要告诉用户结果，而不是只贴命令
- 除非用户明确要求学习命令行，否则不要把终端当成主要交互方式
- 如果涉及 `.ps1`、PowerShell 打包脚本或中文文件读写，优先回看 `references/07-powershell-5.1-file-io-and-encoding.md`

## 项目脚手架强制规则

- **新建项目禁止手写**：所有新建项目必须通过 `../scripts/bootstrap_project.ps1` 或 `../scripts/instantiate_blueprint.ps1` 生成项目骨架，禁止 AI 自己写 pyproject.toml 或逐个 mkdir / write_to_file
- **蓝图匹配时优先 instantiate_blueprint.ps1**：如果用户需求匹配 cli-batch/gui-exe/excel-batch/web-scraper 任一蓝图，必须运行 `instantiate_blueprint.ps1`，在生成的模板基础上修改，禁止跳过脚本直接手写
- **不匹配蓝图时用 bootstrap_project.ps1**：生成通用项目骨架（包含 pyproject.toml、src/、tests/ 等完整结构）

## 依赖管理铁律

- **严禁 `pip install`**：所有依赖必须通过 `uv add <包名>`（会自动写入 `pyproject.toml` 并更新 `uv.lock` 并安装到当前环境）。`uv sync` 仅用于换机器或别人接手项目时根据 lock 文件还原环境，日常开发不需要重复执行
- 运行依赖用 `uv add`
- 开发依赖用 `uv add --dev`
- 不要混用 `pip install` 和 `uv add`，pip 会把包装到全局环境，破坏 uv 的环境隔离
- 依赖版本由 `pyproject.toml` 与 `uv.lock` 管理
- 变更依赖后优先同步锁文件
- 需要读取 `.env` 的项目，默认使用 `python-dotenv` 在程序启动时自动加载
- 中国网络场景下，优先通过 `UV_DEFAULT_INDEX`、`UV_INDEX_URL` 或 `tool.uv.index` 固定国内镜像

## AI 必须代执行的高频动作

- 检查 `uv` 是否存在
- 安装 Python 版本
- 初始化项目
- 添加依赖和开发依赖
- 运行脚本
- 跑测试
- 构建 `exe`

## 推荐环境步骤

1. 检查 `uv --version`
2. 如未安装，先准备中国网络可达的安装方式
3. 为当前会话设置包镜像与 Python 安装镜像
4. 执行 `uv python install 3.12`
5. 在目标目录执行 `uv init`
6. 用 `uv add` 安装业务依赖
7. 用 `uv add --dev` 安装质量工具
8. 在 `pyproject.toml` 的 `[project.scripts]` 中定义启动别名（见下方项目启动规范）
9. 用 `uv run <别名>` 运行程序或测试

## 项目启动规范（强制）

- **必须定义别名**：所有项目必须在 `pyproject.toml` 的 `[project.scripts]` 中定义一个与项目名一致（或易于识别）的启动脚本别名，指向 `main:main` 函数。
- **禁止直接运行文件**：运行程序时，**禁止**直接执行 `python src/.../main.py` 或 `uv run python ...`。
- **统一使用 uv run**：必须优先使用 `uv run <别名>`。这能确保 `PYTHONPATH` 自动包含 `src` 目录，避免模块导入错误，并保持环境隔离。

## 中国网络默认策略

- 用户位于中国大陆、校园网、政企网或已明确提到“下载慢 / 连不上 / SSL 问题”时，后续 AI 默认先走镜像方案
- 不要先假设官方 GitHub、PyPI、Astral 下载地址一定可达
- 不要让零基础用户自己手动研究镜像配置，优先由 AI 在当前终端会话里设置
- 如果镜像不可用，再说明已回退到官方源，并把原因告诉用户

## `uv`、Python、三方包的镜像顺序

### `uv` 本体安装

- Windows 零环境优先考虑系统包管理器或预置安装方式，不要默认第一步就走官方安装脚本
- 如果机器上已经有可用 Python，优先使用国内 PyPI 镜像安装 `uv`
- 只有在没有可用 Python、且系统包管理器不可用时，才考虑官方安装脚本，并提前说明网络风险

```powershell
python -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple uv
uv --version
```

### Python 托管安装

- `uv python install` 前，优先为当前会话设置 `UV_PYTHON_INSTALL_MIRROR`
- 如果团队已有内网或国内可达的 `python-build-standalone` 镜像，优先使用
- 如果没有稳定镜像，至少要先告知用户这一步可能回退官方源
- 当前维护中已核验可达的示例镜像为南京大学兼容路径：`https://mirror.nju.edu.cn/github-release/indygreg/python-build-standalone/releases/download`
- 即使采用默认镜像，后续 AI 在大版本更新后仍应定期回查可用性

### 第三方包安装

- `uv add`、`uv sync`、`uv pip install` 默认优先国内 PyPI 镜像
- 单项目长期维护时，优先在项目级配置 `tool.uv.index`
- 临时执行时，优先在当前 PowerShell 会话设置 `UV_DEFAULT_INDEX` / `UV_INDEX_URL`

## Windows PowerShell 5.1 镜像示例

```powershell
$env:UV_DEFAULT_INDEX = 'https://pypi.tuna.tsinghua.edu.cn/simple'
$env:UV_INDEX_URL = 'https://pypi.tuna.tsinghua.edu.cn/simple'
$env:PIP_INDEX_URL = 'https://pypi.tuna.tsinghua.edu.cn/simple'

# 当前验证可达的示例镜像：南京大学兼容路径
$env:UV_PYTHON_INSTALL_MIRROR = 'https://mirror.nju.edu.cn/github-release/indygreg/python-build-standalone/releases/download'

uv python install 3.12
uv add requests
uv add --dev pytest ruff mypy
```

## 项目级 `uv` 索引示例

```toml
[[tool.uv.index]]
name = "tsinghua"
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
```

## 普通用户场景下的约束

- 不要要求用户自己执行 `uv run python main.py`
- 不要要求用户自己执行 `uv add ...`
- 不要要求用户自己分析终端报错
- 如果程序是交互式命令行，也应优先由 AI 帮用户先跑一次，再解释如何使用
- 如果程序适合 GUI，就不要默认做成纯命令行
- 做用户项目时，必须通过 `../scripts/bootstrap_project.ps1` 或 `../scripts/instantiate_blueprint.ps1` 生成项目骨架；禁止手动复制 `templates/` 文件夹或直接在模板上修改

## 推荐的基础工具

- 代码格式和静态检查：`ruff`
- 类型检查：`mypy`
- 自动化测试：`pytest`
- 打包：`pyinstaller`
- 配置读取：`python-dotenv`
- 浏览器自动化：`playwright`

## Playwright 额外约束

- 不要默认执行 `playwright install` 下载浏览器内核
- 先询问用户本机是否已有 Chrome、Edge、Chromium 等浏览器
- 优先尝试复用本地浏览器可执行文件
- 如果用户不知道浏览器路径，AI 可以辅助检查常见安装目录，必要时再从注册表定位常见浏览器
- 只有在用户明确接受、且本机没有可复用浏览器时，才考虑下载 Playwright 浏览器内核
- 如果目标是分发给别人使用，默认提醒“内核随包分发体积会明显变大”，优先改成复用本地浏览器

## 推荐项目骨架

```text
project-name/
├── pyproject.toml
├── uv.lock
├── .python-version
├── .env.example
├── .gitignore
├── README.md
├── src/
│   └── app_name/
│       ├── __init__.py
│       ├── main.py
│       ├── services/
│       ├── ui/
│       └── utils/
├── tests/
└── dist/
```

## 运行反馈要求

命令执行后，后续 AI 至少要说明：

- 执行了什么
- 成功还是失败
- 产物在哪
- 下一步准备做什么

## `.env` 读取约定

- 开发态优先读取项目根目录下的 `.env`
- 打包后优先读取可执行文件所在目录下的 `.env`
- 如果只存在 `.env.example`，可作为最后兜底模板读取，但交付给普通用户时仍应优先提供真实 `.env`
- 后续 AI 在模板里应显式写入 `load_dotenv(...)`，不要只复制文件却不加载

## 权限与授权说明

- 涉及联网安装、写磁盘、创建虚拟环境、生成 `dist` 目录时，应由 AI 发起
- 用户只需要决定“是否允许执行”
- 一旦用户允许，不要再把同类终端操作重新转交给用户
- 如果需要设置镜像环境变量，默认也由 AI 在当前会话中完成
- 如果 PowerShell 脚本执行结果异常，先排查文件编码与 BOM，不要直接把问题归因到业务逻辑
