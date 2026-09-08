<!-- node_ref: 5bc28e6e-37b3e70f-35a5bf56-6ef5d18b-e0546bd2-e19d6ad6-c8251ac6 -->
# HandyControl 接入与避坑指南

本文是 `dotnet-dev` 中 HandyControl 的唯一入口，覆盖文档路由、场景速查、已验证的避坑经验和强制编码要求。

> **警告**：`../docs/handycontrol/` 目录包含 200+ 个 Markdown 文件，**默认不要全量扫描**。必须先按"场景 -> 子目录"定位，再精读对应文件。

## 场景路由速查

### 快速入门 / 环境配置 / NuGet 安装

- 文档：`../docs/handycontrol/quick_start/index.md`
- 适用场景：
  - 首次接入 HandyControl
  - 安装 NuGet 包（注意 `HandyControl` vs `HandyControls` 官方/非官方区别）
  - 配置 `App.xaml` 中的主题资源
  - 搭建最小可运行 Demo
- 重点看：
  - `hc:Theme` 的正确接入方式（不要用 `ThemeResources`）
  - 官方包 vs 非官方包的区别
  - 基础 XAML 命名空间

### 主题、颜色、换肤、资源字典

- 文档：`../docs/handycontrol/theme/index.md`
- skill 内部标准：`./12-handycontrol-theme-standard.md`
- 适用场景：
  - 修改应用主题（明色/暗色）
  - 自定义品牌色、强调色
  - 配置资源字典
  - 动态切换皮肤

### 原生控件样式（WPF 内置控件）

- 文档：`../docs/handycontrol/native_controls/`
- 适用场景：
  - 使用 `Button`、`TextBox`、`ComboBox`、`DataGrid`、`ListBox` 等原生控件
  - 需要 HandyControl 美化后的原生控件样式
  - 按钮样式如 `ButtonPrimary`、`ButtonSuccess`、`ButtonDanger` 等
- 重点看：
  - 带有 HandyControl 附加属性的原生控件用法
  - 不要错误地把原生控件写成 `hc:` 前缀控件

### 扩展控件（HandyControl 自定义控件）

- 文档：`../docs/handycontrol/extend_controls/`
- 适用场景：
  - 需要 `Growl`（全局通知）、`Dialog`、`MessageBox` 等自定义控件
  - 使用 `TabControl`、`StepBar`、`Tag`、`SearchBar` 等增强控件
  - 需要带有 `hc:` 前缀的自定义控件
- 重点看：
  - 控件专有属性与附加属性
  - 事件绑定与 MVVM 用法

### 数据与集合

- 文档：`../docs/handycontrol/data/`

### 基础 XAML

- 文档：`../docs/handycontrol/basic_xaml/`

### 交互与行为

- 文档：`../docs/handycontrol/interactivity/`

### 媒体与图形

- 文档：`../docs/handycontrol/media/`

### 波斯日历工具

- 文档：`../docs/handycontrol/persianToolkit/`
- 适用场景：波斯日历与日期（通常无需关注，除非用户明确要求）

## 查找优先级

1. **优先找 `quick_start`**：如果不确定怎么接入，先读 `quick_start/index.md`
2. **主题问题找 `theme`**：换肤、颜色、资源字典
3. **控件问题先分原生/扩展**：
   - 按钮、文本框、下拉框等 → `native_controls/`
   - `hc:` 前缀控件 → `extend_controls/`
4. **基础概念走 `basic_xaml` 或 `data`**
5. **实在找不到时**，再从 `index.md` 出发逐层展开，不要一次性全量扫描

---

## 已验证的避坑经验

### 1. 官方 HandyControl 不要默认写 `ThemeResources`

- `ThemeResources` / `Theme` 这一套写法主要出现在 `HandyControls` 非官方版文档里
- 当前 `dotnet-dev` 默认选的是官方包 `HandyControl`
- 对官方包，优先按 `quick_start` 中的官方示例接入：

```xml
<Application xmlns:hc="https://handyorg.github.io/handycontrol">
  <Application.Resources>
    <ResourceDictionary>
      <ResourceDictionary.MergedDictionaries>
        <hc:Theme Name="HandyTheme" />
      </ResourceDictionary.MergedDictionaries>
    </ResourceDictionary>
  </Application.Resources>
</Application>
```

### 2. 旧版 pack URI 只能当兼容兜底，不要当默认模板

- 以下写法在旧版本里可用，但不应作为默认首选：

```xml
<ResourceDictionary Source="pack://application:,,,/HandyControl;component/Themes/SkinDefault.xaml"/>
<ResourceDictionary Source="pack://application:,,,/HandyControl;component/Themes/Theme.xaml"/>
```

- 原因：文档已明确这是 older versions 的兼容写法，新模板默认应优先跟随当前官方推荐入口

### 3. 不要把普通 Button 误写成 `hc:Button`

- **原则：** 优先使用"原生控件 + HC 样式"，只有文档明确说明是扩展控件时才使用 `hc:` 前缀。
- `HandyControl` 对很多原生控件的增强方式不是"换成新控件"，而是"继续用原生控件 + 样式 + 附加属性"
- 例如按钮应该优先这样写：

```xml
<Button Style="{StaticResource ButtonPrimary}"
        hc:BorderElement.CornerRadius="8"
        Content="确定" />
```

- 而不是默认写成 `<hc:Button Content="确定" />`

### 4. 先分清官方包和非官方包，再抄示例

- `HandyControl`：官方版（本 skill 默认使用）
- `HandyControls`：非官方版，文档和能力更多，但接入写法有差异
- 抄示例前先确认当前项目引用的是哪个 NuGet 包，避免混用

### 5. XAML 设计器智能提示（Intellisense）失效处理

- **现象**：`App.xaml` 已配置主题，但 `MainWindow.xaml` 提示"无法解析资源 `ButtonPrimary`"，且没有属性提示。
- **原因**：`App.xaml` 的资源主要在**运行时**生效。对于**设计时**（写代码时），VS 设计器有时无法跨文件自动关联资源字典。
- **解决方案**：同时配置 `DesignTimeResources.xaml` 与 `ThemeOverrides.xaml`。

1. 在 `Properties` 文件夹下新建 `DesignTimeResources.xaml`：
```xml
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
  <ResourceDictionary.MergedDictionaries>
    <ResourceDictionary Source="pack://application:,,,/HandyControl;component/Themes/SkinDefault.xaml" />
    <ResourceDictionary Source="pack://application:,,,/HandyControl;component/Themes/Theme.xaml" />
    <ResourceDictionary Source="/YourApp;component/Resources/ThemeOverrides.xaml" />
  </ResourceDictionary.MergedDictionaries>
</ResourceDictionary>
```

2. 在 `Resources` 文件夹下新建 `ThemeOverrides.xaml`，默认先留空或只保留注释示例，不主动覆盖官方主题色。

3. 在 `.csproj` 中给设计期资源页补元数据：
```xml
<ItemGroup>
  <Page Update="Properties\DesignTimeResources.xaml">
    <Generator>MSBuild:Compile</Generator>
    <SubType>Designer</SubType>
    <ContainsDesignTimeResources>true</ContainsDesignTimeResources>
  </Page>
</ItemGroup>
```

4. `App.xaml` 继续保留运行时主题入口，但要额外挂上 `ThemeOverrides.xaml`：

```xml
<Application.Resources>
  <ResourceDictionary>
    <ResourceDictionary.MergedDictionaries>
      <hc:Theme Name="HandyTheme" />
      <ResourceDictionary Source="/YourApp;component/Resources/ThemeOverrides.xaml" />
    </ResourceDictionary.MergedDictionaries>
  </ResourceDictionary>
</Application.Resources>
```

### 6. 品牌色覆盖默认要“能力存在，但默认不生效”

- 模板需要预留全局主题覆盖入口，但默认保持 `HandyControl` 官方色板
- 不要把橙色、绿色或任意企业色直接写死成默认模板
- 只有当用户明确要求“贴合企业品牌色/行业色/甲方 UI 色系”时，才修改 `ThemeOverrides.xaml`
- 一旦要改品牌色，优先改全局资源入口，不要把 `#RRGGBB` 散落到每个页面里

---

## 控件类型速查表

下面这份清单不是凭印象整理，而是按 `../docs/handycontrol/native_controls/` 和 `../docs/handycontrol/extend_controls/` 的真实子目录名逐项核对得到。

- 脚本核对结果：`native_controls = 36` 项
- 脚本核对结果：`extend_controls = 87` 项
- 两个 skill 的 HandyControl 文档目录结果一致

### 必须使用原生标签的控件目录清单

**默认先把这些控件当作原生 WPF 控件处理**。HandyControl 对它们通常是通过 `Style`、附加属性或模板增强，而不是简单替换成 `hc:` 标签。

| 分组 | 原生控件清单 |
| :--- | :--- |
| **A-F** | `Border`, `Button`, `Calendar`, `CheckBox`, `ComboBox`, `ContentControl`, `ContextMenu`, `DataGrid`, `DatePicker`, `Expander`, `FlowDocument`, `Frame` |
| **G-R** | `GroupBox`, `Image`, `Label`, `ListBox`, `ListView`, `Menu`, `NavigationWindow`, `PasswordBox`, `ProgressBar`, `RadioButton`, `RepeatButton`, `RichTextBox` |
| **S-Z** | `ScrollViewer`, `Separator`, `Slider`, `StatusBar`, `TabControl`, `TextBlock`, `TextBox`, `ToggleButton`, `ToolBar`, `ToolTip`, `TreeView`, `Window` |

补充说明：

- 文档目录里原生分支有一个目录名写作 `seperator`
- 对应的真实 WPF 原生控件仍然是 `Separator`

**示例（正确 vs 错误）：**

- ✅ `<ProgressBar Style="{StaticResource ProgressBarInfoStripe}" />`
- ❌ `<hc:ProgressBar />`

### 扩展控件目录清单

以下条目来自 `extend_controls/` 真实子目录。**只有命中文档中的扩展控件时，才使用 `hc:` 前缀标签**。

| 分组 | 扩展控件清单 |
| :--- | :--- |
| **A-C** | `hc:AnimationPath`, `hc:Badge`, `hc:BlurWindow`, `hc:ButtonGroup`, `hc:CalendarWithClock`, `hc:Card`, `hc:Carousel`, `hc:ChatBubble`, `hc:CheckComboBox`, `hc:CirclePanel`, `hc:CircleProgressBar`, `hc:Clock`, `hc:ColorPicker`, `hc:ComboBox`, `hc:CompareSlider`, `hc:ContextMenuButton`, `hc:CoverFlow`, `hc:CoverView` |
| **D-G** | `hc:DashBorder`, `hc:DatePicker`, `hc:DateTimePicker`, `hc:Dialog`, `hc:Divider`, `hc:Drawer`, `hc:Effect`, `hc:ElementGroup`, `hc:Empty`, `hc:FlexPanel`, `hc:FlipClock`, `hc:FloatingBlock`, `hc:GifImage`, `hc:GlowWindow`, `hc:GotoTop`, `hc:Gravatar`, `hc:Grid`, `hc:Growl` |
| **H-P** | `hc:HatchBrushGenerator`, `hc:HoneycombPanel`, `hc:ImageBlock`, `hc:ImageBrowser`, `hc:ImageSelector`, `hc:ImageViewer`, `hc:Loading`, `hc:Magnifier`, `hc:MessageBox`, `hc:MorphingAnimation`, `hc:Notification`, `hc:NotifyIcon`, `hc:NumericUpDown`, `hc:OutlineText`, `hc:Pagination`, `hc:PasswordBox`, `hc:PinBox`, `hc:PopTip`, `hc:PopupWindow`, `hc:PreviewSlider`, `hc:ProgressButton`, `hc:PropertyGrid` |
| **R-Z** | `hc:RangeSlider`, `hc:Rate`, `hc:RelativePanel`, `hc:RunningBlock`, `hc:Screenshot`, `hc:ScrollViewer`, `hc:SearchBar`, `hc:Shield`, `hc:SideMenu`, `hc:SimpleItemsControl`, `hc:SimplePanel`, `hc:SimpleStackPanel`, `hc:SimpleText`, `hc:SplitButton`, `hc:Sprite`, `hc:StepBar`, `hc:TabControl`, `hc:Tag`, `hc:TextBox`, `hc:TimeBar`, `hc:TimePicker`, `hc:ToggleBlock`, `hc:Transfer`, `hc:TransitioningContentControl`, `hc:UniformSpacingPanel`, `hc:WaterfallPanel`, `hc:Watermark`, `hc:WaveProgressBar`, `hc:Window` |

### 重名目录清单

下面这 7 个名字同时出现在 `native_controls/` 和 `extend_controls/` 中：

- `ComboBox`
- `DatePicker`
- `PasswordBox`
- `ScrollViewer`
- `TabControl`
- `TextBox`
- `Window`

**强制规则：**

- 这些重名项绝不能只看名字就判断“必须原生”或“必须 `hc:`”
- 必须分别进入对应目录核对：
  - `../docs/handycontrol/native_controls/<name>/index.md`
  - `../docs/handycontrol/extend_controls/<name>/index.md`
- 先看文档里的示例标签、命名空间和属性，再决定实际 XAML 写法

**⚠️ 警告：** 扩展控件拥有大量非标准自定义属性。**严禁凭记忆猜属性名**，必须回到 [extend_controls](../docs/handycontrol/extend_controls/index.md) 下进入具体控件文档。

---

## 推荐排错顺序

1. 先回到本文"场景路由速查"，按场景定位对应文档目录
2. 快速接入优先看 `../docs/handycontrol/quick_start/index.md`
3. 主题配置优先看 `../docs/handycontrol/theme/handyControl.md`
4. 如果是原生控件样式问题，进入 `../docs/handycontrol/native_controls/`
5. 如果是扩展控件问题，进入 `../docs/handycontrol/extend_controls/`
6. 如果只是设计器里资源提示不全，再看 `../docs/handycontrol/intellisense/index.md`

## 对后续 AI 的强制要求

- 接入 `HandyControl` 前，先确认当前项目使用的是官方包 `HandyControl`
- 默认按官方 `quick_start` 的 `hc:Theme` 方式接入，不要用 `ThemeResources`
- **强制要求：** 在编写 XAML 前必须查阅本文"必须使用原生标签的控件列表"和"扩展控件清单"
- **强制要求：** 对于扩展控件（`hc:` 前缀），**严禁凭记忆猜测属性名称**（尤其是低频属性）。必须实时回查 [extend_controls](../docs/handycontrol/extend_controls/index.md) 目录下的对应文档
- 默认把按钮、文本框等先当作原生控件处理，再套 `HandyControl` 样式
- 只有文档明确说明是扩展控件（位于 `../docs/handycontrol/extend_controls/` 目录下）时，才直接使用 `hc:` 前缀控件
- 如果接入过程报错，不要只靠猜，先按本文"推荐排错顺序"定位对应文档
