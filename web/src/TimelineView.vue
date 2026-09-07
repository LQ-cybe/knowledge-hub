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

/** 日期折叠状态（持久化到 sessionStorage，跨重渲染保持）；折叠只隐藏卡片，时间线贯穿不受影响 */
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
}
onMounted(load);

function fmtHM(s: string) {
  if (!s) return '';
  const d = new Date(s.replace(' ', 'T'));
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function fmtBytes(b?: number | null) {
  if (!b) return '';
  if (b >= 1 << 20) return (b / (1 << 20)).toFixed(1) + ' MB';
  if (b >= 1 << 10) return (b / (1 << 10)).toFixed(1) + ' KB';
  return b + ' B';
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
        <!-- 日期行：单独一行（数字+日期+星期·项数），箭头常驻并在线 X 上 -->
        <div class="tl-day">
          <button
            class="tl-date" :class="{ collapsed: isCollapsed(g.date) }"
            :aria-expanded="String(!isCollapsed(g.date))"
            @click="toggleDay(g.date)"
          >
            <span class="tl-date-num">{{ g.date.slice(8) }}</span>
            <span class="tl-date-rest">
              <span class="tl-date-ym">{{ g.date }}</span>
              <span class="tl-date-wd">{{ g.weekday }} · {{ g.list.length }} 项</span>
            </span>
            <svg class="caret" width="14" height="14" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M6 9l6 6 6-6" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </button>
          <!-- 卡片列表：位于日期行下方，圆点中心与时间线精确对齐 -->
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
              <span v-if="r.tag_names" class="tl-tags" :title="r.tag_names">{{ r.tag_names }}</span>
              <span v-if="r.size" class="tl-size">{{ fmtBytes(r.size) }}</span>
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
/* 容器直接滚动；.tl-body 高度=内容高度（不能 flex:1 限高，否则线只画到视口底、滚动后下方无线） */
.tl { padding: 0 20px 20px; height: 100%; box-sizing: border-box; overflow-y: auto; }

/* 筛选行固定冻结在顶部 */
.tl-head {
  position: sticky; top: 0; z-index: 6;
  display: flex; align-items: center; gap: 14px;
  padding: 10px 0 8px;
  background: var(--el-bg-color-page, #f5f7fa);
}
.tl-title { font-size: 15px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.tl-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }

/* 贯穿时间线：线左缘 = --line-x（中心 = --line-x + 1），贯穿全部内容高度 */
.tl-body { position: relative; --line-x: 150px; }
.tl-body::before {
  content: ''; position: absolute; left: var(--line-x); top: 0; bottom: 0;
  width: 2px; background: var(--el-color-primary, #409eff); z-index: 0;
}

/* 日期行：单独一行。箭头常驻，中心 = 线中心（--line-x + 1），带底色圆避免与线重叠 */
.tl-date {
  position: relative; display: flex; align-items: flex-start; gap: 10px;
  padding: 16px 0 8px; cursor: pointer; user-select: none; width: 100%;
  text-align: left; font-family: inherit; background: none; border: none;
}
.tl-date-num {
  flex: none; width: 56px; font-size: 24px; font-weight: 700; line-height: 1;
  color: var(--el-color-primary, #409eff); text-align: right; padding-right: 10px;
}
.tl-date-rest { flex: none; }
.tl-date-ym { display: block; font-size: 13px; font-weight: 500; color: var(--el-text-color-primary, #1f2937); }
.tl-date-wd { display: block; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-top: 2px; }
.caret {
  position: absolute; left: calc(var(--line-x) - 6px); top: 16px;
  color: var(--el-color-primary, #409eff); transition: transform .18s; z-index: 2;
  background: var(--el-bg-color-page, #f5f7fa); border-radius: 50%;
  box-sizing: border-box; padding: 1px;
}
.tl-date.collapsed .caret { transform: rotate(-90deg); }

/* 卡片列表：卡片左缘 = --line-x + 14；圆点 box-sizing:border-box 使盒宽=9px，
   中心 = 卡片左缘 - 17.5 + 4.5 = 线中心（数学精确，无像素偏差） */
.tl-cards { padding: 0 0 14px calc(var(--line-x) + 14px); }
.tl-card {
  position: relative; display: flex; align-items: center; gap: 8px;
  padding: 5px 10px; margin: 1px 0; border-radius: 6px; width: 100%;
  text-align: left; cursor: pointer; font-family: inherit; box-sizing: border-box;
  background: none; border: none; transition: background .12s;
}
.tl-card:hover { background: var(--el-fill-color-light, #f5f7fa); }
.tl-dot {
  position: absolute; left: -17.5px; top: 50%; margin-top: -4.5px;
  width: 9px; height: 9px; border-radius: 50%;
  background: var(--el-color-primary, #409eff);
  border: 2px solid var(--el-bg-color, #fff);
  box-shadow: 0 0 0 1px var(--el-border-color, #e5e7eb);
  box-sizing: border-box; z-index: 1;
}
.tl-ico { font-size: 14px; flex: none; }
.tl-name {
  flex: 0 1 auto; min-width: 0; font-size: 13px; color: var(--el-text-color-primary, #1f2937);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.tl-tags {
  flex: 1; min-width: 0; font-size: 11px; color: var(--el-color-primary, #409eff);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-align: left;
}
.tl-size { flex: none; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.tl-time { flex: none; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.tl-empty { color: var(--el-text-color-secondary, #9ca3af); text-align: center; padding: 40px 0; font-size: 13px; }
</style>
