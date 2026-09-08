<!-- resource_ref: 8dfc49f8-e18d2099-e39b78c0-b8cb161d-366aac44-37a3ad40-1e1bdd50 -->
<!-- internal_id: b8d3b628-d4a2df49-d6b48710-8de4e9cd-03455394-028c5290-2b342280 -->
---
title: Window
---

HC's extension of wpf native `Window`.

```cs
[TemplatePart(Name = ElementNonClientArea, Type = typeof(UIElement))]
public class Window : System.Windows.Window
```

# Attributes
|Property|Description|Default Value|Remarks|
|-|-|-|-|
|CloseButtonBackground|Close button background color|||
|CloseButtonForeground|Close button foreground color|||
|CloseButtonHoverBackground|Close button mouse hover background color|||
|CloseButtonHoverForeground|Close button mouse hover foreground color|||
|OtherButtonBackground|Other Button Background Color|||
|OtherButtonForeground|Foreground color of other buttons|||
|OtherButtonHoverBackground|Other button mouse hover background color|||
|OtherButtonHoverForeground|Other button mouse hover foreground color|||
|NonClientAreaContent|NonClientAreaContent|||
|NonClientAreaBackground|NonClientAreaBackground|NonClientAreaBackground|||
|NonClientAreaForeground|Foreground color of non-client area|||
|NonClientAreaHeight|NonClientAreaHeight|||
|ShowNonClientArea|Whether to display non-client area|true||
|ShowTitle|Whether to show the window title|true||
|ExtendViewIntoNonClientArea|Extend View Into NonClientArea|false|Only Custom Version|
|IsFullScreen|Whether the window is in full screen|false|||

# Case

```xml
<hc:Window x:Class="HandyControlDemo.Window.CommonWindow"
           xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
           xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
           xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
           xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
           xmlns:hc="https://handyorg.github.io/handycontrol"
           mc:Ignorable="d"
           Background="{DynamicResource MainContentBackgroundBrush}"
           WindowStartupLocation="CenterScreen"
           Title="Title" 
           Height="450" 
           Width="800" 
           Icon="/HandyControlDemo;component/Resources/Img/icon.ico">
    <Border Background="{DynamicResource MainContentForegroundDrawingBrush}"/>
</hc:Window>
```
![Window](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/extend_controls/Window.png)


# Attached Properties

you can use **WindowAttach** Attached Property for dragging window or any control. 

``` xml
 <hc:Window WindowAttach:IsDragElement="True" 
...
/>
```

# Shortcut
you should use **GlobalShortcut.KeyBindings**
``` xml
  <hc:GlobalShortcut.KeyBindings>
        <KeyBinding Modifiers="Control+Alt" Key="E" Command="{Binding GlobalShortcutErrorCmd}"/>
        <KeyBinding Modifiers="Control+Alt" Key="I" Command="{Binding Main.GlobalShortcutInfoCmd, Source={StaticResource Locator}}"/>
    </hc:GlobalShortcut.KeyBindings>
```

# Menu
If you want to use menus in the title bar, you should use **NonClientAreaContent** property
``` xml
<hc:Window.NonClientAreaContent>
  <StackPanel VerticalAlignment="Stretch" Orientation="Horizontal">
        <Button Content="About" Style="{StaticResource ButtonCustom}"/>
        <Button Content="Help" Style="{StaticResource ButtonCustom}"/>
        <Menu>
            <MenuItem Header="Repository">
                <MenuItem Header="GitHub"/>
            </MenuItem>
        </Menu>
   </StackPanel>
</hc:Window.NonClientAreaContent>
```

# NonClientAreaContent
If you want to put objects, you should use it in this way
``` xml
<hc:Window.NonClientAreaContent>
  <!-- Put your objects here -->
</hc:Window.NonClientAreaContent>
```