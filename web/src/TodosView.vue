<script setup lang="ts">
// 待办视图：左侧分类快捷栏 + 右侧待办列表
// 功能：
//  - 左栏快捷筛选（全部/今日/本周/已完成）、按优先级筛选、标签按「自定义类别」归类
//  - 右侧列表：优先级/待办内容（下方内嵌子项列表，可直接勾选）/截止时间/提醒/标签
//  - 新建/编辑弹窗：内容、说明、优先级、一级子项、开始/截止时间、提醒计划、标签
// 数据：title=待办内容，content=说明，meta=优先级/子项/时间/提醒（JSON）
import { computed, onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import {
  getResourcesPage, createResource, updateResource, deleteResource, setResourceTags,
  getResource, getTags, updateTag, type Resource, type TagItem,
} from './api';
import TagChips from './components/TagChips.vue';
import TagManageDialog from './components/TagManageDialog.vue';

// ---------- 待办扩展数据模型（存 resources.meta JSON） ----------
type Priority = 'low' | 'normal' | 'high';
interface Subtask { id: string; title: string; done: boolean }
interface TodoMeta {
  priority?: Priority;
  subtasks?: Subtask[];
  start_at?: string;   // 'YYYY-MM-DD HH:mm'
  due_at?: string;     // 'YYYY-MM-DD HH:mm'
  reminder?: string;   // none | at_due | 5m | 30m | 1h | 1d
}

const PRIORITY_TEXT: Record<Priority, string> = { low: '低', normal: '普通', high: '高' };
const PRIORITY_CLASS: Record<Priority, string> = { low: 'low', normal: 'normal', high: 'high' };
const REMINDER_OPTIONS: { value: string; label: string }[] = [
  { value: 'none', label: '不提醒' },
  { value: 'at_due', label: '截止时提醒' },
  { value: '5m', label: '提前 5 分钟' },
  { value: '30m', label: '提前 30 分钟' },
  { value: '1h', label: '提前 1 小时' },
  { value: '1d', label: '提前 1 天' },
];
const REMINDER_TEXT: Record<string, string> = Object.fromEntries(REMINDER_OPTIONS.map(o => [o.value, o.label]));

function parseMeta(row: { meta?: string | null }): TodoMeta {
  try { return JSON.parse(row.meta || '{}') as TodoMeta; } catch { return {}; }
}
const todoMeta = (row: Resource): TodoMeta => parseMeta(row);
const subtasksOf = (row: Resource): Subtask[] => todoMeta(row).subtasks || [];
const priorityOf = (row: Resource): Priority => todoMeta(row).priority || 'normal';
const dueAtOf = (row: Resource): string => todoMeta(row).due_at || '';
const reminderOf = (row: Resource): string => todoMeta(row).reminder || 'none';
const rowTagNames = (row: Resource) => (row.tag_names || '').split('|').filter(Boolean);
const rowTagIds = (row: Resource) => (row.tag_ids || '').split('|').filter(Boolean);

// ---------- 日期工具 ----------
const pad2 = (n: number) => String(n).padStart(2, '0');
function localDate(d = new Date()) { return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`; }
const todayStr = () => localDate();
function weekRange() {
  const now = new Date();
  const wd = (now.getDay() + 6) % 7; // 周一为一周开始
  const mon = new Date(now.getFullYear(), now.getMonth(), now.getDate() - wd);
  const sun = new Date(mon.getFullYear(), mon.getMonth(), mon.getDate() + 6);
  return { s: localDate(mon), e: localDate(sun) };
}
function localDateOf(iso: string) {
  if (!iso) return '';
  const d = new Date(iso.includes('T') ? iso : iso.replace(' ', 'T'));
  if (isNaN(d.getTime())) return '';
  return localDate(d);
}
/** 待办所属日期：优先截止时间，其次创建时间（今日/本周筛选用） */
function todoDate(row: Resource) {
  const due = dueAtOf(row);
  return due ? due.slice(0, 10) : localDateOf(row.created_at);
}
function fmtTime(s: string) {
  if (!s) return '';
  const d = new Date(s.replace(' ', 'T'));
  if (isNaN(d.getTime())) return s;
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

// ---------- 数据加载 ----------
const allTodos = ref<Resource[]>([]);
const tags = ref<TagItem[]>([]);
const loading = ref(false);

async function load() {
  loading.value = true;
  try {
    const res = await getResourcesPage({ page: '1', pageSize: '500', type: 'todo', status: 'active' });
    allTodos.value = res.list;
    tags.value = await getTags();
  } catch (e: any) {
    ElMessage.error('加载失败：' + (e?.message || '服务异常'));
  } finally {
    loading.value = false;
  }
}
onMounted(load);
defineExpose({ reload: load });

// ---------- 左栏筛选状态 ----------
type Quick = 'all' | 'today' | 'week' | 'done';
const quick = ref<Quick>('all');
const priFilter = ref<'' | Priority>('');
const tagFilter = ref('');
function setQuick(v: Quick) { quick.value = v; }
function setPri(v: '' | Priority) { priFilter.value = priFilter.value === v ? '' : v; }
function setTag(id: string) { tagFilter.value = tagFilter.value === id ? '' : id; }

/** 右栏列表（快捷 + 优先级 + 标签 组合筛选；非「已完成」视图隐藏已完成项） */
const list = computed(() => {
  const t = todayStr();
  const { s, e } = weekRange();
  return allTodos.value.filter(r => {
    if (quick.value === 'done') { if (!r.done) return false; }
    else {
      if (r.done) return false;
      if (quick.value === 'today') { if (todoDate(r) !== t) return false; }
      else if (quick.value === 'week') { const d = todoDate(r); if (!d || d < s || d > e) return false; }
    }
    if (priFilter.value && priorityOf(r) !== priFilter.value) return false;
    if (tagFilter.value && !rowTagIds(r).includes(tagFilter.value)) return false;
    return true;
  });
});

/** 左栏各筛选项计数（快捷/优先级以「未完成」计，已完成单列） */
const counts = computed(() => {
  const t = todayStr();
  const { s, e } = weekRange();
  const undone = allTodos.value.filter(r => !r.done);
  return {
    all: undone.length,
    today: undone.filter(r => todoDate(r) === t).length,
    week: undone.filter(r => { const d = todoDate(r); return !!d && d >= s && d <= e; }).length,
    done: allTodos.value.filter(r => r.done).length,
    high: undone.filter(r => priorityOf(r) === 'high').length,
    normal: undone.filter(r => priorityOf(r) === 'normal').length,
    low: undone.filter(r => priorityOf(r) === 'low').length,
  };
});
/** 每个标签下的待办数 */
const tagCountMap = computed(() => {
  const m: Record<string, number> = {};
  for (const r of allTodos.value) for (const id of rowTagIds(r)) m[id] = (m[id] || 0) + 1;
  return m;
});
/** 标签按自定义类别分组（未分类排最后） */
const tagGroups = computed(() => {
  const map = new Map<string, TagItem[]>();
  for (const t of tags.value) {
    const c = t.category || '';
    if (!map.has(c)) map.set(c, []);
    map.get(c)!.push(t);
  }
  const groups = [...map.entries()].map(([name, list]) => ({ name, tags: list }));
  groups.sort((a, b) => (a.name === '' ? 1 : b.name === '' ? -1 : a.name.localeCompare(b.name, 'zh')));
  return groups;
});
const catOptions = computed(() => [...new Set(tags.value.map(t => t.category || '').filter(Boolean))]);

// ---------- 新建 / 编辑弹窗 ----------
const dlg = ref({
  visible: false, id: '', title: '', content: '', priority: 'normal' as Priority,
  subtasks: [] as Subtask[], start_at: '', due_at: '', reminder: 'none', tagIds: [] as string[], saving: false,
});
function uid() { return (crypto?.randomUUID ? crypto.randomUUID() : 's' + Date.now() + Math.random().toString(16).slice(2)); }

function openCreate() {
  dlg.value = { visible: true, id: '', title: '', content: '', priority: 'normal', subtasks: [], start_at: '', due_at: '', reminder: 'none', tagIds: [], saving: false };
}
async function openEdit(row: Resource) {
  const detail = await getResource(row.id) as Resource & { meta?: string | null };
  const m = parseMeta(detail);
  dlg.value = {
    visible: true, id: row.id, title: detail.title || '', content: detail.content || '',
    priority: m.priority || 'normal', subtasks: (m.subtasks || []).map(s => ({ ...s })),
    start_at: m.start_at || '', due_at: m.due_at || '', reminder: m.reminder || 'none',
    tagIds: rowTagIds(row), saving: false,
  };
}
function addSubtask() { dlg.value.subtasks.push({ id: uid(), title: '', done: false }); }
function removeSubtask(i: number) { dlg.value.subtasks.splice(i, 1); }

async function doSave() {
  const d = dlg.value;
  if (!d.title.trim()) { ElMessage.warning('请输入待办内容'); return; }
  d.saving = true;
  try {
    const meta: TodoMeta = {
      priority: d.priority,
      subtasks: d.subtasks.filter(s => s.title.trim()).map(s => ({ id: s.id, title: s.title.trim(), done: !!s.done })),
      start_at: d.start_at || undefined,
      due_at: d.due_at || undefined,
      reminder: d.reminder,
    };
    const metaStr = JSON.stringify(meta);
    if (d.id) {
      await updateResource(d.id, { title: d.title.trim(), content: d.content, meta: metaStr });
      if (d.tagIds.length) await setResourceTags(d.id, d.tagIds);
      ElMessage.success('待办已保存');
    } else {
      const r = await createResource('todo', d.title.trim(), d.content, '', metaStr);
      if (d.tagIds.length) await setResourceTags(r.id, d.tagIds);
      ElMessage.success('已添加待办');
    }
    d.visible = false;
    await load();
  } catch (e: any) {
    ElMessage.error('保存失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    d.saving = false;
  }
}

// ---------- 完成状态切换 ----------
const toggling = ref<Set<string>>(new Set());
async function toggleDone(row: Resource) {
  if (toggling.value.has(row.id)) return;
  toggling.value.add(row.id);
  try {
    await updateResource(row.id, { done: !row.done });
    row.done = !row.done;
  } catch (e: any) {
    ElMessage.error('更新失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    toggling.value.delete(row.id);
  }
}
/** 子项勾选：直接修改该待办 meta.subtasks 后整体写回（meta 为覆盖语义） */
async function toggleSub(row: Resource, sub: Subtask) {
  try {
    const m = todoMeta(row);
    const next = (m.subtasks || []).map(s => s.id === sub.id ? { ...s, done: !s.done } : s);
    await updateResource(row.id, { meta: JSON.stringify({ ...m, subtasks: next }) });
    row.meta = JSON.stringify({ ...m, subtasks: next });
  } catch (e: any) {
    ElMessage.error('子项更新失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  }
}

// ---------- 右键菜单 ----------
const ctx = ref({ visible: false, x: 0, y: 0, row: null as Resource | null });
function onCtx(e: MouseEvent, row: Resource) {
  e.preventDefault();
  ctx.value = { visible: true, x: e.clientX, y: e.clientY, row };
}
function closeCtx() { ctx.value.visible = false; }
async function onCtxCmd(cmd: string) {
  const row = ctx.value.row;
  ctx.value.visible = false;
  if (!row) return;
  if (cmd === 'edit') { openEdit(row); return; }
  if (cmd === 'toggle') { toggleDone(row); return; }
  try {
    await ElMessageBox.confirm(`将待办「${row.title}」移入回收站？`, '移入回收站', { type: 'warning' });
  } catch { return; }
  try {
    await deleteResource(row.id);
    ElMessage.success('已移入回收站（30 天后自动清理）');
    await load();
  } catch (e: any) {
    ElMessage.error('删除失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  }
}
onMounted(() => document.addEventListener('click', closeCtx));

// ---------- 行级标签 ----------
const tagDlg = ref({ visible: false, row: null as Resource | null });
function openTagDialog(row: Resource) { tagDlg.value = { visible: true, row }; }
async function saveTags(ids: string[]) {
  const row = tagDlg.value.row;
  if (!row) return;
  try {
    await setResourceTags(row.id, ids);
    await load();
    ElMessage.success('标签已更新');
  } catch (e: any) {
    ElMessage.error('标签更新失败：' + (e?.message || '服务异常'));
  }
}
const tagsMap = ref<Record<string, string>>({});
const namesOf = (ids: string[]) => ids.map(id => tagsMap.value[id] || id).filter(Boolean);
const formTagDlg = ref({ visible: false });
function onFormTagSave(ids: string[]) { dlg.value.tagIds = ids; formTagDlg.value.visible = false; }

// ---------- 类别管理 ----------
const catDlg = ref({ visible: false, rows: [] as { id: string; name: string; category: string; old: string }[], saving: false });
function openCatMgr() {
  catDlg.value = {
    visible: true, saving: false,
    rows: tags.value.map(t => ({ id: t.id, name: t.name, category: t.category || '', old: t.category || '' })),
  };
}
async function saveCatMgr() {
  const d = catDlg.value;
  d.saving = true;
  try {
    const changed = d.rows.filter(r => r.category !== r.old);
    for (const r of changed) await updateTag(r.id, { category: r.category });
    d.visible = false;
    ElMessage.success(changed.length ? `已更新 ${changed.length} 个标签的类别` : '没有变更');
    await load();
  } catch (e: any) {
    ElMessage.error('保存失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    d.saving = false;
  }
}

onMounted(() => {
  getTags().then(ts => {
    const m: Record<string, string> = {};
    ts.forEach(t => { m[t.id] = t.name; });
    tagsMap.value = m;
  }).catch(() => { /* 忽略 */ });
});
</script>

<template>
  <div class="todos-view">
    <div class="tv-head">
      <div class="tv-title">✅ 待办<small>（未完成 {{ counts.all }} 项）</small></div>
      <el-button type="primary" size="default" @click="openCreate">✅ 新建待办</el-button>
    </div>

    <div class="tv-main">
      <!-- 左侧分类快捷栏 -->
      <aside class="tv-side">
        <div class="tv-sec">
          <div class="tv-sec-title">快捷</div>
          <div class="tv-nav" :class="{ on: quick === 'all', sel: quick === 'all' && !priFilter && !tagFilter }" @click="setQuick('all')">
            <span class="tv-nav-t">📋 全部</span><span class="tv-nav-n">{{ counts.all }}</span>
          </div>
          <div class="tv-nav" :class="{ sel: quick === 'today' }" @click="setQuick('today')">
            <span class="tv-nav-t">📆 今日</span><span class="tv-nav-n">{{ counts.today }}</span>
          </div>
          <div class="tv-nav" :class="{ sel: quick === 'week' }" @click="setQuick('week')">
            <span class="tv-nav-t">🗓️ 本周</span><span class="tv-nav-n">{{ counts.week }}</span>
          </div>
          <div class="tv-nav" :class="{ sel: quick === 'done' }" @click="setQuick('done')">
            <span class="tv-nav-t">✅ 已完成</span><span class="tv-nav-n">{{ counts.done }}</span>
          </div>
        </div>

        <div class="tv-sec">
          <div class="tv-sec-title">优先级</div>
          <div class="tv-nav" :class="{ sel: priFilter === 'high' }" @click="setPri('high')">
            <span class="tv-nav-t"><i class="tv-dot high"></i>高</span><span class="tv-nav-n">{{ counts.high }}</span>
          </div>
          <div class="tv-nav" :class="{ sel: priFilter === 'normal' }" @click="setPri('normal')">
            <span class="tv-nav-t"><i class="tv-dot normal"></i>普通</span><span class="tv-nav-n">{{ counts.normal }}</span>
          </div>
          <div class="tv-nav" :class="{ sel: priFilter === 'low' }" @click="setPri('low')">
            <span class="tv-nav-t"><i class="tv-dot low"></i>低</span><span class="tv-nav-n">{{ counts.low }}</span>
          </div>
        </div>

        <div class="tv-sec tv-sec-tags">
          <div class="tv-sec-title">
            标签
            <button class="tv-cat-btn" title="管理标签类别" @click.stop="openCatMgr">⚙ 类别</button>
          </div>
          <template v-for="g in tagGroups" :key="g.name || '__none__'">
            <div class="tv-cat">{{ g.name || '未分类' }}</div>
            <div v-for="t in g.tags" :key="t.id" class="tv-nav tv-nav-tag" :class="{ sel: tagFilter === t.id }" @click="setTag(t.id)">
              <span class="tv-nav-t"><i class="tv-dot" :style="{ background: t.color || '#8BC8EA' }"></i>{{ t.name }}</span>
              <span class="tv-nav-n">{{ tagCountMap[t.id] || 0 }}</span>
            </div>
          </template>
          <div v-if="tags.length === 0" class="tv-side-empty">暂无标签</div>
        </div>
      </aside>

      <!-- 右侧列表 -->
      <div class="tv-body" v-loading="loading">
        <el-table :data="list" size="small" height="100%" stripe @row-click="openEdit" @row-contextmenu="onCtx">
          <el-table-column label="" width="52">
            <template #default="{ row }">
              <el-checkbox :model-value="!!row.done" @change="toggleDone(row)" @click.stop />
            </template>
          </el-table-column>
          <el-table-column label="优先级" width="76" align="center">
            <template #default="{ row }">
              <span class="tv-pri" :class="PRIORITY_CLASS[priorityOf(row)]">{{ PRIORITY_TEXT[priorityOf(row)] }}</span>
            </template>
          </el-table-column>
          <el-table-column label="待办内容" min-width="280">
            <template #default="{ row }">
              <div class="tv-name" :class="{ done: !!row.done }">
                <span class="tv-ico">{{ row.done ? '✅' : '⭕' }}</span>{{ row.title }}
              </div>
              <!-- 子项列表：直接列出 + 可勾选切换完成状态 -->
              <div v-if="subtasksOf(row).length" class="tv-subs">
                <label v-for="s in subtasksOf(row)" :key="s.id" class="tv-sub-item">
                  <el-checkbox :model-value="!!s.done" @change="toggleSub(row, s)" @click.stop />
                  <span class="tv-sub-txt" :class="{ done: !!s.done }">{{ s.title }}</span>
                </label>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="截止时间" width="140">
            <template #default="{ row }">
              <span v-if="dueAtOf(row)" class="tv-due" :class="{ overdue: !row.done && new Date(dueAtOf(row).replace(' ', 'T')).getTime() < Date.now() }">
                {{ dueAtOf(row) }}
              </span>
              <span v-else class="tv-empty-cell">—</span>
            </template>
          </el-table-column>
          <el-table-column label="提醒" width="126">
            <template #default="{ row }">
              <span v-if="reminderOf(row) !== 'none'" class="tv-rem">🔔 {{ REMINDER_TEXT[reminderOf(row)] || reminderOf(row) }}</span>
              <span v-else class="tv-empty-cell">—</span>
            </template>
          </el-table-column>
          <el-table-column label="标签" min-width="150">
            <template #default="{ row }">
              <TagChips :names="rowTagNames(row)" @open="openTagDialog(row)" />
            </template>
          </el-table-column>
        </el-table>
        <div v-if="list.length === 0 && !loading" class="tv-empty">暂无待办</div>
      </div>
    </div>

    <!-- 新建 / 编辑待办 -->
    <el-dialog v-model="dlg.visible" :title="dlg.id ? '编辑待办' : '新建待办'" width="620" destroy-on-close>
      <div class="tv-field">
        <label>待办内容 <em>*</em></label>
        <el-input v-model="dlg.title" placeholder="要做什么？" maxlength="200" @keyup.enter="doSave" />
      </div>
      <div class="tv-field">
        <label>说明</label>
        <el-input v-model="dlg.content" type="textarea" :rows="3" placeholder="补充说明…" />
      </div>
      <div class="tv-field">
        <label>优先级</label>
        <el-radio-group v-model="dlg.priority">
          <el-radio-button value="low">低</el-radio-button>
          <el-radio-button value="normal">普通</el-radio-button>
          <el-radio-button value="high">高</el-radio-button>
        </el-radio-group>
      </div>
      <div class="tv-field">
        <label>一级子项</label>
        <div class="tv-subtasks">
          <div v-for="(s, i) in dlg.subtasks" :key="s.id" class="tv-subtask">
            <el-checkbox v-model="s.done" />
            <el-input v-model="s.title" placeholder="子项内容" size="small" @keyup.enter="addSubtask" />
            <el-button size="small" text type="danger" @click="removeSubtask(i)">✕</el-button>
          </div>
          <el-button size="small" text type="primary" @click="addSubtask">＋ 添加子项</el-button>
        </div>
      </div>
      <div class="tv-row">
        <div class="tv-field">
          <label>开始时间</label>
          <el-date-picker v-model="dlg.start_at" type="datetime" placeholder="选择开始时间" value-format="YYYY-MM-DD HH:mm" style="width: 100%;" />
        </div>
        <div class="tv-field">
          <label>截止时间</label>
          <el-date-picker v-model="dlg.due_at" type="datetime" placeholder="选择截止时间" value-format="YYYY-MM-DD HH:mm" style="width: 100%;" />
        </div>
      </div>
      <div class="tv-field">
        <label>提醒计划</label>
        <el-select v-model="dlg.reminder" style="width: 100%;">
          <el-option v-for="o in REMINDER_OPTIONS" :key="o.value" :label="o.label" :value="o.value" />
        </el-select>
      </div>
      <div class="tv-field">
        <label>标签</label>
        <TagChips :names="namesOf(dlg.tagIds)" placeholder="选择标签" @open="formTagDlg.visible = true" />
      </div>
      <template #footer>
        <el-button @click="dlg.visible = false">取消</el-button>
        <el-button type="primary" :loading="dlg.saving" @click="doSave">{{ dlg.id ? '保存' : '添加' }}</el-button>
      </template>
    </el-dialog>

    <!-- 标签类别管理：给每个标签指定自定义类别（可新建类别名） -->
    <el-dialog v-model="catDlg.visible" title="管理标签类别" width="520">
      <div class="tv-cat-hint">为标签指定所属类别，左栏将按类别归类展示；类别名可直接输入新建。</div>
      <div class="tv-cat-list">
        <div v-for="r in catDlg.rows" :key="r.id" class="tv-cat-row">
          <span class="tv-cat-name" :title="r.name">{{ r.name }}</span>
          <el-select v-model="r.category" size="small" filterable allow-create default-first-option
            placeholder="未分类" style="width: 200px;">
            <el-option v-for="c in catOptions" :key="c" :label="c" :value="c" />
          </el-select>
        </div>
        <div v-if="catDlg.rows.length === 0" class="tv-side-empty">暂无标签</div>
      </div>
      <template #footer>
        <el-button @click="catDlg.visible = false">取消</el-button>
        <el-button type="primary" :loading="catDlg.saving" @click="saveCatMgr">确定</el-button>
      </template>
    </el-dialog>

    <!-- 添加标签（统一弹窗：可直接新建/删除） -->
    <TagManageDialog v-model="tagDlg.visible" :ids="tagDlg.row ? rowTagIds(tagDlg.row) : []" title="添加标签" @save="saveTags" />

    <!-- 表单内选择标签 -->
    <TagManageDialog v-model="formTagDlg.visible" :ids="dlg.tagIds" title="选择标签" :allow-create="false" :allow-delete="false" @save="onFormTagSave" />

    <!-- 右键菜单 -->
    <Teleport to="body">
      <div v-if="ctx.visible" class="ctx-menu" :style="{ left: ctx.x + 'px', top: ctx.y + 'px' }" @contextmenu.prevent>
        <div class="ctx-item" @click="onCtxCmd('edit')">编辑</div>
        <div class="ctx-item" @click="onCtxCmd('toggle')">{{ ctx.row?.done ? '标记为未完成' : '标记为完成' }}</div>
        <div class="ctx-item danger" @click="onCtxCmd('delete')">删除（回收站）</div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.todos-view { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.tv-head { display: flex; align-items: center; gap: 12px; padding: 10px 16px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.tv-title { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.tv-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }
.tv-main { flex: 1; min-height: 0; display: flex; gap: 12px; padding: 12px 16px 16px; box-sizing: border-box; }

/* 左侧分类快捷栏 */
.tv-side { width: 196px; flex: none; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color, #e5e7eb); border-radius: 10px; overflow-y: auto; padding: 8px 6px 12px; }
.tv-sec { margin-bottom: 10px; }
.tv-sec-title { display: flex; align-items: center; justify-content: space-between; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); padding: 6px 8px 4px; }
.tv-cat-btn { border: none; background: transparent; color: var(--el-color-primary, #409eff); font-size: 12px; cursor: pointer; padding: 0 2px; font-family: inherit; }
.tv-cat-btn:hover { text-decoration: underline; }
.tv-nav { display: flex; align-items: center; justify-content: space-between; gap: 6px; padding: 6px 8px; border-radius: 6px; cursor: pointer; font-size: 13px; color: var(--el-text-color-primary, #1f2937); }
.tv-nav:hover { background: var(--el-fill-color-light, #f5f7fa); }
.tv-nav.sel { background: var(--el-color-primary-light-9, #ecf5ff); color: var(--el-color-primary, #409eff); }
.tv-nav-t { display: flex; align-items: center; gap: 6px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.tv-nav-n { flex: none; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); font-variant-numeric: tabular-nums; }
.tv-nav.sel .tv-nav-n { color: var(--el-color-primary, #409eff); }
.tv-nav-tag { padding-left: 14px; }
.tv-cat { font-size: 11px; color: var(--el-text-color-secondary, #b0b6bf); padding: 6px 8px 2px; }
.tv-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex: none; }
.tv-dot.high { background: #f56c6c; }
.tv-dot.normal { background: #409eff; }
.tv-dot.low { background: #c0c4cc; }
.tv-side-empty { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); text-align: center; padding: 16px 0; }

.tv-body { flex: 1; min-width: 0; background: var(--el-bg-color, #fff); border-radius: 10px; border: 1px solid var(--el-border-color, #e5e7eb); overflow: hidden; position: relative; }
.tv-body :deep(.el-table td.el-table__cell) { padding: 2px 0; }
.tv-body :deep(.el-table th.el-table__cell) { padding: 4px 0; }
.tv-body :deep(.el-table .cell) { padding: 0 8px; line-height: 1.5; }
.tv-body :deep(.el-table__row) { cursor: pointer; }
.tv-name { display: flex; align-items: center; gap: 8px; overflow: hidden; }
.tv-name.done { color: var(--el-text-color-secondary, #9ca3af); text-decoration: line-through; }
.tv-ico { flex: none; font-size: 14px; }
.tv-pri { display: inline-block; min-width: 30px; padding: 1px 8px; font-size: 12px; border-radius: 10px; text-align: center; }
.tv-pri.low { background: #f3f4f6; color: #9ca3af; }
.tv-pri.normal { background: var(--el-color-primary-light-9, #ecf5ff); color: var(--el-color-primary, #409eff); }
.tv-pri.high { background: #fef0f0; color: #f56c6c; }
.tv-subs { margin: 2px 0 2px 22px; display: flex; flex-direction: column; gap: 1px; }
.tv-sub-item { display: flex; align-items: center; gap: 6px; cursor: pointer; }
.tv-sub-item :deep(.el-checkbox) { height: 18px; margin-right: 0; }
.tv-sub-txt { font-size: 12px; color: var(--el-text-color-regular, #4b5563); }
.tv-sub-txt.done { color: var(--el-text-color-secondary, #9ca3af); text-decoration: line-through; }
.tv-due { font-size: 12px; color: var(--el-text-color-primary, #1f2937); }
.tv-due.overdue { color: #f56c6c; font-weight: 600; }
.tv-rem { font-size: 12px; color: var(--el-text-color-primary, #1f2937); }
.tv-empty-cell { color: var(--el-text-color-secondary, #c0c4cc); font-size: 12px; }
.tv-empty { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; color: var(--el-text-color-secondary, #9ca3af); font-size: 13px; }
.tv-field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 12px; }
.tv-field label { font-size: 12px; color: var(--el-text-color-secondary, #6b7280); }
.tv-field label em { color: #f56c6c; font-style: normal; }
.tv-row { display: flex; gap: 12px; }
.tv-row .tv-field { flex: 1; }
.tv-subtasks { display: flex; flex-direction: column; gap: 6px; }
.tv-subtask { display: flex; align-items: center; gap: 8px; }
.tv-subtask .el-checkbox { margin-right: 0; }
.tv-cat-hint { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-bottom: 10px; }
.tv-cat-list { max-height: 320px; overflow-y: auto; display: flex; flex-direction: column; gap: 6px; }
.tv-cat-row { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
.tv-cat-name { font-size: 13px; color: var(--el-text-color-primary, #1f2937); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ctx-menu { position: fixed; z-index: 3000; min-width: 120px; padding: 4px; border-radius: 8px; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color, #e5e7eb); box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12); }
.ctx-item { padding: 6px 12px; font-size: 13px; border-radius: 5px; cursor: pointer; color: var(--el-text-color-primary, #1f2937); }
.ctx-item:hover { background: var(--kh-brand, #409eff); color: #fff; }
.ctx-item.danger { color: #f56c6c; }
.ctx-item.danger:hover { background: #f56c6c; color: #fff; }
</style>
