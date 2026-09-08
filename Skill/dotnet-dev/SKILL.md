---
name: dotnet-dev
description: >
  .NET 程序开发总入口。面向零编程基础用户，先澄清需求，再由 AI 代替用户完成环境准备、编码、运行、测试、发布与交付。
  先判断低版本是否够用：默认从 .NET 6 起步；Win10 场景优先 .NET 8；只有明确需要且环境可控时才考虑 .NET 10。
version: "2.1.5"
author: agent
agent_created: true
platform: windows
triggers:
  - "帮我"
  - "我想"
  - ".net"
  - "dotnet"
  - "c#"
  - "程序"
  - "桌面工具"
  - "批量处理"
  - "接口"
  - "网站"
  - "exe"
when_to_use: >
  用户表达任何与 C#、.NET、桌面工具、批处理、接口集成、Windows exe 交付相关的意图时触发。
  触发后先判断低版本是否够用：默认先评估 .NET 6；Win10 优先 .NET 8；仅明确需要且环境可控时再考虑 .NET 10。
internal_ref: "0fb9d715-63c8be74-61dee62d-3a8e88f0-b42f32a9-b5e633ad-9c5e43bd"
---

# dotnet-dev

单一主 skill，处理 .NET 程序开发、交付与维护相关问题。

## PowerShell 5.1 红线

- 所有 `.ps1` 与 `.ps1.tmpl` 默认视为在 `Windows PowerShell 5.1` 下执行，禁止默认使用仅 PowerShell 7+ 支持的参数、语法和命令行为
- 只要创建、修改、复制、分发 `.ps1` 或 `.ps1.tmpl`，一律使用 `UTF-8 with BOM + CRLF`
- 严禁使用 `UTF-8 without BOM` 保存 PowerShell 文件，否则 Windows PowerShell 5.1 下可能出现中文乱码、注释异常、脚本解析失败
- 如果兼容性不确定，优先改写为 PowerShell 5.1 可执行方案；默认不假设用户安装了 PowerShell 7

## 何时使用

用户提到以下任一主题时使用：

- 想做 .NET / C# 程序、桌面工具、批处理脚本或 Windows exe
- 需要 AI 代为执行 `dotnet` 环境检查、项目初始化、依赖安装、运行、测试、发布
- 需求模糊，需要先澄清是脚本、桌面工具还是可交付成品
- 需要判断是否需要兼容 `Win7` / `Win10`，并据此选择 `.NET 6` / `.NET 8` / `.NET 10`
- 需要判断框架依赖发布时是否应启用 `RollForward` 以保留向上兼容
- 桌面 GUI 项目需要 `WPF + MVVM + HandyControl` 技术栈与分层指导
- 需要将项目发布为 `exe`、单文件、自包含目录或源码交付
- 需要补齐日志、配置、`appsettings.json`、`.gitignore`、README 和交付说明
- 涉及 `.ps1` 创建 / 修改 / 中文乱码 / 编码排查
- 需要从零开始安装 .NET SDK，或解决 `dotnet` 环境 / NuGet / 构建问题
- 常见场景：Excel 批处理、Web 抓取、CLI 批处理、GUI 桌面工具
- 改动后验收、质量门禁、技能本体维护与版本发布

## 主题路由

> 原则：先按用户意图关键词命中下表，再读对应文件；命中多个时优先读更具体的那个。每个参考文件只在最适合的小节出现一次。

### 入口与决策

- 不知道走哪条路线 / 想快速了解整体流程：`./references/workflows/development-lifecycle.md`
- 需求澄清、首轮话术、必问问题、零基础沟通、主题未命中时的完整清单：`./references/01-need-discovery.md`
- 版本决策：优先看 `./references/13-targetframework-and-rollforward-strategy.md`，默认先评估 `net6.0`，不够再升 `net8.0`，只有明确需要时才考虑 `net10.0`

### 环境与项目初始化

- 环境检查、命令代执行、SDK 安装与环境自举（`winget` / `dotnet-install.ps1` / `dotnet --info` / `dotnet new` / `dotnet restore`）：`./references/02-agent-execution-and-env.md`
- SDK 自举脚本：`./scripts/ensure_dotnet_sdk.ps1`
- 项目初始化与蓝图实例化：`./scripts/bootstrap_project.ps1` / `./scripts/instantiate_blueprint.ps1`

### 编码与结构

- 项目结构、代码规范、技术选型、安全规范、`WPF + MVVM + CommunityToolkit.Mvvm + HandyControl` 默认栈、日志规范：`./references/03-project-structure-and-code-standards.md`
- HandyControl 文档路由、接入与避坑（快速入门 / 主题 / 原生与扩展控件 / 官方包 vs 非官方包 / `ThemeResources` / `hc:` 控件）：`./references/07-handycontrol-routing.md`
- HandyControl 全局主题覆盖与设计期资源规范：`./references/12-handycontrol-theme-standard.md`

### 质量检查与运行验证

- 代码检查、运行验证、最小测试集：`./references/04-quality-check-and-manual-verification.md`
- 性能优化与并发处理：`./references/09-performance-and-concurrency.md`

### 打包与交付

- 交付形式选择（源码 / 框架依赖 / 自包含单文件 / 自包含目录）、交付清单、用户移交、对外分发：`./references/05-packaging-and-exe-delivery.md`
- 发布 Windows exe、zip 打包、授权文件：`./scripts/build_windows_exe.ps1`

### 常见场景

- CLI 批处理、GUI exe、Excel 批处理、Web 抓取等项目蓝图：`./templates/project-blueprints/`
- 示例需求：`./examples/`
- 高频场景速查：`./references/06-common-scenarios.md`

### 风险与排障

- 编码与中文乱码问题：`./references/08-powershell-5.1-file-io-and-encoding.md`
- 常见问题（NuGet 报错、COM引用、单文件路径等）：`./references/10-common-faq.md`
- Windows 桌面程序图标、WPF 资源路径、`ApplicationIcon`、窗体图标与“加完 ico 后 exe 双击没反应”排查：`./references/11-windows-desktop-icon-and-resource-pitfalls.md`

## 参考实现

- PowerShell SDK 自举脚本（优先 `winget`，回退 `dotnet-install.ps1`）：`./scripts/ensure_dotnet_sdk.ps1`
- PowerShell 项目初始化脚本（创建解决方案、标准 `src/tests` 结构、restore / build）：`./scripts/bootstrap_project.ps1`
- PowerShell 蓝图实例化脚本（按场景生成项目骨架、推荐 NuGet 包）：`./scripts/instantiate_blueprint.ps1`
- PowerShell Windows 发布脚本（`SelfContained` / `SingleFile` / `ReadyToRun` / `TrimMode` / zip / 授权文件）：`./scripts/build_windows_exe.ps1`

- 公共配置模板：`./templates/Directory.Build.props.tmpl`
- `appsettings.json` 模板：`./templates/appsettings.json.tmpl`
- `.gitignore` 模板：`./templates/.gitignore.tmpl`
- `NuGet.config` 模板：`./templates/NuGet.config.tmpl`
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
- `./scripts/`：参考实现与可执行脚本（PowerShell）
- `./templates/`：通用模板、配置模板与场景化项目蓝图（`.tmpl` 与项目骨架）
- `./examples/`：示例需求与典型问法
- `./CHANGELOG.md`：版本变更记录

## 必须遵守

- 先澄清需求，再编码
- 先询问目标人群的 Windows 版本（`Win7` / `Win10` / `Win11`），再判断 `net6.0` 是否够用
- 简单项目默认从 `.NET 6` 起步；`.NET 6` 不够时优先升 `.NET 8`
- 目标人群含 `Win10` 电脑时，不要把 `.NET 10` 当默认基线；部分 `Win10` 对 `.NET 10` 支持不理想
- 只有用户明确要求高版本 API / 包，且环境可控时，才用 `.NET 10`
- 只有在框架依赖发布时，才单独评估 `RollForward`；不要把它当成高版本 API 开关
- 不要默认让用户自己打开终端运行 `dotnet restore`、`dotnet test`、`dotnet publish`
- 如果用户要的是“给别人用”，默认要考虑 `exe`、说明文档和示例输入
- 如果交付对象是普通用户，优先考虑窗口、按钮、文件选择，而不是命令行参数
- 只要创建或修改 `.ps1` / `.ps1.tmpl`，必须使用 `UTF-8 with BOM + CRLF`
- 只要涉及 `.ps1` 中文乱码、文件读写或编码排查，优先按 `./references/08-powershell-5.1-file-io-and-encoding.md` 处理
- 优先使用 `dotnet` 官方 CLI，不要把一堆第三方脚手架当默认前置
- 桌面项目默认优先 `WPF`，并按 `MVVM` 分层；界面库默认优先 `HandyControl`
- 先把核心逻辑和界面分层，再做 GUI 和发布
- 先真实跑通，再交付给用户
- 先保护密钥、配置和用户数据，再追求功能堆叠
- 涉及 `HandyControl` 时，优先通过 `./references/07-handycontrol-routing.md` 路由到 `./docs/handycontrol/` 文档，不要只凭记忆写 XAML 或资源字典；`./docs/handycontrol/` 目录很大，禁止全量扫描
- 涉及 `HandyControl` 主题色与设计器智能提示时，先读 `./references/12-handycontrol-theme-standard.md`；默认保留官方配色，只在用户明确要求品牌色时修改 `ThemeOverrides.xaml`
- 发布单文件时默认启用瘦身配置（压缩、移除调试符号）
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

- 涉及 `dotnet --info`、`dotnet new`、`dotnet add package`、`dotnet restore`、`dotnet build`、`dotnet test`、`dotnet publish` 时，默认由 AI 发起
- 如果需要安装 SDK、桌面运行时、NuGet 包或写入 `dist` 目录，AI 负责发起，用户只需点“允许”
- 如果电脑还没装 `dotnet`，先执行 `./scripts/ensure_dotnet_sdk.ps1`，优先自动安装对应 SDK，再进入项目初始化
- 除非用户明确要求学习命令行，否则不要把“请你在终端执行以下命令”当成默认答案
- 用户问“怎么运行”时，优先直接帮用户运行一次，再补充说明
- 用户问“怎么打包成 exe”时，默认理解为“请 AI 帮我打包并验证产物”

## 代码与结构原则

- 新项目优先使用 `src` + `tests` 结构
- 业务逻辑、界面逻辑、配置读取、文件读写分层
- 默认开启 `Nullable`、`ImplicitUsings`，统一使用 SDK 风格项目
- 默认补齐日志、错误提示、`appsettings.json`、`.gitignore`
- 日志默认按日期分文件、单文件 `5MB`、保留最近 `30` 天
- 单文件过大时主动拆分，不把“先跑起来再说”变成长期结构
- 需要桌面交付时，优先提供清晰入口、状态提示、错误提示和输出位置说明

## 对后续 AI 的最低执行清单

开始写代码前，至少完成这些动作：

1. 问清楚做的是脚本、桌面工具还是 `exe` 交付
2. 问清楚目标人群使用什么 Windows 版本（`Win7` / `Win10` / `Win11`），并先判断 `net6.0` 是否够用
3. 问清楚是新建项目还是基于现有代码迭代
4. 问清楚给谁用，是否是零基础用户，是否需要窗口或双击运行
5. 收集样例文件、网站链接、截图、列名、输入输出样本
6. 先规划项目结构，再创建或修改代码
7. 需要运行命令时，由 AI 自己发起，不要转手给用户
8. 生成后至少跑一次程序、自测一次关键流程
9. 如果用户要求 `exe`，必须实际发布并确认产物存在；**发布单文件时默认启用瘦身配置（压缩、移除调试符号）**
10. 交付时要说明产物位置、使用方法、配置文件、授权说明和注意事项
## 分发授权说明

- 本分发包已写入多重授权追踪信息，禁止绕过原作者进行二次分发
- LicenseId：lqiang1857_廖强_专用
- WatermarkText：本作品归公众号 Excel催化剂 所有，仅限授权用户自用，禁止任何形式的擅自传播。对于恶意传播、营利性传播行为，我方将保留追究法律责任的权利。
- 如朋友需要，请直接转介绍其向原作者获取授权版本