<!-- cache_key: d67b6b60-ba0a0201-b81c5a58-e34c3485-6ded8edc-6c248fd8-459cffc8 -->
<!-- doc_sid: 13b1a785-7fc0cee4-7dd696bd-2686f860-a8274239-a9ee433d-8056332d -->
---
title: Behaviors
---

# FluidMoveBehavior

``` xml
<StackPanel x:Name="Panel" Grid.Row="0">
    <hc:Interaction.Behaviors>
        <hc:FluidMoveBehavior Duration="00:00:01" AppliesTo="Children">
            <hc:FluidMoveBehavior.EaseY>
                <BounceEase EasingMode="EaseOut" Bounces="2" />
            </hc:FluidMoveBehavior.EaseY>
        </hc:FluidMoveBehavior>
    </hc:Interaction.Behaviors>
</StackPanel>
```

now add items:
``` CS
 Rectangle rect = new Rectangle();
 rect.Height = 50;
 rect.Width = 50;
 rect.Fill = Brushes.DeepPink;
 rect.Margin = new Thickness(5.0);
 this.Panel.Children.Add(rect);
```
or remove items:
``` CS
if (this.Panel.Children.Count > 0)
{
    this.Panel.Children.RemoveAt(0);
}
```

# MouseDragElementBehavior
``` xml
<Rectangle Width="40" Height="40" Fill="DeepPink">
    <hc:Interaction.Behaviors>
        <hc:MouseDragElementBehavior/>
    </hc:Interaction.Behaviors>
</Rectangle>
```