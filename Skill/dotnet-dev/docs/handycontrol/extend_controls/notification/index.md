<!-- trace_ref: b0dc78c2-dcad11a3-debb49fa-85eb2727-0b4a9d7e-0a839c7a-233bec6a -->
<!-- flow_ref: f15214d0-9d237db1-9f3525e8-c4654b35-4ac4f16c-4b0df068-62b58078 -->
---
title: Notification
---

Used to display a rich content message on the desktop.

```cs
public sealed class Notification : System.Windows.Window
```

# Method
|Name|Description|
|-|-|
| Show(object, ShowAnimation, bool) | Show desktop notifications (message content, animation effect type, whether to keep it open) |

# Case

```xml
<Border x:Class="HandyControlDemo.UserControl.AppNotification"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:hc="https://handyorg.github.io/handycontrol"
        Background="White"
        BorderThickness="1"
        BorderBrush="{DynamicResource BorderBrush}"
        Width="320"
        Height="518">
    <hc:SimplePanel>
        <Path Margin="0,36,0,0" VerticalAlignment="Top" Width="70" Height="70" Data="{StaticResource LogoGeometry}" Fill="#f06632"/>
        <TextBlock Text="HandyControl" FontSize="30" Foreground="{StaticResource PrimaryBrush}" HorizontalAlignment="Center" Margin="0,122,0,0" VerticalAlignment="Top"/>
        <Button Command="hc:ControlCommands.CloseWindow" CommandParameter="{Binding RelativeSource={RelativeSource Self}}" Content="Close" HorizontalAlignment="Stretch" VerticalAlignment="Bottom" Margin="10,0,10,10"/>
    </hc:SimplePanel>
</Border>
```

```cs
namespace HandyControlDemo.UserControl
{
    public partial class AppNotification
    {
        public AppNotification()
        {
            InitializeComponent();
        }
    }
}
```

```cs
Notification.Show(new AppNotification(), ShowAnimation.Fade, true)
```

![Notification](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/Notification.png)