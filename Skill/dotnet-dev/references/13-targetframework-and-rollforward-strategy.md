<!-- comp_id: 8e056a16-e2740377-e0625b2e-bb3235f3-35938faa-345a8eae-1de2febe -->
<!-- audit_id: b5fc1d94-d98d74f5-db9b2cac-80cb4271-0e6af828-0fa3f92c-261b893c -->
# TargetFramework 与 RollForward 决策参考

这份文档专门给当前 `dotnet-dev` 项目使用，目标不是泛泛解释 `.NET` 概念，而是帮助后续 AI 和用户在需求分析、初始化项目、发布交付时判断：

- 当前项目优先发布 `net6.0`、`net8.0` 还是 `net10.0`
- 为什么简单模板默认应从较低版本起步
- 独立 `.NET` 项目什么时候有必要考虑 `RollForward`
- 为什么“编译目标版本”和“运行时实际命中版本”不是一回事
- 为什么当前阶段不应默认把简单项目直接抬到 `.NET 10`

## 先记住这几个结论

- `TargetFramework` 决定编译边界，也就是“项目能用哪些 API、包版本和桌面能力”
- `RollForward` 决定运行时装载边界，也就是“框架依赖发布后，可否在更高已安装运行时上启动”
- 对当前 `dotnet-dev` 的简单模板，默认优先 `net6.0`
- 如果 `.NET 6` 的 API、语言特性或第三方包不够，再升到 `.NET 8`
- 只有在明确需要 `.NET 10` 新能力，且目标环境比较可控时，才建议直接发布 `.NET 10`
- 对独立 `.NET Core / .NET 6+` 项目，向上兼容通常比 ExcelDNA 场景更值得考虑，但也不该机械默认
- 部分 `Win10` 机器对 `.NET 10` 运行时支持不理想，所以很多项目更平衡的选择是 `.NET 8`

## 两个概念不要混

### `TargetFramework` 是编译边界

它决定：

- 你能不能直接写某个版本才有的 `.NET API`
- 某些第三方包能不能装、能不能编过
- 项目生成的 `runtimeconfig.json` 目标主版本是什么
- 你的项目最低要求什么 SDK 和运行时

直接理解成一句话：

- `TargetFramework` 决定“你能写什么、能编过什么”

### `RollForward` 是运行时装载边界

它主要决定：

- 目标机器没装目标主版本运行时时，能不能接受更高主版本
- 框架依赖发布的程序，能否在更高已安装运行时上落地启动
- 你更偏向“锁定目标主版本”还是“提高单包覆盖面”

直接理解成一句话：

- `RollForward` 决定“编译好的程序运行时可以落到哪里”

## 当前 dotnet-dev 最重要的默认策略

对于当前这套 `cli-batch / excel-batch / gui-exe / web-scraper` 模板：

- 默认从 `net6.0` 起步
- 只有在 `.NET 6` 明显不够时，再升 `net8.0`
- 不把 `.NET 10` 当简单项目默认值

原因不是 `.NET 10` 不能用，而是：

- 简单模板本身并不依赖高版本新能力
- 直接上高版本会抬高目标机器运行时要求
- 用户机器如果包含部分 `Win10`，`.NET 10` 的落地风险更高
- 很多实际项目在“现代能力”和“机器覆盖面”之间，`net8.0` 是更平衡的一档

## 当前项目里的常用组合怎么理解

### 1. `net6.0 + LatestPatch`

```xml
<TargetFramework>net6.0</TargetFramework>
<RollForward>LatestPatch</RollForward>
```

含义：

- 编译期按 `.NET 6` 能力边界开发
- 运行时只接受 `.NET 6` 主版本
- 目标机器没有 `.NET 6 Runtime` 时，框架依赖发布会启动失败

优点：

- 行为最稳定
- 结果最容易解释
- 适合简单工具模板的默认起点

缺点：

- 单包覆盖面有限
- 当目标环境分散时，可能需要用户补装 `.NET 6`

适合：

- 模板项目、简单批处理、普通桌面小工具
- 你优先想控制环境漂移
- 还不确定是否真的需要更高版本

### 2. `net6.0 + Major`

```xml
<TargetFramework>net6.0</TargetFramework>
<RollForward>Major</RollForward>
```

含义：

- 编译期仍是 `.NET 6`
- 有 `.NET 6` 时优先命中 `.NET 6`
- 没有 `.NET 6` 但有 `.NET 8` 或 `.NET 10` 时，允许向上命中

优点：

- 对独立 `.NET` 项目比较实用
- 框架依赖发布时，对分散环境更友好
- 仍然保留“目标版本优先”的思路

缺点：

- 不能让项目获得 `.NET 8/.NET 10` 新 API
- 不同机器实际命中版本可能不同

适合：

- 项目代码仍可兼容 `net6.0`
- 目标机环境不可控
- 希望减少多版本交付负担

### 3. `net6.0 + LatestMajor`

```xml
<TargetFramework>net6.0</TargetFramework>
<RollForward>LatestMajor</RollForward>
```

含义：

- 编译期仍按 `.NET 6`
- 运行时更倾向使用机器上更高主版本

优点：

- 单包覆盖面最大

缺点：

- 实际命中版本更漂移
- 不同机器行为更难解释

适合：

- 团队明确接受环境差异
- 有能力做多机型运行验证

### 4. `net8.0 + LatestPatch`

```xml
<TargetFramework>net8.0</TargetFramework>
<RollForward>LatestPatch</RollForward>
```

含义：

- 编译期可以使用 `.NET 8` 的 API、语言特性和更多新包
- 运行时要求 `.NET 8` 主版本

优点：

- 比 `.NET 6` 更现代
- 比 `.NET 10` 更平衡
- 对部分 `Win10` 场景更稳妥

缺点：

- 不能覆盖只有 `.NET 6` 的框架依赖目标机

适合：

- 项目已经明显受限于 `.NET 6`
- 但又没必要直接拉到 `.NET 10`

### 5. `net8.0 + Major`

```xml
<TargetFramework>net8.0</TargetFramework>
<RollForward>Major</RollForward>
```

含义：

- 编译期按 `.NET 8` 开发
- 优先使用 `.NET 8`
- 若只有更高版本，例如 `.NET 10`，允许向上命中

适合：

- 主线代码更适合 `net8.0`
- 仍希望在框架依赖发布时保留一定向上兼容能力

### 6. `net10.0 + LatestPatch`

```xml
<TargetFramework>net10.0</TargetFramework>
<RollForward>LatestPatch</RollForward>
```

含义：

- 编译期和运行时都以 `.NET 10` 为基线
- 可以使用 `.NET 10` 新能力
- 但没有 `.NET 10` 的机器，无法靠 `RollForward` 回退到 `.NET 8`

最重要的限制：

- `RollForward` 只能向上，不能向下

适合：

- 你确实需要 `.NET 10` API 或高版本包
- 目标环境已知可用

不适合：

- 模板型简单项目
- 目标用户包含部分 `Win10`
- 还希望单包兼容只装了 `.NET 8` 的机器

## 当前项目里的推荐决策顺序

1. 先问清目标用户主要是 `Win7`、`Win10` 还是 `Win11`
2. 再判断项目代码是否真的需要 `.NET 8` 或 `.NET 10` 的 API / 包
3. 如果没有明确高版本依赖，默认从 `net6.0` 起步
4. 如果 `.NET 6` 不够，再升到 `net8.0`
5. 只有在明确需要时才升到 `net10.0`
6. 如果选择框架依赖发布，再单独判断是否要启用 `RollForward`

## 对独立 .NET 项目，什么时候该考虑 `RollForward`

`RollForward` 在独立 `.NET` 项目里，比 ExcelDNA 场景更有现实意义，因为：

- 不需要和 Excel 进程里的其他插件争夺同一个运行时
- 很多业务程序确实希望“一个框架依赖包尽量覆盖更多已装运行时的电脑”
- 团队可能不想为 `net6`、`net8`、`net10` 维护多份近似交付物

但也不要机械默认，建议按下面判断：

- `自包含发布`：通常没必要依赖 `RollForward`
- `框架依赖发布` 且环境可控：优先 `LatestPatch`
- `框架依赖发布` 且环境分散：优先评估 `Major`
- 只有明确接受“总是优先命中更高版本”时，才考虑 `LatestMajor`

## 后续 AI 最容易犯错的点

### 错误 1：以为 `RollForward` 能替代升级 `TargetFramework`

错误理解：

- “先编成 `net6.0`，再配 `Major`，用户有 `.NET 10` 时就等于项目支持 `.NET 10` 新能力”

正确理解：

- 不行
- 运行时命中更高版本，不等于代码就能调用更高版本才有的 API

### 错误 2：以为 `net10.0` 可以靠 `RollForward` 向下兼容 `net8.0`

错误理解：

- “编成 `net10.0` 后，用户电脑只有 `.NET 8`，配 `RollForward` 也能跑”

正确理解：

- 不行
- `RollForward` 只解决向上命中，不解决向下回退

### 错误 3：把简单模板默认做太高

错误理解：

- “反正以后可能要升级，不如模板直接默认 `.NET 10`”

正确理解：

- 模板默认值应该服务于覆盖面和稳定性
- 当前这些简单模板并不需要高版本能力，默认 `net6.0` 更合理

## 面向当前 dotnet-dev 的推荐档位

### 档位 A：保守稳定优先

建议：

- `TargetFramework = net6.0`
- `RollForward = LatestPatch`

### 档位 B：低版本起步 + 向上兼容

建议：

- `TargetFramework = net6.0`
- `RollForward = Major`

适合：

- 独立业务程序
- 希望单包覆盖更多已安装运行时的机器

### 档位 C：现代能力与覆盖面平衡

建议：

- `TargetFramework = net8.0`
- `RollForward = LatestPatch` 或 `Major`

适合：

- `.NET 6` 已经不够
- 同时不想承担 `.NET 10` 的环境风险

### 档位 D：新特性绝对优先

建议：

- `TargetFramework = net10.0`
- `RollForward = LatestPatch`

前提：

- 确认目标环境支持
- 确认项目确实需要

## 给后续 AI 的执行规则

- 不要把 `.NET 10` 当作简单项目默认基线
- 先判断低版本是否够用，再决定是否升级
- 只要推荐 `RollForward`，就明确说明它只影响运行时，不影响编译期 API
- 只要目标用户包含 `Win10`，就提醒“`.NET 10` 在部分机器上可能不可用，`.NET 8` 往往更平衡”
- 如果用户提到“想少发几个版本”或“机器环境不可控”，主动解释 `net6/net8 + RollForward` 的意义
- 如果用户明确要求新 API 或高版本包，直接承认需要升级 `TargetFramework`

## 最小验收清单

- 当前项目真正依赖的 API / NuGet 包，是否仍与所选 `TargetFramework` 匹配
- 目标用户机器的 Windows 版本和运行时分布，是否支持当前发布策略
- 如果走框架依赖发布，是否明确判断了 `RollForward`
- 如果走自包含发布，是否确认无需依赖目标机预装运行时
- 如果选 `net10.0`，是否确认不再需要兼顾部分 `Win10`
