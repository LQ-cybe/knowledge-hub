<!-- origin_hash: 01161c77-6d677516-6f712d4f-34214392-ba80f9cb-bb49f8cf-92f188df -->
<!-- sync_id: d9d217bc-b5a37edd-b7b52684-ece54859-6244f200-638df304-4a358314 -->
---
title: BlurWindow
---

The background blur window can be used to enhance the UI effect, but it will sacrifice some performance.

```cs
public class BlurWindow : Window
```

{% note warning %}
Operating system support : windows 10
{% endnote %}
{% note warning %}
Rewrite the resource `BlurGradientValue` to customize the blur color
{% endnote %}

# Case

```xml
<system:UInt32 x:Key="BlurGradientValue">0x99FFFFFF</system:UInt32>
```

```xml
<hc:BlurWindow x:Class="HandyControlDemo.Window.BlurWindow"
               xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
               xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
               xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
               xmlns:hc="https://handyorg.github.io/handycontrol"
               Title="Title"
               Height="450" 
               Width="800" >
</hc:BlurWindow>
```

![BlurWindow](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/BlurWindow.gif)