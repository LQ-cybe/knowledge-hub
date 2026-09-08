<!-- cache_key: 094fac9b-653ec5fa-67289da3-3c78f37e-b2d94927-b3104823-9aa83833 -->
<!-- dist_id: b37e8277-df0feb16-dd19b34f-8649dd92-08e867cb-092166cf-209916df -->
# GUI exe 蓝图

适用场景：

- 需要普通用户双击运行
- 需要文件选择、按钮、状态提示
- 需要后续打包成 `exe`

蓝图目标：

- 核心逻辑与界面分层
- 保留最小可测试的业务函数
- 便于使用 `PyInstaller` 打包

建议搭配：

- `references/05-packaging-and-exe-delivery.md`
- `references/06-common-scenarios.md`
- `templates/pyinstaller/README.md`
- `scripts/build_windows_exe.ps1`

图标约定：

- 如果用户提供 PNG 图标，优先放到 `assets/app_icon.png`
- 打包时把 `-IconPath .\assets\app_icon.png` 传给 `scripts/build_windows_exe.ps1`
- GUI 模板会在运行时读取 `assets/` 中的图标资源，配合 PyInstaller 的 `--icon`，尽量同步显示在任务栏、窗体左上角和发布的 EXE 文件上
