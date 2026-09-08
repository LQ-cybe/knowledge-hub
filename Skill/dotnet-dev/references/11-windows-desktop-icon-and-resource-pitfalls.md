<!-- blob_id: 8cfefd7e-e08f941f-e299cc46-b9c9a29b-376818c2-36a119c6-1f1969d6 -->
<!-- frag_id: 7313c38d-1f62aaec-1d74f2b5-46249c68-c8852631-c94c2735-e0f45725 -->
# Windows 桌面程序图标与资源坑点

适用范围：

- `WPF`
- `WinForms`
- 其他 .NET Windows 桌面程序

适用场景：

- 用户提供 `.ico`，要求接入窗体左上角、任务栏和发布后的 `exe`
- 图标接入后只在资源管理器里生效，运行时窗口还是默认图标
- 加完 `ico` 后程序双击没反应，或发布版启动即退出

## 核心结论

- 只配置 `.csproj` 里的 `<ApplicationIcon>`，通常只能保证 `exe` 文件图标正确，**不能默认等价于运行时窗体图标**
- `WPF` 想稳定显示窗体图标，优先使用“资源嵌入 + 资源路径引用”
- `WinForms` 的窗体图标与 `exe` 图标是两条线：`Form.Icon` 和 `ApplicationIcon` 要分别处理
- 任务栏图标通常跟随运行时窗口图标，而不是单纯跟随 `exe` 文件图标
- 发布目录验证必须用 `Release` 产物直接启动，不能只在开发目录里看效果
- 图标资产优先落在**项目内部固定目录**，不要继续引用项目目录外的 `.png/.ico` 绝对路径

## 项目内图标目录约定

推荐统一使用：

- `Assets\AppIcon\app.ico`：发布后的 `exe` 图标，以及 `WPF` 运行时窗体图标
- `Assets\AppIcon\app-icon-source.png`：用户提供的原始 `PNG`，用于后续重新生成 `ICO`

这样做的目的：

- 避免项目对 skill 仓库外、桌面或下载目录的绝对路径产生依赖
- 让 AI 在新项目里有固定落点，不会把图标文件散落到项目外
- 让后续改图标时可以同时保留原始 `PNG` 和实际引用的 `ICO`

## WPF 推荐写法

`.csproj`：

```xml
<PropertyGroup>
  <ApplicationIcon>Assets\AppIcon\app.ico</ApplicationIcon>
</PropertyGroup>

<ItemGroup>
  <Resource Include="Assets\AppIcon\app.ico" />
</ItemGroup>
```

`MainWindow.xaml`：

```xml
<Window
    x:Class="Demo.MainWindow"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Demo"
    Icon="/Assets/AppIcon/app.ico">
</Window>
```

为什么这样写：

- `<ApplicationIcon>` 负责发布后 `exe` 图标
- `<Resource Include="Assets\AppIcon\app.ico" />` 保证 `WPF` 运行时能从程序集资源里取到图标
- `Icon="/Assets/AppIcon/app.ico"` 不依赖发布目录旁边必须存在一个物理 `ico` 文件

## WinForms 推荐写法

`.csproj`：

```xml
<PropertyGroup>
  <ApplicationIcon>Assets\AppIcon\app.ico</ApplicationIcon>
</PropertyGroup>
```

窗体代码：

```csharp
public partial class MainForm : Form
{
    public MainForm()
    {
        InitializeComponent();
        Icon = new Icon(Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon", "app.ico"));
    }
}
```

补充判断：

- 如果使用磁盘路径读 `ico`，必须确认发布目录中确实存在该文件
- 更稳妥时优先走资源文件或嵌入资源，不要默认相信相对路径

## 必记坑点

### 坑 1：把 `ApplicationIcon` 当成全能配置

错误认知：

- 配了 `<ApplicationIcon>` 就能自动覆盖窗体左上角、任务栏和 `exe`

正确认知：

- `ApplicationIcon` 主要解决程序文件图标
- 运行时窗体图标仍要单独设置

### 坑 2：WPF 用松散文件路径引用 ico

高风险写法：

```xml
<Window Icon="app.ico">
```

问题：

- 如果运行目录旁边没有这个文件，`WPF` 可能在 `InitializeComponent()` 阶段直接抛 `XamlParseException`
- 用户看到的表象可能只是“双击 exe 没反应”

更稳妥的写法：

```xml
<Window Icon="/Assets/AppIcon/app.ico">
```

并配合：

```xml
<ItemGroup>
  <Resource Include="Assets\AppIcon\app.ico" />
</ItemGroup>
```

### 坑 3：Debug 正常，Release 崩溃

常见原因：

- 开发目录里刚好有 `app.ico`
- 发布目录没有
- 代码引用的是磁盘路径而不是嵌入资源

结论：

- 任何图标接入，最后都要从 `bin\Release\...` 或发布目录直接启动验证

### 坑 4：多个窗口只改了主窗体

现象：

- 主窗体图标对了
- 子窗口、配置窗口、弹窗仍然是默认图标

建议：

- 多窗体项目要么逐个设置 `Icon`
- 要么统一封装窗口基类或公共样式，避免遗漏

## AI 最低排查顺序

只要用户提到“图标没生效”或“加了 ico 后程序打不开”，按这个顺序排查：

1. 判定项目类型：`WPF` 还是 `WinForms`
2. 检查 `.csproj` 是否配置了 `<ApplicationIcon>`
3. 检查运行时窗体是否设置了 `Icon`
4. 如果是 `WPF`，优先确认是否用了 `Resource Include + Icon="/Assets/AppIcon/app.ico"`
5. 检查图标文件是否已经落到项目内 `Assets\AppIcon\`，而不是还引用项目外部路径
6. 检查 `Release` 产物目录是否真的包含所依赖的外部资源
7. 直接从发布目录启动一次，而不是只看 IDE 中运行结果
8. 如果双击无反应，优先怀疑 `XamlParseException`、资源路径和图标文件缺失

## AI 默认回答口径

- 不要只给一句“把 ico 放到项目里即可”
- 必须区分：`exe` 图标、窗体图标、任务栏图标
- 必须给出最小示例代码
- 必须提示 `Release` 目录直接验证
- 如果用户反馈“加完 ico 双击 exe 没反应”，优先按资源路径问题排查，不要先猜业务逻辑崩溃
