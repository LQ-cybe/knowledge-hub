<!-- ref_id: 688904ad-04f86dcc-06ee3595-5dbe5b48-d31fe111-d2d6e015-fb6e9005 -->
# HandyControl 全局主题标准

本文定义 `dotnet-dev` 中 `HandyControl` 的统一主题规范。后续 AI 在 `gui-exe` 或其他 `WPF` 项目中新增页面时，默认先遵守本文，再写具体界面。

## 主题入口

- 运行时主题入口：`./templates/project-blueprints/gui-exe/src/app_name/App.xaml.tmpl`
- 设计期资源入口：`./templates/project-blueprints/gui-exe/src/app_name/Properties/DesignTimeResources.xaml.tmpl`
- 全局主题覆盖入口：`./templates/project-blueprints/gui-exe/src/app_name/Resources/ThemeOverrides.xaml.tmpl`

## 默认策略

- 默认保留 `HandyControl` 官方主题色，不主动覆盖
- 只有当用户明确要求贴合企业品牌色、政务色、工业风色系等场景时，才修改 `ThemeOverrides.xaml`
- 需要让 `MainWindow.xaml`、子页面、弹窗页在设计器里都能识别 `ButtonPrimary`、`PrimaryBrush` 等资源时，必须保留 `DesignTimeResources.xaml`

## 必须遵守

- 不要只在 `App.xaml` 里挂 `hc:Theme` 就结束；如果没有设计期资源，窗口页里容易丢失智能提示
- 不要在每个页面里重复写 `<hc:Theme Name="HandyTheme" />`，默认直接继承应用级主题
- 页面里优先使用 `DynamicResource` 或 `StaticResource` 访问全局主题键，不要硬编码十六进制颜色
- 原生控件优先复用 `HandyControl` 样式，例如 `ButtonPrimary`、`ButtonSuccess`、`ButtonInfo`、`ButtonDanger`
- 业务状态色语义保持固定：
  - 主流程、当前状态、主操作：`Primary`
  - 提示、风险提醒、待确认：`Warning`
  - 失败、报错、删除、不可逆：`Danger`
  - 成功反馈：`Success`
  - 普通信息展示：`Info`

## 推荐写法

```xml
<Border Background="{DynamicResource RegionBrush}"
        BorderBrush="{DynamicResource BorderBrush}"
        BorderThickness="1">
  <StackPanel>
    <TextBlock Foreground="{DynamicResource SecondaryTextBrush}"
               Text="说明文本" />
    <Button Style="{StaticResource ButtonPrimary}"
            hc:BorderElement.CornerRadius="8"
            Content="主操作" />
  </StackPanel>
</Border>
```

## ThemeOverrides 用法

- 默认模板中的 `ThemeOverrides.xaml` 只有注释示例，不主动覆盖任何颜色
- 如需换品牌色，只改这一个文件，不要逐页改 XAML
- 建议优先覆盖这些键：
  - `PrimaryColor / PrimaryBrush`
  - `WarningColor / WarningBrush`
  - `DangerColor / DangerBrush`
  - `SuccessColor / SuccessBrush`
  - `InfoColor / InfoBrush`

## 对后续 AI 的执行要求

- 先读 `./references/07-handycontrol-routing.md`
- 再读本文，确认项目是否已经具备 `DesignTimeResources.xaml` 和 `ThemeOverrides.xaml`
- 用户没明确要求品牌色时，不要主动改成橙色、绿色或其他企业色
- 如果新增了新的主题规范或颜色语义，要同步更新本文、`07-handycontrol-routing.md`、`SKILL.md` 和 `CHANGELOG.md`
