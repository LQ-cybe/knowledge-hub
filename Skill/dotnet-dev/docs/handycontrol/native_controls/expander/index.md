<!-- meta_key: d77b5d6d-bb0a340c-b91c6c55-e24c0288-6cedb8d1-6d24b9d5-449cc9c5 -->
---
title: Expander
---

# ExpanderBaseStyle

Expander Expand Box The default style, which is not recommended for direct use, should always be used by other styles in the BasedOn method.

{% note info no-icon %}

Example:
{% code lang:xml %}
<StackPanel Margin="32" VerticalAlignment="Center" Width="240">
    <Expander Header="Title" BorderThickness="1,1,1,0" BorderBrush="{DynamicResource BorderBrush}">
        <Border Height="100" Background="{DynamicResource SecondaryRegionBrush}"/>
    </Expander>
    <Expander Header="Title" BorderThickness="1,1,1,0" BorderBrush="{DynamicResource BorderBrush}">
        <Border Height="100" Background="{DynamicResource SecondaryRegionBrush}"/>
    </Expander>
    <Expander Header="Title" BorderThickness="1,1,1,0" BorderBrush="{DynamicResource BorderBrush}">
        <Border Height="100" Background="{DynamicResource SecondaryRegionBrush}"/>
    </Expander>
    <Expander Header="Title" BorderThickness="1" BorderBrush="{DynamicResource BorderBrush}">
        <Border Height="100" Background="{DynamicResource SecondaryRegionBrush}"/>
    </Expander>
</StackPanel>
{% endcode %}

![ExpanderBaseStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/ExpanderBaseStyle.png)

{% endnote %}