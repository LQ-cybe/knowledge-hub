<script setup lang="ts">
import { onMounted, ref, watch, nextTick, onBeforeUnmount, computed } from 'vue';
import * as echarts from 'echarts';
import { hierarchy as d3Hierarchy, pack as d3Pack } from 'd3-hierarchy';
import { ElMessage } from 'element-plus';
import { getGraph, getGraphHierarchy, type GraphData, type HierarchyNode } from './api';

const dimension = ref<'folder' | 'tag' | 'link'>('folder');
// 关系图/桑基图/树图基于统一 nodes+links（维度可选）；矩形树图/旭日图/打包图基于文件夹层级（文件数）；弦图基于标签共现
const view = ref<'graph' | 'sankey' | 'tree' | 'treemap' | 'sunburst' | 'pack' | 'chord'>('graph');
const chartEl = ref<HTMLElement>();
const loading = ref(false);
const nodeCount = ref(0);
const linkCount = ref(0);

/** 层级折叠状态：all=全部展开 / root=全部折叠 / depth=折叠到 N 层 */
const collapseMode = ref<'all' | 'root' | 'depth'>('all');
const collapseDepth = ref(2);
const maxDepth = ref(1);

/** 全局标签显示开关（默认不显示；控制所有视图的节点标签） */
const showLabels = ref(false);

/** 层级图下钻栈：点击某个组节点后，只显示该组及其子节点；点空白/返回按钮逐级返回 */
const drillStack = ref<HierarchyNode[]>([]);
/** 打包图滚轮缩放系数（1=原始大小） */
const zoomFactor = ref(1);
/** 旭日图滚轮缩放系数（1..6，radius 缩放，levels 环带跟随） */
const sunZoom = ref(1);
/** 桑基图滚轮缩放系数（1..4，容器 CSS transform，ECharts sankey 官方不支持 roam） */
const cssZoom = ref(1);

let chart: echarts.ECharts | null = null;
let data: GraphData = { nodes: [], links: [] };
let hierarchy: HierarchyNode[] = [];

/** 统一初始化图表 + 在 zrender 层绑定滚轮缩放（ECharts 在 canvas 层拦截 wheel，DOM @wheel 收不到真实滚轮；
 *  pack/sunburst/sankey 无原生 roam → 自实现缩放：pack 重渲染 / sunburst radius / sankey 容器 CSS transform）
 *  桑基图使用 SVG 渲染器：容器 CSS transform 缩放仍是矢量（canvas 下会呈像素块） */
function initChart(): echarts.ECharts {
  const el = chartEl.value || (document.querySelector('.chart-box .chart') as HTMLElement | null);
  if (!el) throw new Error('chart element not found');
  chart = echarts.init(el, null, { renderer: view.value === 'sankey' ? 'svg' : 'canvas' });
  chart.getZr().off('wheel');
  chart.getZr().on('wheel', (e: any) => {
    const dz = e?.event?.deltaY ?? 0;
    if (view.value === 'pack') {
      zoomFactor.value = Math.min(3, Math.max(0.4, zoomFactor.value * (dz > 0 ? 0.9 : 1.1)));
      renderHierarchy();
    } else if (view.value === 'sunburst') {
      sunZoom.value = Math.min(6, Math.max(1, sunZoom.value * (dz > 0 ? 0.92 : 1.08)));
      chart?.setOption({ series: [{ radius: [`${sunZoom.value === 1 ? 0 : 4 / sunZoom.value}%`, `${94 / sunZoom.value}%`] }] }, { lazyUpdate: true });
    } else if (view.value === 'sankey') {
      cssZoom.value = Math.min(4, Math.max(1, cssZoom.value * (dz > 0 ? 0.9 : 1.1)));
      const c = chartEl.value || (document.querySelector('.chart-box .chart') as HTMLElement | null);
      if (c) { c.style.transformOrigin = 'center center'; c.style.transform = cssZoom.value === 1 ? '' : `scale(${cssZoom.value})`; }
    }
  });
  return chart;
}

/** 当前视图是否需要 SVG 渲染器（桑基图矢量缩放） */
function wantSvgRenderer() { return view.value === 'sankey'; }
/** 视图切换时 renderer 必须重建（canvas↔svg 无法复用实例）；以 DOM 实际元素判断（getRendererType 在部分版本不可用） */
function ensureRenderer() {
  if (!chart) return;
  const el = chartEl.value || (document.querySelector('.chart-box .chart') as HTMLElement | null);
  if (!el) return;
  const hasCanvas = !!el.querySelector('canvas');
  const hasSvg = !!el.querySelector('svg');
  const wantSvg = wantSvgRenderer();
  if ((wantSvg && hasCanvas) || (!wantSvg && hasSvg)) { chart.dispose(); chart = null as any; }
}

const dimensionLabels: Record<string, string> = { folder: '文件夹', tag: '标签', link: '引用' };
const viewLabels: Record<string, string> = {
  graph: '关系图', sankey: '桑基图', tree: '树图',
  treemap: '矩形树图', sunburst: '旭日图', pack: '打包图', chord: '弦图',
};
const typeLabels: Record<string, string> = { folder: '文件夹', file: '文件', tag: '标签', resource: '资源' };

/** 图表类型是否基于"文件夹层级"（treemap/sunburst/pack）——这些视图与维度选择无关 */
function isHierarchyView() { return ['treemap', 'sunburst', 'pack'].includes(view.value); }

/** 当前是否暗色主题（ECharts 画布内文字/连线颜色需随主题切换） */
function isDark() {
  return typeof document !== 'undefined' && document.documentElement.classList.contains('dark');
}
function labelColor() { return isDark() ? '#d1d5db' : '#374151'; }
function dimColor() { return isDark() ? '#6b7280' : '#9ca3af'; }
function lineColor() { return isDark() ? '#4b5563' : '#cbd5e1'; }

function nameToLabel() {
  const m = new Map<string, string>();
  data.nodes.forEach(n => m.set(n.name, n.label));
  return m;
}

/** 节点提示：类型 · 标题 + 唯一路径 */
function nodeTip(cat: string, label: string, name: string) {
  return `<b>${typeLabels[cat] || cat}</b> · ${label}<br/><span style="color:${dimColor()};font-size:11px;">${name}</span>`;
}

/** 由边表计算节点深度（0=根） */
function computeDepth(nodes: GraphData['nodes'], links: GraphData['links']): Map<string, number> {
  const dep = new Map<string, number>();
  const children = new Map<string, string[]>();
  const hasParent = new Set<string>();
  for (const l of links) {
    if (!children.has(l.source)) children.set(l.source, []);
    children.get(l.source)!.push(l.target);
    hasParent.add(l.target);
  }
  const queue = nodes.filter(n => !hasParent.has(n.id)).map(n => ({ id: n.id, d: 0 }));
  for (const r of queue) dep.set(r.id, r.d);
  while (queue.length) {
    const cur = queue.shift()!;
    for (const c of children.get(cur.id) || []) {
      if (!dep.has(c)) { dep.set(c, cur.d + 1); queue.push({ id: c, d: cur.d + 1 }); }
    }
  }
  for (const n of nodes) if (!dep.has(n.id)) dep.set(n.id, 0);
  return dep;
}

/** 按折叠模式过滤节点/连线（关系图、桑基图用）
 *  层数=显示节点的层级：第1层=根+一级（同全部折叠）；第N层=显示到第N级；
 *  过滤结果不足2个节点时自动放宽到根+一级（桑基图/关系图保证有内容，不空白） */
function filtered(): { nodes: GraphData['nodes']; links: GraphData['links'] } {
  if (collapseMode.value === 'all') return data;
  const dep = computeDepth(data.nodes, data.links);
  const maxD = collapseMode.value === 'root' ? 1 : collapseDepth.value;
  const pick = (maxDepthD: number) => {
    const keep = new Set<string>();
    for (const [id, d] of dep) if (d <= maxDepthD) keep.add(id);
    return {
      nodes: data.nodes.filter(n => keep.has(n.id)),
      links: data.links.filter(l => keep.has(l.source) && keep.has(l.target)),
    };
  };
  let r = pick(maxD);
  if (r.nodes.length < 2) r = pick(1);
  return r;
}

function render() {
  if (!chartEl.value) return;
  if (!chartEl.value.clientHeight || !chartEl.value.clientWidth) {
    setTimeout(render, 200);
    return;
  }
  try {
    ensureRenderer();
    if (!chart) {
      chart = initChart();
    }
    const labelMap = nameToLabel();
    const fmt = (p: any) => labelMap.get(p.name) || p.name;

    if (view.value === 'graph') {
      const { nodes, links } = filtered();
      const idToLabel = new Map(nodes.map(n => [n.id, n.label]));
      chart.setOption({
        tooltip: {
          trigger: 'item', confine: true, hideDelay: 60,
          formatter: (p: any) => {
            if (p.dataType === 'edge') {
              const s = idToLabel.get(p.data.source) || labelMap.get(p.data.source) || p.data.source;
              const t = idToLabel.get(p.data.target) || labelMap.get(p.data.target) || p.data.target;
              return `${s} → ${t}`;
            }
            return nodeTip(p.data.category, p.data.label || p.data.name, p.data.name);
          },
        },
        series: [{
          type: 'graph', layout: 'force', roam: true, draggable: true,
          animation: false, // 关系图动画彻底关闭（初始布局与拖动重排直接呈现）
          emphasis: { scale: 1.15, label: { show: true } },
          data: nodes.map(n => ({
            id: n.id, name: n.name, symbolSize: (n.symbolSize || 12) * 0.7, category: n.category,
          })),
          links: links.map(l => ({ source: l.source, target: l.target })),
          label: { show: showLabels.value, formatter: fmt, fontSize: 12, color: labelColor(), textBorderColor: isDark() ? 'rgba(15,23,42,0.9)' : 'rgba(255,255,255,0.9)', textBorderWidth: 2 },
          categories: [
            { name: 'folder', itemStyle: { color: '#409eff' } },
            { name: 'file', itemStyle: { color: '#5b6b7d' } },
            { name: 'tag', itemStyle: { color: '#2f9e44' } },
            { name: 'resource', itemStyle: { color: '#e07b00' } },
          ],
          force: { repulsion: 90, edgeLength: 60, gravity: 0.1, friction: 0.9, layoutAnimation: false },
          lineStyle: { color: 'source', curveness: 0.1, opacity: 0.5 },
        }],
      }, true);
      requestAnimationFrame(() => chart?.resize()); // 等 setOption 渲染结束再 resize，避免 ECharts 警告
    } else if (view.value === 'sankey') {
      const { nodes, links } = filtered();
      const idToName = new Map(nodes.map(n => [n.id, n.name]));
      const sNodes = nodes.map((n, i) => ({
        name: n.name,
        // 每个标签节点独立配色（原仅 folder 上色导致其他节点同色）
        itemStyle: { color: packPalette[i % packPalette.length] },
      }));
      const sLinks = links.map(l => ({
        source: idToName.get(l.source) || l.source,
        target: idToName.get(l.target) || l.target,
        value: l.value || 1,
      }));
      chart.setOption({
        tooltip: { trigger: 'item', triggerOn: 'mousemove', confine: true, hideDelay: 60, formatter: fmt },
        series: [{
          type: 'sankey',
          data: sNodes,
          links: sLinks,
          label: { show: showLabels.value, formatter: fmt, fontSize: 12, color: labelColor(), textBorderColor: isDark() ? 'rgba(15,23,42,0.9)' : 'rgba(255,255,255,0.9)', textBorderWidth: 2 },
          lineStyle: { color: 'gradient', opacity: 0.5 },
          nodeAlign: 'left',
          emphasis: { focus: 'adjacency' },
        }],
      }, true);
      requestAnimationFrame(() => chart?.resize());
    } else if (view.value === 'tree') {
      renderTree();
      return;
    } else if (view.value === 'treemap' || view.value === 'sunburst' || view.value === 'pack') {
      renderHierarchy();
      return;
    } else if (view.value === 'chord') {
      renderChord();
      return;
    }
  } catch (e) {
    console.error('graph render error:', e);
  }
}

/** 旭日图配色：同级分组错开色相；子分组/子对象继承父色相并逐层减淡（提高明度、降低饱和），同组渐进有层次
 *  startDepth：错色相从第几层开始（treemap 传 1 → 根容器固定色、其下第一级文件夹才错色相；旭日图剥离根后默认 0） */
const hueStep = 47;
function colorize(ns: HierarchyNode[], depth: number, parent: { hue: number; light: number; sat: number } | null, startDepth = 0): any[] {
  return ns.map((n, i) => {
    let hue: number, light: number, sat: number;
    if (depth < startDepth) {
      // 根容器：统一中性色（treemap 的 Code 根）
      hue = 210; light = 40; sat = 62;
    } else if (!parent || depth === startDepth) {
      // 顶层分组：同级错色相
      hue = (210 + i * hueStep) % 360;
      light = 42; sat = 66;
    } else {
      // 深层：继承父分组色相，逐层减淡
      hue = parent.hue;
      light = Math.min(78, parent.light + 9);
      sat = Math.max(26, parent.sat - 10);
    }
    const hasChildren = !!n.children && n.children.length > 0;
    return {
      ...n,
      // name 兜底：偶发节点缺 name 时回退 data.title，避免中心层显示 undefined
      name: n.name || (n.data as any)?.title || '未命名',
      itemStyle: { color: `hsl(${hue}, ${sat}%, ${light}%)` },
      children: hasChildren ? colorize(n.children, depth + 1, { hue, light, sat }, startDepth) : undefined,
    };
  });
}

/** 返回上级（下钻栈弹出） */
function goBack() {
  if (drillStack.value.length === 0) return;
  drillStack.value.pop();
  renderHierarchy();
}
/** 重置视图：清空下钻 + 打包图/旭日图/桑基图缩放还原 */
function resetView() {
  drillStack.value = [];
  zoomFactor.value = 1;
  sunZoom.value = 1;
  cssZoom.value = 1;
  const el = chartEl.value || (document.querySelector('.chart-box .chart') as HTMLElement | null);
  if (el) el.style.transform = '';
  renderHierarchy();
}
/** 滚轮缩放（DOM 层兜底）：pack 重渲染 / sunburst radius / sankey 容器 CSS 缩放；
 *  真实滚轮在 canvas 被 ECharts 拦截，主路径走 initChart() 的 zrender 监听 */
function onWheel(e: WheelEvent) {
  const dz = e.deltaY;
  if (view.value === 'pack') {
    e.preventDefault();
    zoomFactor.value = Math.min(3, Math.max(0.4, zoomFactor.value * (dz > 0 ? 0.9 : 1.1)));
    renderHierarchy();
  } else if (view.value === 'sunburst') {
    e.preventDefault();
    sunZoom.value = Math.min(6, Math.max(1, sunZoom.value * (dz > 0 ? 0.92 : 1.08)));
    chart?.setOption({ series: [{ radius: [`${18 / sunZoom.value}%`, `${94 / sunZoom.value}%`] }] }, { lazyUpdate: true });
  } else if (view.value === 'sankey') {
    e.preventDefault();
    cssZoom.value = Math.min(4, Math.max(1, cssZoom.value * (dz > 0 ? 0.9 : 1.1)));
    const el = chartEl.value || (document.querySelector('.chart-box .chart') as HTMLElement | null);
    if (el) {
      el.style.transformOrigin = 'center center';
      el.style.transform = cssZoom.value === 1 ? '' : `scale(${cssZoom.value})`;
    }
  }
}

/** 在原始层级树中按 id 找节点（下钻用干净节点，避免 ECharts 加工后的数据项 name 丢失 → 未命名） */
function findNode(ns: HierarchyNode[], id: string): HierarchyNode | null {
  for (const n of ns) {
    if (n.id === id) return n;
    if (n.children?.length) { const r = findNode(n.children, id); if (r) return r; }
  }
  return null;
}

function renderHierarchy() {
  if (!chartEl.value) return;
  if (hierarchy.length === 0) { chart?.clear(); nodeCount.value = 0; linkCount.value = 0; return; }
  // 下钻优先：只显示单击的组及其子节点（drillStack 尾项为当前根）；再按折叠模式剪枝
  let tree: HierarchyNode[] = drillStack.value.length
    ? [drillStack.value[drillStack.value.length - 1]]
    : hierarchy;
  if (collapseMode.value === 'root') {
    tree = pruneHierarchy(tree, 2);
  } else if (collapseMode.value === 'depth') {
    tree = pruneHierarchy(tree, collapseDepth.value + 1);
  }
  // 最大可见层级 = 树层级（含 Code 根）减 1（Code 根不显示，最内层是顶级文件夹）；下拉选项 1..maxDepth，第 maxDepth 层=全量
  maxDepth.value = Math.max(1, hierarchyDepth(hierarchy) - 1);

  const itemTip = (p: any) => {
    const n = p.data;
    const size = n.size ? `<br/><span style="color:${dimColor()};font-size:11px;">${fmtBytes(n.size)}</span>` : '';
    return `<b>${n.name}</b> · 文件 ${n.value} 个${size}`;
  };
  chart?.dispose();
  chart = initChart();
  // 点击组节点 → 下钻到该组（只显示它和它的子节点）；点击空白 → 返回上一级
  chart.on('click', (p: any) => {
    if (view.value !== 'sunburst' && view.value !== 'pack' && view.value !== 'treemap') return;
    // pack：custom 系列 params.data 是渲染项（含 src 原始引用）；sunburst：用 id 回原始树找干净节点（name 不丢）
    // 注意：找不到干净节点（如点击中心孔的虚拟根）时不下钻，避免虚拟根入栈产生“未命名”
    const pid = p?.data?.id ?? p?.data?.src?.id;
    const target = p?.data?.src || (pid ? findNode(hierarchy, String(pid)) : null);
    if (target && Array.isArray(target.children) && target.children.length > 0) {
      // 点击的是当前根（中心圆）→ 返回上一级；否则下钻（按 id 判定，避免 HMR/重载后引用失效重复 push）
      const top = drillStack.value[drillStack.value.length - 1];
      if (drillStack.value.length > 0 && top && String(target.id) === String(top.id)) {
        drillStack.value.pop();
      } else {
        drillStack.value.push(target);
      }
      renderHierarchy();
    } else if (!p?.data) {
      goBack();
    }
  });

  if (view.value === 'treemap') {
    // Code 恒为本软件根目录：显示名改为"所有文件"，不在图中出现 code 字样
    // 下钻后 drillStack 顶层即当前组（保持原名，如 1Excel）；分色与旭日图同源（startDepth=1：根容器固定色，其下错色相）
    const tmData = colorize(tree.map(n => (n.name === 'Code' || n.name === 'code' ? { ...n, name: '所有文件' } : n)), 0, null, 1);
    chart.setOption({
      tooltip: { trigger: 'item', confine: true, hideDelay: 60, formatter: itemTip },
      series: [{
        type: 'treemap',
        data: tmData,
        roam: true,
        nodeClick: false, // 自定义下钻：点击组进入子组并隐藏其它组（同旭日图原理，参考 ECharts treemap-drill-down）
        breadcrumb: { show: false }, // 底部浅蓝色路径条去掉（非必要控件，层级由下钻表达）
        label: { show: showLabels.value, formatter: (p: any) => p.name, fontSize: 12, color: '#fff', textBorderColor: isDark() ? 'rgba(15,23,42,0.9)' : 'rgba(15,23,42,0.9)', textBorderWidth: 2 },
        upperLabel: { show: true, height: 20, formatter: (p: any) => p.name, fontSize: 12, color: labelColor() },
        itemStyle: { borderColor: isDark() ? '#1f2937' : '#fff', borderWidth: 1, gapWidth: 1 },
        levels: [
          { itemStyle: { borderColor: isDark() ? '#1f2937' : '#fff', borderWidth: 2, gapWidth: 2 } },
        ],
      }],
    }, true);
  } else if (view.value === 'sunburst') {
    // 旭日图剥离无意义的根（Code）：初始视图直接从顶级文件夹开始（分色也从这层开始，再继承到子类）
    let sunData = tree;
    if (drillStack.value.length === 0 && sunData.length === 1 && sunData[0].children?.length) {
      sunData = sunData[0].children;
    }
    // 动态生成层半径（0%→94% 均分，中心实心不挖空，官方 sunburst-simple 风格），覆盖数据最大深度，避免深层节点渲染到浅层半径造成重叠/错位
    // maxD 按剥离根后的 sunData 实际深度计算（Code 根不算一层）；levels 标签字号随滚轮缩放放大（节点放大时文字同步放大）
    const sunMaxD = (() => { let m = 1; const w = (ns: HierarchyNode[], d: number) => { for (const n of ns) { m = Math.max(m, d); if (n.children?.length) w(n.children, d + 1); } }; w(sunData, 1); return Math.max(1, m); })();
    const sunLabelSize = Math.max(10, Math.round(10 + (sunZoom.value - 1) * 2));
    const levels: any[] = [{}];
    for (let i = 1; i <= sunMaxD; i++) {
      levels.push({
        r0: `${((i - 1) * 94) / sunMaxD}%`,
        r: `${(i * 94) / sunMaxD}%`,
        label: { rotate: 'tangential', fontSize: sunLabelSize },
      });
    }
    chart.setOption({
      tooltip: { trigger: 'item', confine: true, hideDelay: 60, formatter: itemTip },
      series: [{
        type: 'sunburst',
        data: colorize(sunData, 0, null),
        radius: [`${sunZoom.value === 1 ? 0 : 4 / sunZoom.value}%`, `${94 / sunZoom.value}%`], // 滚轮缩放（sunZoom 1..6，levels 跟随 radius；中心实心）
        center: ['50%', '50%'],
        sort: 'desc',
        emphasis: { focus: 'ancestor' },
        label: { show: showLabels.value, fontSize: sunLabelSize, color: '#fff', rotate: 'radial', textBorderColor: 'rgba(15,23,42,0.85)', textBorderWidth: 2 },
        levels,
        itemStyle: { borderColor: isDark() ? '#1f2937' : '#fff', borderWidth: 1 },
      }],
    }, true);
  } else if (view.value === 'pack') {
    renderPack(tree);
  }
  requestAnimationFrame(() => chart?.resize());
}

/** 打包图（气泡嵌套）：ECharts 无原生 pack 系列 → d3-hierarchy pack 布局 + custom 系列渲染圆 */
const packPalette = ['#409eff', '#67c23a', '#e6a23c', '#f56c6c', '#909399', '#9b59b6', '#1abc9c', '#f39c12', '#e74c3c', '#3498db'];
function renderPack(tree: HierarchyNode[]) {
  if (!chart) return;
  const W = chart.getWidth(), H = chart.getHeight();
  if (!W || !H) return;
  const z = zoomFactor.value;
  let items: { name: string; value: number; x: number; y: number; r: number; depth: number; src: HierarchyNode }[] = [];
  try {
    const root = d3Hierarchy({ name: 'root', children: tree } as any, (d: any) => d.children)
      .sum((d: any) => d.value || 0)
      .sort((a: any, b: any) => (b.value || 0) - (a.value || 0));
    const p = d3Pack().size([W - 16, H - 16]).padding(3)(root);
    p.each((n: any) => {
      const d = n.data as HierarchyNode;
      if (n.depth === 0) return;
      items.push({
        name: d.name, value: n.value,
        x: n.x + 8, y: n.y + 8, r: Math.max(1.5, n.r - 2), depth: n.depth, src: d,
      });
    });
    // 只保留 visible 层级的圆（剪枝后 tree 已限深；但叶子文件数过多时圆很小，无需裁剪）
    // 渲染上限：按半径降序保留前 1500 个（全展开时避免 5000+ 圆拖垮渲染）
    items.sort((a, b) => b.r - a.r);
    if (items.length > 1500) items = items.slice(0, 1500);
  } catch (e) {
    console.error('pack layout failed', e);
    items = [];
  }
  const data = items.map((it, i) => ({ ...it, i }));
  const palette = packPalette;
  chart.setOption({
    // custom 系列必须挂坐标系：隐藏直角坐标轴，范围 = 像素尺寸，使 api.coord 恒等转换
    xAxis: { type: 'value', min: 0, max: W, show: false },
    yAxis: { type: 'value', min: 0, max: H, show: false },
    tooltip: {
      trigger: 'item', confine: true, hideDelay: 60,
      formatter: (p: any) => {
        const it = data[p.dataIndex];
        return it ? `<b>${it.name}</b><br/>文件数：${it.value}` : '';
      },
    },
    series: [{
      type: 'custom',
      data,
      renderItem: (params: any, api: any) => {
        const it = data[params.dataIndex];
        if (!it) return;
        const color = palette[it.depth % palette.length];
        const xy = api.coord([(it.x - W / 2) * z + W / 2, (it.y - H / 2) * z + H / 2]);
        // 滚轮缩放：以画布中心为基准放大/缩小（custom 系列无坐标系，坐标即像素）
        // 统一缩放策略：放大时节点半径增长放缓（避免占满屏幕），文字字号同步放大（提升辨识度）
        const zk = 1 + (z - 1) * 0.55;
        const fontSize = Math.max(10, Math.round(10 + (z - 1) * 4));
        const children = [
          { type: 'circle', shape: { cx: xy[0], cy: xy[1], r: it.r * zk },
            // 父圆近透明仅描边（容器感）、子圆填充略实：嵌套关系清晰，子节点不与父节点"糊"在一起
            style: { fill: color, fillOpacity: it.depth === 1 ? 0.05 : 0.16, stroke: color, lineWidth: it.depth === 1 ? 1.4 : 0.8 } },
        ];
        // 顶层/大圆显示名称（r 足够大才画文字，避免标签堆叠与文字溢出相邻圆）；受全局标签显示开关控制
        if (showLabels.value && it.r * zk >= 22) {
          children.push({
            type: 'text', style: {
              x: xy[0], y: xy[1],
              text: it.name, font: `${fontSize}px sans-serif`, fill: labelColor(), textAlign: 'center', textVerticalAlign: 'middle',
            },
          });
        }
        return { type: 'group', children, silent: false };
      },
      progressive: 2000,
    }],
  }, true);
}

/** 层级剪枝（treemap/sunburst/pack）：保留前 maxDepth 层，更深的剪掉（value 累加已在后端完成） */
function pruneHierarchy(nodes: HierarchyNode[], maxDepth: number, cur = 1): HierarchyNode[] {
  return nodes.map(n => ({ ...n, children: cur < maxDepth ? pruneHierarchy(n.children, maxDepth, cur + 1) : [] }));
}

/** 层级树最大深度 */
function hierarchyDepth(nodes: HierarchyNode[]): number {
  let max = 0;
  const walk = (ns: HierarchyNode[], d: number) => {
    for (const n of ns) { max = Math.max(max, d + 1); if (n.children.length) walk(n.children, d + 1); }
  };
  walk(nodes, 0);
  return Math.max(1, max);
}

function fmtBytes(n: number) {
  if (!n) return '-';
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB';
  return (n / 1024 / 1024).toFixed(2) + ' MB';
}

/** ---------- 弦图：标签共现（同一资源上同时出现的两个标签连一条线） ---------- */
function renderChord() {
  if (!chartEl.value) return;
  if (data.nodes.length === 0) { chart?.clear(); nodeCount.value = 0; linkCount.value = 0; return; }
  // 从标签图（tag → 资源）反推共现：同一资源关联的标签两两计数
  const resTags = new Map<string, string[]>();
  for (const l of data.links) {
    if (l.source.startsWith('res_')) continue;
    if (!resTags.has(l.target)) resTags.set(l.target, []);
    resTags.get(l.target)!.push(l.source);
  }
  const co = new Map<string, number>();
  for (const tags of resTags.values()) {
    if (tags.length < 2) continue;
    for (let i = 0; i < tags.length; i++) {
      for (let j = i + 1; j < tags.length; j++) {
        const [a, b] = [tags[i], tags[j]].sort();
        const k = a + '\u0001' + b;
        co.set(k, (co.get(k) || 0) + 1);
      }
    }
  }
  const tagNodes = data.nodes.filter(n => n.category === 'tag');
  const idToName = new Map(tagNodes.map(n => [n.id, n.name]));
  const used = new Set<string>();
  const chordLinks: { source: string; target: string; value: number }[] = [];
  for (const [k, v] of co) {
    const [a, b] = k.split('\u0001');
    if (!idToName.has(a) || !idToName.has(b)) continue;
    used.add(a); used.add(b);
    chordLinks.push({ source: idToName.get(a)!, target: idToName.get(b)!, value: v });
  }
  // 弦图：标签共现关系，circular 布局节点沿圆周分布（外观接近弦图），
  // 每个节点独立配色（原为默认同色），roam 支持缩放平移
  const sNodes = tagNodes.filter(n => used.has(n.id)).map((n, i) => ({
    name: n.name,
    symbolSize: Math.min(10, (n.symbolSize || 22) * 0.5), // 节点缩小（原 22 过大；10 上限避免大标签节点过大）
    itemStyle: { color: packPalette[i % packPalette.length] },
  }));
  chart?.dispose();
  chart = initChart();
  // 源节点 → 颜色映射：每条连线按源节点独立配色（不再整体一个颜色）
  const colorById = new Map<string, string>();
  sNodes.forEach((n, i) => colorById.set(n.name, packPalette[i % packPalette.length]));
  chart.setOption({
    tooltip: {
      trigger: 'item', confine: true, hideDelay: 60,
      formatter: (p: any) => {
        if (p.dataType === 'edge') return `${p.data.source} ↔ ${p.data.target}：${p.data.value} 个资源共现`;
        return `<b>${p.name}</b><br/><span style="color:${dimColor()};font-size:11px;">与其他标签共现于 ${p.data?.value ?? 0} 个资源</span>`;
      },
    },
    series: [{
      type: 'graph',
      layout: 'circular', // 圆周分布，外观接近弦图
      circular: { rotateLabel: false },
      roam: true, // 滚轮缩放、拖拽平移
      draggable: false,
      animation: false,
      data: sNodes.map(n => ({ ...n, label: { show: showLabels.value, formatter: n.name, fontSize: 12, color: labelColor(), textBorderColor: isDark() ? 'rgba(15,23,42,0.9)' : 'rgba(255,255,255,0.9)', textBorderWidth: 2 } })),
      links: chordLinks.map(l => ({
        source: l.source, target: l.target, value: l.value,
        lineStyle: { color: colorById.get(l.source) || '#909399', width: 1.6, opacity: 0.6, curveness: 0.08 }, // 连线统一粗细（用户：粗细不统一，按统一线条）
      })),
      categories: [],
      emphasis: { focus: 'adjacency', scale: 1.15 },
    }],
  }, true);
  requestAnimationFrame(() => chart?.resize());
}

/** ---------- 树图：构建 + 层级折叠（完全由节点 collapsed 控制，不用 initialTreeDepth） ---------- */
interface TreeNode extends GraphNodeLike { children: TreeNode[]; collapsed?: boolean }
interface GraphNodeLike {
  id: string; name: string; label: string; category: string; symbolSize: number;
}

function buildTree(): TreeNode[] {
  const byId = new Map<string, TreeNode>(data.nodes.map(n => [n.id, { ...n, children: [] as TreeNode[] }]));
  const hasParent = new Set<string>();
  for (const l of data.links) {
    if (byId.has(l.source) && byId.has(l.target)) {
      byId.get(l.source)!.children.push(byId.get(l.target)!);
      hasParent.add(l.target);
    }
  }
  return [...byId.values()].filter(n => !hasParent.has(n.id));
}

/** 剪枝：保留前 maxDepth 层（根=第1层），更深子节点全部剪掉 */
function pruneTree(nodes: TreeNode[], maxDepth: number, cur = 1): TreeNode[] {
  return nodes.map(n => ({
    ...n,
    children: cur < maxDepth ? pruneTree(n.children, maxDepth, cur + 1) : [],
  }));
}

function renderTree() {
  if (!chartEl.value) return;
  const roots = buildTree();
  let treeData: TreeNode[] = roots;
  // 层级控制统一用数据剪枝 + 全展开，规避 ECharts initialTreeDepth 的层数偏移/等价问题
  // 层数=显示节点的层级：第1层=根+一级（同全部折叠）；第N层=显示到第N级
  if (collapseMode.value === 'root') {
    treeData = pruneTree(roots, 2); // 全部折叠：根 + 一级
  } else if (collapseMode.value === 'depth') {
    treeData = pruneTree(roots, collapseDepth.value + 1); // 第N层：显示到第N级
  }
  // ECharts tree 多根（森林）布局有 bug：多根时只渲染第一棵子树
  // 解决：包一个隐藏虚拟根，转成单根树（虚拟根 symbolSize 0、无 label、连线透明，不影响层数语义）
  if (treeData.length > 1) {
    treeData = [{
      id: '__forest__', name: '__forest__', label: '', category: 'tag', symbolSize: 0,
      children: treeData, collapsed: false,
      itemStyle: { color: 'transparent', borderWidth: 0 },
      lineStyle: { color: 'transparent', opacity: 0 },
      label: { show: false },
    } as unknown as TreeNode];
  }
  maxDepth.value = visibleDepth(roots);

  const labelMap = nameToLabel();
  chart?.dispose();
  chart = initChart();
  chart.setOption({
    tooltip: {
      trigger: 'item', confine: true, hideDelay: 60,
      formatter: (p: any) => nodeTip(p.data.category || 'folder', p.data.label || p.data.name, p.data.name),
    },
    series: [{
      type: 'tree',
      data: treeData,
      layout: 'orthogonal',
      orient: 'LR',
      top: 12, left: 10, right: 70, bottom: 12,
      roam: true, // 滚轮缩放、拖拽平移（树图此前无法缩放）
      symbolSize: 7, // 节点缩小（原 9）
      initialTreeDepth: -1,
      label: { show: showLabels.value, formatter: (p: any) => labelMap.get(p.name) || p.name, fontSize: 12, color: labelColor(), position: 'right', textBorderColor: isDark() ? 'rgba(15,23,42,0.9)' : 'rgba(255,255,255,0.9)', textBorderWidth: 2 },
      lineStyle: { color: lineColor(), width: 1.8 }, // 线条加粗（原 1 过细）
      expandAndCollapse: true,
    }],
  }, true);
  requestAnimationFrame(() => chart?.resize());
}

/** 树最大深度（节点层级数，Code=1） */
function treeMaxDepth(roots: TreeNode[]): number {
  let max = 0;
  const walk = (ns: TreeNode[], d: number) => {
    for (const n of ns) {
      max = Math.max(max, d + 1);
      if (n.children.length) walk(n.children, d + 1);
    }
  };
  walk(roots, 0);
  return max;
}

/** 折叠层数上限 = 树层级数 - 1（"可见层数"：第1层=根+一级……第N层=全量；叶子层不计入可展开步数） */
function visibleDepth(roots: TreeNode[]): number {
  return Math.max(1, treeMaxDepth(roots) - 1);
}

/** 层级控制：全部视图可用（关系图/桑基图按深度过滤节点，树图按 collapsed 折叠） */
function setCollapse(mode: 'all' | 'root' | 'depth') {
  collapseMode.value = mode;
  render();
}

/** 自研缩放倍数显示（graph/tree/chord/treemap 走原生 roam，由 ECharts 内部缩放，不显示倍数） */
const zoomLabel = computed(() => {
  if (view.value === 'pack') return zoomFactor.value.toFixed(2) + 'x';
  if (view.value === 'sunburst') return sunZoom.value + 'x';
  if (view.value === 'sankey') return cssZoom.value + 'x';
  return '';
});

async function load() {
  loading.value = true;
  // 视图/维度切换后清除下钻与缩放状态
  drillStack.value = [];
  zoomFactor.value = 1;
  sunZoom.value = 1;
  cssZoom.value = 1;
  const resetEl = chartEl.value || (document.querySelector('.chart-box .chart') as HTMLElement | null);
  if (resetEl) resetEl.style.transform = '';
  // 立即清空旧图，给用户"正在切换"的明确反馈（维度/视图数据量大时渲染较慢）
  if (chart) { chart.clear(); }
  if (isHierarchyView()) {
    // 矩形树图/旭日图/打包图：与维度无关，直接用文件夹层级
    hierarchy = await getGraphHierarchy();
    // value 已在后端自底向上累加为"子树文件数"，顶层求和即总文件数（不得递归重复累加）
    nodeCount.value = hierarchy.reduce((s, n) => s + n.value, 0);
    linkCount.value = 0;
    // 最大可见层级 = 树层级（含 Code 根）减 1（Code 根不显示，最内层是顶级文件夹）；下拉选项 1..maxDepth，第 maxDepth 层=全量
  maxDepth.value = Math.max(1, hierarchyDepth(hierarchy) - 1);
    if (collapseDepth.value > maxDepth.value) collapseDepth.value = maxDepth.value;
  } else {
    // 弦图需要"标签→资源"连线反推共现，强制走 tag 维度；其余按所选维度
    data = await getGraph(view.value === 'chord' ? 'tag' : dimension.value);
    nodeCount.value = data.nodes.length;
    linkCount.value = data.links.length;
    // 树最大深度与视图无关，先算好（折叠下拉选项在任何视图都正确）
    const roots = buildTree();
    maxDepth.value = visibleDepth(roots);
    // 下拉层数上限可能变小（如标签图只有 2 级 → maxDepth=1），夹紧默认值避免显示越界选项
    if (collapseDepth.value > maxDepth.value) collapseDepth.value = maxDepth.value;
  }
  await nextTick();
  render();
  loading.value = false;
}

function onResize() { chart?.resize(); }

/** 主题切换（跟随系统/手动深色/浅色）时重渲染图表 */
function onThemeChange() { render(); }

let ro: ResizeObserver | null = null;

watch([dimension, view], load);
// 标签显示开关：只局部更新 label 显示（不重建图表 → 关系图 force 布局不重排、树图不闪烁）
// pack 为 custom 系列（文字在 renderItem 内）、chord 标签在 data 项上，这两类局部更新无效 → 重渲染
watch(showLabels, () => {
  if (!chart || !chartEl.value) return;
  if (view.value === 'pack' || view.value === 'chord') { render(); return; }
  const patch: any = { series: [{ label: { show: showLabels.value } }] };
  if (view.value === 'treemap') patch.series[0].upperLabel = { show: showLabels.value };
  chart.setOption(patch, { lazyUpdate: true });
});

onMounted(() => {
  load();
  window.addEventListener('resize', onResize);
  window.addEventListener('kh-theme-change', onThemeChange);
  if (typeof ResizeObserver !== 'undefined' && chartEl.value) {
    ro = new ResizeObserver(() => chart?.resize());
    ro.observe(chartEl.value);
  }
});
onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize);
  window.removeEventListener('kh-theme-change', onThemeChange);
  ro?.disconnect();
  chart?.dispose();
  chart = null;
});
</script>

<template>
  <div class="graph-view">
    <div class="graph-toolbar">
      <span class="label">维度</span>
      <!-- 矩形树图/旭日图/打包图基于文件夹层级，与维度无关：禁用维度切换避免"点了没反应" -->
      <el-radio-group v-model="dimension" :disabled="isHierarchyView()">
        <el-radio-button v-for="(d, k) in dimensionLabels" :key="k" :value="k">{{ d }}</el-radio-button>
      </el-radio-group>
      <span class="label" style="margin-left: 16px;">视图</span>
      <el-radio-group v-model="view">
        <el-radio-button v-for="(v, k) in viewLabels" :key="k" :value="k">{{ v }}</el-radio-button>
      </el-radio-group>

      <!-- 标签显示开关：控制所有视图的节点标签（默认不显示） -->
      <el-checkbox v-model="showLabels" style="margin-left: 12px; white-space: nowrap;">显示标签</el-checkbox>

      <!-- 层级控制：所有视图可用（关系图/桑基图按层过滤，树图折叠节点，层级图剪枝） -->
      <el-button-group>
        <el-button size="small" @click="setCollapse('all')">全部展开</el-button>
        <el-button size="small" @click="setCollapse('root')">全部折叠</el-button>
      </el-button-group>
      <span class="label">折叠到层</span>
      <el-select v-model="collapseDepth" size="small" style="width: 88px;" @change="setCollapse('depth')">
        <el-option v-for="d in maxDepth" :key="d" :value="d" :label="`第${d}层`" />
      </el-select>

      <!-- 层级图下钻 / 缩放：点击组节点只显示该组及其子节点，点空白返回上级（返回上级=点击空白区域，无需独立按钮） -->
      <template v-if="isHierarchyView()">
        <el-button size="small" :disabled="drillStack.length === 0 && zoomFactor === 1" @click="resetView">重置视图</el-button>
        <span class="hint">{{ view === 'treemap' ? '滚轮/拖动缩放，点击组节点下钻，点空白返回' : view === 'pack' ? '滚轮缩放，点击组节点下钻，点空白返回' : '点击组节点下钻（放大），点空白返回' }}</span>
      </template>

      <span class="count" v-loading="loading">
        <template v-if="zoomLabel"><span class="zoom-tag">缩放 {{ zoomLabel }}</span></template>
        <template v-if="isHierarchyView()">{{ nodeCount }} 文件（含子文件夹）</template>
        <template v-else>{{ nodeCount }} 节点 / {{ linkCount }} 连线</template>
        <template v-if="!isHierarchyView() && dimension === 'link' && linkCount === 0">（双链表为空，M5 后可用）</template>
        <template v-else-if="!isHierarchyView() && dimension === 'tag' && linkCount === 0">（标签体系在 M2 建立后可用）</template>
      </span>
    </div>
    <div class="chart-box" @wheel="onWheel">
      <div ref="chartEl" class="chart"></div>
      <div v-if="nodeCount === 0" class="chart-empty">
        <div class="ce-icon">{{ isHierarchyView() ? '🗂️' : dimension === 'link' ? '🔗' : '🏷️' }}</div>
        <div class="ce-title">{{ isHierarchyView() ? '文件夹层级暂无数据' : dimension === 'link' ? '引用（双链）暂无数据' : view === 'chord' ? '标签共现暂无数据' : '该维度暂无数据' }}</div>
        <div class="ce-hint">{{ isHierarchyView() ? '先在 Code 目录中存放文件并刷新入库' : dimension === 'link' ? '笔记双链功能尚未建立，后续里程碑可用' : view === 'chord' ? '需要至少两个标签同时出现在同一资源上' : '先在其他页面创建资源或标签' }}</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.graph-view { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.graph-toolbar { display: flex; align-items: center; gap: 8px; padding: 10px 16px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.graph-toolbar .label { font-size: 13px; color: var(--el-text-color-secondary, #6b7280); }
.graph-toolbar .hint { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.graph-toolbar .count { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-left: auto; }
.graph-toolbar .zoom-tag { display: inline-block; margin-right: 10px; padding: 1px 8px; border-radius: 4px; font-size: 12px; color: #fff; background: var(--kh-brand, #409eff); }
.chart-box { flex: 1; min-height: 0; position: relative; }
.chart { height: 100%; width: 100%; }
.chart-empty {
  position: absolute; inset: 0; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 6px;
  background: var(--el-bg-color, #fff); color: var(--el-text-color-secondary, #9ca3af);
}
.ce-icon { font-size: 34px; }
.ce-title { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #4b5563); }
.ce-hint { font-size: 12px; }
</style>
