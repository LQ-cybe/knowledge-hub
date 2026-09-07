<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { getTimeline, type Resource } from './api';

const emit = defineEmits<{ (e: 'open-resource', parentId: string | null): void }>();

const typeFilter = ref('');
const items = ref<Resource[]>([]);
const loading = ref(true);

const typeIcons: Record<string, string> = {
  folder: '📂', file: '📄', note: '📝', bookmark: '🔖', todo: '✅', report: '📊',
};
const typeOptions = [
  { value: '', label: '全部类型' },
  { value: 'note', label: '📝 笔记' },
  { value: 'bookmark', label: '🔖 书签' },
  { value: 'todo', label: '✅ 待办' },
  { value: 'file', label: '📄 文件' },
  { value: 'folder', label: '📂 文件夹' },
  { value: 'report', label: '📊 报表' },
];

/** 按天分组：date -> { dateLabel, weekday, list[] } */
interface DayGroup { date: string; weekday: string; list: Resource[] }
function groupByDay(list: Resource[]): DayGroup[] {
  const map = new Map<string, DayGroup>();
  for (const r of list) {
    const d = new Date(r.created_at.replace(' ', 'T'));
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    if (!map.has(key)) {
      map.set(key, { date: key, weekday: `周${'日一二三四五六'[d.getDay()]}`, list: [] });
    }
    map.get(key)!.list.push(r);
  }
  return [...map.values()];
}
const groups = ref<DayGroup[]>([]);

const W = ref(1);

/** 日期折叠状态（持久化到 sessionStorage，跨重渲染保持） */
const COLLAPSE_KEY = 'kh-tl-collapsed';
function loadCollapsed(): Record<string, boolean> {
  try { return JSON.parse(sessionStorage.getItem(COLLAPSE_KEY) || '{}'); } catch { return {}; }
}
const collapsedDays = ref<Record<string, boolean>>(loadCollapsed());
function toggleDay(date: string) {
  collapsedDays.value[date] = !collapsedDays.value[date];
  try { sessionStorage.setItem(COLLAPSE_KEY, JSON.stringify(collapsedDays.value)); } catch { /* 忽略 */ }
}
function isCollapsed(date: string) { return !!collapsedDays.value[date]; }

async function load() {
  loading.value = true;
  items.value = await getTimeline(typeFilter.value);
  groups.value = groupByDay(items.value);
  loading.value = false;
  W.value = groups.value.length || 1;
}
onMounted(load);

function fmtHM(s: string) {
  if (!s) return '';
  const d = new Date(s.replace(' ', 'T'));
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
</script>

<template>
  <div class="tl" v-loading="loading">
    <div class="tl-head">
      <div class="tl-title">🕐 时间线<small>（按创建时间倒序 · 最近 {{ items.length }} 条）</small></div>
      <el-select v-model="typeFilter" size="default" style="width: 150px;" @change="load">
        <el-option v-for="o in typeOptions" :key="o.value" :value="o.value" :label="o.label" />
      </el-select>
    </div>

    <div class="tl-body">
      <template v-for="g in groups" :key="g.date">
        <!-- 日期节点（可点击折叠） -->
        <div class="tl-day">
          <button
            class="tl-date" :class="{ collapsed: isCollapsed(g.date) }"
            :aria-expanded="String(!isCollapsed(g.date))"
            @click="toggleDay(g.date)"
          >
            <div class="tl-date-num">{{ g.date.slice(8) }}</div>
            <div class="tl-date-rest">
              <div class="tl-date-ym">{{ g.date }}</div>
              <div class="tl-date-wd">{{ g.weekday }} · {{ g.list.length }} 项</div>
            </div>
            <svg class="caret" width="14" height="14" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M6 9l6 6 6-6" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </button>
          <div class="tl-cards">
            <button
              v-for="r in g.list" :key="r.id"
              class="tl-card" :title="r.path"
              v-show="!isCollapsed(g.date)"
              @click="emit('open-resource', r.parent_id)"
            >
              <span class="tl-dot"></span>
              <span class="tl-ico">{{ typeIcons[r.type] || '📄' }}</span>
              <span class="tl-name">{{ r.title }}</span>
              <span class="tl-time">{{ fmtHM(r.created_at) }}</span>
            </button>
          </div>
        </div>
      </template>
      <div v-if="groups.length === 0 && !loading" class="tl-empty">暂无数据</div>
    </div>
  </div>
</template>

<style scoped>
.tl { padding: 8px 20px 20px; display: flex; flex-direction: column; gap: 12px; height: 100%; box-sizing: border-box; overflow-y: auto; }
.tl-head { display: flex; align-items: center; gap: 14px; flex: none; }
.tl-title { font-size: 15px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.tl-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }

.tl-body { display: flex; flex-direction: column; flex: 1; min-height: 0; }
.tl-day { display: flex; gap: 14px; }

/* 日期头（可点击折叠，含向下连接线；线条为实色主题色，无透明度） */
.tl-date {
  flex: none; width: 150px; padding: 12px 0 0; cursor: pointer; user-select: none;
  display: flex; align-items: flex-start; justify-content: flex-end; gap: 8px;
  text-align: left; font-family: inherit; background: none; border: none; position: relative;
}
.tl-date::before {
  content: ''; position: absolute; left: 158px; top: 12px; height: 14px; width: 2px;
  background: var(--el-color-primary, #409eff); z-index: 0;
}
.tl-date.collapsed::before { display: none; }
.tl-date-num { font-size: 22px; font-weight: 700; line-height: 1; color: var(--el-color-primary, #409eff); }
.tl-date-rest { text-align: left; }
.tl-date-ym { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.tl-date-wd { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-top: 2px; }
.caret {
  flex: none; margin-top: 2px; color: var(--el-color-primary, #409eff);
  transition: transform .18s;
}
.tl-date.collapsed .caret { transform: rotate(-90deg); }

/* 卡片列：每条卡片自带左侧实色竖线 + 圆点（折叠时随卡片隐藏，线自然断开） */
.tl-cards {
  flex: 1; min-width: 0; display: flex; flex-direction: column;
  padding: 6px 0 16px 18px; position: relative;
}
.tl-card {
  position: relative; display: flex; align-items: center; gap: 10px; padding: 7px 12px;
  text-align: left; cursor: pointer; font-family: inherit;
  background: var(--el-bg-color, #fff);
  border: 1px solid var(--el-border-color-lighter, #ebeef5);
  border-radius: 8px; box-sizing: border-box;
  transition: border-color .15s, transform .15s;
}
.tl-card::before {
  content: ''; position: absolute; left: -18px; top: 0; bottom: -6px; width: 2px;
  background: var(--el-color-primary, #409eff); z-index: 0;
}
.tl-card:last-child::before { bottom: auto; height: 50%; }
.tl-card:hover { border-color: var(--el-color-primary, #409eff); transform: translateX(2px); }
.tl-dot {
  position: absolute; left: -22px; top: 50%; margin-top: -5px;
  width: 10px; height: 10px; border-radius: 50%;
  background: var(--el-color-primary, #409eff); z-index: 1;
}
.tl-ico { font-size: 14px; flex: none; }
.tl-name {
  flex: 1; min-width: 0; font-size: 13px; color: var(--el-text-color-primary, #1f2937);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.tl-time { flex: none; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.tl-empty { color: var(--el-text-color-secondary, #9ca3af); text-align: center; padding: 40px 0; font-size: 13px; }
</style>
