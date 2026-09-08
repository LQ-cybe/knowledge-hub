<!-- trace_ref: 52cf3011-3ebe5970-3ca80129-67f86ff4-e959d5ad-e890d4a9-c128a4b9 -->
---
title: ContextMenu 
---

# ContextMenuBaseStyle

The default style of the context menu is not recommended for direct use and should always be used by other styles in the BasedOn mode.

{% note info no-icon %}
Example：

{% code lang:xml %}
<ContextMenu ItemsSource="{Binding DataList}">
    <ContextMenu.ItemTemplate>
        <HierarchicalDataTemplate ItemsSource="{Binding DataList}">
            <TextBlock Text="{Binding Name}"/>
        </HierarchicalDataTemplate>
    </ContextMenu.ItemTemplate>
</ContextMenu>
{% endcode %}

![ContextMenu](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/ContextMenu.png)

{% endnote %}