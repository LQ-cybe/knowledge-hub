<!-- data_uid: f5c19c26-99b0f547-9ba6ad1e-c0f6c3c3-4e57799a-4f9e789e-6626088e -->
<!-- data_uid: 68fc0eec-048d678d-069b3fd4-5dcb5109-d36aeb50-d2a3ea54-fb1b9a44 -->
---
title: Args
---

|name|Remarks|
|-|-|
|CancelRoutedEventArgs||
|FunctionEventArgs!1||
|KeyboardHookEventArgs||
|MouseHookEventArgs||

You can use `FunctionEventArgs!1` to create a custom event args

step 1: create a EventHandler

```cs
public event EventHandler<FunctionEventArgs<myArgument>> myEventChanged;

public class myArgument
{
    public string OldValue { get; internal set; }
    public string NewValue { get; internal set; }
}
```
step2: Notify change where necessary

```cs
myEventChanged?.Invoke(this, new FunctionEventArgs<myArgument>(OldValue = "Old", NewValue = "New"));
```

