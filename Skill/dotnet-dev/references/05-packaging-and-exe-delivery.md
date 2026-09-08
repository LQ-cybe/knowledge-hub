<!-- dist_id: 8f45c7d4-e334aeb5-e122f6ec-ba729831-34d32268-351a236c-1ca2537c -->
# 打包与 exe 交付

当用户要求“发给别人用”“双击运行”“做成软件”“生成 exe”时，后续 AI 默认进入交付模式，而不是只给源代码。

## 核心原则

- 发布动作由 AI 发起
- 默认使用 `dotnet publish`
- 发布后必须检查产物实际存在
- 如条件允许，至少做一次启动级冒烟验证
- 交付时说明怎么运行、配置文件放哪里、数据输出在哪里
- 需求调研阶段就要问清楚交付形式，不要等发布时再临时猜
- 不要混用老 `.NET Framework` 的术语和当前 `.NET 6 / .NET 8 / .NET 10` 的发布方式
- GUI 项目如果用了自定义图标，图标资源必须先落到项目内部固定目录，再参与构建和发布
- 先决定 `TargetFramework`，再决定发布形态；简单项目默认优先从 `net6.0` 起步
- 只有在框架依赖发布时，才需要重点讨论 `RollForward`

## 常见交付形式

- `源码交付`
- `框架依赖发布`
- `自包含单文件发布`
- `自包含目录发布`

## 这 4 种方式怎么选

### 1. 源码交付

适合：

- 接收方本来就是开发者
- 对方要自己继续改代码、重新编译、接 Git

特点：

- 交付的是 `.sln/.slnx`、`src/`、`tests/`、配置文件和说明文档
- 不保证普通用户拿到后能直接双击运行
- 普通用户场景下不要默认只交源码

### 2. 框架依赖发布

适合：

- 目标电脑已经安装对应的 `.NET Desktop Runtime` 或 `.NET Runtime`
- 希望发布体积更小
- 内部分发环境可控，例如公司统一装过运行时
- 或者希望用 `RollForward` 提高对更高已安装运行时的覆盖面

特点：

- 发布体积通常比自包含更小
- 启动时依赖目标机器已有运行时
- 如果接收者电脑没装运行时，程序会打不开或提示缺少 runtime
- 可以根据实际情况决定是否启用 `RollForward`

一句话理解：

- `程序本体不带运行时，依赖目标电脑已经装好对应 .NET 运行时`

补充说明：

- 如果项目是 `net6.0` 或 `net8.0`，且目标环境分散，框架依赖发布时可以评估 `RollForward=Major`
- 这能提升“单包向上兼容”能力，但不会让项目获得更高版本 API
- 如果目标环境可控，仍优先 `LatestPatch`，行为更稳定

### 3. 自包含单文件发布

适合：

- 面向普通用户分发
- 用户希望“拿到一个 exe 就尽量能直接双击运行”
- 不希望让用户自己安装 `.NET`

特点：

- 会把运行时一并打进去
- 通常只看到一个主 `exe`，分发体验最直观
- 体积通常比框架依赖发布更大
- 某些场景下杀软、首次启动解包、单文件兼容性需要额外验证
- 一般不需要依赖 `RollForward`

一句话理解：

- `尽量像传统单文件软件一样分发，但体积更大`

### 4. 自包含目录发布

适合：

- 面向普通用户分发
- 不希望依赖用户电脑预装 `.NET`
- 但又不强求必须只有一个 exe
- 希望保留配置文件、依赖 DLL、资源文件更直观可见

特点：

- 运行时一并打包
- 交付的是一个完整目录，不只是单个 exe
- 故障排查、替换配置、查看依赖文件通常更直观
- 对复杂 GUI、资源文件较多、后续还要让 AI 二次排查的问题，往往更稳
- 一般不需要依赖 `RollForward`

一句话理解：

- `自带运行时，但以完整目录交付，稳定性和可排查性通常比单文件更好`

## 需求调研时必须问清楚

- 接收者是不是开发者，还是普通办公用户
- 对方电脑能不能安装运行时
- 是否要求“拿到后尽量双击就能用”
- 是否要通过微信、QQ、邮箱等渠道发给别人
- 是否在意包体大小
- 是否希望配置文件、日志目录、依赖文件可见

## 默认推荐口径

- 默认先判断项目按 `net6.0` 是否够用；不够再升 `net8.0`
- 目标人群含部分 `Win10` 时，不要把 `.NET 10` 当默认发布版本，很多场景下 `.NET 8` 更平衡
- 只有开发者接手继续维护时，优先 `源码交付`
- 公司内网、运行时可控时，可选 `框架依赖发布`
- 面向普通用户且希望最省心时，优先 `自包含单文件发布`
- 面向普通用户但更看重稳定性、可排查性、资源文件可见时，优先 `自包含目录发布`

版本和发布组合建议：

- 简单项目：优先 `net6.0`
- `.NET 6` 不够：升级到 `net8.0`
- 明确需要新 API 且目标环境可控：再考虑 `net10.0`
- 想要单包覆盖更多已安装运行时：优先评估“低版本 `TargetFramework` + 框架依赖发布 + `RollForward=Major`”

## 推荐命令

下面示例都以 `win-x64` 为例，实际可按需换成 `win-x86`、`win-arm64`。

### 框架依赖发布

```powershell
dotnet publish .\src\App\App.csproj -c Release -r win-x64 --self-contained false -o .\dist\App-framework
```

说明：

- 目标电脑必须已有对应运行时
- 适合内部分发，不适合默认发给零基础用户

### 自包含单文件发布（推荐：发布瘦身版）

```powershell
dotnet publish .\src\App\App.csproj -c Release -r win-x64 --self-contained true `
    /p:PublishSingleFile=true `
    /p:IncludeNativeLibrariesForSelfExtract=true `
    /p:EnableCompressionInSingleFile=true `
    /p:DebugType=none `
    /p:DebugSymbols=false `
    -o .\dist\App-single-slim
```

**瘦身参数详解：**

1. **DebugType=none**
   - **作用**：不生成调试信息。跳过生成 `.pdb` 文件（包含行号、变量名等）。
   - **效果**：减少约 2-40MB（视项目大小而定）。Release 版本不需要调试符号。
2. **DebugSymbols=false**
   - **作用**：配合 `DebugType=none` 确保彻底不输出 PDB 符号文件。
3. **EnableCompressionInSingleFile=true**
   - **作用**：对单文件内的 DLL 进行压缩。
   - **效果**：体积减少约 30-50%。
   - **代价**：运行时解压，首次启动会稍慢。

### 自包含单文件发布（完整版，含调试符号）

```powershell
dotnet publish .\src\App\App.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true -o .\dist\App-single-full
```

说明：
- 适合需要收集用户端崩溃堆栈（含行号）的情况。
- 体积通常在 150MB+。

### 自包含目录发布

```powershell
dotnet publish .\src\App\App.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=false -o .\dist\App-folder
```

说明：

- 会生成完整目录
- 更适合后续排查、替换配置、保留依赖文件

### 只交源码

```powershell
dotnet build .\App.slnx -c Release
```

说明：

- 这里只是确保源码可编译，不等于已经生成适合普通用户分发的交付物

## AI 在发布前不要想当然

- 不要默认“生成 exe”就一定等于“自包含单文件”
- 不要默认用户知道“框架依赖”和“自包含”的区别
- 不要套用老 `.NET Framework` 时代“装个运行库就都一样”的思路
- 不要只给一种 publish 命令，让后续 AI 误以为这就是唯一标准答案

## 授权分发建议

- 发给第三方使用时，优先为每个接收者设置独立 `LicenseId`
- 如有需要，可同时写入 `WatermarkText`
- `../scripts/build_windows_exe.ps1` 在提供 `LicenseId` 或 `WatermarkText` 时，会自动写入 `LICENSE_NOTICE.txt` 与 `distribution-license.json`

## 交付清单与用户移交

交付前收口，确保用户拿到的成品可以理解、可以运行。

### 最终交付物清单

1. 源代码目录
2. `*.sln`、`*.csproj`
3. `appsettings.json`
4. `README` 或使用说明
5. `dist` 目录或 `exe`
6. 样例输入文件和样例输出说明
7. 如果有日志目录、配置目录，也要说明位置
8. 如果有授权约束，也要补 `LICENSE_NOTICE.txt` 或对应授权说明
9. 如果有自定义图标，要说明项目内图标目录与发布后验证结果

### 普通用户移交提醒

- 不要把"如何运行终端命令"写成主要说明
- 不要把关键步骤藏在代码注释里
- 不要默认用户知道 SDK、解决方案、项目文件这些概念
- 说明文档优先写"点哪里、选什么、结果在哪"
