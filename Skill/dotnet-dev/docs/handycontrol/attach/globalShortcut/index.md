<!-- node_ref: 482bd2fb-245abb9a-264ce3c3-7d1c8d1e-f3bd3747-f2743643-dbcc4653 -->
---
title: GlobalShortcut
---

With this property you can use shortcut keys

| Name | Use |
|-|-|
| Host | Desired window |

```xml
hc:GlobalShortcut.Host="True"
```

```xml
 <hc:GlobalShortcut.KeyBindings>
        <KeyBinding Modifiers="Control+Alt" Key="I" Command="{Binding GlobalShortcutInfoCmd}"/>
        <KeyBinding Modifiers="Control+Alt" Key="E" Command="{Binding GlobalShortcutWarningCmd}"/>
    </hc:GlobalShortcut.KeyBindings>
```