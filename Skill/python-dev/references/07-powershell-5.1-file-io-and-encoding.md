<!-- sync_id: fafaa511-968bcc70-949d9429-cfcdfaf4-416c40ad-40a541a9-691d31b9 -->
<!-- flow_ref: fd355d68-91443409-93526c50-c802028d-46a3b8d4-476ab9d0-6ed2c9c0 -->
# PowerShell 5.1 文件读写与编码

这个文档用于约束 `python-dev` 里的 PowerShell 模板、打包脚本、辅助脚本在 Windows PowerShell `5.1` 下的文件读写与编码行为。

重点不是"所有文件都统一 UTF-8 BOM"，而是区分不同场景，避免 AI 在中文内容、模板复制、对外交付时把编码搞乱。

## 一句话原则

- `.ps1` / `.ps1.tmpl` 默认保存为 `UTF-8 with BOM`
- `-Raw` 只表示整文件读取，不负责识别原始编码
- `-Encoding UTF8` 只表示按 UTF-8 解码，不表示自动识别或自动转码
- 对外交付的文本文件是否带 BOM，要看消费方规范
- 做用户项目时，必须通过 `../scripts/bootstrap_project.ps1` 或 `../scripts/instantiate_blueprint.ps1` 生成项目骨架，禁止手动复制 `templates/` 文件夹

## 先分三种场景

### 1. 内部可控文件

特点：

- 由当前 skill 或当前项目自己创建、自己读取
- 编码规则可以统一约定

默认策略：

- `.ps1` / `.ps1.tmpl` 用 `UTF-8 with BOM`
- 内部文本模板读写时显式指定编码

### 2. 外部未知文件

特点：

- 用户给的配置、历史脚本、第三方系统导出的文本
- 原始编码不一定可控

默认策略：

- 不要直接假定 `UTF-8`
- 不要把 `Get-Content -Raw -Encoding UTF8` 当万能读取方案
- 先确认来源编码，必要时先探测 BOM 或文件头

### 3. 对外交付文件

特点：

- 要发给别的程序、团队或用户导入

默认策略：

- 不要统一强制带 BOM
- `JSON` 对外交付时更建议 `UTF-8 without BOM`
- 其他文本按目标程序规范决定

## 模板与 skill 本体的安全规则

### 做用户项目时

- **禁止**直接修改 `python-dev\templates\`，也**禁止**手动复制 `templates\` 目录到工作区
- 唯一合法方式：通过 `../scripts/bootstrap_project.ps1` 或 `../scripts/instantiate_blueprint.ps1` 读取模板、替换占位符、写入用户项目目录
- PS1 脚本执行后，在生成的用户项目文件中编写业务代码，不要回头修改原始 `templates/`

### 维护 skill 本体时

- 只有明确在维护 `python-dev` 本身时，才修改原始 `templates/`
- 修改模板时要保留原文件类型的编码策略，不要"读出来再随手写回"
- 如果模板之间互相引用，优先整体理解后再改，不要只改单个文件导致引用失配

## 推荐写法

### 写 `.ps1`

```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($scriptPath, $content, $utf8Bom)
```

### 写对外 JSON

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$jsonText = $data | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($jsonPath, $jsonText, $utf8NoBom)
```

### 读内部已知 UTF-8 文件

```powershell
$text = Get-Content $path -Raw -Encoding UTF8
```

前提：

- 你已经知道这个文件本来就是 UTF-8

## 禁止误解

- 不要把 `-Raw` 理解成自动识别编码
- 不要把 `-Encoding UTF8` 理解成自动转码
- 不要把"脚本能跑"误认为"对外交付兼容性没问题"
- 不要在用户项目开发时直接改全局 skill 里的原模板

## 出现问题时的排查顺序

1. 先确认是不是 Windows PowerShell `5.1`
2. 再确认当前是内部文件、外部未知文件，还是对外交付文件
3. 如果是 `.ps1`，先检查是否为 `UTF-8 with BOM`
4. 检查读写代码是否显式指定了正确编码
5. 最后再排查业务逻辑
