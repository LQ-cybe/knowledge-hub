<!-- source_map: 16d71f1b-7aa6767a-78b02e23-23e040fe-ad41faa7-ac88fba3-85308bb3 -->
# Changelog

## 5.2.5 - 2026-07-04

- 强化 `references/05-packaging-and-exe-delivery.md` 的交付约束语气：明确规定只要进入“发给别人用 / 双击运行 / 做成软件 / 生成 exe”的场景，AI 就必须使用 `PyInstaller` 打包。
- 明确禁止把 `.bat` / `.cmd` 调用 `.py` 文件当作普通用户交付方案，避免后续 AI 用“批处理包一层 Python”冒充发布产物。

## 5.2.4 - 2026-07-04

- 将 `PyInstaller` 冒烟验证图标内置到技能目录：新增 `assets/pyinstaller-smoke-icon.png`，避免后续 AI 依赖 `python-dev` 目录外的开发文件。
- 更新 `scripts/verify_pyinstaller_onefile_icon.ps1`、`templates/pyinstaller/README.md` 与 `references/05-packaging-and-exe-delivery.md`，默认图标路径统一改为技能内部的 `assets/pyinstaller-smoke-icon.png`。
- 更新 `scripts/check_skill_quality_gate.ps1`，新增内置冒烟图标存在性检查，防止后续发布时漏带该资源。

## 5.2.3 - 2026-07-04

- 新增 `scripts/verify_pyinstaller_onefile_icon.ps1`：自动执行 `ensure_uv_env.ps1`、实例化临时 `gui-exe` 蓝图、用 `onefile + windowed` 模式打包，并通过启动日志确认运行时窗口图标已加载，作为 `PyInstaller` 图标链路的回归验证脚本。
- 更新 `SKILL.md`、`templates/pyinstaller/README.md`、`references/05-packaging-and-exe-delivery.md`、`references/workflows/development-lifecycle.md` 与 `scripts/check_skill_quality_gate.ps1`，把 `onefile` 图标冒烟验证脚本挂入路由和门禁。

## 5.2.2 - 2026-07-04

- 新增 `templates/pyinstaller/README.md`：沉淀 `uv + PyInstaller` 的标准打包模板，明确普通用户交付时的 `exe` 打包步骤、图标约定与 AI 执行要点。
- 优化 `scripts/build_windows_exe.ps1`：`-IconPath` 现在支持直接传入 `PNG` 或 `ICO`；当传入 `PNG` 时，脚本会自动通过 `uv add --dev pillow` 转换为 `ICO`，再传给 `PyInstaller --icon`，并把运行时图标资源一起带入产物。
- 优化 `templates/project-blueprints/gui-exe`：新增 `assets/README.md.tmpl`，并让 `ui/app.py.tmpl` 在源码态与打包态优先读取 `assets/` 图标资源，尽量同步任务栏、窗体左上角和发布的 `EXE` 文件图标。
- 更新 `SKILL.md`、`references/05-packaging-and-exe-delivery.md`、`references/workflows/development-lifecycle.md` 与 `templates/project-blueprints/gui-exe/README.md`，统一把 PyInstaller 图标模板挂到打包路由入口。

## 5.2.1 - 2026-06-23

- 新增 `scripts/ensure_uv_env.ps1`：一键安装 uv + 配置中国镜像环境脚本。核心安装方式改为**从 PyPI 镜像直接下载 uv wheel 包并解压 uv.exe**（无需 Python、无需 winget、无需访问 astral.sh），走国内镜像秒级下载；内置三层 fallback：① PyPI 镜像下载 whl → ② winget → ③ astral.sh 官方脚本兜底；镜像自动探测：PyPI 候选（清华→中科大→华为云→阿里云），python-build-standalone 候选（npmmirror→NJU→官方站），自动选择延迟最低的；参照 dotnet 项目的 `ensure_dotnet_sdk.ps1` 风格编写，PowerShell 5.1 兼容。
- SKILL.md 主题路由"环境与项目初始化"新增 `ensure_uv_env.ps1` 入口。

## 5.2.0 - 2026-06-23

- **强化项目初始化铁律**：SKILL.md "必须遵守"节新增"项目初始化铁律"子节，明确：①禁止 AI 从零手写项目文件，必须通过 ps1 脚本生成骨架；②场景匹配蓝图时必须运行 instantiate_blueprint.ps1；③严禁 pip install，必须用 uv add；④骨架未落地前禁止写 .py 业务代码。
- SKILL.md "最低执行清单"从 9 条扩展到 12 条，新增第 5-8 步（脚本脚手架 → uv add 补充依赖 → uv sync → 在模板基础上改代码）。
- SKILL.md "命令代执行规则"新增"严禁 pip install"条目。
- `development-lifecycle.md` 阶段二重写：从可选"优先复用"改为硬性"禁止跳过脚本"，列出 8 步具体操作序列（判断蓝图→运行脚本→确认文件→uv add→uv add --dev→uv sync→确认后方可进入阶段三）。
- `02-agent-execution-and-env.md` 新增"项目脚手架强制规则"和"依赖管理铁律"两个独立章节，删除旧的重复"依赖管理最佳实践"节。

## 5.1.0 - 2026-06-23

- 修复 `references/05-packaging-and-exe-delivery.md` 中"交付清单与用户移交"章节格式损坏（`\`r\`n` 转义符未正确渲染）。
- SKILL.md 顶部新增"第一次用？看这里"新手指南区块，降低零基础用户入口门槛。
- 新增 `docs/troubleshooting.md`：13 个常见问题的排障指南，覆盖环境安装、运行异常、中文乱码、打包问题等。
- 新增 `docs/glossary.md`：用大白话解释 30+ 个技术术语（uv、exe、依赖、镜像、API 等），面向零基础用户。
- 扩充 `examples/index.md`：增加 5 组完整对话示例（文件批处理、Excel 合并、网页抓取、桌面工具、模糊需求引导），包含用户提问→AI 思路→AI 回应全流程，新增蓝图选择决策树。
- SKILL.md 主题路由新增"帮助文档"和"风险与排障→常见报错"入口，目录约定增加 `docs/` 说明。
- `references/workflows/development-lifecycle.md` 顶部增加路径约定注释，统一相对路径基准。
- `templates/project-blueprints/gui-exe/app.py.tmpl` 全面升级：使用 ttk 组件替代基础 tk 组件，引入主题系统（vista/clam 自适应），优化布局和内边距。

## 5.0.0 - 2026-06-23

- 重构 skill 组织结构：将多个子 skill（`need-discovery`、`env-setup`、`code-standards`、`quality-check`、`packaging`、`fullstack-workflow`）合并为单一主入口 `SKILL.md`，专项内容落地为 `references/` 和 `references/workflows/`。
- 脚本目录规范化：将 `.ps1` 脚本从 `templates/` 迁移到 `scripts/`，`templates/` 只保留模板与蓝图。
- 合并重复文件：`01+09`（需求引导+沟通规范）、`06→05`（交付清单→打包文档）、`11→03`（日志规范→代码规范）、4 个 `examples/` 合并为 1 个 `index.md`。
- 新增 `templates/shared/logging_setup.py.tmpl`，消除 4 个蓝图中重复的日志模块。
- 将技能开发过程文档（`08/10/12`）移至 `python/` 根目录，`README.md` 同步移动。
- 重写 `SKILL.md`：增加 `PowerShell 5.1 红线`、主题路由、目录约定、必须遵守、主原则与最低执行清单，版本号升级到 `5.0.0`。
- 更新 `instantiate_blueprint.ps1`、`bootstrap_project.ps1` 的路径定位逻辑以适应 `scripts/` 目录。
- 全局更新路径引用：`templates/*.ps1` → `scripts/*.ps1`，子 skill 路径 → references 路径，序号重新连续排列。
- 移除"模板工作区复制规则"等过时约束。

## 4.9.0 - 2026-06-02

- 优化 `scripts/bootstrap_project.ps1`、`scripts/instantiate_blueprint.ps1`、`scripts/build_windows_exe.ps1`、`scripts/check_skill_quality_gate.ps1`，将 `#requires` 从 PowerShell `7.0` 调整为 Windows 自带的 PowerShell `5.1`，降低普通用户环境门槛。
- 修复 `scripts/bootstrap_project.ps1` 的蓝图 `DryRun` 残留文件问题，避免预演时提前写入项目文件。
- 修复 `scripts/instantiate_blueprint.ps1` 生成蓝图项目时缺少 `src/<package>/__init__.py` 的问题，避免 `uv sync` 构建失败。
- 修复 `templates/project-blueprints/web-scraper/tests/test_scraper.py.tmpl` 的测试桩缺少 `status_code` 字段，恢复模板测试可通过状态。
- 新增 `references/12-release-self-checklist.md`，沉淀对外发布前的版本、门禁、PowerShell 兼容性、模板产物与分发物检查流程。
- 新增 `references/07-powershell-5.1-file-io-and-encoding.md`，统一 Python skill 中 PowerShell `5.1` 的读写编码规则，并明确用户项目必须通过 PS1 脚本生成骨架，禁止手动复制 `templates/` 文件夹。
- 更新根 `SKILL.md`、`README.md`、`references/08-skill-release-and-versioning.md`、`references/10-skill-quality-gate.md` 与全部子 skill 版本号到 `4.9.0`。

## 4.8.1 - 2026-06-02

- 将 `scripts/bootstrap_project.ps1` 的 `PythonInstallMirror` 默认值设置为当前已核验可达的南京大学兼容镜像路径。
- 优化 `references/02-agent-execution-and-env.md` 与 `references/02-agent-execution-and-env.md`，明确当前可先尝试的 `python-build-standalone` 国内镜像地址，并提醒后续定期回查。
- 同步全部 `SKILL.md` 版本号，保持发布记录一致。

## 4.8.0 - 2026-06-02

- 补回 `references/02-agent-execution-and-env.md` 中的中国网络环境说明，明确 `uv`、Python 托管安装与第三方包安装优先镜像。
- 优化 `references/02-agent-execution-and-env.md`，把镜像检查与配置加入必做动作，避免后续 AI 在中国网络环境下直接走官方源。
- 优化 `scripts/bootstrap_project.ps1`，增加中国镜像参数与当前会话环境变量初始化逻辑。
- 更新根 `SKILL.md`、`references/workflows/development-lifecycle.md`、`README.md` 与全部子 skill 版本号，保持流程与发布记录一致。

## 4.7.0 - 2026-06-02

- 新增 `package_skill_distribution.ps1`，支持按 `LicenseId` / `WatermarkText` 为 `python-dev` 生成带授权追踪信息的 skill 分发包。
- 优化 `scripts/build_windows_exe.ps1`，在提供授权参数时自动向 `dist` 写入 `LICENSE_NOTICE.txt` 与拆段编码的 `distribution-license.json`。
- 优化 `references/05-packaging-and-exe-delivery.md`、`references/05-packaging-and-exe-delivery.md` 与交付说明模板，补授权分发说明。
- 更新根 `SKILL.md`、`README.md`、`references/workflows/development-lifecycle.md` 与 `references/05-packaging-and-exe-delivery.md`，挂接授权分发流程。

## 4.6.0 - 2026-06-02

- 优化日志规范文档，补充进程号、线程号、模块名，以及网络类蓝图的脱敏地址、重试次数和失败原因要求。
- 优化四套蓝图与通用骨架的日志格式，统一输出 `pid`、`tid`、`module` 字段。
- 优化 `web-scraper` 蓝图，补 URL 脱敏、请求重试和失败原因日志，并增加对应测试模板。

## 4.5.0 - 2026-06-02

- 优化 `references/03-project-structure-and-code-standards.md`，明确日志按日期分文件、单文件 5MB、保留 30 天。
- 优化四套蓝图的 `logging_setup.py.tmpl`，统一日志文件命名、分片和自动清理策略。
- 优化 `scripts/bootstrap_project.ps1`，让通用项目骨架默认继承相同日志策略。
- 更新 `README.md`、`SKILL.md`、`references/workflows/development-lifecycle.md` 与发布规范说明。

## 4.4.0 - 2026-06-02

- 新增 `references/03-project-structure-and-code-standards.md`，补日志目录、异常堆栈和用户反馈规范。
- 优化 `references/03-project-structure-and-code-standards.md`，补日志规范章节。
- 优化 `templates/project-blueprints/gui-exe`，加入日志初始化和主界面“打开日志目录”按钮。
- 为 `cli-batch`、`gui-exe`、`excel-batch`、`web-scraper` 补 `logging_setup.py.tmpl`，并让关键流程记录日志。
- 优化 `scripts/bootstrap_project.ps1`，默认生成 `logs/` 目录、日志模块和基础日志入口。
- 优化 `scripts/instantiate_blueprint.ps1`，补 `APP_NAME`、`BLUEPRINT_NAME` 占位符替换。
- 优化 `scripts/check_skill_quality_gate.ps1`，增加子 skill 版本一致性与 `CHANGELOG` 版本检查。
- 更新根 `SKILL.md`、`README.md`、`references/workflows/development-lifecycle.md` 以及多个子 skill 说明。

## 4.3.0 - 2026-06-02

- 新增 `references/10-skill-quality-gate.md`，补 skill 结构门禁说明。
- 新增 `scripts/check_skill_quality_gate.ps1`，用于检查关键结构是否齐全。
- 为 `cli-batch`、`gui-exe`、`excel-batch`、`web-scraper` 补 `.env.example.tmpl` 与 `README-delivery.md.tmpl`。
- 优化 `scripts/instantiate_blueprint.ps1`，增加 `-DryRun`、冲突检测和 `-Force` 控制。
- 优化 `scripts/bootstrap_project.ps1`，支持透传蓝图预演与覆盖参数。
- 更新根 `README.md`、`SKILL.md`、`references/workflows/development-lifecycle.md` 与发布规范说明。

## 4.2.0 - 2026-06-02

- 新增根 `README.md`，补 skill 总览、目录结构与维护说明。
- 新增 `references/01-need-discovery.md`，统一零基础用户沟通方式。
- 新增 `scripts/instantiate_blueprint.ps1`，支持按蓝图实例化项目骨架。
- 新增 `templates/project-blueprints/excel-batch` 与 `templates/project-blueprints/web-scraper` 蓝图目录。
- 新增 `examples/request-excel-batch-exe.md` 与 `examples/request-web-scraper.md`。
- 优化 `scripts/bootstrap_project.ps1`，支持直接按蓝图创建项目。
- 更新根 `SKILL.md` 与 `references/workflows/development-lifecycle.md`，挂接第 3 轮增强资源。

## 4.1.0 - 2026-06-02

- 新增 `references/06-common-scenarios.md`，补高频需求场景与蓝图映射。
- 新增 `references/08-skill-release-and-versioning.md`，补 skill 自维护与发布规范。
- 新增 `templates/project-blueprints/cli-batch` 与 `templates/project-blueprints/gui-exe` 蓝图目录。
- 优化 `scripts/bootstrap_project.ps1`，补模板展开、`.python-version`、`dist` 目录和更稳的测试导入方式。
- 优化 `scripts/build_windows_exe.ps1`，补项目根目录参数和入口脚本存在性校验。
- 更新根 `SKILL.md` 与 `references/workflows/development-lifecycle.md`，增加第 2 轮增强后的结构说明。

## 4.0.0 - 2026-06-02

- 重构 `python-dev` 主入口，明确零基础用户和 AI 代执行规则。
- 新增 `references/`、`templates/`、`examples/` 基础目录。
- 补齐需求澄清、环境搭建、代码规范、验证和打包交付流程。
