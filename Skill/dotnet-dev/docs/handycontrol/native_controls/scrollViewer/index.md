<!-- origin_hash: 12acad36-7eddc457-7ccb9c0e-279bf2d3-a93a488a-a8f3498e-814b399e -->
---
title: ScrollViewer
---

# ScrollViewerNativeBaseStyle

The default style of the native ScrollViewer is not recommended. It should always be used by other styles based on On.

Case:

```xml
<ScrollViewer>
   <Grid Height="500">
      <TextBlock Text="Content area"></TextBlock>
   </Grid>
</ScrollViewer>
```

effect:

![ScrollViewer.DefaultStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/ScrollViewer.DefaultStyle.png)

# ScrollViewerUpDown

ScrollViewer style showing up and down buttons

Case:

```xml
<ScrollViewer Style="{StaticResource ScrollViewerUpDown}">
    <StackPanel Height="500">
        <TextBlock Text="Content area" Height="250"></TextBlock>
        <TextBlock Text="Content area" Height="250"></TextBlock>
        <TextBlock Text="Content area"></TextBlock>
        <TextBlock Text="Content area"></TextBlock>
    </StackPanel>
</ScrollViewer>
```

effect:

![ScrollViewer.UpDownStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/ScrollViewer.UpDownStyle.png)
