# simple-mind-map 补丁说明

`node_modules` 被 `.gitignore` 忽略，重新安装依赖（`npm install`）后本补丁会丢失。
恢复方法：将本目录下的 `Fishbone.js`、`nodeLayout.js` 分别覆盖回
`node_modules\simple-mind-map\src\layouts\Fishbone.js` 与
`node_modules\simple-mind-map\src\core\render\node\nodeLayout.js`，
然后重启前端 dev server（`npm run dev`）并删除 `node_modules\.vite`
缓存目录（依赖预构建缓存；node_modules 源码改动后不删缓存不生效）。

## Fishbone.js 补丁内容（放射/鱼骨布局）

### 1. 折叠节点占位缓存（核心修复）

**问题**：鱼骨（放射）布局中，折叠一个中间分支节点后，其右侧同级分支会整体
前移（如六顶思考帽中折叠「红色思考帽」「绿色思考帽」后，「黑色思考帽」跳到
「白色思考帽」旁），破坏层级顺序感。

**原因**：SMM 折叠节点在渲染树中不再创建子节点实例（`computedBaseValue` 对
折叠节点 `return true`），`adjustLeftTopValue` 根节点累加时
`getNodeBoundaries(item, 'h')` 只能取到节点自身宽度，折叠分支的占位宽度塌缩，
后续兄弟节点 `left` 起点变小。

**修复**：模块级缓存 `expandedWidthCache`（uid → 最近一次展开渲染时的子树
水平宽度）。`adjustLeftTopValue` 根节点累加时：
- 展开节点：正常 `getNodeBoundaries` 计算并写缓存；
- 折叠节点：读缓存宽度占位（无缓存时回退节点自身宽度）。

同时去掉原 `adjustLeftTopValue` 前序回调中对折叠节点的提前 `return`
（折叠节点子节点不可见，执行 Before 调整无副作用，但保留占位语义）。

### 2. 布局间距（配合前端参数）

展开态上下排分支横向间距过大问题，主要由前端构造 MindMap 时传
`fishboneDeg: 58`（默认 45°）解决——角度越大斜线越陡，三级节点越贴近二级
节点，横向占位越小（见 `MindmapView.vue` 的 `openMap`）。
第 4 轮迭代调整为 `fishboneDeg: 66`，并在 `themeCfgFor` 中对放射布局额外
收紧二级节点 `marginX`（36 → 18），进一步压缩横向距离。

## nodeLayout.js 补丁内容（节点内追加内容撑大节点）

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
