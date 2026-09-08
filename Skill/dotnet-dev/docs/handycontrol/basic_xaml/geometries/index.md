<!-- source_map: 32083754-5e795e35-5c6f066c-073f68b1-899ed2e8-8857d3ec-a1efa3fc -->
<!-- asset_hash: d2d966b1-bea80fd0-bcbe5789-e7ee3954-694f830d-68868209-413ef219 -->
---
title: Geometric shape
---

HandyControl comes with some geometric shape definitions, but it is obviously not enough to apply to production. We are not prepared to be all-encompassing. There is never a bottom, so we will do the opposite. It only contains the control library itself (of course users can also use it), and the rest should expand on its own. All shape definitions in the control library are listed in the following table:

| Name | Description |
|-|-|
| CalendarGeometry | Calendar |
| DeleteGeometry | Delete |
| DeleteFillCircleGeometry | Delete (Circular Fill) |
| CloseGeometry | Close |
| DownGeometry | Next |
| UpGeometry | On |
| ClockGeometry | Clock |
| LeftGeometry | Left |
| RightGeometry | Right |
| RotateLeftGeometry | Rotate Left |
| RotateRightGeometry | Rotate Right |
| EnlargeGeometry | Zoom |
| ReduceGeometry | Zoom out |
| DownloadGeometry | Download |
| SaveGeometry | Save |
| WindowsGeometry | Window |
| FullScreenGeometry | Full Screen |
| FullScreenReturnGeometry | Full Screen Back |
| SearchGeometry | Search |
| UpDownGeometry | Upper and lower combinations |
| WindowMinGeometry | Window Minimization |
| WindowRestoreGeometry | Window Restore |
| WindowMaxGeometry | Window Maximization |
| PageModeGeometry | Single page mode |
| TwoPageModeGeometry | Double page mode |
| ScrollModeGeometry | Scroll mode |
| AudioGeometry | Sound |
| BubbleTailGeometry | Bubble Tail |
| StarGeometry | Love |
| AddGeometry | Add |
| SubGeometry | Subtract |
| WarningGeometry | Warning |
| InfoGeometry | Information |
| ErrorGeometry | Error |
| SuccessGeometry | Success |
| FatalGeometry | Critical |
| AskGeometry | Inquiry |
| AllGeometry | All |
| DragVerticalGeometry | Drag and Drop Vertically (for toolbars) |
| DragHorizontalGeometry | Drag and Drop Horizontally (for toolbars) |
| CheckedGeometry | Selected |
| EyeOpenGeometry | Open eyes |
| EyeCloseGeometry | Close eyes |
| DropperGeometry | Select Color from Shell |
| VisualStudioGeometry | Visual Studio Icon |
| ConfigGeometry | Gear Icon |
| NewGeometry | New Icon |
| RemoveGeometry | Remove Icon |
| AlignLeftGeometry |  |
| AlignRightGeometry |  |
| AlignHCenterGeometry |  |
| AlignHStretchGeometry |  |
| AlignTopGeometry |  |
| AlignBottomGeometry |  |
| AlignVCenterGeometry |  |
| AlignVStretchGeometry |  |


{% note info no-icon %}
Example: `Data="{StaticResource ErrorGeometry}"`
{% endnote %}