<!-- cache_key: f014a11b-9c65c87a-9e739023-c523fefe-4b8244a7-4a4b45a3-63f335b3 -->
---
title: FlipClock
---

A clock scheme in 3D form.

```cs
public class FlipClock : Control
```

# Attributes
|Property|Description|Default Value|Remarks|
|-|-|-|-|
|NumberList|Number Collection|||
|DisplayTime|Display Time||||

# Case
```xml
<hc:FlipClock Margin="32"/>
```

![FlipClock](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/FlipClock.gif)

{% note warning %}
When you no longer use `FlipClock`, remember to call the `Dispose` method to clean up resources.
{% endnote %}
{% note warning %}
The size of `FlipClock` can be adjusted with the help of `ViewBox`.
{% endnote %}