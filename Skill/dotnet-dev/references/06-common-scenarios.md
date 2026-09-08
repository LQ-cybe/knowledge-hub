<!-- data_uid: e61724f5-8a664d94-887015cd-d3207b10-5d81c149-5c48c04d-75f0b05d -->
# 常见场景库

这个文档用于处理高频 .NET 需求时的快速判断。

## 场景一：批量文件处理

- 自己用为主：优先 `cli-batch`
- 要给同事或运营人员使用：优先 `gui-exe`

## 场景二：Excel / 表格批处理

- 规则固定、自己用：`cli-batch`
- 需要普通用户选文件再处理：`excel-batch`

## 场景三：网页抓取

- 静态页面优先 `web-scraper`
- 需要登录态或复杂点击流程时，再单独评估浏览器自动化

## 场景四：桌面小工具

- 优先 `gui-exe`
- 默认考虑 `exe`

## 性能优化模式（高频代码模式）

在处理大量文件、高并发请求或耗时计算时，请统一参考专项文档：[09-performance-and-concurrency.md](09-performance-and-concurrency.md)。

该文档涵盖了：
- 异步并行处理（SemaphoreSlim）
- 线程安全集合（ConcurrentBag 等）
- UI 线程保护与异步更新
- 常见性能陷阱（StringBuilder、避免死锁等）

## 最后原则

- 不要因为用户说了 “.NET” 就默认交付源码
- 不要因为用户说了 “自动化” 就默认交付命令行
- 不要因为用户说了 “exe” 就跳过需求澄清
