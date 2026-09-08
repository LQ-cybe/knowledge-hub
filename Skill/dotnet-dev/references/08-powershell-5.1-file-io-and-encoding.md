<!-- commit_ref: e391932a-8fe0fa4b-8df6a212-d6a6cccf-58077696-59ce7792-70760782 -->
<!-- schema_v: 2d864ace-41f723af-43e17bf6-18b1152b-9610af72-97d9ae76-be61de66 -->
# PowerShell 5.1 文件读写与编码

这个文档专门给后续 AI 处理 Windows PowerShell `5.1` 的文件读写与编码问题使用。

目标不是泛泛讲“编码知识”，而是让 AI 在写 `.ps1`、读取外部文本、生成交付文件时，不要把几种完全不同的场景混成一套写法。

## 一句话原则

- `.ps1` 文件默认保存为 `UTF-8 with BOM`
- `-Raw` 只表示整文件读取，不负责识别原始编码
- `-Encoding UTF8` 只表示按 UTF-8 解码，不表示自动识别文件编码
- 写文件是否带 BOM，要看是内部文件、外部输入还是对外交付
- 中文报错先查编码，再查逻辑

## 为什么 PowerShell 5.1 容易踩坑

Windows PowerShell `5.1` 不是以“默认所有内容都按 UTF-8 处理”为前提设计的。

最常见的坑是：

1. AI 生成了带中文的 `.ps1`
2. 文件被保存成 `UTF-8 without BOM`
3. PowerShell `5.1` 用系统默认编码去解析
4. 结果出现乱码、字符串异常、甚至语法错误

所以对 `.ps1` 文件来说，重点不只是“内容对不对”，还要看“文件本身是怎么编码保存的”。

## 先分三种场景

后续 AI 处理文件读写前，先判断当前属于哪一类：

### 1. 内部可控文件

特点：

- 文件由当前项目自己创建、自己读取
- 编码规则可以统一约定
- 例如：`.ps1` 模板、项目内部 `.xml`、内部配置 `.txt`

默认策略：

- 可以统一指定编码
- 读写都显式写编码
- `.ps1` 默认用 `UTF-8 with BOM`

### 2. 外部未知文件

特点：

- 文件由用户提供、第三方系统导出、历史项目遗留
- 原始编码不一定可控
- 例如：用户给的 `.txt`、外部系统吐出的 `.csv/.json/.xml`

默认策略：

- 不要直接假设它是 UTF-8
- 不要看见文本文件就直接 `Get-Content -Encoding UTF8`
- 先确认来源编码，或先做编码探测，再决定怎么读

### 3. 对外交付文件

特点：

- 文件要发给别的程序、别的团队、第三方系统使用
- 兼容性优先于“本机好用”

默认策略：

- 不要统一强制写成 `UTF-8 with BOM`
- 要按目标消费者的规范决定是否带 BOM
- `JSON` 对外交付时更推荐 `UTF-8 without BOM`

## 文件类型推荐编码

| 文件类型 | 内部可控 | 对外交付 | 说明 |
|----------|----------|----------|------|
| `.ps1` | `UTF-8 with BOM` | 一般仍用 `UTF-8 with BOM` | 对 PowerShell `5.1` 最稳 |
| `.json` | `UTF-8`，可按内部约定 | 优先 `UTF-8 without BOM` | 不要默认对外带 BOM |
| `.xml` | `UTF-8 with BOM` | 视对方规范而定 | 多数 Windows 场景兼容较好 |
| `.txt` | 内部可用 `UTF-8 with BOM` | 视消费者决定 | 跨平台交换要谨慎 |
| `.cs` | `UTF-8 with BOM` | 不属于本文重点 | 与 Windows 开发工具链更一致 |

## `.ps1` 的默认写法

### 1. 创建编码器

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
```

### 2. 写 PowerShell 文件

```powershell
$content = @'
Write-Host "中文测试"
$name = "演示脚本"
'@

[System.IO.File]::WriteAllText($scriptPath, $content, $utf8Bom)
```

### 3. 改写已有 PowerShell 文件

前提：

- 这个文件本来就是项目内部可控文件
- 你已经知道它应该按什么编码保存

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$content = Get-Content $scriptPath -Raw -Encoding UTF8
[System.IO.File]::WriteAllText($scriptPath, $content, $utf8Bom)
```

注意：

- 这里的 `-Encoding UTF8` 不是自动识别
- 如果原文件编码未知，这种写法可能先把内容读错，再按正确编码写回，等于把乱码固化

## 读取文件的默认流程

## 核心提醒

- `-Raw` 只是不按行拆分，直接返回一个字符串
- `-Encoding UTF8` 只是告诉 PowerShell “按 UTF-8 解码”
- 它不会先判断原文件到底是 `UTF-8`、`GBK`、`ANSI`、`UTF-16`

### A. 内部可控文件

前提：

- 文件是本项目自己生成的
- 编码规则已知

#### 读 JSON

```powershell
$jsonText = Get-Content $jsonPath -Raw -Encoding UTF8
$jsonObject = $jsonText | ConvertFrom-Json
```

#### 读 TXT

```powershell
$text = Get-Content $txtPath -Raw -Encoding UTF8
```

#### 读 XML

```powershell
$xmlText = Get-Content $xmlPath -Raw -Encoding UTF8
[xml]$xml = $xmlText
```

### B. 外部未知文件

前提：

- 文件来源未知
- 不确定是不是 UTF-8

默认不要直接这样写：

```powershell
Get-Content $path -Raw -Encoding UTF8
```

应该先做这几步：

1. 先确认文件来源
2. 先看对方系统有没有导出编码说明
3. 如果没有说明，再做 BOM / 编码探测
4. 最后再决定 `-Encoding`

## 写文件的默认流程

### 核心提醒

- 写文件是否带 BOM，不是只看“PowerShell 5.1 方不方便”
- 还要看这个文件后面给谁读

### A. 内部可控文件

适合：

- 项目内部 `.ps1`
- 项目内部文本模板
- 明确只给 Windows / PowerShell `5.1` / 自家工具链消费的文件

#### 写 PowerShell 脚本

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($scriptPath, $content, $utf8Bom)
```

#### 写 XML

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$writer = New-Object System.IO.StreamWriter($xmlPath, $false, $utf8Bom)
$xml.Save($writer)
$writer.Close()
```

#### 写内部 TXT

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($txtPath, $content, $utf8Bom)
```

### B. 对外交付文件

适合：

- 给第三方程序读的输出文件
- 要打包分发的导出结果
- 用户会拿去给别的系统导入的文件

#### 写对外 JSON

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$jsonText = $data | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($jsonPath, $jsonText, $utf8NoBom)
```

#### 写对外 TXT

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($txtPath, $content, $utf8NoBom)
```

#### 写对外 XML

```powershell
# XML 是否带 BOM 要看目标系统要求，不要统一强制
$xml.Save($xmlPath)
```

注意：

- 对外交付时，默认优先考虑目标系统兼容性
- 如果对方规范明确要求 BOM，就按对方要求来
- 如果没有明确要求，不要因为“PowerShell 5.1 里看着顺手”就统一加 BOM

## 最容易犯的错误

### 错误 1：把 `-Raw` 当成“自动识别编码”

现象：

- 以为只要 `-Raw` 就能安全读取任何文本文件

纠正：

- `-Raw` 只负责整文件读取
- 编码判断仍然取决于 `-Encoding`

### 错误 2：把 `-Encoding UTF8` 当成“自动转 UTF-8”

现象：

- 以为“读到 Raw 后再写回”就自动把任何文件变成 UTF-8 了

纠正：

- 如果原文件不是 UTF-8，第一步就已经读错了
- 后面再写成 UTF-8，只会把错误内容固化

### 错误 3：所有文件统一写 `UTF-8 with BOM`

现象：

- 内部脚本没问题，但发给第三方的 JSON / TXT 出现兼容性问题

纠正：

- `.ps1` 默认 BOM
- `JSON` 对外交付默认更建议无 BOM
- 其他文件按消费方规范判断

### 错误 4：只改内容，不管文件本身编码

现象：

- 脚本逻辑看着没问题，但 PowerShell `5.1` 解析异常

纠正：

- 先检查脚本文件本身是不是 `UTF-8 with BOM`

## 推荐修复顺序

1. 先确认是不是 Windows PowerShell `5.1`
2. 再确认当前处理的是内部文件、外部未知文件，还是对外交付文件
3. 如果是 `.ps1`，先检查文件是不是 `UTF-8 with BOM`
4. 检查 `Get-Content` / `Set-Content` / 输出逻辑有没有显式编码
5. 如果输入文件来源未知，先确认原始编码，不要直接假设 UTF-8
6. 最后再排查业务逻辑

## 给后续 AI 的固定规则

- 只要新建或改写 `.ps1`，默认优先考虑 `UTF-8 with BOM`
- 只要输入文件来源未知，不要直接假设 `-Encoding UTF8`
- 只要输出文件是给第三方程序消费，不要默认统一写 BOM
- 只要用户说“PowerShell 脚本突然乱码 / 不认中文 / 终端显示奇怪错误”，优先看本页
- 在 Trae / Cursor 中编辑 `.ps1` 后，如果执行结果异常，先检查文件编码再继续改代码
