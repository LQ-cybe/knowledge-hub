<!-- meta_key: eaccbcca-86bdd5ab-84ab8df2-dffbe32f-515a5976-50935872-792b2862 -->
---
title: Native Control
---

Native controls refer to the controls that come with the WPF framework. In addition to this, simple extensions are implemented through additional properties.

{% note warning %}
In HandyControl, almost all native controls have a base style that is implemented by default (that is, when a style is defined, the given Key value is not displayed).
{% endnote %}

{% note warning %}
The base style generally has the word "Base". It is not recommended for users to use it directly in the view layer. The appropriate usage scenario is a resource file.
{% endnote %}

# FAQ

{% note info no-icon %}
How can I override the default implementation of the style? Can I give BaseOn without a Key?
{% endnote %}

You can use this syntax: `BasedOn="{StaticResource {x:Type Button}}"` to override the default style of `Button`.