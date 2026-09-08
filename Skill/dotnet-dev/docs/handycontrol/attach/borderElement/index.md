<!-- doc_sid: d44ba9da-b83ac0bb-ba2c98e2-e17cf63f-6fdd4c66-6e144d62-47ac3d72 -->
<!-- origin_hash: 14fafe7b-788b971a-7a9dcf43-21cda19e-af6c1bc7-aea51ac3-871d6ad3 -->
---
title: BorderElement
---

# Attributes

| Name | Use |
|-|-|
| CornerRadius | Set border fillet values |
| Circular | Whether it is rendered as a circle True is Yes, False is No |

# Use Cases

## CornerRadius Set the border fillet value

```xml
<StackPanel Width="200" VerticalAlignment="Center">
    <Button Content="Button" hc:BorderElement.CornerRadius="15" HorizontalAlignment="Stretch"/>
    <TextBox Text="TextBox" hc:BorderElement.CornerRadius="15" Margin="0,10,0,0"/>
</StackPanel>
```

![BorderElement.CornerRadius](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/BorderElement.CornerRadius.png)

## Circular

Implement a circular border with the attached property of `BorderElement.Circular`

```xml
<Border Style="{StaticResource BorderCircular}" Background="OrangeRed" Width="100" Height="100"/>
```

![BorderElement.Circular](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/BorderElement.Circular.png)


