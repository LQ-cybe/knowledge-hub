<!-- data_uid: 373f11fe-5b4e789f-595820c6-02084e1b-8ca9f442-8d60f546-a4d88556 -->
# .NET 开发高频常见问题 (FAQ)

这个文档汇总了 .NET 开发中的环境、编译、运行时及零基础用户常见问题。

## NuGet 与环境问题

### 1. NU1301: 本地 NuGet 源不存在
- **现象**：编译或还原包时报错，提示某个本地路径（如 Visual Studio Offline Packages）找不到。
- **原因**：本机 NuGet 配置文件（`NuGet.config`）中残留了已失效的本地离线源路径。
- **解决**：在终端执行以下命令禁用该源：
  ```powershell
  dotnet nuget disable source "Microsoft Visual Studio Offline Packages"
  ```

### 2. NU1047: 资产文件没有目标
- **现象**：提示 `Assets file '...\project.assets.json' doesn't have a target for 'net10.0-windows/win-x64'`。
- **原因**：项目配置了特定的 RuntimeIdentifier 但还原时未识别。
- **解决**：在 `.csproj` 中确保配置了正确的运行时标识符：
  ```xml
  <PropertyGroup>
      <RuntimeIdentifiers>win-x64</RuntimeIdentifiers>
  </PropertyGroup>
  ```

### 3. dotnet restore 超时或失败（公司网络/代理）
- **现象**：`dotnet restore` 报超时、连接失败。
- **原因**：公司网络有代理或防火墙限制了 NuGet 连接。
- **解决**：检查 `NuGet.config` 中的源地址是否可访问，或配置代理：
  ```xml
  <config>
    <add key="http_proxy" value="http://proxy.company.com:8080" />
  </config>
  ```

---

## 系统调用与互操作

### 1. Shell32 COM 引用失败 (.NET 8/10)
- **现象**：尝试引用 `Shell32.dll` 或 COM 组件报错。
- **原因**：现代 .NET 对旧版 COM 组件支持有限。
- **解决**：使用 `ProcessStartInfo` 调用系统原生命令：
  ```csharp
  var psi = new ProcessStartInfo
  {
      FileName = "cmd.exe",
      Arguments = $"/c del /q \"{filePath}\"",
      WindowStyle = ProcessWindowStyle.Hidden,
      CreateNoWindow = true
  };
  Process.Start(psi)?.WaitForExit();
  ```

---

## 发布与部署

### 0. 部分 Win10 电脑打不开 .NET 10 程序
- **现象**：程序在部分 `Win10` 机器上无法启动，或安装 `.NET 10 Runtime` 后仍不稳定。
- **原因**：`.NET 10` 对目标环境要求更高，而部分 `Win10` 场景下落地并不理想。
- **解决**：
  - 如果项目没有明确依赖 `.NET 10` 新能力，优先回退到 `net8.0`
  - 如果只是想提升兼容面，不要把“升级到 `.NET 10`”当成唯一方案，先评估 `net6.0/net8.0 + RollForward`
  - 发布前先确认目标用户的 Windows 版本和运行时分布

### 1. 单文件发布后文件路径获取异常
- **现象**：`AppDomain.CurrentDomain.BaseDirectory` 拿到的路径在临时目录。
- **原因**：单文件自解压模式下，程序运行在临时目录。
- **解决**：使用 `Process.GetCurrentProcess().MainModule?.FileName` 获取主程序绝对路径。

### 2. 自包含发布后体积过大
- **现象**：生成的 exe 超过 150MB。
- **原因**：未启用瘦身配置。
- **解决**：使用 `build_windows_exe.ps1`（默认启用压缩+去调试符号），或手动添加 `/p:EnableCompressionInSingleFile=true /p:DebugType=none /p:DebugSymbols=false`。

### 3. 发布后的 exe 被杀软误报
- **现象**：Windows Defender 或第三方杀软拦截自包含单文件 exe。
- **原因**：自包含单文件的自解压行为可能触发杀软启发式扫描。
- **解决**：
  - 优先使用自包含目录发布（`/p:PublishSingleFile=false`）
  - 对 exe 做数字签名
  - 告知用户这是正常现象，添加信任即可

---

## WPF 与 HandyControl

### 1. HandyControl 主题不生效
- **现象**：控件显示为默认样式，没有 HandyControl 外观。
- **原因**：`App.xaml` 中 ResourceDictionary 合并顺序或写法错误。
- **解决**：确保使用 `<hc:Theme Name="HandyTheme" />`，不要用 `ThemeResources`；检查 `<hc:Theme>` 必须在 `StartupUri` 之前定义。

### 2. WPF 窗口闪退
- **现象**：双击 exe 后窗口一闪就消失。
- **原因**：程序启动了但遇到未捕获异常后崩溃。
- **解决**：
  - 在 `App.xaml.cs` 中注册全局异常处理
  - 检查日志目录是否有错误日志
  - 用命令行启动 exe 查看错误输出

### 3. "无法加载 DLL 'hostfxr.dll'" 或 "You must install .NET"
- **现象**：用户双击 exe 后弹出缺少运行时的错误。
- **原因**：目标电脑没有安装对应版本的 .NET 运行时，且发布时未使用自包含模式。
- **解决**：重新发布，确保使用 `--self-contained true`（自包含模式）。

### 4. 明明机器装了更高版本运行时，程序还是打不开
- **现象**：项目目标是 `net6.0` 或 `net8.0`，机器只装了更高版本运行时，但框架依赖发布仍启动失败。
- **原因**：项目没有放宽 `RollForward`，默认只接受目标主版本。
- **解决**：
  - 确认是否真的需要框架依赖发布
  - 如果目标环境分散，可评估在项目里增加：
  ```xml
  <PropertyGroup>
      <RollForward>Major</RollForward>
  </PropertyGroup>
  ```
  - 注意这只影响运行时装载，不会让项目获得更高版本 API

---

## 零基础用户常见问题

### 1. "双击 exe 闪一下就没了"
- **原因**：程序执行完退出，或遇到错误崩溃。
- **解决**：
  - 控制台程序：在末尾加 `Console.ReadKey()` 让窗口不自动关闭
  - 检查日志目录：通常在 exe 同目录的 `logs/` 下
  - 用命令行运行 exe 查看输出

### 2. "软件打不开"
- **排查顺序**：
  1. 确认用户电脑的 Windows 版本（Win7 / Win10 / Win11）
  2. 确认是否缺少 .NET 运行时（如为框架依赖发布）
  3. 检查杀软是否拦截
  4. 查看 `logs/` 目录下是否有报错日志

### 3. "不知道怎么描述我的需求"
- **引导策略**：
  1. 让用户截图或录屏展示当前手工操作的流程
  2. 问"最费时间的是哪一步"
  3. 问"做完后你希望看到什么结果"
  4. 不急着问技术名词，先理解业务流程
