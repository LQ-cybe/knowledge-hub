<!-- rev_id: a67a6f41-ca0b0620-c81d5e79-934d30a4-1dec8afd-1c258bf9-359dfbe9 -->
# 示例问法

## 搜索候选图标

- 帮我找几个“搜索”相关的图标，最好有放大镜风格
- 我要做一个会员中心页面，找一些适合“用户 / 账号 / 个人中心”的图标
- 给我找几个适合“下载、导出 Excel、文件输出”的图标
- 我需要微信、Github、Youtube 这种品牌 logo
- 我需要 React、Python、Docker、MySQL 这种技术栈图标
- 我要一组适合企业后台和控制台的线性图标
- 找一批适合“支付、钱包、订单、购物车”的图标

## AI 优先搜索策略

- 品牌 logo 优先搜：`simple-icons`
- 技术栈 / 开发生态 logo 优先搜：`devicon`
- 通用功能图标优先搜：`tabler-icons,heroicons`
- 企业后台 / 控制台优先搜：`tabler-icons`
- Windows / Office / 企业系统风格优先搜：`fluentui-system-icons`
- 大而全但非默认库：`material-design-icons,remixicon`
- 第一轮先搜 `1 到 2` 个库，不满意再扩到更多库，不要一开始就全库

## 推荐调用示例

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_icons.ps1 -Keyword 搜索,放大镜,查找 -OutputHtml D:\MyProject\temp\search-icons-auto.html
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_icons.ps1 -Keyword github,facebook,logo -Library simple-icons,devicon -OutputHtml D:\MyProject\temp\brand-search.html
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_icons.ps1 -Keyword 搜索,放大镜,查找 -Library tabler-icons,heroicons -OutputHtml D:\MyProject\temp\search-icons.html
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_icons.ps1 -Keyword 用户,账号,会员中心 -Library tabler-icons,heroicons -OutputHtml D:\MyProject\temp\member-icons.html
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_icons.ps1 -Keyword 下载,导出,excel,file -Library tabler-icons,bootstrap-icons -OutputHtml D:\MyProject\temp\export-icons.html
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_icons.ps1 -Keyword react,python,docker,mysql -Library devicon -OutputHtml D:\MyProject\temp\tech-stack-icons.html
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\search_icons.ps1 -Keyword windows,文件,设置,工具 -Library fluentui-system-icons -OutputHtml D:\MyProject\temp\windows-icons.html
```

## 让用户挑选

- 把命中的图标生成一个 HTML 文件给我，我想肉眼选
- 结果页里把组合名、图标原名、分类都列出来
- 我会复制组合名给你，你再帮我拿 SVG
- 搜索结果页的样式和交互如果要调整，优先改 `templates/search-icons-preview.html`
- 先别急着导出，你先给我两组图标颜色建议，我去 HTML 里试一下
- 我给你一张参考图，你帮我判断这套风格更适合什么图标颜色
- 这个后台页面偏企业感，图标默认色和强调色分别建议用什么
- 这个 AI 工具页面偏科技风，图标更适合蓝紫还是蓝青
- 你先在结果页顶部给我的“推荐配色”里点两组试一下，我看看哪组更顺眼

## 直接取 SVG

- 把 `iconpark:02102:Base:search` 这个图标的 SVG 返回给我
- 把 `iconpark:00972:Edit:find` 的原始 SVG 文本给我
- 我已经确认组合名了，直接把 SVG 源码给我
- 我已经从结果页复制了完整参数 JSON，直接按这个参数返回应用样式后的 SVG

## 按要求导出图片

- 把 `heroicons:20:solid:magnifying-glass` 导出成蓝色 `128x128` PNG
- 把 `heroicons:20:solid:magnifying-glass` 做成 `.ico`，尺寸要 `16,32,48,64,128,256`
- 这个图标我要做浏览器插件图标，请给我一组 `16,32,48,128` 的 PNG
- 把这个图标颜色改成 `#22c55e`，同时给我 `svg`、`png`、`ico`
- 把结果直接输出到 `D:\MyProject\assets\`，不要写进 skill 安装目录
- 我已经从结果页复制了完整 JSON，直接按这个样式导出 PNG
- 我已经从结果页复制了完整 JSON，直接按这个样式导出多尺寸 ICO
