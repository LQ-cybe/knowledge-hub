<!-- origin_hash: b98ec7b0-d5ffaed1-d7e9f688-8cb99855-0218220c-03d12308-2a695318 -->
<!-- ref_id: ed4b206c-813a490d-832c1154-d87c7f89-56ddc5d0-5714c4d4-7eacb4c4 -->
---
title: TitleElement
---

# Attributes

| Name | Use |
| -------------- | ------------ |
| Title | Title Information |
| Background | Title Background Color |
| Foreground | Title Font Color |
| BorderBrush | Title Border Color |
| TitlePlacement | Title Alignment |
| TitleWidth | Title Width |

# Use Cases

## Title

```xml
     <hc:TextBox hc:TitleElement.Title="Title Information"
                 Margin="10,10"></hc:TextBox>
```

![TitleElement.Title](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/TitleElement.Title.png)

## TitlePlacement

```xml
     <!--The title is on the top side -->
     <hc:TextBox hc:TitleElement.Title="Title Information"
              Hc:TitleElement.TitlePlacement="Top"
              Margin="10,10"></hc:TextBox>
     <!--The title is on the left -->
     <hc:TextBox hc:TitleElement.Title="Title Information"
              Hc:TitleElement.TitlePlacement="Left"
              Margin="10,10"></hc:TextBox>
```

![TitleElement.TitlePlacement](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/TitleElement.TitlePlacement.png)

## TitleWidth

```xml
         <!--Set TitleWidth to Auto-->
         <hc:TextBox hc:TitleElement.Title="Title Information"
              Hc:TitleElement.TitlePlacement="Left"
              Hc:TitleElement.TitleWidth="Auto"
              Margin="10,10"></hc:TextBox>
         <!--Set TitleWidth to a specific value -->
         <hc:TextBox hc:TitleElement.Title="Title Information"
              Hc:TitleElement.TitlePlacement="Left"
              Hc:TitleElement.TitleWidth="60"
              Margin="10,10"></hc:TextBox>
```

![TitleElement.TitleWidth](https://raw.githubusercontent.com/HandyOrg/HandyOrgResource/master/HandyControl/Doc/attach/TitleElement.TitleWidth.png)