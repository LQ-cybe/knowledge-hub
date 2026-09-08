<!-- flow_ref: e36a52b1-8f1b3bd0-8d0d6389-d65d0d54-58fcb70d-5935b609-708dc619 -->
<!-- content_sig: 567ae41d-3a0b8d7c-381dd525-634dbbf8-edec01a1-ec2500a5-c59d70b5 -->
# 项目结构与代码规范

这个文档用于约束 .NET 项目的结构、代码风格、可维护性和安全性。

## 技术选型速查

| 需求类型　　　　 | 推荐方案　　　　　　　　　　　　　　　　　　　　 | 说明　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| ------------------| --------------------------------------------------| --------------------------------------------------------------------------|
| 批量文件处理　　 | `Console` + 标准库　　　　　　　　　　　　　　　 | 适合一次性和自动化任务　　　　　　　　　　　　　　　　　　　　　　　　　 |
| 桌面界面　　　　 | `WPF` + `CommunityToolkit.Mvvm` + `HandyControl` | 兼顾美观、高分屏适配、组件丰富度与 MVVM 分层，适合面向普通用户的长期交付 |
| Excel / 表格处理 | `ClosedXML`　　　　　　　　　　　　　　　　　　　| 易读易写，适合批处理　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| 静态网页抓取　　 | `HttpClient` + `HtmlAgilityPack`　　　　　　　　 | 大多数页面足够稳定　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| 配置读取　　　　 | `appsettings.json`　　　　　　　　　　　　　　　 | 比让普通用户碰环境变量更直观　　　　　　　　　　　　　　　　　　　　　　 |
| 日志　　　　　　 | `Serilog` 或自定义文件日志　　　　　　　　　　　 | GUI 交付更容易落盘　　　　　　　　　　　　　　　　　　　　　　　　　　　 |

## 桌面端默认栈

- Windows 桌面项目默认优先 `WPF`，不要再把 `WinForms` 当成首选
- 主要原因不只是美观，还包括更稳的高分屏适配、布局伸缩能力和样式扩展能力
- 默认采用 `MVVM` 架构，至少拆成 `Views`、`ViewModels`、`Services`
- 默认优先 `CommunityToolkit.Mvvm`，因为文档完整、心智负担低、社区稳定
- 默认 UI 组件库优先 `HandyControl`，因为现成控件多、中文资料相对更容易找、示例丰富
- 如果后续用户对 Fluent 风格或更现代的 Windows 视觉要求很强，再单独评估 `Wpf.Ui` 等替代方案

## 界面库推荐顺序

1. 默认：`HandyControl`
2. MVVM 配套：`CommunityToolkit.Mvvm`
3. 可选替代：`Wpf.Ui`

## 选择理由

- `WPF`：更适合复杂布局、主题样式、高分屏和动画效果
- `CommunityToolkit.Mvvm`：微软系生态、示例多、命令和属性通知写法简洁
- `HandyControl`：控件数量足、主题能力强、搜索到的资料和示例相对集中

## HandyControl 本地文档路由

- `HandyControl` 本地文档位于 `../docs/handycontrol/`，优先通过 `./handycontrol-routing.md` 按场景路由到对应文档
- 对 AI 来说，本地 Markdown 文档通常比只有 `dll`、`xml` 注释或零散截图更容易学习和引用
- 以后凡是项目用了 `HandyControl`，或出现"不会写控件""主题资源不生效""XAML 命名空间报错""样式找不到"这类问题，优先看 `./handycontrol-routing.md` 路由入口
- `../docs/handycontrol/` 目录很大（200+ 文件），默认不要全量扫描，必须先按路由文档定位子目录再精读
- 如果要避免官方版 / 非官方版文档混用、`ThemeResources` 用错、把原生控件误写成 `hc:` 控件，再看 `./handycontrol-routing.md` 中的避坑经验
- 快速接入优先看 `../docs/handycontrol/quick_start/index.md`
- 主题、颜色、换肤、资源字典优先看 `../docs/handycontrol/theme/index.md`
- 普通控件样式优先看 `../docs/handycontrol/native_controls/`
- 扩展控件优先看 `../docs/handycontrol/extend_controls/`
- 仍然找不到时，再结合官方 GitHub、NuGet 页面和示例工程交叉确认

## 结构原则

- 默认使用 `src` + `tests` 结构
- 入口层、业务层、基础设施层分开
- WPF 项目默认使用 `MVVM`
- `View`、`ViewModel`、`Model`、`Service` 分层明确
- GUI 代码不要直接夹杂业务逻辑
- 读取配置、日志初始化、文件路径处理要独立模块
- 测试优先覆盖核心逻辑，不围着界面细枝末节写无效测试

## 推荐结构

### 1. 通用结构
```text
src/AppName/
├── App.xaml
├── App.xaml.cs
├── Views/
├── ViewModels/
├── Models/
├── Services/
├── Converters/
├── Resources/
└── Themes/
```

### 2. WPF 多项目分层结构（推荐）
对于复杂桌面应用，建议将界面与核心逻辑拆分：
```text
Project/
├── Project.Core/           # 核心业务逻辑（类库）
│   ├── Models/             # 数据模型
│   └── Services/           # 服务层
├── Project.App/            # WPF UI 项目
│   ├── App.xaml            # 全局资源（HandyControl 主题）
│   ├── MainWindow.xaml     # 主窗口
│   └── Views/              # 其他窗口
└── publish/                # 发布输出目录
```

## 代码风格

- 命名空间和类名使用大驼峰
- 局部变量使用小驼峰
- 方法尽量短小，职责单一
- 默认开启 `Nullable` 和 `ImplicitUsings`
- 超过 `400` 到 `500` 行的文件要主动拆分
- 复杂流程前可以加一行简洁中文注释，但不要写流水账注释

## 错误处理

- 不要静默吞异常
- 外部请求必须设置超时
- 文件读写要给出用户能看懂的报错
- WPF 场景下，报错要尽量转换成窗口提示、状态栏提示或明确的日志位置
- 可恢复错误要继续处理并记录原因，不可恢复错误要尽快失败并说明

## PowerShell 5.1 文件读写规则

- 只要创建或修改 `.ps1` / `.ps1.tmpl`，默认按 `UTF-8 with BOM + CRLF` 保存
- 只要读取 `.json`、`.xml`、`.txt`，先区分输入文件是内部可控还是外部未知来源
- 只对内部可控文件默认显式写编码，不要对来源不明的文件直接假定 `UTF-8`
- 只要写回文本文件，优先用 `[System.IO.File]::WriteAllText(..., $encoding)` 或 `StreamWriter`
- `.ps1` / `.ps1.tmpl` 默认优先 `UTF-8 with BOM + CRLF`，但对外交付的 `JSON / TXT / XML` 是否带 BOM 要看消费方规范
- 如果 PowerShell `5.1` 报语法错误但代码表面正常，先查文件编码，再查逻辑
- 详细规则统一看 `references/08-powershell-5.1-file-io-and-encoding.md`

## 安全规范

- 禁止硬编码密码、密钥、Cookie、令牌
- 真实配置放 `appsettings.json` 或用户配置文件
- 日志中不要打印完整敏感值

## 日志规范

- 每个关键环节都要有日志：启动、配置加载、文件选择、读取、处理、写出、网络请求、异常退出
- 每次异常都尽量留下堆栈，而不是只留一句失败提示
- 用户看到的是友好提示，开发者拿到的是可定位的日志
- GUI 工具默认提供"打开日志目录"按钮
- 日志目录：项目运行 `项目根目录\logs\`，打包后 `exe 同目录\logs\`
- 默认按日期分文件，单文件最大 `5MB`，保留最近 `30` 天
