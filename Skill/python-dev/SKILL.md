---
name: python-dev
description: >
  Python 程序开发总入口。面向零编程基础用户，先澄清需求，
  再由 AI 代替用户完成环境搭建、编码、运行、测试、打包与交付。
  默认不要求用户手动操作终端。
version: "5.2.5"
author: agent
agent_created: true
platform: windows
triggers:
  - "帮我"
  - "能不能"
  - "我想"
  - "有没有办法"
  - "python"
  - "程序"
  - "脚本"
  - "自动化"
  - "批量处理"
  - "爬虫"
  - "工具"
  - "桌面软件"
  - "exe"
when_to_use: >
  用户表达任何与 Python 程序、脚本、自动化、桌面工具、exe 打包相关的意图时触发。
internal_ref: "02a7e182-6ed688e3-6cc0d0ba-3790be67-b931043e-b8f8053a-9140752a"
---

# python-dev

单一主 skill，处理 Python 程序开发、打包与交付相关问题。

## 第一次用？看这里

这个 Skill 就像一个 **Python 编程助手**，你只需要告诉我：

> "我想把一堆 Excel 合并成一个"、"帮我做个双击就能用的小工具"、"帮我每天自动抓一下网页上的数据"

剩下的事情（装环境、写代码、运行测试、打包成 exe）全部由 AI 帮你搞定。

### 你能得到什么？

- **一个能跑的程序** — 不是说"你回去自己试试"，而是 AI 真的帮你跑通
- **双击就能用** — 如果需要发给别人用，可以打包成 exe，对方不需要装任何东西
- **每一步都说明白** — 做了什么、结果在哪里、怎么用，用大白话告诉你

### 你不需要会什么？

- 不需要懂编程
- 不需要知道什么是 Python、pip、终端
- 不需要自己安装任何环境

### 现在就可以开始

直接告诉我想做什么，哪怕说得不太清楚也没关系，我会先问你几个问题帮你理清需求。

---

## PowerShell 5.1 红线

- 所有 `.ps1` 与 `.ps1.tmpl` 默认视为在 `Windows PowerShell 5.1` 下执行，禁止默认使用仅 PowerShell 7+ 支持的参数、语法和命令行为
- 只要创建、修改、复制、分发 `.ps1` 或 `.ps1.tmpl`，一律使用 `UTF-8 with BOM + CRLF`
- 严禁使用 `UTF-8 without BOM` 保存 PowerShell 文件，否则 Windows PowerShell 5.1 下可能出现中文乱码、注释异常、脚本解析失败
- 如果兼容性不确定，优先改写为 PowerShell 5.1 可执行方案；默认不假设用户安装了 PowerShell 7

## 何时使用

用户提到以下任一主题时使用：

- 想做 Python 程序、自动化脚本、桌面工具或 Windows exe
- 需要 AI 代为执行 `uv` 环境搭建、依赖安装、运行、测试、打包
- 需求模糊，需要先澄清是脚本、桌面工具还是可交付成品
- 需要将项目打包为 `exe`（PyInstaller），或源码交付
- 桌面 GUI 项目需要 tkinter/PySide6 技术选型与分层指导
- 需要补齐日志、配置、`.env`、`.gitignore`、README 和交付说明
- 涉及 `.ps1` 创建 / 修改 / 中文乱码 / 编码排查
- 需要从零开始安装 Python 环境，或解决 `uv` / 包管理器问题
- 常见场景：Excel 批处理、Web 抓取、浏览器自动化、CLI 批处理、GUI 桌面工具
- 改动后验收、质量门禁、技能本体维护

## 主题路由

> 原则：先按用户意图关键词命中下表，再读对应文件；命中多个时优先读更具体的那个。

### 入口与决策

- 不知道走哪条路线 / 想快速了解整体流程：`./references/workflows/development-lifecycle.md`
- 需求澄清、首轮话术、必问问题、零基础沟通规范：`./references/01-need-discovery.md`
- 场景判断：脚本还是桌面工具还是 exe 交付？→ `./references/01-need-discovery.md`（场景判断节）

### 环境与项目初始化

- **必须先运行** `./scripts/ensure_uv_env.ps1`：在用户机器上检查/安装 uv、自动探测最快的中国镜像、配置环境变量、安装 Python。任何新建项目的第一步，禁止跳过
- 从零开始搭建环境 / 镜像配置 / Playwright 原则：`./references/02-agent-execution-and-env.md`
- 环境检查与命令代执行（`uv init`、`uv add`、`uv run`、`pytest`、`pyinstaller`）：`./references/02-agent-execution-and-env.md`
- 项目初始化与蓝图实例化：`./scripts/bootstrap_project.ps1` / `./scripts/instantiate_blueprint.ps1`

### 编码与结构

- 项目结构、代码规范、技术选型、安全规范、日志规范：`./references/03-project-structure-and-code-standards.md`
- tkinter / PySide6 桌面栈选择：`./references/03-project-structure-and-code-standards.md`
- Playwright 使用原则：`./references/03-project-structure-and-code-standards.md`

### 质量检查与运行验证

- 代码检查（ruff/mypy/pytest）、运行验证：`./references/04-quality-check-and-manual-verification.md`

### 打包与交付

- PyInstaller 打包 / exe 交付 / 配置文件原则 / 授权分发：`./references/05-packaging-and-exe-delivery.md`
- 打包后检查、交付清单、用户移交：`./references/05-packaging-and-exe-delivery.md`（末尾）
- 标准 PyInstaller 模板（含 PNG 图标嵌入约定）：`./templates/pyinstaller/README.md`
- 发布 Windows exe 脚本：`./scripts/build_windows_exe.ps1`
- `onefile + 图标` 冒烟验证脚本：`./scripts/verify_pyinstaller_onefile_icon.ps1`

### 常见场景

- CLI 批处理、GUI exe、Excel 批处理、Web 抓取等项目蓝图：`./templates/project-blueprints/`
- 示例需求：`./examples/index.md`
- 高频场景速查：`./references/06-common-scenarios.md`

### 风险与排障

- 编码与中文乱码问题：`./references/07-powershell-5.1-file-io-and-encoding.md`
- 对零基础用户沟通方式：`./references/01-need-discovery.md`（零基础用户沟通规范节）
- 常见报错与解决方案：`./docs/troubleshooting.md`

### 帮助文档（面向零基础用户）

- 术语解释（不懂的词来这里查）：`./docs/glossary.md`
- 常见问题排障：`./docs/troubleshooting.md`

### 维护与发布（skill 本体）

- 维护 skill 本身：`../08-skill-release-and-versioning.md`
- Skill 质量门禁：`../10-skill-quality-gate.md`
- 发布前自检：`../12-release-self-checklist.md`

## 参考实现

- PowerShell 项目初始化脚本（创建解决方案、标准 `src` 结构、`uv` 初始化）：`./scripts/bootstrap_project.ps1`
- PowerShell 蓝图实例化脚本（按场景生成项目骨架）：`./scripts/instantiate_blueprint.ps1`
- PowerShell Windows 打包脚本（PyInstaller 打包 + 授权文件写入）：`./scripts/build_windows_exe.ps1`
- PowerShell `onefile` 图标冒烟验证脚本：`./scripts/verify_pyinstaller_onefile_icon.ps1`
- PyInstaller 打包模板（`uv` + PNG 图标自动转 ICO + GUI 图标同步）：`./templates/pyinstaller/README.md`
- 公共日志模板：`./templates/shared/logging_setup.py.tmpl`
- `pyproject.toml` 模板：`./templates/pyproject.toml.tmpl`
- `.env.example` 模板：`./templates/.env.example.tmpl`
- `.gitignore` 模板：`./templates/.gitignore.tmpl`
- 交付说明模板：`./templates/README-delivery.md.tmpl`
- CLI 批处理蓝图：`./templates/project-blueprints/cli-batch`
- GUI exe 蓝图：`./templates/project-blueprints/gui-exe`
- Excel 批处理蓝图：`./templates/project-blueprints/excel-batch`
- Web Scraper 蓝图：`./templates/project-blueprints/web-scraper`
- 示例需求：`./examples/index.md`

## 目录约定

- `./SKILL.md`：主入口和总路由
- `./references/`：知识、边界、路由、实测结论（入口见主题路由）
- `./references/workflows/`：工作流入口文件（从子 skill 合并而来）
- `./docs/`：面向零基础用户的帮助文档（术语表、排障指南等）
- `./scripts/`：参考实现与可执行脚本（PowerShell）
- `./templates/`：通用模板、配置模板与场景化项目蓝图（`.tmpl` 与项目骨架）
- `./templates/shared/`：各蓝图共用的公共模板
- `./examples/`：示例需求与典型问法（含对话示例）
- `./CHANGELOG.md`：版本变更记录
- `../README.md`：skill 总览与快速使用顺序

## 必须遵守

### 项目初始化铁律（最高优先级）

- **环境先行，必须先跑 ensure_uv_env.ps1**：任何新建项目或首次在该机器上开发前，**必须率先运行** `./scripts/ensure_uv_env.ps1`。这个脚本会自动检查/安装 uv、探测最快的中国镜像、配置环境变量、安装指定 Python 版本。**禁止跳过这一步**，禁止 AI 手动执行 `uv init`、`uv python install` 等零散命令来代替这个一体化脚本
- **禁止从零手写项目文件**：环境就绪后，新建项目必须运行 `./scripts/bootstrap_project.ps1` 或 `./scripts/instantiate_blueprint.ps1` 生成完整的项目骨架（`pyproject.toml`、`src/`、`tests/`、`.env.example`、`.gitignore` 等），**禁止 AI 自己手动创建 pyproject.toml 或逐个 mkdir / write_to_file**
- **场景匹配蓝图时必须用脚本**：如果用户需求匹配四大蓝图之一（cli-batch / gui-exe / excel-batch / web-scraper），必须运行 `instantiate_blueprint.ps1`，在生成的模板基础上修改业务逻辑，**禁止跳过脚本直接手写**
- **必须用 uv add 管理依赖**：要新增任何第三方包时，必须用 `uv add <包名>`（会自动写入 `pyproject.toml` 并安装到当前环境）。**严禁使用 `pip install`**，这会把依赖装到全局而非项目的 `uv.lock` 里，破坏环境隔离。`uv sync` 仅用于换机器或给别人用项目时还原环境，日常开发不需要重复执行
- **必须先有骨架再写代码**：骨架文件（pyproject.toml、目录结构）没落地之前，**禁止开始写任何 .py 业务代码**

### 通用规则

- 先澄清需求，再编码
- 先问清楚是做脚本、桌面工具还是 exe 交付，再决定技术方案
- 不要默认让用户自己打开终端运行 `uv run`、`pytest`、`pyinstaller`
- 如果用户要的是"给别人用"，默认要考虑 `exe`、说明文档和示例输入
- 如果交付对象是普通用户，优先考虑窗口、按钮、文件选择，而不是命令行参数
- 只要创建或修改 `.ps1` / `.ps1.tmpl`，必须使用 `UTF-8 with BOM + CRLF`
- 只要涉及 `.ps1` 中文乱码、文件读写或编码排查，优先按 `./references/07-powershell-5.1-file-io-and-encoding.md` 处理
- 优先使用 `uv` 官方 CLI 管理 Python 环境和依赖，不要把一堆第三方脚手架当默认前置
- 桌面项目 tkinter 优先，需要专业 UI 再上 PySide6
- 先把核心逻辑和界面分层，再做 GUI 和打包
- 先真实跑通，再交付给用户
- 先保护密钥、配置和用户数据，再追求功能堆叠
- 对外分发时，默认补 `LicenseId`、`WatermarkText` 和授权追踪信息
- 不把密钥、密码、Cookie、令牌直接写进代码
- 修改能力后，要同步更新 `references/` 和 `CHANGELOG.md`

## 主原则

- 面向零编程基础用户，先沟通清楚需求，再决定技术方案
- 不要让用户自己敲终端，命令默认由 AI 发起
- 不要只给代码，不做运行、验证和交付
- 不要把测试责任直接丢给用户
- 不要默认所有需求都只需要命令行工具
- 不要让 skill 只有流程文字，没有可复用模板、蓝图和发布记录
- 不要修改完 skill 后不做一次结构门禁检查
- 不要只给用户一句报错，不留下日志路径和异常上下文

## 命令代执行规则

- 涉及 `uv init`、`uv add`、`uv sync`、`uv run`、`ruff`、`mypy`、`pytest`、`pyinstaller` 时，默认由 AI 发起
- **严禁在项目中使用 `pip install`**：所有依赖必须通过 `uv add` 写入 `pyproject.toml`，确保 `uv.lock` 记录完整依赖图
- 中国网络环境下，涉及 `uv`、Python 与包安装时，默认先设置镜像再执行
- 如果运行命令需要系统授权、联网安装或写文件，AI 负责发起，用户只需点"允许"
- 除非用户明确要求学习命令行，否则不要把"请你在终端执行以下命令"当成默认答案
- 用户问"怎么运行"时，优先直接帮用户运行一次，再补充说明
- 用户问"怎么打包成 exe"时，默认理解为"请 AI 帮我打包并验证产物"

## 代码与结构原则

- 新项目优先使用 `src` 结构
- 必须在 `pyproject.toml` 的 `[project.scripts]` 中定义启动别名
- 运行程序时优先执行 `uv run <别名>`，禁止直接通过 `python src/.../main.py` 运行
- `pyproject.toml` 中统一放依赖和工具配置，优先使用 `uv add` 维护
- 业务逻辑、界面逻辑、配置读取、文件读写分层
- 默认补齐类型注解、日志、错误提示、`.env.example`、`.gitignore`
- 日志默认按日期分文件、单文件 `5MB`、保留最近 `30` 天
- 单文件过大时主动拆分，不把"先跑起来再说"变成长期结构
- 需要桌面交付时，优先提供清晰入口、状态提示、错误提示和输出位置说明

## 对后续 AI 的最低执行清单

开始写代码前，至少完成这些动作：

1. **第一步：运行 `./scripts/ensure_uv_env.ps1`** — 一键安装 uv、配置中国镜像、安装 Python。这台机器从未执行过此脚本时，**禁止跳过**
2. 问清楚做的是脚本、桌面工具还是 `exe` 交付
3. 问清楚是新建项目还是基于现有代码迭代
4. 问清楚给谁用，是否是零基础用户，是否需要窗口或双击运行
5. 收集样例文件、网站链接、截图、列名、输入输出样本
6. **如果是新建项目且匹配蓝图场景 → 运行 `instantiate_blueprint.ps1` 生成项目骨架**
7. **如果是不匹配蓝图的新建项目 → 运行 `bootstrap_project.ps1` 生成通用骨架**
8. **在生成的 `pyproject.toml` 中用 `uv add` 补充业务依赖（会自动安装并更新 uv.lock）**
9. **确认骨架和依赖就绪后，再在生成的 .py 模板基础上修改业务代码**
10. 需要运行命令时，由 AI 自己发起，不要转手给用户
11. 生成后至少跑一次程序、自测一次关键流程
12. 如果用户要求 `exe`，必须实际打包并确认产物存在
13. 交付时要说明产物位置、使用方法、配置文件、授权说明和注意事项
## 分发授权说明

- 本分发包已写入多重授权追踪信息，禁止绕过原作者进行二次分发
- LicenseId：lqiang1857_廖强_专用
- WatermarkText：本作品归公众号 Excel催化剂 所有，仅限授权用户自用，禁止任何形式的擅自传播。对于恶意传播、营利性传播行为，我方将保留追究法律责任的权利。
- 如朋友需要，请直接转介绍其向原作者获取授权版本