<!-- ref_id: f8f2182b-9483714a-96952913-cdc547ce-4364fd97-42adfc93-6b158c83 -->
<!-- manifest_ref: 9767aa17-fb16c376-f9009b2f-a250f5f2-2cf14fab-2d384eaf-04803ebf -->
# 质量检查与运行验证

生成代码后，后续 AI 不应把"未经运行的代码"直接交给用户。至少要完成自动检查和一次最小人工验证。

## 推荐顺序

1. `dotnet format` — 自动格式化代码
2. `dotnet build` — 确保无编译错误
3. `dotnet test` — 运行所有单元测试
4. `dotnet run --project ...` 或实际启动 GUI
5. 如有文件输出，检查生成文件是否存在且内容合理

如果任一步失败，先自行修复再继续，不要把报错直接甩给用户。

## 测试编写要求

### 最低可接受测试

每个项目至少写一个冒烟测试（Smoke Test），验证：

- 核心类可以实例化
- 核心方法能被调用且不抛异常
- 配置文件可以正常读取

```csharp
// 冒烟测试示例
[TestMethod]
public void SmokeTest_AppConfig_CanBeLoaded()
{
    var config = new AppConfig();
    Assert.IsNotNull(config);
    Assert.IsFalse(string.IsNullOrEmpty(config.AppName));
}
```

### 测试覆盖建议

| 输入类型 | 必须测　　　　　　| 建议测　　　　　　　　　　　　|
| ----------| -------------------| -------------------------------|
| 正常输入 | ✅ 主流程正确　　　| 多组不同数据　　　　　　　　　|
| 空输入　 | ✅ 不崩溃　　　　　| 给出友好提示　　　　　　　　　|
| 边界输入 | ✅ 极值不溢出　　　| 如 0 文件、1 条记录、最大文件 |
| 错误输入 | ✅ 不崩溃 + 有日志 | 如错误格式、不存在路径　　　　|

### 测试命名规范

方法命名格式：`{方法名}_{场景}_{预期结果}`

```csharp
public void ParseData_EmptyFile_ReturnsEmptyList() { }
public void ParseData_InvalidFormat_LogsWarning() { }
```

### 对 AI 的测试要求

- 测试要自己跑，确认通过后再告诉用户
- 测试失败时，先分析原因、修复代码、再跑一次
- 不要写"针对界面细枝末节"的无效测试
- 核心逻辑优先覆盖，GUI 交互可通过冒烟测试验证

## 运行验证检查表

### 控制台程序

- [ ] 程序能正常启动和退出（非零退出码时有日志）
- [ ] 示例输入产生预期输出
- [ ] 空输入时给出提示而非崩溃
- [ ] 输出文件路径清晰可见

### 桌面程序（WPF）

- [ ] 窗口能正常打开，UI 不卡死
- [ ] 所有按钮能触发核心动作
- [ ] 报错提示是中文且用户能看懂（不是技术堆栈）
- [ ] 输出路径 / 日志目录入口在界面上可见
- [ ] 关闭窗口后进程正常退出

## dotnet format 失败应对

如果 `dotnet format` 报错或无法运行：

1. 先检查是否安装了 format 工具：`dotnet tool list -g`
2. 如需安装：`dotnet tool install -g dotnet-format`
3. 如果 format 不可用，至少确保 `dotnet build` 无警告
4. Visual Studio 用户可跳过 format，用 IDE 自带格式化

## 交付前冒烟

发布 exe 后，在另一台干净的机器上（或至少在新目录中）执行一次启动冒烟：

1. 将 exe（或发布目录）拷贝到新位置
2. 双击运行一次
3. 确认程序正常启动、核心功能可用
4. 确认不依赖开发环境的任何文件
