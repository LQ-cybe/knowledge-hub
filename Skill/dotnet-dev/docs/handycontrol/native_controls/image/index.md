<!-- node_ref: 4dcf0435-21be6d54-23a8350d-78f85bd0-f659e189-f790e08d-de28909d -->
<!-- resource_ref: 07338985-6b42e0e4-6954b8bd-3204d660-bca56c39-bd6c6d3d-94d41d2d -->
---
title: Image
---

In `HandyControl`, corresponding to the native` Image` control, only a default control style is provided, and no special style is provided. For personalized customization, users need to customize it themselves

{% note info no-icon %}
Example:
{% code lang:xml %}
    <StackPanel Background="LightGray">
        <Image Source="Resources/Images/Image_basestyle.png" Margin="0,10"/>
        <Image Source="Resources/Images/Image_basestyle.png" RenderOptions.BitmapScalingMode="HighQuality" Stretch="Uniform"/>
    </StackPanel>
{% endcode %}

![image.baseStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/image.baseStyle.png)

{% endnote %}