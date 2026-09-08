<!-- meta_key: 3cc3f998-50b290f9-52a4c8a0-09f4a67d-87551c24-869c1d20-af246d30 -->
---
title: Magnifier
---

With the help of `Magnifier`, any control can be partially magnified.

```cs
[TemplatePart(Name = ElementVisualBrush, Type = typeof(VisualBrush))]
public class Magnifier : AdornerElement
```
# Attributes
|Property|Description|Default Value|Remarks|
|-|-|-|-|
|HorizontalOffset|Horizontal offset relative to the mouse|0||
|VerticalOffset|Vertical offset relative to the mouse|0||
|Scale|Scale factor|5.0|||

# Case

```xml
<Image Margin="16" hc:Magnifier.Instance="{x:Static hc:Magnifier.Default}" Source="/HandyControlDemo;component/Resources/Img/b1.jpg" Stretch="None"/>
```

```xml
<Image Margin="16" Source="/HandyControlDemo;component/Resources/Img/b1.jpg" Stretch="None">
    <hc:Magnifier.Instance>
        <hc:Magnifier Scale="6" HorizontalOffset="-16" VerticalOffset="-16"/>
    </hc:Magnifier.Instance>
</Image>

```
![Magnifier](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/Magnifier.png)