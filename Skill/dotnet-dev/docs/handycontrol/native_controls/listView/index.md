<!-- cid: daebfe19-b69a9778-b48ccf21-efdca1fc-617d1ba5-60b41aa1-490c6ab1 -->
<!-- source_map: f62d46bb-9a5c2fda-984a7783-c31a195e-4dbba307-4c72a203-65cad213 -->
---
title: ListView
---

`HandyControl` only provides a default `ListView` style, which can be customized according to personal needs.

{% note info no-icon %}
Example：
{% code lang:xml %}
    <ListView ItemsSource="{Binding DataList}" Margin="20">
        <ListView.View>
            <GridView>
                <GridViewColumn Width="80" Header="title1" DisplayMemberBinding="{Binding Index}"/>
                <GridViewColumn Width="100" Header="title2" DisplayMemberBinding="{Binding Name}"/>
                <GridViewColumn Width="200" Header="title3" DisplayMemberBinding="{Binding Remark}"/>
            </GridView>
        </ListView.View>
    </ListView>
{% endcode %}

![ListView.DefaultStyle](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/native_controls/ListView.DefaultStyle.png)

{% endnote %}