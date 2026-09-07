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
          <el-button size="small" title="为选中节点添加子主题" @click="addChild">＋子主题</el-button>
          <el-button size="small" title="为选中节点添加同级（根节点除外）" @click="addSibling">＋同级</el-button>
          <el-button size="small" title="概要：Shift 多选同一父节点的两个及以上子节点后点击，直接进入文本框编辑多行说明" :disabled="selCount < 2" @click="addSummary">{}概要</el-button>
          <el-button size="small" title="边界：Shift 多选两个及以上节点后点击，将在所选节点外围创建一个矩形，输入边界名称" :disabled="selCount < 2" @click="addOutline">边界</el-button>
          <el-button size="small" title="关系线：Shift 多选两个节点后点击（多选顺序即连线方向，起点→终点）" :disabled="selCount < 2" @click="addAssoc">关系</el-button>
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
          <p class="ms-hint">单击选中 · Shift 多选<br/>双击编辑节点 / 关系线 / 边界文字<br/>Enter 新建同级 · Tab 新建子级<br/>Delete 删除选中节点 / 关系线 / 边界<br/>拖拽节点调整层级<br/>概要 / 边界 / 关系：Shift 多选两个及以上节点后点击工具栏对应按钮<br/>概要创建后直接输入多行文本<br/>边界：多选节点 → 一个矩形包裹<br/>关系线：多选顺序即方向（先选为起点）<br/>单击矩形可选中，双击文字可改名<br/>全部修改自动保存</p>
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

      <!-- 边界名称输入（新建 / 双击边界文字改名共用） -->
      <el-dialog v-model="outlineDialog" :title="outlineEditId ? '修改边界名称' : '添加边界'" width="420" append-to-body :close-on-click-modal="false">
        <p class="mm-dialog-tip">边界将以一个矩形整体包裹所选节点，显示在底层。单击矩形可选中（按 Delete 删除），双击文字可改名。</p>
        <el-input v-model="outlineText" placeholder="边界名称" maxlength="30" />
        <template #footer>
          <el-button size="small" @click="outlineDialog = false">取消</el-button>
          <el-button size="small" type="primary" @click="confirmOutline">{{ outlineEditId ? '保存' : '确定' }}</el-button>
        </template>
      </el-dialog>
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
// 关联线全局样式：细线（1.5）+ 主题色；分支节点与父节点同色系（second/node 取 root 的浅色调变体）
const THEMES: Record<string, { name: string; rootFill: string; cfg: Record<string, any> }> = {
  'nexa-light': {
    name: 'Nexa 明亮', rootFill: '#3b82f6',
    cfg: {
      background: '#ffffff', lineColor: '#9bb7e8', generalizationLineColor: '#9bb7e8',
      associativeLineWidth: 1.5, associativeLineColor: '#93a4bc', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#64748b',
      root: { fillColor: '#3b82f6', color: '#ffffff', borderColor: 'transparent' },
      second: { fillColor: '#dbeafe', color: '#1e3a5f', borderColor: '#93c5fd' },
      node: { fillColor: '#eff6ff', color: '#274b6d', borderColor: '#bfdbfe' },
    },
  },
  'nexa-dark': {
    name: 'Nexa 深色', rootFill: '#4a8cf7',
    cfg: {
      background: '#1e222b', lineColor: '#3d4759', generalizationLineColor: '#3d4759',
      associativeLineWidth: 1.5, associativeLineColor: '#5a6b84', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#8fa3bd',
      root: { fillColor: '#4a8cf7', color: '#ffffff', borderColor: 'transparent' },
      second: { fillColor: '#2b3a55', color: '#cfd8e6', borderColor: '#4a8cf7' },
      node: { fillColor: '#232f42', color: '#b8c4d6', borderColor: '#3d557a' },
    },
  },
  classic: {
    name: '经典分支', rootFill: '#2563eb',
    cfg: {
      background: '#fdf8f2', lineColor: '#f59e0b', generalizationLineColor: '#f59e0b',
      associativeLineWidth: 1.5, associativeLineColor: '#c2884a', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#9a6b2f',
      root: { fillColor: '#2563eb', color: '#ffffff', borderColor: 'transparent' },
      second: { fillColor: '#fdeed0', color: '#7c4a12', borderColor: '#f5c765' },
      node: { fillColor: '#fef6e4', color: '#8a5a1a', borderColor: '#f5d795' },
    },
  },
  azure: {
    name: '音蓝架构', rootFill: '#1d4ed8',
    cfg: {
      background: '#f0f6ff', lineColor: '#60a5fa', generalizationLineColor: '#60a5fa',
      associativeLineWidth: 1.5, associativeLineColor: '#7ba7e0', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#4a76b8',
      root: { fillColor: '#1d4ed8', color: '#ffffff', borderColor: 'transparent' },
      second: { fillColor: '#dbeafe', color: '#1e3a8a', borderColor: '#60a5fa' },
      node: { fillColor: '#f0f7ff', color: '#334f7c', borderColor: '#b3d4ff' },
    },
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
// 当前选中的有效节点数（驱动概要/边界/关系按钮的可用状态：单选禁用，多选 2 个及以上可用）
const selCount = ref(0);
// 边界（自定义包围盒矩形）：{ id, text, nodeIds }[]
const khBounds = ref<{ id: string; text: string; nodeIds: string[] }[]>([]);
const khActiveBound = ref('');
// 边界名称输入弹窗（新建 / 改名共用）
const outlineDialog = ref(false);
const outlineText = ref('');
const outlineEditId = ref('');

const fmtTime = (s: string) => (s ? s.slice(5, 16).replace('T', ' ') : '');
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : 'n' + Date.now() + Math.random().toString(16).slice(2, 8));
// 富文本 HTML → 纯文本（DB 统一存纯文本；<br>/</p> 转 \n 保留换行，否则多行概要会被压成一行）
const plain = (s: any): string => {
  if (s == null) return '';
  let t = String(s);
  t = t.replace(/<br\s*\/?>/gi, '\n').replace(/<\/p>/gi, '\n').replace(/<\/div>/gi, '\n').replace(/<li[^>]*>/gi, '\n');
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
  // 边界（自定义包围盒矩形）：从 DB boundary 记录 + 组成员构建（兼容旧 SMM outerFrame 数据）
  khBounds.value = boundaries.map(b => ({
    id: b.id,
    text: plain(b.title) || '边界',
    nodeIds: memByGroup.get(b.id) || [],
  }));
  const build = (n: MindmapNode): any => {
    const d: any = { data: { text: plain(n.title), uid: n.id, expand: true }, children: (kids.get(n.id) || []).filter(c => c.kind === 'node').map(build) };
    if (n.color) { d.data.fillColor = n.color; d.data.color = '#ffffff'; }
    if (n.shape && n.shape !== 'auto') d.data.shape = SHAPE_MAP[n.shape] || 'rectangle';
    // 概要（每行包成独立 <p>：SMM 富文本转换 removeRichTextStyes 会保留多个 <p> 为独立段落，
    // 这样多行概要才能正确撑高节点并换行显示；\n 和 <br> 都会被其吞掉，不能用）
    const sums = nodes.filter(s => s.kind === 'summary' && s.parent_id === n.id);
    if (sums.length) d.data.generalization = sums.map(s => ({ text: plain(s.title).split('\n').map(l => '<p>' + l + '</p>').join(''), richText: true }));
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
    (d.children || []).forEach((c: any) => walk(c, effParent, false));
  };
  walk(root, null, true);
  // 边界（自定义包围盒矩形）：直接由运行时状态生成，不依赖 SMM outerFrame
  khBounds.value.forEach((b, i) => {
    nodes.push({ id: b.id, parent_id: null, title: b.text || '边界', kind: 'boundary', x: 0, y: 0, color: null, shape: 'auto', sort: nSort++ });
    b.nodeIds.forEach(nid => members.push({ group_id: b.id, node_id: nid }));
  });
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
      // 关联线渲染在节点下层，避免遮挡节点内容（默认 true 会盖住节点）
      associativeLineIsAlwaysAboveNode: false,
    });
    let fitted = false;
    mm.on('node_tree_render_end', () => {
      scale.value = mm.view.scale || 1;
      if (!fitted) { fitted = true; setTimeout(() => { try { mm.view.fit(); } catch {} }, 30); }
      scheduleRenderBounds();
    });
    bindEvents();
    window.addEventListener('keydown', onEditorKeydown);
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
  if (mm) {
    try {
      mm.off('node_active');
      mm.off('node_tree_render_end');
      mm.off('data_change');
      mm.off('view_data_change');
      mm.off('scale');
      mm.destroy();
    } catch {}
    mm = null;
  }
  window.removeEventListener('keydown', onEditorKeydown);
  khBounds.value = [];
  khActiveBound.value = '';
}
// Delete/Backspace：优先删除已选中的边界矩形（点击矩形时 SMM 已通过 draw_click 清空节点激活，互不冲突）
function onEditorKeydown(e: KeyboardEvent) {
  if ((e.key === 'Delete' || e.key === 'Backspace') && khActiveBound.value && mm) {
    const id = khActiveBound.value;
    khActiveBound.value = '';
    khBounds.value = khBounds.value.filter(b => b.id !== id);
    renderBounds();
    markDirty();
    ElMessage.success('已删除边界');
  }
}
function bindEvents() {
  mm.on('node_active', (node: any) => {
    const nd = node?.nodeData?.data;
    if (!node || !nd || nd.uid === VIRT_ROOT) { activeNode.value = null; selCount.value = 0; return; }
    activeNode.value = node;
    curColor.value = nd.fillColor || THEMES[themeKey.value].rootFill;
    curShape.value = SHAPE_REV[nd.shape] || 'auto';
    selCount.value = selNodes().length;
  });
  mm.on('node_tree_render_end', () => { scale.value = mm.view.scale || 1; });
  mm.on('data_change', () => markDirty());
  mm.on('view_data_change', () => markDirty());
  mm.on('scale', () => scheduleRenderBounds());
  mm.on('draw_click', () => {
    // 点击画布空白处：取消边界选中
    khActiveBound.value = '';
    renderBounds();
    selCount.value = selNodes().length;
  });
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
function active() {
  if (activeNode.value) return activeNode.value;
  const l = mm?.renderer?.activeNodeList || [];
  if (l.length && l[0].nodeData?.data && l[0].nodeData.data.uid !== VIRT_ROOT) return l[0];
  return null;
}
// 当前选中的有效节点（支持 Shift 多选）
function selNodes(): any[] {
  const l = mm?.renderer?.activeNodeList || [];
  return l.filter(n => n.nodeData?.data && n.nodeData.data.uid !== VIRT_ROOT);
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
// 概要：Shift 多选同一父节点的两个及以上子节点 → 直接进入文本框编辑（无弹窗）
function addSummary() {
  const ns = selNodes();
  if (ns.length < 2) { ElMessage.warning('请按住 Shift 多选同一父节点的两个及以上子节点'); return; }
  if (ns.some(n => n.isRoot || n.isGeneralization)) { ElMessage.warning('根节点 / 概要节点不能添加概要'); return; }
  const p = ns[0].parent;
  if (ns.some(n => n.parent !== p)) { ElMessage.warning('概要只能针对同一父节点的多个子节点'); return; }
  if (ns.some(n => { const d = n.getData ? n.getData('generalization') : null; return d && d.length; })) {
    ElMessage.warning('选中节点已有概要，请先删除旧概要或选择其他节点'); return;
  }
  try {
    mm.execCommand('ADD_GENERALIZATION', { text: '' }, true); // openEdit=true：创建后直接进入文本编辑
    markDirty();
  } catch (e: any) { ElMessage.error('添加概要失败：' + (e?.message || e)); }
}
// 边界：Shift 多选两个及以上节点 → 一个矩形整体包裹所选节点（弹窗输入名称）
function addOutline() {
  const ns = selNodes();
  if (ns.length < 2) { ElMessage.warning('请按住 Shift 多选两个及以上节点'); return; }
  if (ns.some(n => n.isRoot || n.isGeneralization)) { ElMessage.warning('根节点 / 概要节点不能添加边界'); return; }
  outlineEditId.value = '';
  outlineText.value = '边界';
  outlineDialog.value = true;
}
function confirmOutline() {
  const text = outlineText.value.trim();
  if (outlineEditId.value) {
    // 改名
    const b = khBounds.value.find(x => x.id === outlineEditId.value);
    if (b) { b.text = text || '边界'; renderBounds(); markDirty(); }
    outlineDialog.value = false;
    return;
  }
  const ns = selNodes();
  if (ns.length < 2) { outlineDialog.value = false; return; }
  khBounds.value.push({ id: 'b_' + uid(), text: text || '边界', nodeIds: ns.map(n => n.nodeData.data.uid) });
  renderBounds();
  markDirty();
  ElMessage.success('已添加边界');
  outlineDialog.value = false;
}
// 边界渲染层：SVG g 元素插到 svg 顶层（节点容器之下），坐标用 node.getRect()（rbox 视口坐标）
const SVG_NS = 'http://www.w3.org/2000/svg';
let boundsTimer: any = null;
function scheduleRenderBounds() {
  if (boundsTimer) clearTimeout(boundsTimer);
  boundsTimer = setTimeout(renderBounds, 80);
}
function renderBounds() {
  const host = mmEl.value;
  if (!host || !mm) return;
  const svg = host.querySelector('.smm-container svg') || host.querySelector('svg');
  if (!svg) return;
  let layer = host.querySelector('.kh-bound-layer') as SVGGElement | null;
  // 无边界时移除层：空的 <g> 会让 SMM Scrollbar 的 rbox() 崩溃，导致整图渲染中断
  if (!khBounds.value.length) {
    if (layer) layer.remove();
    return;
  }
  if (!layer) {
    layer = document.createElementNS(SVG_NS, 'g');
    layer.setAttribute('class', 'kh-bound-layer');
    svg.insertBefore(layer, svg.firstChild);
  }
  layer.innerHTML = '';
  // renderer.root 是渲染节点树根（MindMapNode 实例，含 nodeData/getRect），递归收集所有节点
  const nodes: any[] = [];
  const walkN = (n: any) => {
    if (!n) return;
    if (n.nodeData?.data && n.nodeData.data.uid !== VIRT_ROOT) nodes.push(n);
    (n.children || []).forEach(walkN);
  };
  walkN(mm.renderer.root);
  const byUid = new Map(nodes.map((n: any) => [n.nodeData?.data?.uid, n]));
  for (const b of khBounds.value) {
    const rects = b.nodeIds.map(id => byUid.get(id)).filter(Boolean).map((n: any) => n.getRect()).filter((r: any) => r);
    if (!rects.length) continue;
    const pad = 14;
    const left = Math.min(...rects.map((r: any) => r.x));
    const top = Math.min(...rects.map((r: any) => r.y));
    const right = Math.max(...rects.map((r: any) => r.x + r.width));
    const bottom = Math.max(...rects.map((r: any) => r.y + r.height));
    const x = left - pad, y = top - pad - 16, w = right - left + pad * 2, h = bottom - top + pad * 2;
    const sel = khActiveBound.value === b.id;
    const grp = document.createElementNS(SVG_NS, 'g');
    grp.setAttribute('class', 'kh-bound');
    const rect = document.createElementNS(SVG_NS, 'rect');
    rect.setAttribute('x', String(x)); rect.setAttribute('y', String(y));
    rect.setAttribute('width', String(w)); rect.setAttribute('height', String(h));
    rect.setAttribute('rx', '10');
    rect.setAttribute('fill', 'rgba(96,165,250,0.05)');
    rect.setAttribute('stroke', sel ? '#e11d48' : '#7ba7e0');
    rect.setAttribute('stroke-width', sel ? '2' : '1.2');
    rect.setAttribute('stroke-dasharray', '7,5');
    const txt = document.createElementNS(SVG_NS, 'text');
    txt.setAttribute('x', String(x + 8)); txt.setAttribute('y', String(y - 5));
    txt.setAttribute('fill', sel ? '#e11d48' : '#64748b');
    txt.setAttribute('font-size', '12');
    txt.textContent = b.text || '边界';
    grp.appendChild(rect); grp.appendChild(txt);
    grp.addEventListener('click', (e) => {
      e.stopPropagation();
      khActiveBound.value = b.id;
      renderBounds();
    });
    grp.addEventListener('dblclick', (e) => {
      e.stopPropagation();
      outlineEditId.value = b.id;
      outlineText.value = b.text || '边界';
      outlineDialog.value = true;
    });
    layer.appendChild(grp);
  }
}
// 关系线：Shift 多选两个节点 → 自动连线（多选顺序即方向：先选为起点，后选为终点）
function addAssoc() {
  const ns = selNodes();
  if (ns.length < 2) { ElMessage.warning('请按住 Shift 多选两个节点（先选的为起点）'); return; }
  try {
    mm.execCommand('ADD_ASSOCIATIVE_LINE', ns[0], ns[1]);
    markDirty();
    ElMessage.success('已创建关联线');
  } catch (e: any) { ElMessage.error('添加关联线失败：' + (e?.message || e)); }
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
.ms-layout { display: flex; flex-direction: column; gap: 2px; align-items: flex-start; }
.ms-layout :deep(.el-radio) { margin-right: 0; height: 26px; width: 100%; }
.ms-layout :deep(.el-radio__label) { text-align: left; }
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
.mm-dialog-tip { font-size: 12px; color: #8a8f99; margin: 0 0 10px; line-height: 1.6; }

/* ===== simple-mind-map 外观修正 ===== */
/* 1) 节点文字垂直居中：消除富文本 <p> 默认上下 margin 导致的文字偏下溢出 */
.mm-host :deep(.smm-node p),
.mm-host :deep(.smm-generalization-node p),
.mm-host :deep(.smm-richtext-node-wrap p) {
  margin: 0;
  line-height: 1.5;
}
.mm-host :deep(.smm-richtext-node-wrap) {
  padding: 0;
  display: flex;
  /* 纵向排列：flex 容器内多个 <p>（多行富文本）需换行堆叠，而不是横向压成一行 */
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  box-sizing: border-box;
  /* 保留 \n 换行（概要/节点含换行文本时按行显示；也让 SMM 测高 div 正确撑高） */
  white-space: pre-line;
}
.mm-host :deep(.smm-richtext-node-wrap > *),
.mm-host :deep(.smm-richtext-node-wrap .smm-richtext-node-content) {
  max-width: 100%;
  word-break: break-word;
}
/* 2) 关联线细线（主题已配置 width=1.5，此处兜底防覆盖） */
.mm-host :deep(.smm-associative-line-container path),
.mm-host :deep(.smm-associative-line-container line) {
  stroke-width: 1.5 !important;
}
/* 2.1) 关联线点击热区：SMM 的 clickPath 是透明描边 path，SVG 默认 pointer-events
       不命中透明描边，导致无法点选/删除/编辑文字；改为按描边区域接收事件。
       线文字（text）不拦截点击（文字编辑走 clickPath 的 dblclick） */
.mm-host :deep(.smm-associative-line-container path) {
  pointer-events: stroke;
  cursor: pointer;
}
.mm-host :deep(.smm-associative-line-container text) {
  pointer-events: none;
}
/* 3) 概要节点 / 边界文字行高紧凑；概要多行文本（\n）按换行显示
   注：概要节点类名形如 smm-node generalization_{nodeId} */
.mm-host :deep(.smm-node[class*="generalization_"]) { font-size: 12px; }
.mm-host :deep(.smm-node[class*="generalization_"] p),
.mm-host :deep(.smm-node[class*="generalization_"] .smm-richtext-node-wrap) { white-space: pre-line; }
.mm-host :deep(.smm-outer-frame-text) { font-size: 12px; }
.mm-host :deep(.smm-associative-line-text) { font-size: 11px; }
</style>
