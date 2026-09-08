<!-- asset_hash: 241a9e11-486bf770-4a7daf29-112dc1f4-9f8c7bad-9e457aa9-b7fd0ab9 -->
# Changelog

## 2.1.5 - 2026-07-04

- 新增 `references/13-targetframework-and-rollforward-strategy.md`，把 `TargetFramework`、`RollForward`、低版本优先发布、`.NET 8` 平衡定位、`.NET 10` 在部分 `Win10` 不理想等知识统一沉淀到 `dotnet-dev`。
- 更新 `SKILL.md`、`references/01-need-discovery.md`、`references/02-agent-execution-and-env.md`、`references/05-packaging-and-exe-delivery.md`、`references/10-common-faq.md` 与 `references/workflows/development-lifecycle.md`，让 AI 在需求分析、环境准备与发布阶段优先引导“先看低版本是否够用，再决定是否升高版本，并按需评估 RollForward”。
- 调整 `scripts/bootstrap_project.ps1`、`scripts/ensure_dotnet_sdk.ps1`、`scripts/instantiate_blueprint.ps1`：默认目标框架统一回到 `net6.0`，不再把简单模板默认抬到 `net8.0` 或 `net10.0`。
- 更新各蓝图 `README` 与交付说明模板，统一说明模板默认从 `net6.0` 起步，如确有需要再升到 `net8.0` / `net10.0`，框架依赖发布时再评估 `RollForward`。
- 更新 `scripts/check_skill_quality_gate.ps1`，补充对新参考文档和 `net6.0` 默认基线的检查。

## 2.1.4 - 2026-07-04

- 为 `gui-exe` 蓝图补齐项目内图标约定：默认改为引用 `Assets\AppIcon\app.ico`，同时在 `MainWindow.xaml` 上设置窗口图标，避免只改 `exe` 图标却遗漏运行时窗体图标。
- 修正 `gui-exe` 蓝图项目输出类型：从 `Exe` 改为 `WinExe`，避免 WPF 程序双击后背后多出控制台窗口。
- 更新 `scripts/instantiate_blueprint.ps1`：实例化 `gui-exe` 时，自动把图标资产写入目标项目内部的 `Assets\AppIcon\`，不再依赖项目外部绝对路径；并新增 `-GuiIconSourcePath` 支持按用户提供的 `PNG/ICO` 注入新项目。
- 新增 `scripts/gui_icon_asset_tools.ps1` 与 `scripts/update_gui_blueprint_icon.ps1`，支持把 `PNG` 稳定转换成多尺寸 `ICO`，并维护 `dotnet-dev/assets/gui-exe-default-icon/` 内置图标资产。
- 更新 `references/11-windows-desktop-icon-and-resource-pitfalls.md`、`references/05-packaging-and-exe-delivery.md` 与 `templates/project-blueprints/gui-exe/README.md`，统一要求图标资源落在项目内部固定目录，并沉淀 `PNG -> ICO -> 项目内 Assets\AppIcon` 的落地链路。

## 2.1.3 - 2026-07-02

- 为 `gui-exe` 蓝图新增 `Properties/DesignTimeResources.xaml`，修复只在 `App.xaml` 挂 `HandyControl` 主题时，窗口页设计器里资源提示不全的问题。
- 为 `gui-exe` 蓝图新增 `Resources/ThemeOverrides.xaml` 全局主题覆盖入口，默认保留 `HandyControl` 官方配色，仅在用户明确要求品牌色时覆盖。
- 更新 `App.xaml.tmpl`、`MainWindow.xaml.tmpl` 与 `app_name.csproj.tmpl`，让运行时主题、设计期资源与示例界面统一走同一套全局主题链路。
- 新增 `references/12-handycontrol-theme-standard.md`，并同步更新 `references/07-handycontrol-routing.md`、`SKILL.md` 与 `gui-exe/README.md`，沉淀设计期资源和企业色覆盖规范。

## 2.1.2 - 2026-06-26

- 将 Windows 桌面程序 `ico` 图标接入与资源避坑内容从主 `SKILL.md` 下沉到独立参考文件 `references/11-windows-desktop-icon-and-resource-pitfalls.md`。
- 在主入口 `SKILL.md` 的 `风险与排障` 路由中新增该参考文件，保持主 skill 以路由和原则为主，避免承载过多细节。

## 2.1.1 - 2026-06-26

- 在 `SKILL.md` 中新增 `核心知识沉淀` 章节，补充 Windows 桌面程序 `ico` 图标接入的核心认知与避坑结论。
- 总结 `WPF` 与 `WinForms` 的图标接入差异，明确区分 `ApplicationIcon`、运行时窗体图标与任务栏图标。
- 补充最小示例代码，强调 `WPF` 优先使用 `Resource Include + Icon="/app.ico"`，避免 AI 误用松散文件路径。
- 新增图标问题的统一排查顺序，避免未来在“图标不生效”或“加完 ico 后 exe 双击没反应”场景下重复踩坑。

## 2.1.0 - 2026-06-23

- 调整 .NET 版本策略：不再"跳过 .NET 8"，改为根据目标用户群体选择版本。
  - `Win7` → `.NET 6`（不变）
  - `Win10` → 优先 `.NET 8`（部分 Win10 不支持 .NET 10）
  - `Win11+` → 可 `.NET 10`，需用户明确要求
- 新增"目标人群 Windows 版本"作为需求澄清必问问题（`01-need-discovery.md`）。
- 更新 `SKILL.md`、`README.md`、`02-agent-execution-and-env.md`、`development-lifecycle.md` 中的版本决策描述。
- 更新 `ensure_dotnet_sdk.ps1`、`bootstrap_project.ps1`：默认框架改为 `net8.0`，`Get-SdkMajorVersion` / `Get-WingetPackageId` 支持三版本。
- 更新 `instantiate_blueprint.ps1`：移除 .NET 8 拦截，`$testFramework` 支持三版本。
- 更新 `build_windows_exe.ps1`：移除 .NET 8 拦截。
- 更新 `check_skill_quality_gate.ps1`：断言同步为新版本策略（Win10/.NET 8/SDK.8 检查）。

## 2.0.0 - 2026-06-22

- 重构 skill 组织结构：将多个子 skill（`need-discovery`、`env-setup`、`code-standards`、`quality-check`、`packaging`、`powershell-encoding`、`fullstack-workflow`）合并为单一主入口 `SKILL.md`，专项内容落地为 `references/workflows/development-lifecycle.md`。
- 新增 `references/workflows/` 目录，统一存放从子 skill 合并而来的工作流入口。
- 脚本目录规范化：将 `.ps1` 脚本从 `templates/` 迁移到 `scripts/`，`templates/` 只保留模板与蓝图。
- 文档目录规范化：将 `references/handycontrol/` 移至 `docs/handycontrol/`，新增 `references/handycontrol-routing.md` 作为路由入口，提醒 AI 默认不要全量扫描 `docs/`。
- 将 `README.md` 从 `dotnet-dev/` 移至 `dotnet/` 根目录。
- 更新所有文档中的脚本路径引用（`templates/*.ps1` -> `scripts/*.ps1`）和 HandyControl 路径引用（`references/handycontrol/` -> `docs/handycontrol/`）。
- 重写 `SKILL.md`：增加 `PowerShell 5.1 红线`、主题路由、目录约定、必须遵守、主原则与最低执行清单。
- 更新 `README.md`、`references/02-agent-execution-and-env.md`、`references/05-packaging-and-exe-delivery.md`、`references/08-skill-release-and-versioning.md`、`references/12-release-self-checklist.md`、`references/03-project-structure-and-code-standards.md`、`references/13-handycontrol-integration-pitfalls.md`、`references/workflows/development-lifecycle.md`、`templates/project-blueprints/gui-exe/README.md` 以匹配新结构。
- 更新 `scripts/instantiate_blueprint.ps1` 与 `scripts/bootstrap_project.ps1` 的路径定位逻辑，使其适应 `scripts/` 与 `templates/` 分离。
- 更新 `scripts/check_skill_quality_gate.ps1` 以检查新结构（移除子 skill 目录检查，增加 `references/workflows/`、`docs/handycontrol/` 与 `scripts/` 结构检查）。
- 版本号升级到 `2.0.0`，反映不兼容的目录结构变化。

## 1.0.0 - 2026-06-03

- 新增 `dotnet-dev` 根入口、全流程子 skill、参考文档、模板、蓝图和示例需求。
- 明确版本策略：先判断是否需要兼容 `Win7`，需要则默认 `.NET 6`，否则统一 `.NET 10`，跳过 `.NET 8`。
- 新增 `templates/bootstrap_project.ps1`、`templates/instantiate_blueprint.ps1`、`templates/build_windows_exe.ps1`、`templates/check_skill_quality_gate.ps1`。
- 新增四套蓝图：`cli-batch`、`gui-exe`、`excel-batch`、`web-scraper`。
- 新增授权分发脚本 `package_skill_distribution.ps1`，支持 `LicenseId`、`WatermarkText` 和追踪文件输出。
- 强化 `bootstrap_project.ps1`：改为真正的 .NET 初始化流程，支持 Win7=>`.NET 6`、其他=>`.NET 10`、自动 `restore/build`、兼容 `.sln` 与 `.slnx`。
- 强化 `instantiate_blueprint.ps1`：自动生成解决方案、标准 `src/tests` 结构、`NuGet.config`、`Directory.Build.props`、根 `README`，并支持按蓝图补推荐 NuGet 包。
- 强化 `build_windows_exe.ps1`：支持 `SelfContained`、`SingleFile`、`ReadyToRun`、`TrimMode`、发布说明、授权文件与 zip 打包。
- 强化 `check_skill_quality_gate.ps1`：增加对 .NET 专用模板、脚本约束、蓝图关键文件和 Win7 / `.NET 10` 策略的门禁检查。
- 新增 `templates/ensure_dotnet_sdk.ps1`：支持在未安装 `dotnet CLI` 的电脑上优先用 `winget` 自动安装对应 SDK，失败时回退到官方 `dotnet-install.ps1` 做用户级自举安装。
- 更新桌面端规范：默认桌面技术栈改为 `WPF + CommunityToolkit.Mvvm + HandyControl`，并补充 MVVM 分层、高分屏适配和给 AI 提供界面库资料的建议。
- 升级 `gui-exe` 蓝图：从 `WinForms` 模板切换为真正的 `WPF + MVVM + HandyControl` 结构，新增 `App.xaml`、`MainWindow`、`ViewModel`、`ShellService` 与可运行测试。
- 增加 `HandyControl` 本地文档路由：在主入口、全流程、代码规范和 GUI 蓝图中明确要求，遇到控件、主题、资源字典或 XAML 报错时优先回看 `references/handycontrol/`。
- 修正 `HandyControl` 接入经验：模板改为按官方 `hc:Theme` 方式接入主题，按钮示例改为原生 `Button` 搭配 `ButtonPrimary` 样式和附加属性，并新增 `references/13-handycontrol-integration-pitfalls.md` 记录已验证的避坑规则。
- 强化环境说明：在根入口、流程文档、环境子 skill 和 `references/02-agent-execution-and-env.md` 中补齐“从 0 开始安装 SDK 并由 AI 全程代执行”的流程说明。
- 新增 `powershell-encoding` 子 skill 与 `references/14-powershell-5.1-file-io-and-encoding.md`，专门约束 Windows PowerShell `5.1` 下的文件读写、UTF-8 BOM、中文乱码与编码排查流程，并把路由接入主入口、环境与编码阶段。
- 重写 PowerShell `5.1` 编码指引：明确区分“内部可控文件 / 外部未知文件 / 对外交付文件”，不再把 `-Raw`、`-Encoding UTF8` 和 `UTF-8 with BOM` 写成万能默认方案，并同步校正主入口、环境说明、代码规范与子 skill 口径。
- 补充模板安全规则：明确做用户项目时默认先复制整个 `templates/` 到模板工作区，再在副本里修改或运行，原 skill 模板保持只读。
