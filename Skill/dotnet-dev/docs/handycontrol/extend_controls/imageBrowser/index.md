<!-- origin_hash: b878e431-d4098d50-d61fd509-8d4fbbd4-03ee018d-02270089-2b9f7099 -->
<!-- trace_ref: 6e844ff2-02f52693-00e37eca-5bb31017-d512aa4e-d4dbab4a-fd63db5a -->
---
title: ImageBrowser
---

You can easily browse a single picture with the help of `ImageBrowser`.

```cs
public class ImageBrowser : Window
```

# Case
After the constructor passes in the picture address, you can start to browse the picture:

```cs
new ImageBrowser(new Uri("pack://application:,,,/Resources/Img/1.jpg")).Show()
```

![ImageBrowser](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/ImageBrowser.gif)

# Features
The screenshot of the function panel is as follows:

![ImageBrowser](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/extend_controls/ImageBrowser_1.png)

The functions from left to right are: `Save to local`, `Open the picture with the system default program`, `Zoom out the picture`, `Enlarge the picture`, `Original size`, `Turn left picture`, `Turn right picture` .