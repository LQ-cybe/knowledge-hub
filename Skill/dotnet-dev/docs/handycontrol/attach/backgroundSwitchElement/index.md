<!-- dist_id: e68b6309-8afa0a68-88ec5231-d3bc3cec-5d1d86b5-5cd487b1-756cf7a1 -->
<!-- v_id: a66579b6-ca1410d7-c802488e-93522653-1df39c0a-1c3a9d0e-3582ed1e -->
---
title: BackgroundSwitchElement
---

# Attributes

| Name | Use |
|-|-|
| MouseHoverBackground | Set mouse hover background color |
| MouseDownBackground | Set mouse down background color |

# Use Cases

## MouseHoverBackground Set Mouse hover background color

In the style or template we add the following trigger code:

```xml
<Trigger Property="IsMouseOver" Value="True">
    <Setter Property="Background" TargetName="Chrome" Value="{Binding Path=(hc:BackgroundSwitchElement.MouseHoverBackground),RelativeSource={RelativeSource TemplatedParent}}"/>
</Trigger>
```

Then we can use this property:

```xml
<Target control  hc:BackgroundSwitchElement.MouseHoverBackground ="Blue"/>
```


## MouseDownBackground  Set Mouse down background color

In the style or template we add the following trigger code:

```xml
<Trigger Property="IsPressed" Value="True">
    <Setter Property="Background" TargetName="Chrome" Value="{Binding Path=(hc:BackgroundSwitchElement.MouseDownBackground),RelativeSource={RelativeSource TemplatedParent}}"/>
</Trigger>
```

Then we can use this property:

```xml
<Target control hc:BackgroundSwitchElement.MouseDownBackground ="Yellow"/>
```