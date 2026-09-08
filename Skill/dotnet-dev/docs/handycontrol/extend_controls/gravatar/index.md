<!-- data_uid: 9814cbf1-f465a290-f673fac9-ad239414-23822e4d-224b2f49-0bf35f59 -->
<!-- commit_ref: 230759ee-4f76308f-4d6068d6-1630060b-9891bc52-9958bd56-b0e0cd46 -->
---
title: Gravatar
---

A way to implement random avatars for users.

```cs
public class Gravatar : ContentControl
```

# Attributes
|Property|Description|Default Value|Remarks|
|-|-|-|-|
|Generator|Avatar Generator|GithubGravatarGenerator||
|Id|UserId|||
|Source|User Profile||||

# Style
|Style|Description|
|-|-|
|GravatarBaseStyle|Default Style|
|GravatarCircle|Circle Head|
|GravatarCircleImg|Circle picture avatar|

# Case

```xml
<StackPanel Margin="32" Orientation="Horizontal">
    <UniformGrid Rows="3" Columns="3" Width="240" Height="240">
        <hc:Gravatar Id="User1"/>
        <hc:Gravatar Id="User2"/>
        <hc:Gravatar Style="{StaticResource GravatarCircleImg}">
            <Image Source="/HandyControlDemo;component/Resources/Img/Album/2.jpg"/>
        </hc:Gravatar>
        <hc:Gravatar Id="User4"/>
        <hc:Gravatar Id="User5" Style="{StaticResource GravatarCircle}"/>
        <hc:Gravatar Id="User6"/>
        <hc:Gravatar Style="{StaticResource GravatarCircle}" Source="/HandyControlDemo;component/Resources/Img/Album/1.jpg"/>
        <hc:Gravatar Id="User8"/>
        <hc:Gravatar Id="User9"/>
    </UniformGrid>
    <StackPanel Margin="16,0,0,0" Height="220" VerticalAlignment="Center">
        <TextBox Text="User1" Name="TextBoxName" Width="180"/>
        <hc:Gravatar Height="180" Width="180" Id="{Binding Text,ElementName=TextBoxName}" Margin="10"/>
    </StackPanel>
</StackPanel>
```

![Gravatar](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Resources/Gravatar.gif)