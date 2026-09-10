import { degToRad } from '../utils/'

// ============================================================================
// knowledge-hub 补丁版 fishboneUtils（基于 simple-mind-map 0.14.0-fix.3 官方原版）
//
// 补丁内容（2026-09-10，用户需求：子节点统一为 TEXT格式化 分支的显示布局）：
// 1. 二级节点的子节点（三层）不再沿鱼骨刺对角线串排（旧布局相邻子节点随累计高度
//    不断右移，横向拉得很开、且与更深层级的竖列风格不一致），改为「紧凑竖列 +
//    恒定左缘」，与三层节点的子列（TEXT格式化 风格）完全一致。
// 2. 二级节点的连线由对角斜刺改为竖干线（与更深层级一致），配合 Fishbone.js 的
//    水平短线构成肘形连接。
// 3. renderLine 的二级分支同步改为竖干线（M x,top+height → x,miny 等）。
//
// 同步方式：修改本文件后需复制到
//   web/node_modules/simple-mind-map/src/layouts/fishboneUtils.js
// 并清 node_modules/.vite 缓存、重启 vite dev server（dev server 会缓存
// node_modules 预构建结果，仅删 .vite 不重启不生效）。
// ============================================================================

export default {
  top: {
    renderExpandBtn({
      node,
      btn,
      expandBtnSize,
      translateX,
      translateY,
      width,
      height
    }) {
      if (node.parent && node.parent.isRoot) {
        btn.translate(
          width * 0.3 - expandBtnSize / 2 - translateX,
          -expandBtnSize / 2 - translateY
        )
      } else {
        btn.translate(
          width * 0.3 - expandBtnSize / 2 - translateX,
          height + expandBtnSize / 2 - translateY
        )
      }
    },
    renderLine({
      node,
      line,
      top,
      x,
      lineLength,
      height,
      expandBtnSize,
      maxy,
      miny,
      ctx
    }) {
      if (node.parent && node.parent.isRoot) {
        // 补丁：二级节点子列在其上方，竖干线必须从节点顶边贯通到「最上方（最远）」
        // 子节点的中线（miny），否则上方远处的子节点只有横短线、缺竖线连接而悬空。
        // （旧版误用 maxy = 最靠近父节点的子节点，导致除第一个外的子节点全部悬空）
        line.plot(
          ctx.transformPath(`M ${x},${top} L ${x},${miny}`)
        )
      } else {
        line.plot(
          ctx.transformPath(
            `M ${x},${top + height + expandBtnSize} L ${x},${maxy}`
          )
        )
      }
    },
    computedLeftTopValue({ layerIndex, node, ctx }) {
      if (layerIndex >= 1 && node.children) {
        // 遍历三级及以下节点的子节点
        let marginY = ctx.getMarginY(layerIndex + 1)
        let startLeft = node.left + node.width * ctx.childIndent
        let totalTop =
          node.top +
          node.height +
          (ctx.getNodeActChildrenLength(node) > 0 ? node.expandBtnSize : 0) +
          marginY
        node.children.forEach(item => {
          item.left = startLeft
          item.top += totalTop
          totalTop +=
            item.height +
            (ctx.getNodeActChildrenLength(item) > 0 ? item.expandBtnSize : 0) +
            marginY
        })
      }
    },
    adjustLeftTopValueBefore({ node, parent, ctx, layerIndex }) {
      // 调整top
      let len = node.children.length
      let marginY = ctx.getMarginY(layerIndex + 1)
      // 调整三级及以下节点的top
      if (parent && !parent.isRoot && len > 0) {
        let totalHeight = node.children.reduce((h, item) => {
          return (
            h +
            item.height +
            (ctx.getNodeActChildrenLength(item) > 0 ? item.expandBtnSize : 0) +
            marginY
          )
        }, 0)
        ctx.updateBrothersTop(node, totalHeight)
      }
    },
    adjustLeftTopValueAfter({ parent, node, ctx }) {
      // 补丁：将二级节点的子节点移到上方——紧凑竖列、恒定左缘（不再沿对角线漂移）。
      // 每个子节点的底边贴着前一个子树块的顶部减 marginY；子树块高度用其后代真实
      // 已计算出的位置求最小 top 精确得出（此时后代 adjust 已完成，位置可用）。
      if (parent && parent.isRoot) {
        let marginY = ctx.getMarginY(node.layerIndex + 1)
        let startLeft = node.left + node.width * ctx.childIndent
        let cursorBottom = node.top - marginY
        node.children.forEach(item => {
          const hasChildren = ctx.getNodeActChildrenLength(item) > 0
          const _top = item.top
          // 子树块相对偏移（后代坐标此刻仍是旧值，随后经 updateChildrenPro 整体平移）：
          // upExtent = 子树在自身 top 之上的延伸量；downExtent = 自身 top 之下的延伸量（含自身高度）
          let minTop = Infinity
          let maxBottom = -Infinity
          const walk = n => {
            if (n.top < minTop) minTop = n.top
            const b = n.top + n.height
            if (b > maxBottom) maxBottom = b
            n.children.forEach(walk)
          }
          walk(item)
          const upExtent = _top - minTop
          const downExtent = maxBottom - _top
          item.left = startLeft
          // 块底（含向节点方向延伸的深层子树）不得越过 cursorBottom
          item.top = cursorBottom - downExtent - (hasChildren ? item.expandBtnSize : 0)
          ctx.updateChildrenPro(item.children, { top: item.top - _top })
          // 下一个子节点的块底 = 本子树块顶（top − upExtent）再留一个 marginY
          cursorBottom = item.top - upExtent - marginY
        })
      }
    }
  },
  bottom: {
    renderExpandBtn({
      node,
      btn,
      expandBtnSize,
      translateX,
      translateY,
      width,
      height
    }) {
      if (node.parent && node.parent.isRoot) {
        btn.translate(
          width * 0.3 - expandBtnSize / 2 - translateX,
          height + expandBtnSize / 2 - translateY
        )
      } else {
        btn.translate(
          width * 0.3 - expandBtnSize / 2 - translateX,
          -expandBtnSize / 2 - translateY
        )
      }
    },
    renderLine({ node, line, top, x, lineLength, height, miny, maxy, ctx }) {
      if (node.parent && node.parent.isRoot) {
        // 补丁：二级节点子列在其下方，竖干线必须从节点底边贯通到「最下方（最远）」
        // 子节点的中线（maxy），否则下方远处的子节点只有横短线、缺竖线连接而悬空。
        // （旧版误用 miny = 最靠近父节点的子节点，导致除第一个外的子节点全部悬空）
        line.plot(ctx.transformPath(`M ${x},${top + height} L ${x},${maxy}`))
      } else {
        line.plot(ctx.transformPath(`M ${x},${top} L ${x},${miny}`))
      }
    },
    computedLeftTopValue({ layerIndex, node, ctx }) {
      let marginY = ctx.getMarginY(layerIndex + 1)
      if (layerIndex === 1 && node.children) {
        // 遍历二级节点的子节点
        let startLeft = node.left + node.width * ctx.childIndent
        let totalTop =
          node.top +
          node.height +
          (ctx.getNodeActChildrenLength(node) > 0 ? node.expandBtnSize : 0) +
          marginY

        node.children.forEach(item => {
          item.left = startLeft
          item.top =
            totalTop +
            (ctx.getNodeActChildrenLength(item) > 0 ? item.expandBtnSize : 0)
          totalTop +=
            item.height +
            (ctx.getNodeActChildrenLength(item) > 0 ? item.expandBtnSize : 0) +
            marginY
        })
      }
      if (layerIndex > 1 && node.children) {
        // 遍历三级及以下节点的子节点
        let startLeft = node.left + node.width * ctx.childIndent
        let totalTop =
          node.top -
          (ctx.getNodeActChildrenLength(node) > 0 ? node.expandBtnSize : 0) -
          marginY
        node.children.forEach(item => {
          item.left = startLeft
          item.top = totalTop - item.height
          totalTop -=
            item.height +
            (ctx.getNodeActChildrenLength(item) > 0 ? item.expandBtnSize : 0) +
            marginY
        })
      }
    },
    adjustLeftTopValueBefore({ node, ctx, layerIndex }) {
      // 调整top
      let marginY = ctx.getMarginY(layerIndex + 1)
      let len = node.children.length
      if (layerIndex > 2 && len > 0) {
        let totalHeight = node.children.reduce((h, item) => {
          return (
            h +
            item.height +
            (ctx.getNodeActChildrenLength(item) > 0 ? item.expandBtnSize : 0) +
            marginY
          )
        }, 0)
        ctx.updateBrothersTop(node, -totalHeight)
      }
    },
    adjustLeftTopValueAfter({ parent, node, ctx }) {
      // 补丁：二级节点的子节点向下排——紧凑竖列、恒定左缘（不再沿对角线漂移）。
      // 每个子节点的顶边贴着前一个子树块的底部加 marginY；子树块高度用其后代
      // 真实位置求最大底边精确得出（此时后代 adjust 已完成，位置可用）。
      if (parent && parent.isRoot) {
        let marginY = ctx.getMarginY(node.layerIndex + 1)
        let startLeft = node.left + node.width * ctx.childIndent
        let cursorTop = node.top + node.height + marginY
        node.children.forEach(item => {
          const hasChildren = ctx.getNodeActChildrenLength(item) > 0
          const _top = item.top
          // 子树块相对偏移：upExtent = 子树在自身 top 之上的延伸量（深层子列向上生长，
          // 如 TEXT格式化 的公式子列），放置时必须整体下移让出该空间，否则顶到上级节点
          let minTop = Infinity
          let maxBottom = -Infinity
          const walk = n => {
            if (n.top < minTop) minTop = n.top
            const b = n.top + n.height
            if (b > maxBottom) maxBottom = b
            n.children.forEach(walk)
          }
          walk(item)
          const upExtent = _top - minTop
          const downExtent = maxBottom - _top
          item.left = startLeft
          item.top = cursorTop + upExtent + (hasChildren ? item.expandBtnSize : 0)
          ctx.updateChildrenPro(item.children, { top: item.top - _top })
          // 下一个子节点的块顶 = 本子树块底（top + downExtent）再留一个 marginY
          cursorTop = item.top + downExtent + marginY
        })
      }
    }
  }
}
