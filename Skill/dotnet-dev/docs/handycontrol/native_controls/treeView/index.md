<!-- comp_id: e301d931-8f70b050-8d66e809-d63686d4-58973c8d-595e3d89-70e64d99 -->
<!-- state_hash: 4c9a982d-20ebf14c-22fda915-79adc7c8-f70c7d91-f6c57c95-df7d0c85 -->
---
title: TreeView
---

# TreeViewBaseStyle : BaseStyle

The default style of the treeview is not recommended. It should always be used by other styles in the BasicOn mode.

Case:

 ```xml
<TreeView Width="200" VerticalAlignment="Center">
    <TreeViewItem Header="111">
        <TreeViewItem Header="111"/>
        <TreeViewItem Header="222"/>
        <TreeViewItem Header="333"/>
    </TreeViewItem>
    <TreeViewItem Header="222">
        <TreeViewItem Header="111"/>
        <TreeViewItem Header="222"/>
        <TreeViewItem Header="333"/>
    </TreeViewItem>
</TreeView>
 ```

effect:

![TreeViewBaseStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/TreeViewBaseStyle.png)

# Related styles

| Name | Inherited from | Description |
|-|-|-|
| TreeViewItemBaseStyle | BaseStyle | Tree View Item Default Style |
| ExpandCollapseToggleStyle | | Treeview Collapse Button Style |