<!-- node_ref: 66841fe8-0af57689-08e32ed0-53b3400d-dd12fa54-dcdbfb50-f5638b40 -->
---
title: UniformSpacingPanel
---


```cs
public class UniformSpacingPanel : Panel
```

# Attributes
|Property|Description|Default Value|Remarks|
|-|-|-|-|
|Orientation||Horizontal||
|Spacing||0||
|ItemWidth||NaN||
|ItemHeight||NaN||
|ChildWrapping|||||

```xml
 <hc:SimpleStackPanel Margin="32">
    <hc:UniformSpacingPanel Spacing="10">
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
    </hc:UniformSpacingPanel>
    <hc:Divider LineStrokeDashArray="2,2"/>
    <hc:UniformSpacingPanel Spacing="10" Orientation="Vertical">
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
    </hc:UniformSpacingPanel>
    <hc:Divider LineStrokeDashArray="2,2"/>
    <hc:UniformSpacingPanel Spacing="10" Width="300" ChildWrapping="Wrap" HorizontalAlignment="Left">
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
    </hc:UniformSpacingPanel>
    <hc:Divider LineStrokeDashArray="2,2"/>
    <hc:UniformSpacingPanel Spacing="10" Orientation="Vertical" Height="70" ChildWrapping="Wrap" HorizontalAlignment="Left">
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
        <Button Content="This is the content"/>
    </hc:UniformSpacingPanel>
</hc:SimpleStackPanel>
```

![UniformSpacingPanel](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/UniformSpacingPanel.png)