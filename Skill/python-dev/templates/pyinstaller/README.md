<!-- origin_hash: dd1ad4a4-b16bbdc5-b37de59c-e82d8b41-668c3118-6745301c-4efd400c -->
<!-- rev_id: 95ce015f-f9bf683e-fba93067-a0f95eba-2e58e4e3-2f91e5e7-062995f7 -->
# PyInstaller Windows 打包模板

这个模板给后续 AI 一个统一做法：用 `uv` 安装依赖，用 `scripts/build_windows_exe.ps1` 发起打包，并把 GUI 图标处理沉淀为固定流程。

## 适用场景

- 用户要“做成 exe”“发给别人双击运行”
- 用户提供了 `PNG` 或 `ICO` 图标，希望打包后显示在任务栏、窗体左上角和发布的 `EXE` 文件上
- 项目已经通过 `scripts/bootstrap_project.ps1` 或 `scripts/instantiate_blueprint.ps1` 生成骨架

## 标准流程

1. 先运行 `scripts/ensure_uv_env.ps1`
2. 用 `uv add` / `uv add --dev` 管理依赖
3. GUI 项目把图标放进 `assets/` 目录
4. 使用 `scripts/build_windows_exe.ps1` 打包，而不是让用户手写 `pyinstaller` 命令
5. 打包后检查 `dist/` 是否存在、程序是否能启动、说明文档是否齐全
6. 如果要回归验证 `onefile + PNG 图标`，优先执行 `scripts/verify_pyinstaller_onefile_icon.ps1`

## 图标约定

- 推荐路径：`assets/app_icon.png` 或 `assets/app_icon.ico`
- 如果用户只给了 `PNG`，不要要求用户自己先转 `ICO`
- `scripts/build_windows_exe.ps1` 会自动处理：
  - `uv add --dev pyinstaller`
  - 如传入的是 `PNG`，额外执行 `uv add --dev pillow`
  - 将 `PNG` 转成 `ICO`
  - 用转换后的 `ICO` 传给 `PyInstaller --icon`
  - 把 `app_icon.png` / `app_icon.ico` 一起带入打包产物里的 `assets/`
- `gui-exe` 蓝图会在运行时优先读取 `assets/` 图标资源，用于同步窗口图标

## 推荐命令模板

```powershell
& .\scripts\build_windows_exe.ps1 `
  -ProjectRoot . `
  -EntryScript .\src\app_name\main.py `
  -AppName MyTool `
  -BuildMode onedir `
  -Windowed `
  -IconPath .\assets\app_icon.png
```

## AI 执行要点

- 不要让零基础用户自己研究 `pyinstaller` 参数
- 不要把 `PNG -> ICO` 转换工作转交给用户
- 不要只保证 `EXE` 图标，不处理窗口运行时图标
- 优先让 GUI 蓝图代码和打包脚本使用同一份 `assets/` 图标来源

## onefile 冒烟验证

如果刚修改了图标逻辑、`build_windows_exe.ps1` 或 GUI 蓝图，优先跑：

```powershell
& .\scripts\verify_pyinstaller_onefile_icon.ps1
```

这支脚本会自动：

- 运行 `ensure_uv_env.ps1`
- 实例化临时 `gui-exe` 蓝图项目
- 默认使用技能内置的 `assets/pyinstaller-smoke-icon.png` 作为验证图标
- 调用 `build_windows_exe.ps1` 以 `onefile` 模式打包
- 启动生成的 `EXE`
- 从日志里检查“窗口图标已加载”“GUI 已初始化完成”

## 配套入口

- 打包规则：`references/05-packaging-and-exe-delivery.md`
- 全流程工作流：`references/workflows/development-lifecycle.md`
- 实际打包脚本：`scripts/build_windows_exe.ps1`
- onefile 图标冒烟脚本：`scripts/verify_pyinstaller_onefile_icon.ps1`
- GUI 蓝图：`templates/project-blueprints/gui-exe`
