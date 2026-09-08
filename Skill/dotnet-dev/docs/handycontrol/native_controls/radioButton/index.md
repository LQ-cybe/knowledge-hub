<!-- manifest_ref: cc5cc01e-a02da97f-a23bf126-f96b9ffb-77ca25a2-760324a6-5fbb54b6 -->
<!-- frag_id: bfe8cb6f-d399a20e-d18ffa57-8adf948a-047e2ed3-05b72fd7-2c0f5fc7 -->
---
title: RadioButton
---

# RadioButtonBaseStyle

The default style of the radiobutton is not recommended. It should always be used by other styles as BasedOn.

Case:

```xml
<StackPanel>
    <RadioButton Content="Default style"/>
    <RadioButton Margin="0,16,0,0" Content="Not editable" IsChecked="True" IsEnabled="False"/>
    <RadioButton Margin="0,16,0,0" Content="Default style"/>
    <RadioButton Margin="0,16,0,0" Content="Not editable" IsEnabled="False"/>
</StackPanel>
```

effect:

![RadioButton.DefaultStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/RadioButton.DefaultStyle.png)

# RadioButtonIcon : RadioButtonBaseStyle

With icon style, can display only icons or graphics

Case:

```xml
<UniformGrid Margin="22,0,0,0" Rows="2" Columns="2">
    <RadioButton Margin="10,0,0,0" Background="{DynamicResource SecondaryRegionBrush}" hc:IconElement.Geometry="{StaticResource CalendarGeometry}" Style="{StaticResource RadioButtonIcon}" Content="RadioButtonIcon"/>
    <RadioButton Margin="10,0,0,0" Background="{DynamicResource SecondaryRegionBrush}" Style="{StaticResource RadioButtonIcon}" Content="RadioButtonIcon" IsChecked="True"/>
    <RadioButton Margin="10,0,0,0" BorderThickness="1" hc:IconElement.Geometry="{StaticResource CalendarGeometry}" Style="{StaticResource RadioButtonIcon}" Content="RadioButtonIcon"/>
    <RadioButton Margin="10,0,0,0" BorderThickness="1" Style="{StaticResource RadioButtonIcon}" Content="RadioButtonIcon"/>
</UniformGrid>
```

effect:

![RadioButton.IconStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/RadioButton.IconStyle.png)