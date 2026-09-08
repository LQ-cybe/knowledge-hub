<!-- schema_v: 1ba07ac0-77d113a1-75c74bf8-2e972525-a0369f7c-a1ff9e78-8847ee68 -->
<!-- env_hash: e0f8471c-8c892e7d-8e9f7624-d5cf18f9-5b6ea2a0-5aa7a3a4-731fd3b4 -->
---
title: IfExtension
---

Using the Conditional expression in XAML.

```xml
<Button Command="{hc:If {Binding BoolProperty},
                            {Binding OkCommand},
                            {Binding CancelCommand}}" />

<!--OR-->
<UserControl>
    <markup:If Condition="{Binding IsLoading}">
        <markup:If.True>
            <views:LoadingView />
        </markup:If.True>
        <markup:If.False>
            <views:LoadedView />
        </markup:If.False>
    </markup:If>
</UserControl>
```
