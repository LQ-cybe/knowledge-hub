<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { getStats } from './api';
import { getSavedTheme, setTheme, type KhTheme } from './theme';
import GraphView from './GraphView.vue';
import HomeView from './HomeView.vue';
import BrowserView from './BrowserView.vue';

const activeTab = ref('browse');
const browserRef = ref<InstanceType<typeof BrowserView>>();

const stats = ref<{ total: number; byType: { type: string; n: number }[] }>({ total: 0, byType: [] });

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

const typeLabels: Record<string, string> = { file: '文件', folder: '文件夹', note: '笔记', bookmark: '书签', todo: '待办', report: '报表' };

onMounted(async () => {
  stats.value = await getStats();
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
</script>

<template>
  <div class="page">
    <header class="topbar">
      <h1>Knowledge Hub <span class="sub">本地知识库</span></h1>
      <div class="stats">
        <el-tag type="info" effect="plain">资源总数 {{ stats.total }}</el-tag>
        <el-tag v-for="t in stats.byType" :key="t.type" effect="plain">
          {{ typeLabels[t.type] || t.type }} {{ t.n }}
        </el-tag>
      </div>
      <div class="top-actions">
        <el-button text circle @click="settingsVisible = true" title="设置">
          <span style="font-size: 16px;">⚙️</span>
        </el-button>
      </div>
    </header>

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
    </el-dialog>

    <el-tabs v-model="activeTab" class="main-tabs">
      <el-tab-pane label="🏠 工作台" name="home">
        <HomeView @open-folder="openFolder" @open-tag="openTag" />
      </el-tab-pane>
      <el-tab-pane label="📚 浏览" name="browse">
        <BrowserView ref="browserRef" />
      </el-tab-pane>
      <el-tab-pane label="🕸️ 图谱" name="graph">
        <GraphView />
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<style>
body {
  margin: 0;
  font-family: 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', sans-serif;
  background: var(--el-bg-color-page, #f5f7fa);
  color: var(--el-text-color-primary, #1f2937);
}
/* 下拉选项统一正常行高 */
.el-select-dropdown__item { height: 30px; line-height: 30px; padding: 0 12px; font-size: 13px; }
.page { display: flex; flex-direction: column; height: 100vh; }
.topbar { display: flex; align-items: center; gap: 16px; padding: 12px 20px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); }
.topbar h1 { font-size: 18px; margin: 0; color: var(--el-text-color-primary, #1f2937); }
.topbar .sub { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); font-weight: 400; margin-left: 6px; }
.stats { display: flex; gap: 8px; flex-wrap: wrap; }
.top-actions { margin-left: auto; }

.main-tabs { flex: 1; display: flex; flex-direction: column; min-height: 0; }
.main-tabs > .el-tabs__header { margin-bottom: 0; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); padding: 0 8px; }
.main-tabs > .el-tabs__content { flex: 1; min-height: 0; }
.main-tabs > .el-tabs__content > .el-tab-pane { height: 100%; }

/* 设置对话框 */
.set-group { display: flex; flex-direction: column; gap: 8px; }
.set-label { font-size: 13px; color: var(--el-text-color-secondary, #6b7280); }
.set-hint { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); line-height: 1.6; }
</style>
