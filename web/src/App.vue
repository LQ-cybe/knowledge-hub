<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { getSavedTheme, setTheme, type KhTheme } from './theme';
import GraphView from './GraphView.vue';
import HomeView from './HomeView.vue';
import BrowserView from './BrowserView.vue';
import TimelineView from './TimelineView.vue';
import NotesView from './NotesBookmarksView.vue';
import TodosView from './TodosView.vue';
import ReportView from './ReportView.vue';
import MindmapView from './MindmapView.vue';
import FileEditorView from './FileEditorView.vue';

const activeTab = ref(localStorage.getItem('kh-home-tab') || 'browse');
const browserRef = ref<InstanceType<typeof BrowserView>>();
const notesRef = ref<InstanceType<typeof NotesView>>();
const todosRef = ref<InstanceType<typeof TodosView>>();

/** 独立文件编辑器状态（非空 = 全屏编辑器页，替代弹窗）；mode='file' 磁盘文件 / 'note' 数据库笔记 */
const editor = ref<{ id: string; title: string; ext: string; path: string; isImage: boolean; mode: 'file' | 'note' } | null>(null);
/** 编辑器打开来源页（打开时记录当前 tab）：关闭时返回该页而不是固定回浏览页 */
const editorFrom = ref<'browse' | 'notes' | 'todos'>('browse');
function openEditor(e: { id: string; title: string; ext: string; path: string; isImage: boolean; mode?: 'file' | 'note' }) {
  editorFrom.value = (activeTab.value === 'notes' || activeTab.value === 'todos' ? activeTab.value : 'browse');
  editor.value = { mode: 'file', ...e };
}
function closeEditor() {
  editor.value = null;
  // 回到编辑器前的页面（笔记页/待办页/浏览页），并刷新对应列表
  const back = editorFrom.value;
  activeTab.value = back;
  if (back === 'browse') browserRef.value?.reload?.();
  else if (back === 'notes') notesRef.value?.reload?.();
  else if (back === 'todos') todosRef.value?.reload?.();
}

// 设置对话框
const settingsVisible = ref(false);
const theme = ref<KhTheme>(getSavedTheme());
const themeOptions = [
  { value: 'auto', label: '跟随系统', icon: '🖥️' },
  { value: 'light', label: '浅色', icon: '☀️' },
  { value: 'dark', label: '深色', icon: '🌙' },
];
function onThemeChange(t: KhTheme) {
  setTheme(t);
}

// 主页面设置（进入软件后默认显示的窗口），持久化到 localStorage
const HOME_TAB_KEY = 'kh-home-tab';
const homeTab = ref(activeTab.value);
const navTabs = [
  { value: 'home', label: '🏠工作台' },
  { value: 'browse', label: '📁文件' },
  { value: 'graph', label: '🧠图谱' },
  { value: 'timeline', label: '🕐历史' },
  { value: 'notes', label: '📑书签笔记' },
  { value: 'todos', label: '✅待办' },
  { value: 'report', label: '📅报表' },
  { value: 'mindmap', label: '🧩思维导图' },
];
const homeTabOptions = navTabs;
function onHomeTabChange(v: string) {
  homeTab.value = v;
  activeTab.value = v;
  try { localStorage.setItem(HOME_TAB_KEY, v); } catch { /* 忽略 */ }
}

onMounted(() => {
  /* 顶部标题行不再展示统计标签（已并入工作台统计控件） */
});

/** 工作台点击顶层目录 → 跳转浏览页并定位到该目录 */
async function openFolder(id: string) {
  activeTab.value = 'browse';
  await browserRef.value?.openFolder(id);
}

/** 工作台点击常用标签 → 跳转浏览页按标签筛选 */
async function openTag(tagId: string) {
  activeTab.value = 'browse';
  await browserRef.value?.openTag(tagId);
}

/** 时间线点击资源 → 跳转浏览页定位到其所在目录 */
async function openResource(parentId: string | null) {
  activeTab.value = 'browse';
  if (parentId) await browserRef.value?.openFolder(parentId);
}

/** 时间线单击可编辑文件 → 打开文件编辑器进入编辑模式 */
function openFile(r: { id: string; title: string; path: string }) {
  const e = (r.path.split('.').pop() || '').toLowerCase();
  const imgExt = new Set(['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'svg', 'ico']);
  editorFrom.value = 'browse';
  editor.value = { mode: 'file', id: r.id, title: r.title, ext: e, path: r.path, isImage: imgExt.has(e) };
}
</script>

<template>
  <!-- 独立文件编辑器：打开时整页切换（跳转到编辑器页面） -->
  <FileEditorView
    v-if="editor"
    :id="editor.id"
    :title="editor.title"
    :ext="editor.ext"
    :path="editor.path"
    :is-image="editor.isImage"
    :mode="editor.mode"
    @close="closeEditor"
  />

  <div v-else class="page">
    <!-- 标题栏与页面切换按钮同一行 -->
    <div class="topbar">
      <h1>本地知识库</h1>
      <nav class="nav-tabs">
        <button v-for="t in navTabs" :key="t.value"
          class="nav-tab" :class="{ active: activeTab === t.value }"
          @click="activeTab = t.value">{{ t.label }}</button>
      </nav>
      <div class="top-actions">
        <el-button text circle @click="settingsVisible = true" title="设置">
          <span style="font-size: 16px;">⚙️</span>
        </el-button>
      </div>
    </div>

    <!-- 软件设置 -->
    <el-dialog v-model="settingsVisible" title="软件设置" width="420">
      <div class="set-group">
        <div class="set-label">外观主题</div>
        <el-radio-group v-model="theme" @change="onThemeChange">
          <el-radio-button v-for="o in themeOptions" :key="o.value" :value="o.value">
            {{ o.icon }} {{ o.label }}
          </el-radio-button>
        </el-radio-group>
        <div class="set-hint">「跟随系统」会随 Windows 深浅色自动切换；也可固定为浅色或深色。</div>
      </div>
      <div class="set-group">
        <div class="set-label">进入软件后显示的窗口</div>
        <el-radio-group v-model="homeTab" @change="onHomeTabChange">
          <el-radio-button v-for="o in homeTabOptions" :key="o.value" :value="o.value">
            {{ o.label }}
          </el-radio-button>
        </el-radio-group>
        <div class="set-hint">选择启动后默认停留的页面；设置会保存在本地，下次打开自动生效。</div>
      </div>
    </el-dialog>

    <div class="tab-content">
      <HomeView v-if="activeTab === 'home'" @open-folder="openFolder" @open-tag="openTag" />
      <BrowserView v-else-if="activeTab === 'browse'" ref="browserRef" @open-editor="openEditor" />
      <GraphView v-else-if="activeTab === 'graph'" />
      <TimelineView v-else-if="activeTab === 'timeline'" @open-resource="openResource" @open-file="openFile" />
      <NotesView v-else-if="activeTab === 'notes'" ref="notesRef" @open-editor="openEditor" />
      <TodosView v-else-if="activeTab === 'todos'" ref="todosRef" />
      <ReportView v-else-if="activeTab === 'report'" />
      <MindmapView v-else-if="activeTab === 'mindmap'" />
    </div>
  </div>
</template>

<style>
/* 全局主色参数：所有强调蓝统一走 --kh-brand（默认取 Element 主题主色） */
:root { --kh-brand: var(--el-color-primary, #409eff); }
body {
  margin: 0;
  font-family: 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', sans-serif;
  background: var(--el-bg-color-page, #f5f7fa);
  color: var(--el-text-color-primary, #1f2937);
}
/* 下拉选项统一正常行高 */
.el-select-dropdown__item { height: 30px; line-height: 30px; padding: 0 12px; font-size: 13px; }
.page { display: flex; flex-direction: column; height: 100vh; }
/* 标题 + 页面切换按钮同一行 */
.topbar { display: flex; align-items: center; gap: 14px; padding: 0 16px; height: 48px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex: none; }
.topbar h1 { font-size: 17px; margin: 0; color: var(--el-text-color-primary, #1f2937); white-space: nowrap; flex: none; padding-right: 12px; border-right: 1px solid var(--el-border-color-lighter, #ebeef5); }
.top-actions { margin-left: auto; flex: none; }

/* 自定义导航按钮：横向排列 + 当前页高亮 */
.nav-tabs { display: flex; gap: 4px; flex: 1; min-width: 0; overflow-x: auto; }
.nav-tab {
  padding: 0 12px; height: 32px; line-height: 32px;
  background: transparent; border: none; cursor: pointer;
  font: inherit; font-size: 13px; color: var(--el-text-color-regular, #4b5563);
  border-radius: 6px; white-space: nowrap;
  transition: background-color .15s, color .15s;
}
.nav-tab:hover { background: var(--el-fill-color-light, #f5f7fa); color: var(--el-text-color-primary, #1f2937); }
.nav-tab.active { background: var(--kh-brand, #409eff); color: #fff; }
.nav-tab.active:hover { background: var(--kh-brand, #409eff); color: #fff; }

.tab-content { flex: 1; min-height: 0; overflow: hidden; }
.tab-content > * { height: 100%; }

/* 设置对话框 */
.set-group { display: flex; flex-direction: column; gap: 8px; }
.set-label { font-size: 13px; color: var(--el-text-color-secondary, #6b7280); }
.set-hint { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); line-height: 1.6; }
</style>
