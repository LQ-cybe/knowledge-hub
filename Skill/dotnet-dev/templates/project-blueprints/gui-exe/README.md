<!-- meta_key: 171018f6-7b617197-797729ce-22274713-ac86fd4a-ad4ffc4e-84f78c5e -->
# gui-exe 蓝图

适合普通用户双击使用的 Windows 桌面工具。默认采用 `WPF + MVVM`，界面库默认优先 `HandyControl`，更适合高分屏和长期维护。

## 版本建议

- 当前蓝图默认从 `net6.0` 起步
- 如果确认 `.NET 6` 的 API 或包生态不够，再升到 `net8.0`
- 只有明确需要高版本能力，且目标环境可控时，才考虑 `net10.0`
- 如果做框架依赖发布，再单独判断是否需要 `RollForward`

## 默认结构

- `App.xaml`：应用入口和 HandyControl 主题资源
- `Assets/AppIcon/`：项目内图标资源目录，默认放 `app.ico` 和原始图标文件
- `Properties/DesignTimeResources.xaml`：给 XAML 设计器提供 HandyControl 设计期资源，避免窗口页里缺少智能提示
- `Resources/ThemeOverrides.xaml`：全局主题覆盖入口，默认保持官方配色，只在用户明确要求品牌色时覆盖
- `Views/MainWindow.xaml`：主窗口界面
- `ViewModels/MainWindowViewModel.cs`：界面状态和命令
- `Services/ShellService.cs`：打开目录等系统交互
- `tests/SmokeTests.cs`：最小可运行测试

## 图标约定

- `gui-exe` 蓝图默认把 `exe` 图标、窗体左上角图标和任务栏图标统一指向项目内 `Assets/AppIcon/app.ico`
- 图标文件必须落在项目内部，不要继续引用模板仓库外或用户桌面上的绝对路径
- 如果用户提供的是 `PNG`，优先保留原图到 `Assets/AppIcon/app-icon-source.png`，并生成 `Assets/AppIcon/app.ico`
- 实例化蓝图时，如未显式传 `-GuiIconSourcePath`，默认使用 `dotnet-dev/assets/gui-exe-default-icon/` 里的内部图标资产

## 实例化示例

```powershell
& .\scripts\instantiate_blueprint.ps1 `
  -BlueprintName gui-exe `
  -TargetRoot .\workbench-demo `
  -ProjectName WorkbenchDemo `
  -TargetFramework net6.0 `
  -GuiIconSourcePath "D:\icons\brand.png"
```

## HandyControl 文档使用规则

- 如果对 `HandyControl` 控件、主题、资源字典或样式写法不确定，优先查看 `../../../references/07-handycontrol-routing.md` 路由入口
- 避坑总结：`../../../references/07-handycontrol-routing.md`
- 快速接入：`../../../docs/handycontrol/quick_start/index.md`
- 主题与颜色：`../../../docs/handycontrol/theme/index.md`
- 主题覆盖规范：`../../../references/12-handycontrol-theme-standard.md`
