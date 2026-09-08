# simple-mind-map 补丁说明

`node_modules` 被 `.gitignore` 忽略，重新安装依赖（`npm install`）后本补丁会丢失。
恢复方法：将本目录下的 `Fishbone.js`、`fishboneUtils.js`、`nodeLayout.js` 分别覆盖回
`node_modules\simple-mind-map\src\layouts\Fishbone.js`、
`node_modules\simple-mind-map\src\layouts\fishboneUtils.js`、
`node_modules\simple-mind-map\src\core\render\node\nodeLayout.js`，
然后重启前端 dev server（`npm run dev`）并删除 `node_modules\.vite`
缓存目录（依赖预构建缓存；node_modules 源码改动后不删缓存不生效）。

> **第 6 轮（2026-09-08）重要变更**：第 5 轮"子树紧凑拼接 + 父中心→子中心直连 path"
> 的激进 patch 经用户实测被否决（放射图线条方向错乱）。本轮**回退 `Fishbone.js` /
> `fishboneUtils.js` 至官方 0.14.0-fix.3 原版**，只保留下述两个最小、可控的紧凑化修改。

## Fishbone.js 补丁内容（放射/鱼骨布局，第 6 轮精简版）

### 1. 二级节点横向紧凑（去掉子树宽二次平移）

**问题**：官方 `adjustLeftTopValue()` 对根节点的子节点做二次平移——
`item.left += topTotalLeft`，其中 `topTotalLeft` 累加的是**整棵子树的水平宽度**
（`getNodeBoundaries(item,'h')` 的 right-left）。结果二级节点间距 =
`computedLeftTopValue` 的紧凑排布（前兄弟宽 + second.marginX）**再叠加**上一棵
子树的水平宽度 → 短文本节点后出现大片横向空白（六顶思考帽实测间距 236px）。

**修复**：去掉二次累加（`topTotalLeft`/`bottomTotalLeft` 恒为 0，仅保留
`maxx` 计算），二级节点位置完全由 `computedLeftTopValue` 决定 =
「前兄弟自身宽 + second.marginX」。间距从 236px 压到约 122px。

**注意**：这放弃了官方的"子树防重叠"平移。浅层树（≤3 级）子节点在二级节点
下方垂直展开，与兄弟节点矩形垂直错开、视觉不重叠；深层宽子树可能贴近兄弟，
届时可恢复 max(自身宽+marginX, 子树水平宽) 作为增量（见 Git 历史上一版）。

### 2. 折叠节点占位缓存（沿袭第 5 轮，保留）

折叠中间分支后右侧同级会整体前移的问题仍需占位缓存 `expandedWidthCache`
（uid → 展开时子树水平宽度）。第 6 轮回退时该机制已并入本文件，展开/折叠
行为正常。

### 3. 布局间距（配合前端参数）

横向间距由前端控制：`MindmapView.vue` 实例化 `fishboneDeg: 72`（角度越陡
三级节点越贴近），`themeCfgFor()` 对放射布局覆盖 `second.marginX: 6`
（官方默认 100 是横向空白主因）。**切布局时必须重设 themeConfig**
（`onLayoutChange` 内已补 `mm.setThemeConfig(themeCfgFor(...))`），否则
marginX 覆盖不生效。

## fishboneUtils.js 补丁内容（第 6 轮精简版）

官方 `adjustLeftTopValueAfter` 会把二级节点的 `left` 用角度公式重算：
`node.left + node.width*indent + 子树高/tan(fishboneDeg)` —— 这同样会造成
大空白且与紧凑排布冲突。**修复**：只保留 top 调整（子节点移到二级节点上方/
下方），不再覆盖 left（二级节点横向保持 `computedLeftTopValue` 的紧凑位置）。

## nodeLayout.js 补丁内容（节点内追加内容撑大节点，沿袭第 4 轮）

**用途**：幕布式节点描述渲染在**节点矩形内部底部**（而非节点外浮层）。
SMM 通过 `addCustomContentToNode.create` 钩子把自定义 HTML 内容追加进节点
group（`nodeLayout.js` 的 `layout()` 中自动创建 foreignObject 并调用
`addCustomContentToNode.handle` 定位）。

**问题**：`getNodeRect()`（决定节点宽高）原本不计入追加内容尺寸，描述会
溢出节点矩形。

**修复**：`getNodeRect` 返回值中，宽取
`max(原宽, 追加内容宽 + 内边距)`、高在原有高度上累加追加内容高度，使节点
矩形自动撑大、描述完整显示在矩形内部（前端 `addCustomContentToNode.create`
返回 `{ el, width, height }`，`handle` 将 foreignObject 平移到节点内底部）。
