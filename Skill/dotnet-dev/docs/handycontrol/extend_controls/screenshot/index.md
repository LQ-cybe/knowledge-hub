<!-- v_id: d974fb37-b5059256-b713ca0f-ec43a4d2-62e21e8b-632b1f8f-4a936f9f -->
<!-- rev_id: 11daca7a-7daba31b-7fbdfb42-24ed959f-aa4c2fc6-ab852ec2-823d5ed2 -->
---
title: ScreenShot
---

It can be triggered by shortcut keys to save the entire screen or the content of a specified area as a picture.

```cs
public class Screenshot
```

# Attributes
| Property |
| - |
| IsDrawing | 
| IsSelecting |
| Size |
| SizeStr |
| PixelColor |
| PixelColorStr |
| PreviewBrush |

# Method
|Name|Description|
|-|-|
| Start() | Start screenshot |

# Events
|Name|Description|
|-|-|
| Snapped | Triggered when the screenshot is complete |

# Case

```cs
new Screenshot().Start();
```

or

``` xml
<Button Content="Start Screenshot" Command="hc:ControlCommands.StartScreenshot"/>
```

# Snapped

``` CS
public partial class ScreenshotDemoCtl : IDisposable
    {
        public ScreenshotDemoCtl()
        {
            InitializeComponent();
            Screenshot.Snapped += Screenshot_Snapped;
        }

        private void Screenshot_Snapped(object sender, FunctionEventArgs<ImageSource> e)
        {
            new HandyControl.Controls.Window
            {
                Content = new Image
                {
                    Source = e.Info,
                    Stretch = Stretch.None
                },
                WindowStartupLocation = WindowStartupLocation.CenterScreen
            }.ShowDialog();
        }

        public void Dispose() => Screenshot.Snapped -= Screenshot_Snapped;
    }
```

![Screenshot](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/Screenshot.png)
