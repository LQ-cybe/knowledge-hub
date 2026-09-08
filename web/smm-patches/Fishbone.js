import Base from './Base'
import { walk, asyncRun, degToRad, getNodeIndexInNodeList } from '../utils'
import { CONSTANTS } from '../constants/constant'
import utils from './fishboneUtils'
import { SVG } from '@svgdotjs/svg.js'
import { shapeStyleProps } from '../core/render/node/Style'

// 折叠占位宽度缓存：uid -> 该节点最近一次展开渲染时的子树水平宽度。
// 折叠后渲染树中不再包含子节点实例，无法计算子树宽度，用此缓存保持兄弟节点位置稳定，
// 避免鱼骨（放射）布局折叠中间分支后右侧分支整体前移、破坏层级顺序。
const expandedWidthCache = new Map()

//  鱼骨图
class Fishbone extends Base {
  //  构造函数
  constructor(opt = {}, layout) {
    super(opt)
    this.layout = layout
    this.indent = 0.3
    this.childIndent = 0.5
    this.fishTail = null
    this.maxx = 0
    this.headRatio = 1
    this.tailRatio = 0.6
    this.paddingXRatio = 0.3
    this.fishHeadPathStr =
      'M4,181 C4,181, 0,177, 4,173 Q 96.09523809523809,0, 288.2857142857143,0 L 288.2857142857143,354 Q 48.047619047619044,354, 8,218.18367346938777 C8,218.18367346938777, 6,214.18367346938777, 8,214.18367346938777 L 41.183673469387756,214.18367346938777 Z'
    this.fishTailPathStr =
      'M 606.9342905223708 0 Q 713.1342905223709 -177 819.3342905223708 -177 L 766.2342905223709 0 L 819.3342905223708 177 Q 713.1342905223709 177 606.9342905223708 0 z'
    this.bindEvent()
    this.extendShape()
    this.beforeChange = this.beforeChange.bind(this)
  }

  // 重新渲染时，节点连线是否全部删除
  // 鱼尾鱼骨图会多渲染一些连线，按需删除无法删除掉，只能全部删除重新创建
  nodeIsRemoveAllLines(node) {
    return node.isRoot || node.layerIndex === 1
  }

  // 是否是带鱼头鱼尾的鱼骨图
  isFishbone2() {
    return this.layout === CONSTANTS.LAYOUT.FISHBONE2
  }

  bindEvent() {
    if (!this.isFishbone2()) return
    this.onCheckUpdateFishTail = this.onCheckUpdateFishTail.bind(this)
    this.mindMap.on('afterExecCommand', this.onCheckUpdateFishTail)
  }

  unBindEvent() {
    this.mindMap.off('afterExecCommand', this.onCheckUpdateFishTail)
  }

  // 扩展节点形状
  extendShape() {
    if (!this.isFishbone2()) return
    // 扩展鱼头形状
    this.mindMap.addShape({
      name: 'fishHead',
      createShape: node => {
        const rect = SVG(`<path d="${this.fishHeadPathStr}"></path>`)
        const { width, height } = node.shapeInstance.getNodeSize()
        rect.size(width, height)
        return rect
      },
      getPadding: ({ width, height, paddingX, paddingY }) => {
        width += paddingX * 2
        height += paddingY * 2
        let shapePaddingX = this.paddingXRatio * width
        let shapePaddingY = 0
        width += shapePaddingX * 2
        const newHeight = width / this.headRatio
        shapePaddingY = (newHeight - height) / 2
        return {
          paddingX: shapePaddingX,
          paddingY: shapePaddingY
        }
      }
    })
  }

  //  布局
  doLayout(callback) {
    let task = [
      () => {
        this.computedBaseValue()
        this.addFishTail()
      },
      () => {
        this.computedLeftTopValue()
      },
      () => {
        this.adjustLeftTopValue()
        this.updateFishTailPosition()
      },
      () => {
        callback(this.root)
      }
    ]
    asyncRun(task)
  }

  // 创建鱼尾
  addFishTail() {
    if (!this.isFishbone2()) return
    const exist = this.mindMap.lineDraw.findOne('.smm-layout-fishbone-tail')
    if (!exist) {
      this.fishTail = SVG(`<path d="${this.fishTailPathStr}"></path>`)
      this.fishTail.addClass('smm-layout-fishbone-tail')
    } else {
      this.fishTail = exist
    }
    const tailHeight = this.root.height
    const tailWidth = tailHeight * this.tailRatio
    this.fishTail.size(tailWidth, tailHeight)
    this.styleFishTail()
    this.mindMap.lineDraw.add(this.fishTail)
  }

  // 如果根节点更新了形状样式，那么鱼尾也要更新
  onCheckUpdateFishTail(name, node, data) {
    if (name === 'SET_NODE_DATA') {
      let hasShapeProp = false
      Object.keys(data).forEach(key => {
        if (shapeStyleProps.includes(key)) {
          hasShapeProp = true
        }
      })
      if (hasShapeProp) {
        this.styleFishTail()
      }
    }
  }

  styleFishTail() {
    this.root.style.shape(this.fishTail)
  }

  // 删除鱼尾
  removeFishTail() {
    const exist = this.mindMap.lineDraw.findOne('.smm-layout-fishbone-tail')
    if (exist) {
      exist.remove()
    }
  }

  // 更新鱼尾形状位置
  updateFishTailPosition() {
    if (!this.isFishbone2()) return
    this.fishTail.x(this.maxx).cy(this.root.top + this.root.height / 2)
  }

  //  遍历数据创建节点、计算根节点的位置，计算根节点的子节点的top值
  computedBaseValue() {
    walk(
      this.renderer.renderTree,
      null,
      (node, parent, isRoot, layerIndex, index, ancestors) => {
        if (isRoot && this.isFishbone2()) {
          // 将根节点形状强制修改为鱼头
          node.data.shape = 'fishHead'
        }
        // 创建节点
        let newNode = this.createNode(
          node,
          parent,
          isRoot,
          layerIndex,
          index,
          ancestors
        )
        // 根节点定位在画布中心位置
        if (isRoot) {
          this.setNodeCenter(newNode)
        } else {
          // 非根节点
          // 三级及以下节点以上级方向为准
          if (parent._node.dir) {
            newNode.dir = parent._node.dir
          } else {
            // 节点生长方向
            newNode.dir =
              index % 2 === 0
                ? CONSTANTS.LAYOUT_GROW_DIR.TOP
                : CONSTANTS.LAYOUT_GROW_DIR.BOTTOM
          }
          // 计算二级节点的top值
          if (parent._node.isRoot) {
            let marginY = this.getMarginY(layerIndex)
            // 带鱼头鱼尾的鱼骨图因为根节点高度比较大，所以二级节点需要向中间靠一点
            const topOffset = this.isFishbone2() ? parent._node.height / 4 : 0
            if (this.checkIsTop(newNode)) {
              newNode.top =
                parent._node.top - newNode.height - marginY + topOffset
            } else {
              newNode.top =
                parent._node.top + parent._node.height + marginY - topOffset
            }
          }
        }
        if (!node.data.expand) {
          return true
        }
      },
      null,
      true,
      0
    )
  }

  //  遍历节点树计算节点的left、top
  computedLeftTopValue() {
    walk(
      this.root,
      null,
      (node, parent, isRoot, layerIndex) => {
        if (node.isRoot) {
          // 鱼骨（放射）横向紧凑方案：二级节点分"上/下"两行，起点对齐根节点右侧；
          // 每个二级节点的 x 先按自身宽度 + 留白排布（后续 adjustLeftTopValue 再按
          // "子树最大宽度 + 留白"二次推进，保证下一个兄弟紧跟上一子树，无空白浪费）
          const marginX = this.getMarginX(layerIndex + 1)
          let topTotalLeft = node.left + node.width + marginX
          let bottomTotalLeft = node.left + node.width + marginX
          node.children.forEach(item => {
            if (this.checkIsTop(item)) {
              item.left = topTotalLeft
              topTotalLeft += item.width + marginX
            } else {
              item.left = bottomTotalLeft
              bottomTotalLeft += item.width + marginX
            }
          })
        }
        let params = { layerIndex, node, ctx: this }
        if (this.checkIsTop(node)) {
          utils.top.computedLeftTopValue(params)
        } else {
          utils.bottom.computedLeftTopValue(params)
        }
      },
      null,
      true
    )
  }

  //  调整节点left、top
  adjustLeftTopValue() {
    walk(
      this.root,
      null,
      (node, parent, isRoot, layerIndex) => {
        // 折叠节点：不调整内部子节点，但保留其子树布局占位（子树边界仍参与兄弟节点间距计算），
        // 保证折叠后同级兄弟节点位置稳定、层级顺序不被破坏（鱼骨/放射布局核心修复）
        let params = { node, parent, layerIndex, ctx: this }
        if (this.checkIsTop(node)) {
          utils.top.adjustLeftTopValueBefore(params)
        } else {
          utils.bottom.adjustLeftTopValueBefore(params)
        }
      },
      (node, parent) => {
        let params = { parent, node, ctx: this }
        if (this.checkIsTop(node)) {
          utils.top.adjustLeftTopValueAfter(params)
        } else {
          utils.bottom.adjustLeftTopValueAfter(params)
        }
        // 调整二级节点的子节点的left值
        if (node.isRoot) {
          // 紧凑拼接：每个二级节点的子树按"子树最大水平宽度 + 小留白"横向推进，
          // 下一个兄弟紧跟上一子树最右端，消除固定角度产生的横向空白（用户要求的
          // "每个节点最长文字 + 留白 = 下一个节点位置"）。折叠节点无子节点实例，
          // 用最近一次展开渲染时缓存的子树宽度占位，保证折叠后兄弟位置稳定不跳位。
          const gap = 10
          let topTotalLeft = 0
          let bottomTotalLeft = 0
          let maxx = -Infinity
          node.children.forEach(item => {
            const isExpanded = item.getData('expand')
            const isTop = this.checkIsTop(item)
            let w = 0
            if (isExpanded) {
              let { left, right } = this.getNodeBoundaries(item, 'h')
              w = right - left
              expandedWidthCache.set(item.uid, w)
            } else {
              const cachedW = expandedWidthCache.get(item.uid)
              w = typeof cachedW === 'number' ? cachedW : item.width || 0
            }
            const step = w + gap
            if (isTop) {
              item.left += topTotalLeft
              this.updateChildren(item.children, 'left', topTotalLeft)
              topTotalLeft += step
            } else {
              item.left += bottomTotalLeft
              this.updateChildren(item.children, 'left', bottomTotalLeft)
              bottomTotalLeft += step
            }
            if (item.left + w > maxx) {
              maxx = item.left + w
            }
          })
          this.maxx = maxx
        }
      },
      true
    )
  }

  //  递归计算节点的宽度
  getNodeAreaHeight(node) {
    let totalHeight = 0
    let loop = node => {
      let marginY = this.getMarginY(node.layerIndex)
      totalHeight +=
        node.height +
        (this.getNodeActChildrenLength(node) > 0 ? node.expandBtnSize : 0) +
        marginY
      if (node.children.length) {
        node.children.forEach(item => {
          loop(item)
        })
      }
    }
    loop(node)
    return totalHeight
  }

  //  调整兄弟节点的left
  updateBrothersLeft(node) {
    let childrenList = node.children
    let totalAddWidth = 0
    childrenList.forEach(item => {
      item.left += totalAddWidth
      if (item.children && item.children.length) {
        this.updateChildren(item.children, 'left', totalAddWidth)
      }
      let { left, right } = this.getNodeBoundaries(item, 'h')
      let areaWidth = right - left
      let difference = areaWidth - item.width
      if (difference > 0) {
        totalAddWidth += difference
      }
    })
  }

  //  调整兄弟节点的top
  updateBrothersTop(node, addHeight) {
    if (node.parent && !node.parent.isRoot) {
      let childrenList = node.parent.children
      let index = getNodeIndexInNodeList(node, childrenList)
      childrenList.forEach((item, _index) => {
        if (item.hasCustomPosition()) {
          // 适配自定义位置
          return
        }
        let _offset = 0
        // 下面的节点往下移
        if (_index > index) {
          _offset = addHeight
        }
        item.top += _offset
        // 同步更新子节点的位置
        if (item.children && item.children.length) {
          this.updateChildren(item.children, 'top', _offset)
        }
      })
      // 更新父节点的位置
      if (this.checkIsTop(node)) {
        this.updateBrothersTop(node.parent, addHeight)
      } else {
        this.updateBrothersTop(
          node.parent,
          node.layerIndex === 3 ? 0 : addHeight
        )
      }
    }
  }

  // 检查节点是否是上方节点
  checkIsTop(node) {
    return node.dir === CONSTANTS.LAYOUT_GROW_DIR.TOP
  }

  //  绘制连线，连接该节点到其子节点
  renderLine(node, lines, style) {
    if (node.layerIndex !== 1 && node.children.length <= 0) {
      return []
    }
    let { top, height, expandBtnSize } = node
    const { alwaysShowExpandBtn, notShowExpandBtn } = this.mindMap.opt
    if (!alwaysShowExpandBtn || notShowExpandBtn) {
      expandBtnSize = 0
    }
    let len = node.children.length
    if (node.isRoot) {
      // 当前节点是根节点
      // 列式布局：根节点右侧画一条主干水平线到二级列，再逐条直连到每个二级节点
      // （二级节点同列且上下分布，直连斜线比固定角度汇聚线更贴合列式坐标）
      let nodeHalfTop = node.top + node.height / 2
      let marginY = this.getMarginY(1)
      let offset = node.height / 2 + marginY
      // 二级列起点（与 computedLeftTopValue 的 rootRight 一致）
      const rootRight = node.left + node.width + this.getMarginX(1)
      // 主干水平线
      let line = this.lineDraw.path()
      line.plot(
        this.transformPath(
          `M ${node.left + node.width},${nodeHalfTop} L ${
            rootRight - offset / Math.tan(degToRad(this.mindMap.opt.fishboneDeg))
          },${nodeHalfTop}`
        )
      )
      node.style.line(line)
      node._lines.push(line)
      style && style(line, node)
      // 二级节点直连斜线
      node.children.forEach(item => {
        let cy = item.top + item.height / 2
        let line = this.lineDraw.path()
        line.plot(
          this.transformPath(
            `M ${
              rootRight - offset / Math.tan(degToRad(this.mindMap.opt.fishboneDeg))
            },${nodeHalfTop} L ${item.left},${cy}`
          )
        )
        node.style.line(line)
        node._lines.push(line)
        style && style(line, node)
      })
    } else {
      // 当前节点为非根节点
      // 列式布局：子节点全部位于下一列，父节点中心到每个子节点中心直接连线
      // （原固定角度汇聚斜线已不适用列式坐标；直接创建 path，不依赖外部 lines 数组）
      let x = node.left + node.width * this.indent
      let y = node.top + node.height / 2
      node.children.forEach(item => {
        let cy = item.top + item.height / 2
        let line = this.lineDraw.path()
        line.plot(this.transformPath(`M ${x},${y} L ${item.left},${cy}`))
        node.style.line(line)
        node._lines.push(line)
        style && style(line, node)
      })
    }
  }

  //  渲染按钮
  renderExpandBtn(node, btn) {
    let { width, height, expandBtnSize, isRoot } = node
    if (!isRoot) {
      let { translateX, translateY } = btn.transform()
      let params = {
        node,
        btn,
        expandBtnSize,
        translateX,
        translateY,
        width,
        height
      }
      if (this.checkIsTop(node)) {
        utils.top.renderExpandBtn(params)
      } else {
        utils.bottom.renderExpandBtn(params)
      }
    }
  }

  //  创建概要节点
  renderGeneralization(list) {
    list.forEach(item => {
      let {
        top,
        bottom,
        right,
        generalizationLineMargin,
        generalizationNodeMargin
      } = this.getNodeGeneralizationRenderBoundaries(item, 'h')
      let x1 = right + generalizationLineMargin
      let y1 = top
      let x2 = right + generalizationLineMargin
      let y2 = bottom
      let cx = x1 + 20
      let cy = y1 + (y2 - y1) / 2
      let path = `M ${x1},${y1} Q ${cx},${cy} ${x2},${y2}`
      item.generalizationLine.plot(this.transformPath(path))
      item.generalizationNode.left = right + generalizationNodeMargin
      item.generalizationNode.top =
        top + (bottom - top - item.generalizationNode.height) / 2
    })
  }

  // 渲染展开收起按钮的隐藏占位元素
  renderExpandBtnRect(rect, expandBtnSize, width, height, node) {
    let dir = ''
    if (node.dir === CONSTANTS.LAYOUT_GROW_DIR.TOP) {
      dir =
        node.layerIndex === 1
          ? CONSTANTS.LAYOUT_GROW_DIR.TOP
          : CONSTANTS.LAYOUT_GROW_DIR.BOTTOM
    } else {
      dir =
        node.layerIndex === 1
          ? CONSTANTS.LAYOUT_GROW_DIR.BOTTOM
          : CONSTANTS.LAYOUT_GROW_DIR.TOP
    }
    if (dir === CONSTANTS.LAYOUT_GROW_DIR.TOP) {
      rect.size(width, expandBtnSize).x(0).y(-expandBtnSize)
    } else {
      rect.size(width, expandBtnSize).x(0).y(height)
    }
  }

  // 切换切换为其他结构时的处理
  beforeChange() {
    // 删除鱼尾
    if (!this.isFishbone2()) return
    this.root.nodeData.data.shape = CONSTANTS.SHAPE.RECTANGLE
    this.removeFishTail()
    this.unBindEvent()
    this.mindMap.removeShape('fishHead')
  }
}

export default Fishbone
