<!-- internal_id: cec5cc15-a2b4a574-a0a2fd2d-fbf293f0-755329a9-749a28ad-5d2258bd -->
---
title: GridAttach
---

|Property|
|-|
|Name|
|RowName|
|ColumnName|

```xml
<Grid>
    <Grid.RowDefinitions>
      <RowDefinition hc:GridExtensions.Name="R0" />
      <RowDefinition hc:GridExtensions.Name="R1" />
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition />
      <ColumnDefinition />
      <ColumnDefinition hc:GridExtensions.Name="C1" />
    </Grid.ColumnDefinitions>
        <TextBlock hc:GridExtensions.RowName="R1" hc:GridExtensions.ColumnName="C1" Text="12" />
  </Grid>
```