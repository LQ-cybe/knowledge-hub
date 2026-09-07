<script setup lang="ts">
import { onMounted, ref, watch, nextTick, onBeforeUnmount } from 'vue';
import * as echarts from 'echarts';
import { getGraph, type GraphData } from './api';

const dimension = ref<'folder' | 'tag' | 'link'>('folder');
const view = ref<'graph' | 'sankey' | 'tree'>('graph');
const chartEl = ref<HTMLElement>();
const loading = ref(false);
const nodeCount = ref(0);
const linkCount = ref(0);

/** 层级折叠状态：all=全部展开 / root=全部折叠 / depth=折叠到 N 层 */
const collapseMode = ref<'all' | 'root' | 'depth'>('all');
const collapseDepth = ref(2);
const maxDepth = ref(1);

let chart: echarts.ECharts | null = null;
let data: GraphData = { nodes: [], links: [] };

const dimensionLabels: Record<string, string> = { folder: '文件夹', tag: '标签', link: '引用' };
const viewLabels: Record<string, string> = { graph: '关系图', sankey: '桑基图', tree: '树图' };
const typeLabels: Record<string, string> = { folder: '文件夹', file: '文件', tag: '标签', resource: '资源' };

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
    if (!chart) {
      chart = echarts.init(chartEl.value);
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
          animationDurationUpdate: 0,
          emphasis: { scale: 1.15, label: { show: true } },
          data: nodes.map(n => ({
            id: n.id, name: n.name, symbolSize: n.symbolSize, category: n.category,
            label: { show: true, formatter: fmt, fontSize: 11, color: labelColor() },
          })),
          links: links.map(l => ({ source: l.source, target: l.target })),
          categories: [
            { name: 'folder', itemStyle: { color: '#8BC8EA' } },
            { name: 'file', itemStyle: { color: '#B0BEC5' } },
            { name: 'tag', itemStyle: { color: '#52C41A' } },
            { name: 'resource', itemStyle: { color: '#F4A261' } },
          ],
          force: { repulsion: 90, edgeLength: 60, gravity: 0.1, friction: 0.9, layoutAnimation: false },
          lineStyle: { color: 'source', curveness: 0.1, opacity: 0.5 },
        }],
      }, true);
      requestAnimationFrame(() => chart?.resize()); // 等 setOption 渲染结束再 resize，避免 ECharts 警告
    } else if (view.value === 'sankey') {
      const { nodes, links } = filtered();
      const idToName = new Map(nodes.map(n => [n.id, n.name]));
      const sNodes = nodes.map(n => ({ name: n.name, itemStyle: n.category === 'folder' ? { color: '#8BC8EA' } : {} }));
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
          label: { formatter: fmt, fontSize: 11, color: labelColor() },
          lineStyle: { color: 'gradient', opacity: 0.5 },
          nodeAlign: 'left',
          emphasis: { focus: 'adjacency' },
        }],
      }, true);
      requestAnimationFrame(() => chart?.resize());
    } else {
      renderTree();
      return;
    }
  } catch (e) {
    console.error('graph render error:', e);
  }
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
  chart = echarts.init(chartEl.value);
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
      symbolSize: 9,
      initialTreeDepth: -1,
      label: { formatter: (p: any) => labelMap.get(p.name) || p.name, fontSize: 11, color: labelColor(), position: 'right' },
      lineStyle: { color: lineColor(), width: 1 },
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

async function load() {
  loading.value = true;
  // 立即清空旧图，给用户"正在切换"的明确反馈（维度/视图数据量大时渲染较慢）
  if (chart) { chart.clear(); }
  data = await getGraph(dimension.value);
  nodeCount.value = data.nodes.length;
  linkCount.value = data.links.length;
  // 树最大深度与视图无关，先算好（折叠下拉选项在任何视图都正确）
  const roots = buildTree();
  maxDepth.value = visibleDepth(roots);
  // 下拉层数上限可能变小（如标签图只有 2 级 → maxDepth=1），夹紧默认值避免显示越界选项
  if (collapseDepth.value > maxDepth.value) collapseDepth.value = maxDepth.value;
  await nextTick();
  render();
  loading.value = false;
}

function onResize() { chart?.resize(); }

/** 主题切换（跟随系统/手动深色/浅色）时重渲染图表 */
function onThemeChange() { render(); }

let ro: ResizeObserver | null = null;

watch([dimension, view], load);

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
      <el-radio-group v-model="dimension">
        <el-radio-button v-for="(d, k) in dimensionLabels" :key="k" :value="k">{{ d }}</el-radio-button>
      </el-radio-group>
      <span class="label" style="margin-left: 16px;">视图</span>
      <el-radio-group v-model="view">
        <el-radio-button v-for="(v, k) in viewLabels" :key="k" :value="k">{{ v }}</el-radio-button>
      </el-radio-group>

      <!-- 层级控制：所有视图可用（关系图/桑基图按层过滤，树图折叠节点） -->
      <el-button-group>
        <el-button size="small" @click="setCollapse('all')">全部展开</el-button>
        <el-button size="small" @click="setCollapse('root')">全部折叠</el-button>
      </el-button-group>
      <span class="label">折叠到层</span>
      <el-select v-model="collapseDepth" size="small" style="width: 88px;" @change="setCollapse('depth')">
        <el-option v-for="d in maxDepth" :key="d" :value="d" :label="`第${d}层`" />
      </el-select>

      <span class="count" v-loading="loading">
        {{ nodeCount }} 节点 / {{ linkCount }} 连线
        <template v-if="dimension === 'link' && linkCount === 0">（双链表为空，M5 后可用）</template>
        <template v-else-if="dimension === 'tag' && linkCount === 0">（标签体系在 M2 建立后可用）</template>
      </span>
    </div>
    <div class="chart-box">
      <div ref="chartEl" class="chart"></div>
      <div v-if="nodeCount === 0" class="chart-empty">
        <div class="ce-icon">{{ dimension === 'link' ? '🔗' : '🗂️' }}</div>
        <div class="ce-title">{{ dimension === 'link' ? '引用（双链）暂无数据' : '该维度暂无数据' }}</div>
        <div class="ce-hint">{{ dimension === 'link' ? '笔记双链功能尚未建立，后续里程碑可用' : '先在其他页面创建资源或标签' }}</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.graph-view { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.graph-toolbar { display: flex; align-items: center; gap: 8px; padding: 10px 16px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.graph-toolbar .label { font-size: 13px; color: var(--el-text-color-secondary, #6b7280); }
.graph-toolbar .count { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-left: auto; }
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
