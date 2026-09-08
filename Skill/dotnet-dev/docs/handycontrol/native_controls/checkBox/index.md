<!-- resource_ref: 9af85c8a-f68935eb-f49f6db2-afcf036f-216eb936-20a7b832-091fc822 -->
---
title: CheckBox 
---

# CheckBoxBaseStyle

The default style of the checkbox is not recommended for direct use and should always be used by other styles in the BasedOn mode.

{% note info no-icon %}
Example：

{% code lang:xml %}
<StackPanel>
    <CheckBox Content="CheckBox" IsChecked="True"/>
    <CheckBox Margin="0,16,0,0" Content="CheckBox" IsChecked="True" IsEnabled="False"/>
    <CheckBox Margin="0,16,0,0" Content="CheckBox"/>
    <CheckBox Margin="0,16,0,0" Content="CheckBox" IsEnabled="False"/>
    <CheckBox Margin="0,16,0,0" Content="CheckBox" IsChecked="{x:Null}"/>
    <CheckBox Margin="0,16,0,0" Content="CheckBox" IsChecked="{x:Null}" IsEnabled="False"/>
</StackPanel>
{% endcode %}

![CheckBox](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/CheckBox.png)

{% endnote %}