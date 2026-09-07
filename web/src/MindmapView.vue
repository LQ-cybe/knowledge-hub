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
          <div class="ml-meta">{{ m.node_count }} 节点 · {{ fmtTime(m.updated_at) }}</div>
          <div class="ml-del" @click.stop="delMap(m.id)">✕</div>
        </div>
      </div>
      <div v-if="!maps.length" class="ml-empty">暂无导图，点击右上角「＋ 新建导图」开始</div>
    </div>

    <!-- ============ 编辑器 ============ -->
    <div v-else class="mm-editor">
      <div class="mm-toolbar">
        <el-button size="small" text @click="backToLib">← 返回导图库</el-button>
        <input v-model="mapTitle" class="mm-title-input" @change="markDirty" placeholder="导图标题" />
        <div class="mm-tools">
          <el-button size="small" @click="addChild">＋子主题</el-button>
          <el-button size="small" @click="addSibling">＋同级</el-button>
          <el-button size="small" @click="addSummary">{}概要</el-button>
          <el-button size="small" @click="addOutline">边界</el-button>
          <el-button size="small" @click="addAssoc">关系</el-button>
        </div>
        <div class="mm-zoom">
          <el-button size="small" text @click="zoomOut">－</el-button>
          <span>{{ Math.round(scale * 100) }}%</span>
          <el-button size="small" text @click="zoomIn">＋</el-button>
        </div>
        <span class="mm-saved" :class="{ err: savedState === 'save-fail' }">
          {{ { idle: '未修改', saving: '保存中…', saved: '已保存', 'save-fail': '保存失败' }[savedState] }}
        </span>
      </div>

      <div class="mm-body">
        <!-- 左侧：布局 -->
        <div class="mm-side mm-side-left">
          <div class="ms-title">布局</div>
          <el-radio-group v-model="layoutKey" class="ms-layout" @change="onLayoutChange">
            <el-radio value="free">自由编辑</el-radio>
            <el-radio value="right">向右</el-radio>
            <el-radio value="left">向左</el-radio>
            <el-radio value="org">组织图</el-radio>
            <el-radio value="radial">放射</el-radio>
          </el-radio-group>
          <p class="ms-hint">单击选中节点<br/>双击编辑文字<br/>Enter 新建同级<br/>Tab 新建子级<br/>Delete 删除<br/>拖拽节点调整层级<br/>全部修改自动保存</p>
        </div>

        <!-- 画布 -->
        <div class="mm-canvas"><div ref="mmEl" class="mm-host"></div></div>

        <!-- 右侧：节点属性 -->
        <div class="mm-side mm-side-right">
          <div class="ms-title">节点属性</div>
          <div class="ms-group">
            <div class="ms-label">文档主题</div>
            <div class="ms-themes">
              <div v-for="(t, k) in THEMES" :key="k" class="ms-theme" :class="{ on: themeKey === k }" @click="setTheme(k)">
                <span class="mt-dot" :style="{ background: t.rootFill }"></span>{{ t.name }}
              </div>
            </div>
          </div>
          <div class="ms-group" v-if="activeNode">
            <div class="ms-label">节点颜色</div>
            <div class="ms-colors">
              <span v-for="c in nodeColors" :key="c" class="ms-color" :class="{ on: curColor === c }" :style="{ background: c }"
                @click="setNodeColor(c)"></span>
            </div>
            <div class="ms-label" style="margin-top: 10px;">节点形状</div>
            <div class="ms-shapes">
              <span v-for="(s, k) in SHAPES" :key="k" class="ms-shape" :class="{ on: curShape === k }" @click="setNodeShape(k)">{{ s }}</span>
            </div>
          </div>
          <div class="ms-group" v-else>
            <div class="ms-tip">单击画布中的节点后可设置颜色与形状</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import MindMap from 'simple-mind-map';
import 'simple-mind-map/full.js';
import { getMindmaps, createMindmap, deleteMindmap, getMindmap, updateMindmap, saveMindmapNodes, saveMindmapLinks, saveMindmapMembers, type MindmapNode, type MindmapLink, type MindmapMember, type MindmapMeta } from './api';

const VIRT_ROOT = '__VR__';
const LAYOUT_MAP: Record<string, string> = { free: 'mindMap', right: 'logicalStructure', left: 'logicalStructureLeft', org: 'organizationStructure', radial: 'fishbone' };
const LAYOUT_REV: Record<string, string> = { mindMap: 'free', logicalStructure: 'right', logicalStructureLeft: 'left', organizationStructure: 'org', fishbone: 'radial' };
const SHAPES: Record<string, string> = { auto: '自动', rect: '矩形', round: '圆角', ellipse: '椭圆' };
const SHAPE_MAP: Record<string, string> = { auto: 'rectangle', rect: 'rectangle', round: 'roundedRectangle', ellipse: 'ellipse' };
const SHAPE_REV: Record<string, string> = { rectangle: 'rect', roundedRectangle: 'round', ellipse: 'ellipse' };

// 四套主题（NexaNote 风格），基于默认主题的覆盖配置
const THEMES: Record<string, { name: string; rootFill: string; cfg: Record<string, any> }> = {
  'nexa-light': {
    name: 'Nexa 明亮', rootFill: '#3b82f6',
    cfg: { background: '#ffffff', lineColor: '#9bb7e8', generalizationLineColor: '#9bb7e8', root: { fillColor: '#3b82f6', color: '#ffffff', borderColor: 'transparent' }, second: { fillColor: '#ffffff', color: '#333333', borderColor: '#3b82f6' }, node: { fillColor: '#f5f7fa', color: '#333333', borderColor: 'transparent' } },
  },
  'nexa-dark': {
    name: 'Nexa 深色', rootFill: '#4a8cf7',
    cfg: { background: '#1e222b', lineColor: '#3d4759', generalizationLineColor: '#3d4759', root: { fillColor: '#4a8cf7', color: '#ffffff', borderColor: 'transparent' }, second: { fillColor: '#2a2f3a', color: '#e6e9ef', borderColor: '#4a8cf7' }, node: { fillColor: '#232936', color: '#c5cad5', borderColor: '#3d4759' } },
  },
  classic: {
    name: '经典分支', rootFill: '#2563eb',
    cfg: { background: '#fdf8f2', lineColor: '#f59e0b', generalizationLineColor: '#f59e0b', root: { fillColor: '#2563eb', color: '#ffffff', borderColor: 'transparent' }, second: { fillColor: '#ffffff', color: '#7c2d12', borderColor: '#f59e0b' }, node: { fillColor: '#fffbeb', color: '#92400e', borderColor: '#fbbf24' } },
  },
  azure: {
    name: '音蓝架构', rootFill: '#1d4ed8',
    cfg: { background: '#f0f6ff', lineColor: '#60a5fa', generalizationLineColor: '#60a5fa', root: { fillColor: '#1d4ed8', color: '#ffffff', borderColor: 'transparent' }, second: { fillColor: '#eff6ff', color: '#1e3a8a', borderColor: '#3b82f6' }, node: { fillColor: '#ffffff', color: '#334155', borderColor: '#bfdbfe' } },
  },
};

const view = ref<'library' | 'editor'>('library');
const maps = ref<MindmapMeta[]>([]);
const mapId = ref('');
const mapTitle = ref('');
const layoutKey = ref('right');
const themeKey = ref('nexa-light');
const scale = ref(1);
const savedState = ref<'idle' | 'saving' | 'saved' | 'save-fail'>('idle');
const activeNode = ref<any>(null);
const curColor = ref('#3b82f6');
const curShape = ref('auto');
const nodeColors = ['#3b82f6', '#52c41a', '#f4a261', '#e74c3c', '#9b59b6', '#16a085'];

const mmEl = ref<HTMLElement>();
let mm: any = null;
let saveTimer: any = null;
let dirty = false;
let loading = false;

const fmtTime = (s: string) => (s ? s.slice(5, 16).replace('T', ' ') : '');
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : 'n' + Date.now() + Math.random().toString(16).slice(2, 8));
// 富文本 HTML → 纯文本（DB 统一存纯文本）
const plain = (s: any): string => {
  if (s == null) return '';
  let t = String(s);
  t = t.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
  return t.replace(/<[^>]*>/g, '').trim();
};

// ---------- 导图库 ----------
async function loadMaps() {
  maps.value = await getMindmaps();
}
async function newMap() {
  const title = await ElMessageBox.prompt('请输入导图名称', '新建思维导图', { confirmButtonText: '创建', cancelButtonText: '取消', inputValue: '' }).then(r => r.value.trim()).catch(() => null);
  if (!title) return;
  try {
    await createMindmap(title);
    await loadMaps();
  } catch (e: any) { ElMessage.error('创建失败：' + (e?.message || e)); }
}
async function delMap(id: string) {
  await ElMessageBox.confirm('确定删除该导图？', '删除', { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' }).catch(() => { throw 0; });
  try { await deleteMindmap(id); await loadMaps(); } catch (e: any) { ElMessage.error('删除失败：' + (e?.message || e)); }
}

// ---------- 数据映射：DB → simple-mind-map ----------
function dbToSmm(nodes: MindmapNode[], links: MindmapLink[], members: MindmapMember[]) {
  const byId = new Map(nodes.map(n => [n.id, n]));
  const kids = new Map<string, MindmapNode[]>();
  for (const n of nodes) { if (n.parent_id) { if (!kids.has(n.parent_id)) kids.set(n.parent_id, []); kids.get(n.parent_id)!.push(n); } }
  for (const k of kids.keys()) kids.get(k)!.sort((a, b) => a.sort - b.sort);
  const boundaries = nodes.filter(n => n.kind === 'boundary');
  const memByGroup = new Map<string, string[]>();
  for (const m of members) { if (!memByGroup.has(m.group_id)) memByGroup.set(m.group_id, []); memByGroup.get(m.group_id)!.push(m.node_id); }
  const build = (n: MindmapNode): any => {
    const d: any = { data: { text: plain(n.title), uid: n.id, expand: true }, children: (kids.get(n.id) || []).filter(c => c.kind === 'node').map(build) };
    if (n.color) { d.data.fillColor = n.color; d.data.color = '#ffffff'; }
    if (n.shape && n.shape !== 'auto') d.data.shape = SHAPE_MAP[n.shape] || 'rectangle';
    // 概要
    const sums = nodes.filter(s => s.kind === 'summary' && s.parent_id === n.id);
    if (sums.length) d.data.generalization = sums.map(s => ({ text: plain(s.title) }));
    // 外框（边界）：取组成员中第一个成员挂外框（SMM 外框含该节点子树）
    const b = boundaries.find(bd => (memByGroup.get(bd.id) || [])[0] === n.id);
    if (b) d.data.outerFrame = { text: plain(b.title) || '边界' };
    // 关联线（SMM associativeLineTargets 为 uid 字符串数组）
    const rels = links.filter(l => l.source_id === n.id).map(l => l.target_id);
    if (rels.length) d.data.associativeLineTargets = rels;
    return d;
  };
  const roots = nodes.filter(n => n.kind === 'node' && !n.parent_id).sort((a, b) => a.sort - b.sort);
  if (!roots.length) return { data: { text: '', uid: VIRT_ROOT, expand: true }, children: [] };
  if (roots.length === 1) return build(roots[0]);
  // 多根：包一层虚拟根
  return { data: { text: '知识导图', uid: VIRT_ROOT, expand: true }, children: roots.map(build) };
}

// ---------- 数据映射：simple-mind-map → DB（全量保存） ----------
function smmToDb(root: any) {
  const nodes: MindmapNode[] = [];
  const links: MindmapLink[] = [];
  const members: MindmapMember[] = [];
  let nSort = 0;
  const walk = (d: any, parentId: string | null, isVrChild: boolean) => {
    const data = d.data || {};
    const id = data.uid;
    if (id !== VIRT_ROOT) {
      nodes.push({
        id, parent_id: parentId, title: plain(data.text), kind: 'node',
        x: 0, y: 0,
        color: data.fillColor || null,
        shape: SHAPE_REV[data.shape] || 'auto',
        sort: nSort++,
      });
    }
    const effParent = id === VIRT_ROOT ? parentId : id;
    (data.generalization || []).forEach((g: any, i: number) => {
      nodes.push({ id: 'g_' + id + '_' + i, parent_id: effParent, title: plain(g.text), kind: 'summary', x: 0, y: 0, color: null, shape: 'auto', sort: nSort++ });
    });
    (data.associativeLineTargets || []).forEach((uid: string, i: number) => {
      if (uid) links.push({ id: 'l_' + id + '_' + i, source_id: id, target_id: uid, label: '' });
    });
    if (data.outerFrame) {
      const bId = 'b_' + id;
      nodes.push({ id: bId, parent_id: null, title: plain(data.outerFrame.text), kind: 'boundary', x: 0, y: 0, color: null, shape: 'auto', sort: nSort++ });
      // SMM 外框挂在该节点上（含其子树），组员 = 该节点及其子树
      const subtree: string[] = [];
      const collect = (x: any) => { if (x.data?.uid && x.data.uid !== VIRT_ROOT) subtree.push(x.data.uid); (x.children || []).forEach(collect); };
      collect(d);
      subtree.forEach(nid => members.push({ group_id: bId, node_id: nid }));
    }
    (d.children || []).forEach((c: any) => walk(c, effParent, false));
  };
  walk(root, null, true);
  return { nodes, links, members };
}

// ---------- 编辑器 ----------
async function openMap(id: string) {
  try {
    const data = await getMindmap(id);
    mapId.value = id;
    mapTitle.value = data.title;
    view.value = 'editor';
    layoutKey.value = (['free', 'right', 'left', 'org', 'radial'].includes(data.layout) ? data.layout : 'right');
    themeKey.value = (THEMES[data.theme] ? data.theme : 'nexa-light');
    activeNode.value = null;
    await nextTickRender();
    const smmData = dbToSmm(data.nodes, data.links, data.members);
    mm = new MindMap({
      el: mmEl.value!,
      data: smmData,
      layout: LAYOUT_MAP[layoutKey.value] || 'logicalStructure',
      theme: 'default',
      themeConfig: THEMES[themeKey.value].cfg,
      enableFreeDrag: true,
      mousewheelAction: 'zoom',
    });
    let fitted = false;
    mm.on('node_tree_render_end', () => {
      scale.value = mm.view.scale || 1;
      if (!fitted) { fitted = true; setTimeout(() => { try { mm.view.fit(); } catch {} }, 30); }
    });
    bindEvents();
    savedState.value = 'saved';
    dirty = false;
  } catch (e: any) { ElMessage.error('打开导图失败：' + (e?.message || e)); }
}
function nextTickRender() { return new Promise(r => setTimeout(r, 50)); }
function backToLib() {
  flushSave();
  destroyMindMap();
  view.value = 'library';
  loadMaps();
}
function destroyMindMap() {
  if (saveTimer) { clearTimeout(saveTimer); saveTimer = null; }
  if (mm) { try { mm.destroy(); } catch {} mm = null; }
}
function bindEvents() {
  mm.on('node_active', (node: any) => {
    const nd = node?.nodeData?.data;
    if (!node || !nd || nd.uid === VIRT_ROOT) { activeNode.value = null; return; }
    if (assocFrom && node !== assocFrom) {
      const from = assocFrom; assocFrom = null;
      mm.execCommand('ADD_ASSOCIATIVE_LINE', from, node);
      ElMessage.success('已创建关联线');
    }
    activeNode.value = node;
    curColor.value = nd.fillColor || THEMES[themeKey.value].rootFill;
    curShape.value = SHAPE_REV[nd.shape] || 'auto';
  });
  mm.on('node_tree_render_end', () => { scale.value = mm.view.scale || 1; });
  mm.on('data_change', () => markDirty());
  mm.on('view_data_change', () => markDirty());
}
function markDirty() {
  if (!mapId.value || view.value !== 'editor') return;
  dirty = true;
  savedState.value = 'saving';
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(flushSave, 600);
}
async function flushSave() {
  if (saveTimer) { clearTimeout(saveTimer); saveTimer = null; }
  if (!dirty || !mm || !mapId.value) return;
  dirty = false;
  try {
    const root = mm.getData();
    const { nodes, links, members } = smmToDb(root);
    await Promise.all([
      updateMindmap(mapId.value, { title: mapTitle.value, layout: layoutKey.value, theme: themeKey.value }),
      saveMindmapNodes(mapId.value, nodes),
      saveMindmapLinks(mapId.value, links),
      saveMindmapMembers(mapId.value, members),
    ]);
    savedState.value = 'saved';
  } catch (e) { savedState.value = 'save-fail'; console.error(e); }
}

// ---------- 工具栏 ----------
function setNodeColor(c: string) {
  if (!activeNode.value) return;
  curColor.value = c;
  mm.execCommand('SET_NODE_STYLE', activeNode.value, 'fillColor', c);
  mm.execCommand('SET_NODE_STYLE', activeNode.value, 'color', c === '#ffffff' ? '#333' : '#ffffff');
  markDirty();
}
function setNodeShape(s: string) {
  if (!activeNode.value) return;
  curShape.value = s;
  mm.execCommand('SET_NODE_SHAPE', activeNode.value, SHAPE_MAP[s] || 'rectangle');
  markDirty();
}
// ---------- 工具栏 ----------
let assocFrom: any = null;
function active() {
  if (activeNode.value) return activeNode.value;
  const l = mm?.renderer?.activeNodeList || [];
  if (l.length && l[0].nodeData?.data && l[0].nodeData.data.uid !== VIRT_ROOT) return l[0];
  return null;
}
function addChild() {
  const n = active(); if (!n) { ElMessage.warning('请先单击选中一个节点'); return; }
  mm.execCommand('INSERT_CHILD_NODE', true, [n]);
}
function addSibling() {
  const n = active(); if (!n) { ElMessage.warning('请先单击选中一个节点'); return; }
  if (n.isRoot) { ElMessage.warning('根节点不能添加同级'); return; }
  mm.execCommand('INSERT_NODE', true, [n]);
}
function addSummary() {
  const n = active(); if (!n) { ElMessage.warning('请先选中一个节点'); return; }
  mm.execCommand('ADD_GENERALIZATION', { text: '概要' }, false);
}
function addOutline() {
  const n = active(); if (!n) { ElMessage.warning('请先选中一个节点'); return; }
  mm.execCommand('ADD_OUTER_FRAME', [n], { text: '边界' });
}
function addAssoc() {
  const n = active(); if (!n) { ElMessage.warning('请先单击起点节点'); return; }
  assocFrom = n;
  ElMessage.info('已选起点，请再单击目标节点');
}

// ---------- 布局 / 主题 / 节点样式 ----------
function onLayoutChange() {
  if (!mm) return;
  mm.setLayout(LAYOUT_MAP[layoutKey.value] || 'logicalStructure');
  markDirty();
}
function setTheme(k: string) {
  themeKey.value = k;
  if (mm) mm.setThemeConfig(THEMES[k].cfg);
  markDirty();
}
function zoomIn() { mm?.view.enlarge(); }
function zoomOut() { mm?.view.narrow(); }

onMounted(() => { loadMaps(); });
onBeforeUnmount(() => { flushSave(); destroyMindMap(); });
</script>

<style scoped>
.mm-view { height: 100%; display: flex; flex-direction: column; }
.mm-library { padding: 12px 16px; overflow: auto; }
.ml-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
.ml-head h3 { margin: 0; font-size: 16px; }
.ml-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; }
.ml-card { position: relative; border: 1px solid #e5e7eb; border-radius: 10px; padding: 14px; cursor: pointer; background: #fff; transition: box-shadow .15s; }
.ml-card:hover { box-shadow: 0 3px 12px rgba(0, 0, 0, .08); }
.ml-title { font-weight: 600; margin-bottom: 6px; }
.ml-meta { font-size: 12px; color: #8a8f99; }
.ml-del { position: absolute; top: 8px; right: 10px; color: #c0c4cc; font-size: 12px; display: none; }
.ml-card:hover .ml-del { display: block; }
.ml-empty { color: #8a8f99; text-align: center; padding: 60px 0; }

.mm-editor { height: 100%; display: flex; flex-direction: column; min-height: 0; }
.mm-toolbar { display: flex; align-items: center; gap: 8px; padding: 6px 12px; border-bottom: 1px solid #eef0f3; flex-wrap: nowrap; }
.mm-title-input { width: 170px; border: 1px solid #e5e7eb; border-radius: 6px; padding: 4px 8px; font-size: 13px; outline: none; }
.mm-tools { display: flex; gap: 6px; margin-left: 8px; }
.mm-zoom { display: flex; align-items: center; gap: 2px; margin-left: auto; font-size: 12px; color: #555; }
.mm-saved { font-size: 12px; color: #10b981; margin-left: 10px; white-space: nowrap; }
.mm-saved.err { color: #e74c3c; }

.mm-body { flex: 1; display: flex; min-height: 0; }
.mm-side { width: 170px; flex: none; overflow: auto; padding: 10px 12px; border-right: 1px solid #eef0f3; }
.mm-side-right { border-right: none; border-left: 1px solid #eef0f3; }
.ms-title { font-weight: 600; font-size: 13px; margin-bottom: 10px; }
.ms-layout { display: flex; flex-direction: column; gap: 2px; }
.ms-layout :deep(.el-radio) { margin-right: 0; height: 26px; }
.ms-hint { font-size: 11px; color: #9aa1ab; margin-top: 14px; line-height: 1.8; }
.ms-themes { display: flex; flex-direction: column; gap: 6px; }
.ms-theme { display: flex; align-items: center; gap: 8px; padding: 6px 8px; border-radius: 6px; cursor: pointer; font-size: 13px; border: 1px solid transparent; }
.ms-theme.on { border-color: var(--kh-brand, #409eff); background: rgba(64, 158, 255, .06); }
.mt-dot { width: 14px; height: 14px; border-radius: 50%; flex: none; }
.ms-colors { display: flex; flex-wrap: wrap; gap: 8px; }
.ms-color { width: 22px; height: 22px; border-radius: 50%; cursor: pointer; border: 2px solid transparent; }
.ms-color.on { border-color: #333; }
.ms-shapes { display: flex; flex-wrap: wrap; gap: 6px; }
.ms-shape { padding: 3px 8px; border: 1px solid #e5e7eb; border-radius: 6px; font-size: 12px; cursor: pointer; }
.ms-shape.on { border-color: var(--kh-brand, #409eff); color: var(--kh-brand, #409eff); }
.ms-tip { font-size: 12px; color: #9aa1ab; line-height: 1.7; }

.mm-canvas { flex: 1; min-width: 0; overflow: hidden; position: relative; }
.mm-host { width: 100%; height: 100%; }
.mm-host :deep(.smm-container) { width: 100%; height: 100%; }
</style>
