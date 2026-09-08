# simple-mind-map 补丁说明

`node_modules` 被 `.gitignore` 忽略，重新安装依赖（`npm install`）后本补丁会丢失。
恢复方法：将本目录下的 `Fishbone.js` 覆盖回
`node_modules\simple-mind-map\src\layouts\Fishbone.js`，然后重启前端 dev server
（`npm run dev`）并删除 `node_modules\.vite` 缓存目录（依赖预构建缓存）。

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
