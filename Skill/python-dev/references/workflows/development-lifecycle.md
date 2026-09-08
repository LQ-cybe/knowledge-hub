<!-- build_hash: 875066b2-eb210fd3-e937578a-b2673957-3cc6830e-3d0f820a-14b7f21a -->
<!-- content_sig: b4069178-d877f819-da61a040-8131ce9d-0f9074c4-0e5975c0-27e105d0 -->
# Python 程序开发全流程（强制执行）

> **路径约定**：本文档位于 `references/workflows/`，`../` 指向 `references/` 目录，`../../` 指向 skill 根目录。

这个文档规定 Python 程序开发的阶段推进方式。面向零编程经验用户，AI 按阶段推进：需求澄清、环境准备、编码、验证、打包与交付。

## 铁律

1. 不可跳过阶段
2. 面向零基础用户时，默认不要让用户自己操作终端
3. 涉及运行、测试、打包时，优先由 AI 发起命令
4. 当前阶段未完成，不进入下一阶段
5. 用户要求 `exe` 时，必须真的打包，而不是只讲方法

## 阶段一：需求澄清

- 先看 `../01-need-discovery.md`
- 先问清楚是做脚本、桌面工具还是 exe 交付
- 如需求很像高频场景，补看 `../06-common-scenarios.md`
- 面向零基础用户表达时，参考 `../01-need-discovery.md` 中的沟通规范
- 问清楚输入、输出、使用对象、触发方式、是否需要窗口、是否需要 `exe`
- 用户确认需求后再继续

## 阶段二：环境与项目初始化（禁止跳过脚本）

> **铁律**：必须先跑环境安装脚本，再跑项目脚手架脚本，禁止 AI 手写 pyproject.toml 或逐个创建目录文件。

1. 先看 `../02-agent-execution-and-env.md`
2. **第一步：运行 `../../scripts/ensure_uv_env.ps1`** — 安装 uv、配置中国镜像、安装 Python。这是所有后续操作的前提，禁止跳过
3. 判断场景是否匹配蓝图：
   - 匹配 cli-batch / gui-exe / excel-batch / web-scraper 任一蓝图 → **必须运行** `../../scripts/instantiate_blueprint.ps1`
   - 不匹配任何蓝图 → **必须运行** `../../scripts/bootstrap_project.ps1`
4. 脚本执行完成后，确认生成的文件：（pyproject.toml、src/、tests/、.env.example、.gitignore 等）
5. 用 `uv add` 补充业务依赖（如 pandas、openpyxl、requests 等），**严禁 pip install**（uv add 会自动写入 pyproject.toml 并更新 uv.lock）
6. 用 `uv add --dev` 补充开发依赖（pytest、ruff、mypy 等）
7. **确认依赖安装成功、pyproject.toml 中 [project.scripts] 已定义启动别名后，方可进入阶段三**（uv sync 仅用于换机器或给别人用项目时还原环境，日常开发不需要重复执行）
8. 如果阶段二或阶段三涉及 `.ps1` 模板、PowerShell 命令包装或中文乱码，优先查看 `../07-powershell-5.1-file-io-and-encoding.md`

## 阶段三：编码与结构实现

- 先看 `../03-project-structure-and-code-standards.md`
- 按分层结构组织代码（`src/app_name/`）
- 补齐配置、错误处理、类型注解和日志
- GUI 默认优先 `tkinter`，专业需求上 `PySide6`
- 必须在 `pyproject.toml` 中配置 `[project.scripts]`

## 阶段四：质量检查与运行验证

- 先看 `../04-quality-check-and-manual-verification.md`
- 运行 `ruff check`、`mypy`、`pytest`
- 实际启动程序，验证关键流程

## 阶段五：打包与交付

- 用户需要发给别人用、双击运行或明确提到 `exe` 时，进入交付模式
- 先看 `../05-packaging-and-exe-delivery.md`
- 如果要处理图标、GUI 窗口外观或标准打包参数，补看 `../../templates/pyinstaller/README.md`
- 使用 `../../scripts/build_windows_exe.ps1` 执行实际打包
- 如果刚调整过 `onefile` 图标链路，补跑 `../../scripts/verify_pyinstaller_onefile_icon.ps1`
- 对外分发时，补充 `LicenseId`、`WatermarkText` 与授权追踪信息
- 完成打包、产物检查、说明文档整理
- 最后对照 `../05-packaging-and-exe-delivery.md` 末尾的交付清单
