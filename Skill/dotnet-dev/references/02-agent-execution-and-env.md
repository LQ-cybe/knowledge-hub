<!-- anchor_ref: 15cc07fe-79bd6e9f-7bab36c6-20fb581b-ae5ae242-af93e346-862b9356 -->
# AI 代执行与环境约束

这个文档规定：涉及 .NET 项目的命令执行、环境搭建、依赖安装、运行和调试时，默认由 AI 发起，不把终端操作转给普通用户。

## 核心原则

- 优先由 AI 执行命令，用户只负责授权
- 统一使用 `dotnet` 官方 CLI
- 先询问用户目标人群使用的 Windows 版本
- 默认先评估 `net6.0` 是否够用；简单模板和普通工具优先从 `.NET 6` 起步
- `Win7` 需求默认选 `.NET 6`
- 目标人群含 `Win10` 电脑时，如 `.NET 6` 不够，优先推荐 `.NET 8`（部分 Win10 不支持 .NET 10）
- 只有用户明确需要 `.NET 10` 新能力，且确认目标电脑环境比较可控时，才使用 `.NET 10`
- 如果是框架依赖发布，再单独判断是否要启用 `RollForward`；不要把它当成高版本 API 开关
- 命令执行后要告诉用户结果，而不是只贴命令
- 如果电脑没装 `dotnet`，先由 AI 完成 SDK 自举安装，再继续项目初始化
- 如果需要创建或修改 `.ps1`、`.ps1.tmpl`、`.json`、`.xml`、`.txt`，尤其包含中文内容，优先回看 `references/08-powershell-5.1-file-io-and-encoding.md`

## AI 必须代执行的高频动作

- 检查 `dotnet --info`
- 检查 `Get-Command dotnet`
- 安装或补齐 `.NET SDK`
- 检查 PowerShell `5.1` 脚本与文本文件编码
- 初始化解决方案与项目
- 添加 NuGet 包
- 运行程序
- 跑测试
- 发布 `exe`

## 从零开始时的环境自举

当前 skill 不应假设用户电脑已经装好 `dotnet CLI`。

普通用户场景下，推荐固定按下面顺序执行：

1. AI 先与用户沟通目标人群的 Windows 版本（`Win7` / `Win10` / `Win11`）
2. 先判断当前项目按 `net6.0` 是否够用；简单模板默认优先 `.NET 6 SDK`
3. 需要兼容 `Win7` 时，统一准备 `.NET 6 SDK`
4. `net6.0` 不够，且目标人群含 `Win10` 电脑时，优先推荐 `.NET 8 SDK` 并告知原因（部分 Win10 不支持 .NET 10）
5. 用户明确要求 `.NET 10` 新能力，或确认目标电脑均为 `Win11+` 且环境可控时，才使用 `.NET 10 SDK`
6. 如果后续选择框架依赖发布，再根据目标环境决定是否启用 `RollForward`
7. AI 执行 `../scripts/ensure_dotnet_sdk.ps1`
8. 安装完成后，再执行 `dotnet --info`
9. 确认 SDK 正常后，再执行 `../scripts/bootstrap_project.ps1`

## SDK 安装优先级

### 方案一：优先使用 `winget`

不要按"电脑新旧"猜，按系统版本和 `winget` 实测结果判断。

- 优点：更接近"系统级正常安装"
- 优点：后续终端、IDE、资源管理器环境通常都更稳定
- 一般适合：大多数 `Windows 11`，以及较新的 `Windows 10` 且已安装 `App Installer`
- 一般不适合：`Windows 7 / 8 / 8.1`、较老的 `Windows 10`、被公司策略禁用 Store / `winget` 的环境
- 最终判断方式：先执行 `winget --version`，能输出版本号再走 `winget` 安装

默认安装包规则：

- `.NET 6` => `Microsoft.DotNet.SDK.6`
- `.NET 8` => `Microsoft.DotNet.SDK.8`
- `.NET 10` => `Microsoft.DotNet.SDK.10`

### 方案二：回退到官方 `dotnet-install.ps1`

适合没有 `winget`、权限受限、或不想要求系统级安装的情况。

- 优点：可以安装到当前用户目录
- 优点：更适合 AI 在受限环境里快速自举
- 注意：安装后要把目录加入当前会话 `PATH`
- 注意：最好同时写入用户 `PATH`，方便后续新开的终端也能识别

默认用户级目录可用：

- `%LOCALAPPDATA%\Microsoft\dotnet`

## 推荐环境步骤

### A. 电脑还没装 `dotnet`

1. 检查 `Get-Command dotnet`
2. 如果不存在，先检查 `winget --version`
3. 如果 `winget` 可用，优先用 `winget` 安装对应 SDK
4. 如果 `winget` 不可用，或安装失败，再执行 `../scripts/ensure_dotnet_sdk.ps1`
5. 再检查 `dotnet --info`
6. 继续执行 `../scripts/bootstrap_project.ps1`
7. 后续再做 `restore/build/test/publish`

常见命令示例：

```powershell
Get-Command dotnet
winget --version
winget install --id Microsoft.DotNet.SDK.6 --exact --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.DotNet.SDK.8 --exact --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.DotNet.SDK.10 --exact --accept-package-agreements --accept-source-agreements
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure_dotnet_sdk.ps1 -TargetFramework net6.0
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure_dotnet_sdk.ps1 -TargetFramework net8.0
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure_dotnet_sdk.ps1 -TargetFramework net10.0
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure_dotnet_sdk.ps1 -NeedWin7Support
dotnet --info
```

说明：

- `winget` 可用时，优先走 `winget`
- `../scripts/ensure_dotnet_sdk.ps1` 本身也会优先尝试 `winget`，失败后再回退到官方 `dotnet-install.ps1`
- 所以后续 AI 可以直接调用 `../scripts/ensure_dotnet_sdk.ps1`，但文档里仍要明确"优先 `winget`"这层策略

### B. 电脑已经装了 `dotnet`

1. 检查 `dotnet --info`
2. 先评估当前项目是否可以按 `.NET 6` 开发和发布；简单模板默认优先 `.NET 6`
3. 如果最终用户必须兼容 `Win7`，开发和发布统一走 `.NET 6`
4. 如果 `.NET 6` 不够，且目标人群含 `Win10`，优先走 `.NET 8`；仅用户明确要求 `.NET 10` 时才用 `.NET 10`
5. 如果计划做框架依赖发布，再评估是否需要 `RollForward=Major` 一类的向上兼容策略
6. 继续执行 `../scripts/bootstrap_project.ps1`
7. 在目标目录生成解决方案、项目、配置和测试骨架
8. 用 `dotnet add package` 安装业务依赖
9. 用 `dotnet build`、`dotnet test`、`dotnet publish` 完成验证和交付

## 普通用户场景下的约束

- 不要要求用户自己执行 `dotnet run`
- 不要要求用户自己执行 `dotnet add package`
- 不要要求用户自己安装 `.NET SDK`
- 不要要求用户自己分析终端报错
- 如果程序适合 GUI，就不要默认做成纯命令行

## 对后续 AI 的要求

- 如果发现当前机器没有 `dotnet`，不要直接结束在"请先安装 SDK"
- 要优先尝试自己执行 `../scripts/ensure_dotnet_sdk.ps1`
- 需要做版本决策时，优先看 `references/13-targetframework-and-rollforward-strategy.md`
- 如果需要联网下载、安装或写入用户环境变量，向用户申请授权即可
- 如果系统级安装失败，优先尝试用户级安装，而不是立刻把问题抛给用户
- 只有在网络、权限、代理或系统兼容性明确阻断时，才要求用户额外配合
- 如果 PowerShell 脚本执行结果异常，先排查文件编码与 BOM，不要直接把问题归因到业务代码
- 如果输入文件来自用户或第三方系统，不要默认直接 `Get-Content -Encoding UTF8`
- 如果输出文件是给第三方程序消费，不要默认统一写成 `UTF-8 with BOM`

## 推荐项目骨架

```text
project-name/
├── project-name.sln
├── Directory.Build.props
├── appsettings.json
├── .gitignore
├── README.md
├── src/
│   └── AppName/
│       ├── AppName.csproj
│       ├── Program.cs
│       ├── Services/
│       ├── Ui/
│       └── Logging/
├── tests/
│   └── AppName.Tests/
└── dist/
```
