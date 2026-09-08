<!-- manifest_ref: 0d0c61d0-617d08b1-636b50e8-383b3e35-b69a846c-b7538568-9eebf578 -->
<!-- origin_hash: 8ce18ec5-e090e7a4-e286bffd-b9d6d120-37776b79-36be6a7d-1f061a6d -->
# 打包与 exe 交付

当用户要求“发给别人用”“双击运行”“做成软件”“生成 exe”时，后续 AI 默认进入交付模式，而不是只给源代码。

## 核心原则

- 打包动作由 AI 发起
- **只要进入“发布给别人用 / 双击运行 / 做成软件 / 生成 exe”的交付场景，AI 就必须使用 `PyInstaller` 打包**
- **禁止把 `.bat` / `.cmd` 调用 `.py` 文件当作“已发布的软件”交付给普通用户**
- **禁止用“给用户一个 Python 源码 + 一个启动脚本”冒充 exe 交付**
- 优先复用 `templates/pyinstaller/README.md` 里的标准模板，而不是每次临时拼参数
- 打包后必须检查产物实际存在
- 如条件允许，至少做一次启动级冒烟验证
- 交付时说明怎么运行、配置文件放哪里、数据输出在哪里

## 常见交付形式

- `源码交付`：适合开发者或已装 Python 的团队
- `单文件 exe`：适合依赖不多、追求单文件分发
- `目录交付`：适合依赖多、启动速度优先、资源文件较多

## 强制规则

- 用户只要明确说“发给别人用”“双击运行”“做成软件”“生成 exe”，AI 就必须走 `PyInstaller`
- 对普通用户交付时，`exe` 或 `dist` 目录才算合格交付物；`.bat`、`.cmd`、`python xxx.py`、要求用户自己安装 Python，都不算完成交付
- 除非用户明确要求只交源码给开发者团队，否则不要退回到“脚本 + 启动批处理”的方案
- 如果 AI 想偷懒用 BAT 包一层 Python 启动命令，视为偏离模板，必须改回 `PyInstaller`
- 需要窗口程序时，优先交付 `--windowed` 的 PyInstaller 产物，而不是留一个黑框命令行启动器给用户

## 经验法则

- GUI 程序优先考虑 `--windowed`
- 依赖多或包含资源文件时，优先考虑 `--onedir`
- 用户明确要求一个文件时，再优先尝试 `--onefile`
- GUI 程序如果需要自定义图标，优先把图标放到 `assets/`，并通过 `scripts/build_windows_exe.ps1 -IconPath ...` 传入
- 如果用户给的是 `PNG` 图标，默认由 AI 走脚本自动转换为 `ICO`，不要让用户自己转格式
- 打包产物较大是正常现象，不要为了体积盲目删依赖

## 推荐命令

```powershell
uv add --dev pyinstaller
uv run pyinstaller --noconfirm --clean --onefile src\app_name\main.py
uv run pyinstaller --noconfirm --clean --windowed --onedir src\app_name\main.py
```

## 推荐脚本入口

优先使用根目录脚本，而不是让 AI 每次临时手写命令：

```powershell
& .\scripts\build_windows_exe.ps1 `
  -ProjectRoot . `
  -EntryScript .\src\app_name\main.py `
  -AppName app_name `
  -BuildMode onedir `
  -Windowed `
  -IconPath .\assets\app_icon.png
```

对应模板入口：`../templates/pyinstaller/README.md`

## 打包前检查

- 入口脚本能运行
- 资源文件路径不是写死的开发路径
- `.env`、配置文件、图标文件的读取路径已考虑打包后场景
- 如果用户给了 PNG 图标，已规划好 `PNG -> ICO -> PyInstaller --icon -> 运行时 assets/` 这一整条链路
- 输出目录已明确

## 打包后检查

- `dist` 目录下确实有目标产物
- 名称符合用户理解，不要是一串临时文件名
- 如果是 GUI，启动后不会弹出多余控制台
- 如果是 GUI，任务栏、窗体左上角和 `EXE` 文件图标尽量保持一致
- 如果是文件处理工具，能完成一次最小样例处理

## `onefile` 图标回归验证

- 如果刚改过 `build_windows_exe.ps1`、GUI 图标逻辑或 `templates/pyinstaller/README.md`，优先执行 `scripts/verify_pyinstaller_onefile_icon.ps1`
- 这支脚本会自动实例化临时 `gui-exe` 项目，使用 `onefile + windowed` 重新打包，并通过启动日志确认窗口图标资源在运行时也能加载
- 默认会优先尝试技能内置的 `assets/pyinstaller-smoke-icon.png` 作为验证图标；如需替换，可传 `-IconSourcePath`

## 交付给普通用户时至少包含

- `exe` 或整个 `dist` 目录
- `README` 或使用说明
- `dist` 内可直接读取的 `.env`，或一个用户无需猜测如何改名的明确配置文件
- 如果存在授权约束，补 `LICENSE_NOTICE.txt` 与授权追踪文件
- 样例输入文件或最小演示说明

## 配置文件交付原则

- 源码仓库中保留 `.env.example` 作为模板是合理的
- 但发给普通用户的 `dist` 目录，默认应提供 `.env`
- 程序启动时要显式用 `python-dotenv` 加载 `.env`，不要只把文件复制进 `dist`
- 打包后默认从可执行文件所在目录读取 `.env`
- 如果必须交付模板文件，也要在说明文档中明确写清楚“先复制或重命名为 `.env` 再使用”
- 不要让普通用户自己猜 `.env.example` 是否需要改名

## 授权分发建议

- 发给第三方使用时，优先为每个接收者设置独立 `LicenseId`
- 如有需要，可同时写入 `WatermarkText`，便于在 `dist` 中留下接收者标识
- `scripts/build_windows_exe.ps1` 在提供 `LicenseId` 或 `WatermarkText` 时，会自动写入 `LICENSE_NOTICE.txt` 与 `distribution-license.json`
- 可见说明文件用于直接告知“禁止二次分发”，追踪文件用于保留拆段编码后的授权声明
- skill 本体需要按授权对象分发时，优先使用根目录的 `package_skill_distribution.ps1`

## 交付清单与用户移交

### 最终交付物清单

1. 源代码目录
2. `pyproject.toml`、`uv.lock`
3. 源码仓库中的 `.env.example`
4. `README` 或使用说明
5. `dist` 目录或 `exe`
6. 样例输入文件和样例输出说明
7. 如果有日志目录、配置目录，也要说明位置
8. 如果有授权约束，也要补 `LICENSE_NOTICE.txt` 或对应授权说明

### 普通用户场景特别提醒

- 不要把"如何运行终端命令"写成主要说明
- 不要把关键步骤藏在代码注释里
- 不要默认用户知道虚拟环境、依赖、入口模块这些概念
- 说明文档优先写"点哪里、选什么、结果在哪"

## 不要这样做

- 不要只告诉用户“你自己运行 pyinstaller”
- 不要只生成构建命令，不执行
- 不要把 `dist` 目录里哪个文件要发给别人说得含糊不清
- 不要跳过打包后的存在性验证
- 不要用 `.bat` / `.cmd` 调 `python xxx.py` 冒充“可发布软件”
- 不要让普通用户先装 Python、再双击批处理脚本来运行程序
- 不要在已经进入 exe 交付场景时，绕开 `PyInstaller` 模板另搞一套发布方式
