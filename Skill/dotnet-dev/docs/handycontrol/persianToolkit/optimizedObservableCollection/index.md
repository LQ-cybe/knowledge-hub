<!-- blob_id: 405cfeed-2c2d978c-2e3bcfd5-756ba108-fbca1b51-fa031a55-d3bb6a45 -->
<!-- env_hash: d52e6802-b95f0163-bb49593a-e01937e7-6eb88dbe-6f718cba-46c9fcaa -->
---
title: OptimizedObservableCollection
---

A super awesome ObservableCollection that adds important methods such as: AddRange, RemoveRange, Replace, and ReplaceRange with single CollectionChanged notification.


Example:

```cs
public OptimizedObservableCollection<int> Items = new OptimizedObservableCollection<int>();

private void AddItems()
{
    var array = new int[3];
    array[0] = 7;
    array[1] = 6;
    array[2] = 7;

    Items.AddRange(array);
}

```