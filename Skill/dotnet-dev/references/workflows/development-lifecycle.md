<!-- pkg_hash: 154de4e0-793c8d81-7b2ad5d8-207abb05-aedb015c-af120058-86aa7048 -->
# .NET 程序开发全流程（强制执行）

这个文档规定 .NET 程序开发的阶段推进方式。面向零编程经验用户，AI 按阶段推进：需求澄清、环境准备、编码、验证、发布与交付。

## 铁律

1. 不可跳过阶段
2. 面向零基础用户时，默认不要让用户自己操作终端
3. 涉及运行、测试、发布时，优先由 AI 发起命令
4. 当前阶段未完成，不进入下一阶段
5. 用户要求 `exe` 时，必须真的发布，而不是只讲方法

## 阶段一：需求澄清

- 先看 `../01-need-discovery.md`
- 先问是否需要兼容 `Win7`，以及目标人群使用 `Win10` 还是 `Win11`
- 版本取舍不明确时，补看 `../13-targetframework-and-rollforward-strategy.md`
- 如需求很像高频场景，补看 `../06-common-scenarios.md`
- 面向零基础用户表达时，参考 `../01-need-discovery.md` 中的沟通原则
- 问清楚输入、输出、使用对象、触发方式、是否需要窗口、是否需要 `exe`
- 用户确认需求后再继续

## 阶段二：环境与项目初始化

- 先看 `../02-agent-execution-and-env.md`
- 默认先判断 `net6.0` 是否够用；不够再升 `net8.0`，只有明确需要时才考虑 `net10.0`
- 根据 `Win7` / `Win10` / `Win11` 需求决定 `TargetFramework`：Win7 → .NET 6，Win10 → 优先 .NET 8，Win11+ 且环境可控 → 可 .NET 10
- 如果选择框架依赖发布，再单独判断是否需要 `RollForward`
- 由 AI 检查 `dotnet`、初始化项目、安装 NuGet 依赖、创建基础目录
- 如果电脑没装 `dotnet`，先执行 `../../scripts/ensure_dotnet_sdk.ps1`，优先自动完成 SDK 安装，再继续后续步骤
- 优先复用 `../../scripts/ensure_dotnet_sdk.ps1`、`../../scripts/bootstrap_project.ps1`、`../../scripts/instantiate_blueprint.ps1`、项目模板和蓝图目录
- 如果阶段二或阶段三涉及 `.ps1` 模板、PowerShell 命令包装或中文乱码，优先查看 `../08-powershell-5.1-file-io-and-encoding.md`
- 如果只想预览蓝图落地结果，优先使用 `-DryRun`

## 阶段三：编码与结构实现

- 先看 `../03-project-structure-and-code-standards.md`
- 按分层结构组织代码
- 补齐配置、错误处理和日志
- GUI 默认优先 `WPF`，并按 `MVVM` 架构组织代码；界面库默认优先 `HandyControl`
- 如果要使用 `HandyControl`，或出现控件不会用、主题资源不生效、XAML 命名空间报错、样式找不到，优先查看 `../07-handycontrol-routing.md` 按场景路由到对应文档
- 如果担心混用了官方版 / 非官方版示例，或不确定该用 `hc:Theme` 还是 pack URI、该用原生控件还是 `hc:` 控件，补看 `../07-handycontrol-routing.md` 中的避坑经验
- 需要快速接入时先看 `../../docs/handycontrol/quick_start/index.md`
- 需要主题、换肤、资源字典时看 `../../docs/handycontrol/theme/index.md`
- 需要控件具体写法时，优先进入 `../../docs/handycontrol/native_controls/` 或 `../../docs/handycontrol/extend_controls/`

## 阶段四：质量检查与运行验证

- 先看 `../04-quality-check-and-manual-verification.md`
- 运行 `dotnet format`、`dotnet build`、`dotnet test`
- 实际启动程序，验证关键流程
- 如果涉及性能或并发问题，补看 `../09-performance-and-concurrency.md`
- 如果遇到常见 NuGet / COM / 单文件路径问题，补看 `../10-common-faq.md`

## 阶段五：打包与交付

- 用户需要发给别人用、双击运行或明确提到 `exe` 时，进入交付模式
- 先看 `../05-packaging-and-exe-delivery.md`
- 使用 `../../scripts/build_windows_exe.ps1` 执行实际发布
- 对外分发时，补充 `LicenseId`、`WatermarkText` 与授权追踪信息
- 完成发布、产物检查、说明文档整理
- 最后对照 `../05-packaging-and-exe-delivery.md` 末尾的交付清单
