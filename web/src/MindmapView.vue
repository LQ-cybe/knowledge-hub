<script setup lang="ts">
/** 思维导图：独立导图工作区（导图库 + 编辑器）
 *  布局：自由编辑/向右/向左/组织图/放射；节点编辑：Enter同级 Tab子级 Delete删除 双击改名 拖拽自由调整
 *  工具：+子主题 +同级 多选 关系 边界 概要；右侧：主题样式/节点颜色/形状；自动保存 + 缩放
 */
import { computed, nextTick, onMounted, onBeforeUnmount, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getMindmaps, createMindmap, deleteMindmap, getMindmap, updateMindmap, saveMindmapNodes, saveMindmapLinks, saveMindmapMembers } from './api';

interface MMNode { id: string; parent_id: string | null; title: string; kind: string; x: number; y: number; color: string | null; shape: string; sort: number }
interface MMLink { id: string; source_id: string; target_id: string; label: string }
interface MMMember { group_id: string; node_id: string }

const THEMES: Record<string, { name: string; bg: string; node: string; text: string; line: string }> = {
  'nexa-light': { name: 'Nexa 明亮', bg: '#ffffff', node: '#409eff', text: '#1f2937', line: '#c3cad4' },
  'nexa-dark': { name: 'Nexa 深色', bg: '#1e222b', node: '#5aa2ff', text: '#e5e9f0', line: '#3a4150' },
  classic: { name: '经典分支', bg: '#faf6ee', node: '#d97706', text: '#5b4636', line: '#e0d3bd' },
  azure: { name: '音蓝架构', bg: '#0e1a2b', node: '#38bdf8', text: '#d9e6f5', line: '#27415e' },
};
const SHAPES: Record<string, string> = { auto: '自动', rect: '矩形', round: '圆角', ellipse: '椭圆' };
const ROW_H = 44, COL_W = 230, RAD_R = 190;

// ---------- 状态 ----------
const view = ref<'library' | 'editor'>('library');   // 导图库 / 编辑器
const maps = ref<{ id: string; title: string; layout: string; theme: string; updated_at: string; node_count: number }[]>([]);
const mapId = ref('');
const mapTitle = ref('');
const mapLayout = ref('right');
const mapTheme = ref('nexa-light');
const nodes = ref<MMNode[]>([]);
const links = ref<MMLink[]>([]);
const members = ref<MMMember[]>([]);
const selected = ref<Set<string>>(new Set());       // 多选（Shift 点击）；单选时含 1 个
const hoverId = ref('');
const editingId = ref('');
const editText = ref('');
const toolMode = ref<'none' | 'relate'>('none');     // 关系连线模式
const relateFrom = ref('');
const zoom = ref(1);
const savedState = ref('');                          // ''=未变 / 保存中 / 已保存
const canvasEl = ref<HTMLElement>();

const theme = computed(() => THEMES[mapTheme.value] || THEMES['nexa-light']);

// ---------- 节点工具 ----------
const nodeById = computed(() => new Map(nodes.value.map(n => [n.id, n])));
function childrenOf(id: string | null) {
  return nodes.value.filter(n => n.parent_id === id && n.kind === 'node').sort((a, b) => a.sort - b.sort);
}
const selNode = computed(() => selected.value.size === 1 ? nodeById.value.get([...selected.value][0]) : null);

// ---------- 布局算法 ----------
function leafCount(id: string, byId: Map<string, MMNode>, kids: Map<string, MMNode[]>): number {
  const cs = kids.get(id) || [];
  if (!cs.length) return 1;
  return cs.reduce((s, c) => s + leafCount(c.id, byId, kids), 0);
}
/** 树布局：返回 id → {x,y}（父垂直居中于子树叶子带；径向单独处理） */
function treeLayout(roots: MMNode[], byId: Map<string, MMNode>, kids: Map<string, MMNode[]>): Map<string, { x: number; y: number }> {
  const pos = new Map<string, { x: number; y: number }>();
  const leaves = new Map<string, number>();
  const calc = (id: string) => { const v = leafCount(id, byId, kids); leaves.set(id, v); return v; };
  const dir = mapLayout.value === 'left' ? -1 : 1;
  const place = (id: string, depth: number, topY: number) => {
    calc(id);
    const lc = leaves.get(id)!;
    const y = topY + (lc / 2 - 0.5) * ROW_H;
    pos.set(id, { x: dir * depth * COL_W, y });
    let cur = topY;
    for (const c of kids.get(id) || []) {
      const clc = calc(c.id);
      place(c.id, depth + 1, cur);
      cur += clc * ROW_H;
    }
  };
  let top = 0;
  for (const r of roots) { const rlc = calc(r.id); place(r.id, 0, top); top += rlc * ROW_H; }
  return pos;
}
function radialLayout(roots: MMNode[], byId: Map<string, MMNode>, kids: Map<string, MMNode[]>): Map<string, { x: number; y: number }> {
  const pos = new Map<string, { x: number; y: number }>();
  const place = (id: string, depth: number, a0: number, a1: number) => {
    const cs = kids.get(id) || [];
    pos.set(id, { x: depth * RAD_R * Math.cos((a0 + a1) / 2), y: depth * RAD_R * Math.sin((a0 + a1) / 2) });
    if (cs.length === 0) return;
    const span = (a1 - a0) / cs.length;
    cs.forEach((c, i) => place(c.id, depth + 1, a0 + span * i, a0 + span * (i + 1)));
  };
  if (!roots.length) return pos;
  if (roots.length === 1) {
    pos.set(roots[0].id, { x: 0, y: 0 });
    const cs = kids.get(roots[0].id) || [];
    const n = cs.length || 1;
    cs.forEach((c, i) => place(c.id, 1, (i / n) * Math.PI * 2 - Math.PI / 2, ((i + 1) / n) * Math.PI * 2 - Math.PI / 2));
  } else {
    const n = roots.length;
    roots.forEach((r, i) => place(r.id, 0, (i / n) * Math.PI * 2 - Math.PI / 2, ((i + 1) / n) * Math.PI * 2 - Math.PI / 2));
  }
  return pos;
}
/** 组织图布局：垂直向下，父在上子在下，按叶子列宽居中（类公司组织架构） */
function orgLayout(roots: MMNode[], byId: Map<string, MMNode>, kids: Map<string, MMNode[]>): Map<string, { x: number; y: number }> {
  const pos = new Map<string, { x: number; y: number }>();
  const leaves = new Map<string, number>();
  const calc = (id: string) => { const v = leafCount(id, byId, kids); leaves.set(id, v); return v; };
  const place = (id: string, depth: number, start: number, span: number) => {
    const x = (start + span / 2 - 0.5) * COL_W;
    const y = depth * 96;
    pos.set(id, { x, y });
    let cur = start;
    for (const c of kids.get(id) || []) {
      const clc = calc(c.id);
      place(c.id, depth + 1, cur, clc);
      cur += clc;
    }
  };
  let col = 0;
  for (const r of roots) { const rlc = calc(r.id); place(r.id, 0, col, rlc); col += rlc; }
  return pos;
}
/** 计算所有 node 节点的渲染坐标（自由布局用存储坐标；其余自动计算，不写回存储，保护自由坐标） */
const renderPos = ref<Map<string, { x: number; y: number }>>(new Map());
function applyLayout() {
  const byId = nodeById.value;
  const kids = new Map<string, MMNode[]>();
  for (const n of nodes.value) {
    if (!n.parent_id) continue;
    if (!kids.has(n.parent_id)) kids.set(n.parent_id, []);
    kids.get(n.parent_id)!.push(n);
  }
  for (const k of kids.keys()) kids.get(k)!.sort((a, b) => a.sort - b.sort);
  const m = new Map<string, { x: number; y: number }>();
  const roots = nodes.value.filter(n => !n.parent_id && n.kind === 'node');
  if (mapLayout.value === 'free') {
    for (const n of nodes.value) m.set(n.id, { x: n.x, y: n.y });
  } else {
    const auto = mapLayout.value === 'radial' ? radialLayout(roots, byId, kids) : mapLayout.value === 'org' ? orgLayout(roots, byId, kids) : treeLayout(roots, byId, kids);
    for (const n of nodes.value) { const p = auto.get(n.id); if (p) m.set(n.id, p); }
  }
  // 概要节点固定显示在所属主题右侧（不参与层级递推）
  for (const n of nodes.value) {
    if (n.kind === 'summary' && n.parent_id) {
      const p = byId.get(n.parent_id);
      const pp = p && m.get(p.id);
      if (pp) m.set(n.id, { x: pp.x + 140, y: pp.y });
    }
  }
  renderPos.value = m;
}
const P = (n: MMNode) => renderPos.value.get(n.id) || { x: 0, y: 0 };

/** 画布内容包围盒（节点 + 边界/概要成员 + 关系线） */
const canvasSize = computed(() => {
  let minX = -80, minY = -80, maxX = 80, maxY = 80;
  for (const n of nodes.value) {
    const p = P(n);
    minX = Math.min(minX, p.x - 90); maxX = Math.max(maxX, p.x + 90);
    minY = Math.min(minY, p.y - 26); maxY = Math.max(maxY, p.y + 26);
  }
  return { x: minX, y: minY, w: maxX - minX + 60, h: maxY - minY + 60 };
});

// ---------- 数据加载 / 保存 ----------
let saveTimer: ReturnType<typeof setTimeout> | null = null;
function markDirty() { savedState.value = ''; if (saveTimer) clearTimeout(saveTimer); saveTimer = setTimeout(saveAll, 500); }
async function saveAll() {
  if (!mapId.value) return;
  savedState.value = '保存中';
  try {
    await Promise.all([
      saveMindmapNodes(mapId.value, nodes.value),
      saveMindmapLinks(mapId.value, links.value),
      saveMindmapMembers(mapId.value, members.value),
      updateMindmap(mapId.value, { title: mapTitle.value, layout: mapLayout.value, theme: mapTheme.value }),
    ]);
    savedState.value = '已保存';
  } catch { savedState.value = '保存失败'; }
}
async function openMap(id: string) {
  const data = await getMindmap(id);
  mapId.value = id;
  mapTitle.value = data.title;
  mapLayout.value = data.layout;
  mapTheme.value = data.theme;
  nodes.value = data.nodes;
  links.value = data.links;
  members.value = data.members;
  selected.value = new Set();
  applyLayout();
  view.value = 'editor';
  savedState.value = '已保存';
}
function backToLibrary() { if (saveTimer) clearTimeout(saveTimer); saveAll(); view.value = 'library'; loadMaps(); }
async function loadMaps() { maps.value = await getMindmaps(); }
async function newMap() {
  const { value } = await ElMessageBox.prompt('给新导图起个名字', '新建思维导图', { inputValue: '', confirmButtonText: '创建', cancelButtonText: '取消' });
  const r = await createMindmap(value || '未命名导图');
  await openMap(r.id);
  loadMaps();
}
async function delMap(id: string, title: string) {
  await ElMessageBox.confirm(`确定删除导图「${title}」？该操作不可恢复。`, '删除确认', { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' });
  await deleteMindmap(id);
  loadMaps();
}

// ---------- 节点操作 ----------
function uid() { return crypto.randomUUID(); }
function insertNode(parentId: string | null, title = '新主题'): MMNode {
  const sibs = nodes.value.filter(n => n.parent_id === parentId && n.kind === 'node');
  const n: MMNode = { id: uid(), parent_id: parentId, title, kind: 'node', x: 0, y: 0, color: null, shape: 'auto', sort: sibs.length };
  nodes.value.push(n);
  return n;
}
function addChild() {
  const p = selNode.value;
  if (!p) { ElMessage.warning('请先单击选中一个节点'); return; }
  const n = insertNode(p.id);
  applyLayout(); selected.value = new Set([n.id]); editingId.value = n.id; editText.value = ''; markDirty();
}
function addSibling() {
  const p = selNode.value;
  if (!p) { ElMessage.warning('请先选中一个节点'); return; }
  const n = insertNode(p.parent_id);
  applyLayout(); selected.value = new Set([n.id]); editingId.value = n.id; editText.value = ''; markDirty();
}
function removeSelected() {
  if (!selected.value.size) return;
  const ids = [...selected.value];
  const doomed = new Set(ids);
  // 级联删除子树（node 类型）
  let grew = true;
  while (grew) { grew = false; for (const n of nodes.value) if (doomed.has(n.parent_id as string) && !doomed.has(n.id)) { doomed.add(n.id); grew = true; } }
  nodes.value = nodes.value.filter(n => !doomed.has(n.id));
  links.value = links.value.filter(l => !doomed.has(l.source_id) && !doomed.has(l.target_id));
  members.value = members.value.filter(m => !doomed.has(m.group_id) && !doomed.has(m.node_id));
  selected.value = new Set(); markDirty();
}
function startEdit(id: string) { editingId.value = id; editText.value = nodeById.value.get(id)?.title || ''; }
function commitEdit() {
  const n = nodeById.value.get(editingId.value);
  if (n) { n.title = editText.value.trim() || n.title; markDirty(); }
  editingId.value = '';
}
function onKeydown(e: KeyboardEvent) {
  if (view.value !== 'editor') return;
  if (editingId.value) { if (e.key === 'Escape') editingId.value = ''; return; }
  if (e.key === 'Enter' && selected.value.size) { e.preventDefault(); addSibling(); }
  else if (e.key === 'Tab' && selected.value.size) { e.preventDefault(); addChild(); }
  else if ((e.key === 'Delete' || e.key === 'Backspace') && selected.value.size) { e.preventDefault(); removeSelected(); }
}

// ---------- 交互：选中 / 拖拽（自由布局）/ 关系连线 / 边界 / 概要 ----------
function onNodeClick(n: MMNode, e: MouseEvent) {
  if (toolMode.value === 'relate') {
    if (!relateFrom.value) { relateFrom.value = n.id; return; }
    if (relateFrom.value !== n.id) {
      links.value.push({ id: uid(), source_id: relateFrom.value, target_id: n.id, label: '' });
      markDirty();
    }
    relateFrom.value = ''; toolMode.value = 'none'; return;
  }
  const multi = e.shiftKey;
  if (multi) {
    const s = new Set(selected.value);
    if (s.has(n.id)) s.delete(n.id); else s.add(n.id);
    selected.value = s;
  } else {
    selected.value = new Set([n.id]);
  }
}
let dragState: { id: string; ox: number; oy: number; sx: number; sy: number } | null = null;
function onNodeDown(n: MMNode, e: MouseEvent) {
  if (e.button !== 0) return;
  dragState = { id: n.id, ox: n.x, oy: n.y, sx: e.clientX, sy: e.clientY };
  (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
}
function onNodeMove(n: MMNode, e: MouseEvent) {
  if (!dragState || dragState.id !== n.id || mapLayout.value !== 'free') return;
  const dx = (e.clientX - dragState.sx) / zoom.value, dy = (e.clientY - dragState.sy) / zoom.value;
  n.x = dragState.ox + dx; n.y = dragState.oy + dy;
  const m = new Map(renderPos.value); m.set(n.id, { x: n.x, y: n.y });
  renderPos.value = m;
  markDirty();
}
function onNodeUp() { dragState = null; }

function toggleRelate() { toolMode.value = toolMode.value === 'relate' ? 'none' : 'relate'; relateFrom.value = ''; ElMessage.info(toolMode.value === 'relate' ? '关系模式：依次单击两个节点建立连线' : '已退出关系模式'); }
function addBoundary() {
  const s = [...selected.value];
  if (s.length < 2) { ElMessage.warning('请按住 Shift 多选至少 2 个节点，再创建边界'); return; }
  const b: MMNode = { id: uid(), parent_id: null, title: '边界', kind: 'boundary', x: 0, y: 0, color: null, shape: 'auto', sort: 0 };
  nodes.value.push(b);
  for (const id of s) members.value.push({ group_id: b.id, node_id: id });
  applyLayout(); markDirty(); selected.value = new Set([b.id]);
}
function addSummary() {
  const p = selNode.value;
  if (!p) { ElMessage.warning('请先选中一个节点'); return; }
  const s: MMNode = { id: uid(), parent_id: p.id, title: '概要', kind: 'summary', x: 0, y: 0, color: null, shape: 'auto', sort: 0 };
  nodes.value.push(s);
  applyLayout(); markDirty(); selected.value = new Set([s.id]); editingId.value = s.id; editText.value = '';
}
function removeBoundary(b: MMNode) {
  nodes.value = nodes.value.filter(n => n.id !== b.id);
  members.value = members.value.filter(m => m.group_id !== b.id);
  selected.value = new Set(); markDirty();
}
/** 布局切换：重算渲染坐标；切到自由布局且从未整理过（坐标全 0）时自动按层级填充，避免节点重叠 */
function onLayoutChange() {
  applyLayout();
  if (mapLayout.value === 'free' && nodes.value.some(n => n.kind === 'node') &&
      nodes.value.filter(n => n.kind === 'node').every(n => n.x === 0 && n.y === 0)) {
    tidyFree(false);
  }
  markDirty();
}
/** 按层级整理自由坐标：用向右布局的位置写入存储坐标，供自由布局拖拽的起点 */
function tidyFree(notify = true) {
  const saved = mapLayout.value;
  mapLayout.value = 'right';
  applyLayout();
  for (const n of nodes.value) { const p = renderPos.value.get(n.id); if (p) { n.x = Math.round(p.x); n.y = Math.round(p.y); } }
  mapLayout.value = saved;
  applyLayout();
  markDirty();
  if (notify) ElMessage.success('已按层级整理自由坐标，可继续拖动调整');
}

// ---------- 渲染辅助 ----------
const nodeStyle = (n: MMNode) => {
  const p = P(n);
  const w = n.kind === 'summary' ? 120 : n.kind === 'boundary' ? 0 : undefined;
  const h = n.kind === 'summary' ? 30 : n.kind === 'boundary' ? 0 : undefined;
  return {
    left: (p.x + (canvasSize.value.x < 0 ? -canvasSize.value.x : 0) - (w || 78) / 2) + 'px',
    top: (p.y + (canvasSize.value.y < 0 ? -canvasSize.value.y : 0) - (h || 16) / 2) + 'px',
    width: w ? w + 'px' : undefined,
    height: h ? h + 'px' : undefined,
  };
};
const nodeFill = (n: MMNode) => n.color || theme.value.node;
const isSel = (id: string) => selected.value.has(id);
const shapeRadius = (s: string) => ({ auto: 8, rect: 2, round: 14, ellipse: 20 }[s] || 8);

function edgePath(a: MMNode, b: MMNode, org = false) {
  const pa = P(a), pb = P(b);
  const off = canvasSize.value.x < 0 ? -canvasSize.value.x : 0;
  const top = canvasSize.value.y < 0 ? -canvasSize.value.y : 0;
  const x1 = pa.x + off, y1 = pa.y + top, x2 = pb.x + off, y2 = pb.y + top;
  if (org) return `M ${x1} ${y1} C ${x1} ${(y1 + y2) / 2}, ${x2} ${(y1 + y2) / 2}, ${x2} ${y2}`;
  return `M ${x1} ${y1} C ${(x1 + x2) / 2} ${y1}, ${(x1 + x2) / 2} ${y2}, ${x2} ${y2}`;
}
/** 边界包围盒（成员节点 bbox + padding） */
function boundaryBox(b: MMNode) {
  const ms = members.value.filter(m => m.group_id === b.id).map(m => nodeById.value.get(m.node_id)).filter(Boolean) as MMNode[];
  if (!ms.length) return null;
  const off = canvasSize.value.x < 0 ? -canvasSize.value.x : 0, top = canvasSize.value.y < 0 ? -canvasSize.value.y : 0;
  const pad = 16;
  const xs = ms.map(n => P(n).x + off), ys = ms.map(n => P(n).y + top);
  return { x: Math.min(...xs) - 70 - pad, y: Math.min(...ys) - 18 - pad, w: Math.max(...xs) - Math.min(...xs) + 140 + pad * 2, h: Math.max(...ys) - Math.min(...ys) + 32 + pad * 2 };
}

// ---------- 生命周期 ----------
onMounted(() => { loadMaps(); window.addEventListener('keydown', onKeydown); });
onBeforeUnmount(() => { window.removeEventListener('keydown', onKeydown); if (saveTimer) { clearTimeout(saveTimer); saveAll(); } });
</script>

<template>
  <div class="mm-view">
    <!-- ============ 导图库 ============ -->
    <div v-if="view === 'library'" class="mm-library">
      <div class="ml-head">
        <h3>📐 思维导图库</h3>
        <el-button type="primary" size="small" @click="newMap">＋ 新建导图</el-button>
      </div>
      <div class="ml-grid">
        <div v-for="m in maps" :key="m.id" class="ml-card" @click="openMap(m.id)">
          <div class="ml-title">{{ m.title }}</div>
          <div class="ml-meta">{{ m.node_count }} 节点 · {{ m.updated_at.slice(0, 16).replace('T', ' ') }}</div>
          <el-button size="small" text type="danger" class="ml-del" @click.stop="delMap(m.id, m.title)">删除</el-button>
        </div>
        <div v-if="!maps.length" class="ml-empty">暂无导图，点击右上角新建</div>
      </div>
    </div>

    <!-- ============ 编辑器 ============ -->
    <div v-else class="mm-editor" :style="{ background: theme.bg, color: theme.text }">
      <!-- 顶部工具栏 -->
      <div class="mm-toolbar">
        <el-button size="small" @click="backToLibrary">‹ 返回导图库</el-button>
        <el-input v-model="mapTitle" size="small" class="mm-title-input" @change="markDirty" />
        <div class="mm-tools">
          <el-button size="small" type="primary" plain @click="addChild">＋子主题</el-button>
          <el-button size="small" plain @click="addSibling">＋同级</el-button>
          <el-button size="small" plain @click="addBoundary">边界</el-button>
          <el-button size="small" plain @click="addSummary">{}概要</el-button>
          <el-button size="small" :type="toolMode === 'relate' ? 'primary' : ''" plain @click="toggleRelate">关系</el-button>
        </div>
        <span class="mm-saved">{{ savedState || '已保存' }}</span>
        <div class="mm-zoom">
          <el-button size="small" text @click="zoom = Math.max(0.4, +(zoom - 0.15).toFixed(2))">−</el-button>
          <span>{{ Math.round(zoom * 100) }}%</span>
          <el-button size="small" text @click="zoom = Math.min(2, +(zoom + 0.15).toFixed(2))">＋</el-button>
        </div>
      </div>

      <div class="mm-body">
        <!-- 左侧：布局 -->
        <div class="mm-side mm-side-left">
          <div class="ms-title">布局</div>
          <el-radio-group v-model="mapLayout" class="ms-layout" @change="onLayoutChange">
            <el-radio value="free">自由编辑</el-radio>
            <el-radio value="right">向右</el-radio>
            <el-radio value="left">向左</el-radio>
            <el-radio value="org">组织图</el-radio>
            <el-radio value="radial">放射</el-radio>
          </el-radio-group>
          <el-button v-if="mapLayout === 'free'" class="ms-tidy" size="small" @click="tidyFree">按层级整理坐标</el-button>
          <p class="ms-hint">Enter 新建同级<br/>Tab 新建子级<br/>双击编辑文字<br/>Delete 删除<br/>Shift 单击多选<br/>拖动节点自由调整<br/>所有修改自动保存</p>
        </div>

        <!-- 画布 -->
        <div ref="canvasEl" class="mm-canvas" :style="{ background: theme.bg }" @click.self="selected = new Set(); toolMode = 'none'">
          <div class="mm-stage" :style="{ width: (canvasSize.w * zoom) + 'px', height: (canvasSize.h * zoom) + 'px' }">
            <svg class="mm-svg" :viewBox="`${canvasSize.x} ${canvasSize.y} ${canvasSize.w} ${canvasSize.h}`" :style="{ width: (canvasSize.w * zoom) + 'px', height: (canvasSize.h * zoom) + 'px' }">
              <!-- 父子连线 -->
              <path v-for="n in nodes.filter(x => x.kind === 'node' && x.parent_id && nodeById.get(x.parent_id)?.kind !== 'boundary')"
                :key="'e' + n.id" :d="edgePath(nodeById.get(n.parent_id)!, n, mapLayout === 'org')" :stroke="theme.line" stroke-width="1.6" fill="none" />
              <!-- 概要括号线 -->
              <path v-for="n in nodes.filter(x => x.kind === 'summary' && x.parent_id)" :key="'s' + n.id"
                :d="edgePath(nodeById.get(n.parent_id)!, n, false)" :stroke="theme.accent || theme.node" stroke-width="1.6" fill="none" stroke-dasharray="4 3" />
              <!-- 关系连线 -->
              <g v-for="l in links" :key="'l' + l.id">
                <template v-if="nodeById.get(l.source_id) && nodeById.get(l.target_id)">
                  <line
                    :x1="P(nodeById.get(l.source_id)!).x + (canvasSize.x < 0 ? -canvasSize.x : 0)" :y1="P(nodeById.get(l.source_id)!).y + (canvasSize.y < 0 ? -canvasSize.y : 0)"
                    :x2="P(nodeById.get(l.target_id)!).x + (canvasSize.x < 0 ? -canvasSize.x : 0)" :y2="P(nodeById.get(l.target_id)!).y + (canvasSize.y < 0 ? -canvasSize.y : 0)"
                    :stroke="theme.accent || theme.node" stroke-width="1.4" stroke-dasharray="5 4" />
                  <text v-if="l.label" :x="(P(nodeById.get(l.source_id)!).x + P(nodeById.get(l.target_id)!).x) / 2 + (canvasSize.x < 0 ? -canvasSize.x : 0)"
                    :y="(P(nodeById.get(l.source_id)!).y + P(nodeById.get(l.target_id)!).y) / 2 + (canvasSize.y < 0 ? -canvasSize.y : 0) - 4"
                    :fill="theme.text" font-size="11" text-anchor="middle">{{ l.label }}</text>
                </template>
              </g>
            </svg>

            <!-- 边界框 -->
            <div v-for="b in nodes.filter(n => n.kind === 'boundary')" :key="'b' + b.id" class="mm-boundary"
              :style="{ left: (boundaryBox(b)?.x || 0) + 'px', top: (boundaryBox(b)?.y || 0) + 'px', width: (boundaryBox(b)?.w || 0) + 'px', height: (boundaryBox(b)?.h || 0) + 'px', borderColor: (theme.accent || theme.node) + '99', color: theme.text }">
              <span class="mb-title" @dblclick.stop="startEdit(b.id)">{{ b.title }}</span>
              <span class="mb-del" @click.stop="removeBoundary(b)">✕</span>
            </div>

            <!-- 节点 -->
            <div v-for="n in nodes.filter(x => x.kind === 'node' || x.kind === 'summary')" :key="n.id"
              class="mm-node" :class="{ 'is-sel': isSel(n.id), 'is-hover': hoverId === n.id, 'is-editing': editingId === n.id, 'is-summary': n.kind === 'summary' }"
              :style="{ ...nodeStyle(n), background: nodeFill(n), color: theme.bg, borderColor: isSel(n.id) ? (theme.accent || theme.node) : 'transparent' }"
              @click="onNodeClick(n, $event)" @dblclick.stop="startEdit(n.id)"
              @pointerdown="onNodeDown(n, $event)" @pointermove="onNodeMove(n, $event)" @pointerup="onNodeUp" @pointercancel="onNodeUp"
              @mouseenter="hoverId = n.id" @mouseleave="hoverId = ''">
              <input v-if="editingId === n.id" v-model="editText" class="mm-edit" :style="{ color: theme.bg }"
                @keydown.stop="(e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === 'Escape') commitEdit(); }"
                @blur="commitEdit" @click.stop autofocus />
              <span v-else class="mm-label" :style="{ borderRadius: shapeRadius(n.shape) + 'px' }">{{ n.title }}</span>
              <span v-if="n.kind === 'summary'" class="mm-summary-brace">}</span>
            </div>
          </div>
        </div>

        <!-- 右侧：节点属性 -->
        <div class="mm-side mm-side-right">
          <div class="ms-title">节点属性</div>
          <div class="ms-group">
            <div class="ms-label">文档主题</div>
            <div class="ms-themes">
              <div v-for="(t, k) in THEMES" :key="k" class="ms-theme" :class="{ on: mapTheme === k }" @click="mapTheme = k; markDirty()">
                <span class="mt-dot" :style="{ background: t.node }"></span>{{ t.name }}
              </div>
            </div>
          </div>
          <div class="ms-group" v-if="selNode && selNode.kind === 'node'">
            <div class="ms-label">节点颜色</div>
            <div class="ms-colors">
              <span v-for="c in [theme.node, '#52c41a', '#f4a261', '#e74c3c', '#9b59b6', '#16a085']" :key="c" class="ms-color"
                :class="{ on: (selNode.color || theme.node) === c }" :style="{ background: c }"
                @click="selNode.color = selNode.color === c ? null : c; markDirty()"></span>
            </div>
            <div class="ms-label" style="margin-top: 10px;">节点形状</div>
            <el-radio-group v-model="selNode.shape" size="small" @change="markDirty">
              <el-radio-button v-for="(s, k) in SHAPES" :key="k" :value="k">{{ s }}</el-radio-button>
            </el-radio-group>
          </div>
          <div class="ms-group" v-else-if="selNode && selNode.kind === 'summary'">
            <div class="ms-label">概要内容（双击节点编辑）</div>
            <p class="ms-dim">概要节点显示在所属主题的右侧，用虚线连接。</p>
          </div>
          <div class="ms-group" v-else>
            <div class="ms-label">提示</div>
            <p class="ms-dim">单击节点选中；按住 Shift 多选可创建边界；关系模式下依次单击两个节点建立连线。</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.mm-view { height: 100%; display: flex; flex-direction: column; min-height: 0; }
/* 导图库 */
.mm-library { padding: 20px; overflow: auto; }
.ml-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.ml-head h3 { margin: 0; font-size: 16px; }
.ml-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; }
.ml-card { position: relative; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color, #e5e7eb); border-radius: 10px; padding: 14px; cursor: pointer; transition: box-shadow 0.15s; }
.ml-card:hover { box-shadow: 0 3px 10px rgba(0, 0, 0, 0.1); }
.ml-title { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); margin-bottom: 6px; word-break: break-all; }
.ml-meta { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.ml-del { position: absolute; top: 8px; right: 8px; opacity: 0; transition: opacity 0.15s; }
.ml-card:hover .ml-del { opacity: 1; }
.ml-empty { grid-column: 1 / -1; text-align: center; color: var(--el-text-color-secondary, #9ca3af); padding: 60px 0; font-size: 13px; }

/* 编辑器 */
.mm-editor { flex: 1; display: flex; flex-direction: column; min-height: 0; }
.mm-toolbar { display: flex; align-items: center; gap: 8px; padding: 8px 14px; border-bottom: 1px solid rgba(128, 128, 128, 0.2); flex-wrap: wrap; }
.mm-title-input { width: 220px; }
.mm-tools { display: flex; gap: 4px; }
.mm-saved { font-size: 12px; opacity: 0.65; margin-left: 8px; }
.mm-zoom { display: flex; align-items: center; gap: 2px; margin-left: auto; font-size: 12px; }
.mm-body { flex: 1; display: flex; min-height: 0; }
.mm-side { width: 176px; padding: 14px 12px; border-right: 1px solid rgba(128, 128, 128, 0.2); overflow: auto; font-size: 13px; }
.mm-side-right { border-right: none; border-left: 1px solid rgba(128, 128, 128, 0.2); }
.ms-title { font-weight: 600; margin-bottom: 12px; }
.ms-layout { display: flex; flex-direction: column; gap: 6px; align-items: flex-start; }
.ms-hint { font-size: 12px; opacity: 0.7; line-height: 1.9; margin-top: 18px; }
.ms-group { margin-bottom: 16px; }
.ms-label { font-size: 12px; opacity: 0.7; margin-bottom: 8px; }
.ms-themes { display: flex; flex-direction: column; gap: 6px; }
.ms-theme { display: flex; align-items: center; gap: 8px; padding: 5px 8px; border: 1px solid rgba(128, 128, 128, 0.25); border-radius: 6px; cursor: pointer; font-size: 12px; }
.ms-theme.on { border-color: var(--kh-brand, #409eff); box-shadow: 0 0 0 1px var(--kh-brand, #409eff); }
.mt-dot { width: 12px; height: 12px; border-radius: 50%; display: inline-block; }
.ms-colors { display: flex; gap: 6px; flex-wrap: wrap; }
.ms-color { width: 20px; height: 20px; border-radius: 50%; cursor: pointer; border: 2px solid transparent; }
.ms-color.on { border-color: #fff; box-shadow: 0 0 0 2px rgba(128, 128, 128, 0.6); }
.ms-dim { font-size: 12px; opacity: 0.65; line-height: 1.7; margin: 0; }

/* 画布 */
.mm-canvas { flex: 1; min-width: 0; overflow: auto; position: relative; display: flex; }
.mm-stage { position: relative; margin: auto; flex: none; }
.ms-tidy { margin-top: 8px; width: 100%; }
.mm-svg { position: absolute; inset: 0; pointer-events: none; }
.mm-node { position: absolute; cursor: pointer; border-radius: 8px; border: 1.5px solid transparent; box-shadow: 0 1px 4px rgba(0, 0, 0, 0.18); z-index: 2; }
.mm-node.is-sel { box-shadow: 0 0 0 2px var(--kh-brand, #409eff), 0 1px 5px rgba(0, 0, 0, 0.2); }
.mm-node.is-hover { filter: brightness(1.06); }
.mm-label { display: block; padding: 5px 12px; font-size: 12px; white-space: nowrap; max-width: 240px; overflow: hidden; text-overflow: ellipsis; }
.mm-node.is-summary { background: transparent !important; border: 1px dashed currentColor; }
.mm-node.is-summary .mm-label { color: inherit; opacity: 0.85; }
.mm-summary-brace { position: absolute; right: -6px; top: 50%; transform: translateY(-50%); font-size: 16px; color: inherit; }
.mm-edit { width: 100%; border: none; outline: none; background: rgba(255, 255, 255, 0.85); border-radius: 6px; padding: 4px 8px; font-size: 12px; box-sizing: border-box; }
.mm-boundary { position: absolute; border: 1.6px dashed; border-radius: 12px; z-index: 1; pointer-events: none; }
.mb-title { position: absolute; top: -9px; left: 12px; font-size: 11px; background: inherit; padding: 0 6px; pointer-events: auto; cursor: text; }
.mb-del { position: absolute; top: 4px; right: 8px; font-size: 11px; opacity: 0.6; cursor: pointer; pointer-events: auto; }
.mb-del:hover { opacity: 1; }
</style>
