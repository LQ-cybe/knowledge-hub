<!-- v_id: 54d54aea-38a4238b-3ab27bd2-61e2150f-ef43af56-ee8aae52-c732de42 -->
# 性能优化与并发处理

这个文档用于指导 .NET 应用的性能调优、异步编程和多线程并发处理。

## 核心原则

1.  **I/O 密集型任务**（文件、网络、数据库）→ 必须使用 `async/await` 异步 I/O。
2.  **CPU 密集型任务**（大量计算、图像处理）→ 使用并行处理（`Parallel`、`Task.Run`）。
3.  **UI 线程保护** → 永远不要在 UI 线程执行耗时操作，避免界面卡死。
4.  **资源管理** → 频繁创建的大对象考虑复用，使用 `StringBuilder` 处理长字符串。
5.  **线程安全** → 多线程访问共享数据时，优先使用 `System.Collections.Concurrent` 集合。

---

## 并行处理模式

### 1. 受控并行（推荐）
使用 `SemaphoreSlim` 严格控制并发数量，防止内存溢出（OOM）或目标服务崩溃。
```csharp
public async Task ProcessInParallelAsync(List<Item> items, int maxParallel = 4)
{
    var semaphore = new SemaphoreSlim(maxParallel);
    var tasks = items.Select(async item =>
    {
        await semaphore.WaitAsync();
        try { await ProcessItemAsync(item); }
        finally { semaphore.Release(); }
    });
    await Task.WhenAll(tasks);
}
```

### 2. 简单并行
适用于纯 CPU 计算且任务相互独立。
```csharp
Parallel.ForEach(items, new ParallelOptions { MaxDegreeOfParallelism = 4 }, item => 
{
    Compute(item);
});
```

---

## 异步 I/O 优化

### 1. 文件 I/O
大文件读写应指定缓冲区大小并启用异步选项。
```csharp
using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, useAsync: true);
```

### 2. 网络 I/O
`HttpClient` 应该单例复用，不要在每个请求中 `using` 创建。

---

## 线程安全集合选择

| 集合类型 | 适用场景 |
| :--- | :--- |
| `ConcurrentBag<T>` | 无序集合，适合并行生产/消费。 |
| `ConcurrentDictionary<K,V>` | 高频读写的共享字典。 |
| `ConcurrentQueue<T>` | 先进先出队列。 |
| `BlockingCollection<T>` | 经典的生产者-消费者模型，支持阻塞等待。 |

---

## UI 线程保护（WPF）

### 1. 异步更新 UI
耗时操作放在 `Task.Run` 中，进度更新通过 `Dispatcher` 回传。
```csharp
await Task.Run(() => 
{
    // 耗时逻辑
    Dispatcher.Invoke(() => ProgressBar.Value = progress); 
});
```

### 2. 避免死锁
在库代码（非 UI 层）中，优先使用 `.ConfigureAwait(false)`。
```csharp
await SomeTask().ConfigureAwait(false);
```

---

## 性能陷阱规避

- **字符串拼接**：循环内严禁使用 `+`，统一改用 `StringBuilder`。
- **对象创建**：避免在热点循环中 `new` 大对象或频繁分配内存。
- **同步等待**：严禁在异步代码中使用 `.Result` 或 `.Wait()`，这会导致线程池饥饿甚至死锁。
- **文件操作**：避免频繁打开/关闭同一个文件，应尽量批量处理。

---

## 性能分析清单

- [ ] 是否存在阻塞 UI 线程的操作？
- [ ] 所有的 I/O 操作是否都已异步化？
- [ ] 并行任务是否设置了合理的并发限额？
- [ ] 共享集合是否使用了线程安全版本？
- [ ] 是否在循环中使用了 `StringBuilder`？
- [ ] 是否已移除不必要的 `.Result` 或 `.Wait()` 调用？
