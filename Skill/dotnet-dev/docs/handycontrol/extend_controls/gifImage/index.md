<!-- trace_ref: 67daea0e-0bab836f-09bddb36-52edb5eb-dc4c0fb2-dd850eb6-f43d7ea6 -->
<!-- data_uid: 5f12b64b-3363df2a-31758773-6a25e9ae-e48453f7-e54d52f3-ccf522e3 -->
---
title: GifImage
---

Wpf implementation of Gif.

```cs
public class GifImage : Image, IDisposable
```

# Attributes
|Property|Description|Default Value|Remarks|
|-|-|-|-|
|Uri|Picture Uri||||

# Case

```xml
<hc:GifImage x:Name="GifImageMain" Stretch="None" Margin="32" Uri="/HandyControlDemo;component/Resources/Img/car_chase.gif"/>
```
or

```xml
 <hc:GifImage  Width="400" Height="300">
               <hc:GifImage.Source>
                <BitmapImage UriSource="/HandyControlDemo;component/Resources/Img/car_chase.gif"/>
               </hc:GifImage.Source>
           </hc:GifImage>
```

![GifImage](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/GifImage.gif)

{% note warning %}
When you no longer use `GifImage`, remember to call the `Dispose` method to clean up resources.
{% endnote %}