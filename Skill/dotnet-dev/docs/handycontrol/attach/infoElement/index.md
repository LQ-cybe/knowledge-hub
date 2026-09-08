<!-- ctx_id: cc0c75f1-a07d1c90-a26b44c9-f93b2a14-779a904d-76539149-5febe159 -->
<!-- origin_hash: f6b5d508-9ac4bc69-98d2e430-c3828aed-4d2330b4-4cea31b0-655241a0 -->
---
title: InfoElement
---

{% note info no-icon %}

Inherited from [TitleElement]( https://handyorg.github.io/handycontrol/attach/titleElement/ )

{% endnote%}

# Attributes

| Name | Use |
| ---------------- | ------------------ |
| Placeholder | Placeholder (input prompt) |
| Necessary | Required?
| Symbol | Tag Information |
| ContentHeight | Content Height |
| MinContentHeight | Minimum Content Height |
| MaxContentHeight | Maximum Content Height |
| RegexPattern | Regex Pattern |

# Use Cases

## Placeholder

```xml
<StackPanel Width="200" VerticalAlignment="Center">
    <hc:SearchBar/>
    <hc:SearchBar hc:InfoElement.Placeholder="请输入查询条件" Style="{StaticResource SearchBarExtend}" Margin="0,16,0,0"/>
</StackPanel>
```

![InfoElement.Placeholder](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/InfoElement.Placeholder.png)

## Necessary

```xml
     <hc:SearchBar hc:InfoElement.Placeholder="Please enter the query criteria"
                   Hc:InfoElement.Title="Query Condition"
                   Margin="10,10" hc:InfoElement.Necessary="True"
                   Style="{StaticResource SearchBarExtend}"/>
```

Where `hc:InfoElement.Title="query condition"` inherited from parent class

effect:

![InfoElement.Necssary](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/InfoElement.Necssary.png)

## Symbol

```xml
     <hc:SearchBar hc:InfoElement.Placeholder="Please enter the content"
               Hc:InfoElement.Title="This item is required" Style="{StaticResource SearchBarExtend}"
               Margin="10,10" hc:InfoElement.Necessary="True"
               Hc:InfoElement.Symbol="x"/>
```

![InfoElement.Symbol](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/InfoElement.Symbol.png)

## ContentHeight

```xml
     <hc:SearchBar hc:InfoElement.Placeholder="Please enter the query criteria"
                   Hc:InfoElement.ContentHeight="50"
                   Hc:InfoElement.Title="Query Condition"
                   Margin="10,10" hc:InfoElement.Necessary="True"
                   Style="{StaticResource SearchBarExtend}"/>
```

![InfoElement.ContentHeight](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/InfoElement.ContentHeight.png)

## RegexPattern

By setting this attribute, you can customize the verification logic inside the information element to realize error prompts for content outside the specified format.