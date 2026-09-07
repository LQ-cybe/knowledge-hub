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
        <!-- 日期节点 -->
        <div class="tl-day">
          <div class="tl-date">
            <div class="tl-date-num">{{ g.date.slice(8) }}</div>
            <div class="tl-date-rest">
              <div class="tl-date-ym">{{ g.date }}</div>
              <div class="tl-date-wd">{{ g.weekday }} · {{ g.list.length }} 项</div>
            </div>
          </div>
          <div class="tl-line"></div>
          <div class="tl-cards">
            <button
              v-for="r in g.list" :key="r.id"
              class="tl-card" :title="r.path"
              @click="emit('open-resource', r.parent_id)"
            >
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
.tl { padding: 8px 20px 20px; display: flex; flex-direction: column; gap: 12px; }
.tl-head { display: flex; align-items: center; gap: 14px; }
.tl-title { font-size: 15px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.tl-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }

.tl-body { display: flex; flex-direction: column; }
.tl-day { display: flex; gap: 14px; }
.tl-date {
  flex: none; width: 120px; padding-top: 10px; text-align: right;
  display: flex; align-items: flex-start; justify-content: flex-end; gap: 8px;
}
.tl-date-num { font-size: 22px; font-weight: 700; line-height: 1; color: var(--el-color-primary, #409eff); }
.tl-date-rest { text-align: left; }
.tl-date-ym { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.tl-date-wd { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-top: 2px; }

.tl-line {
  flex: none; width: 2px; margin: 0 8px;
  background: linear-gradient(180deg, var(--el-color-primary, #409eff) 0%, transparent 100%);
  opacity: .35; position: relative;
}
.tl-line::before {
  content: ''; position: absolute; top: 12px; left: -4px;
  width: 10px; height: 10px; border-radius: 50%;
  background: var(--el-color-primary, #409eff);
}

.tl-cards {
  flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px;
  padding: 6px 0 16px;
}
.tl-card {
  display: flex; align-items: center; gap: 10px; padding: 7px 12px;
  text-align: left; cursor: pointer; font-family: inherit;
  background: var(--el-bg-color, #fff);
  border: 1px solid var(--el-border-color-lighter, #ebeef5);
  border-radius: 8px; box-sizing: border-box;
  transition: border-color .15s, transform .15s;
}
.tl-card:hover { border-color: var(--el-color-primary, #409eff); transform: translateX(2px); }
.tl-ico { font-size: 14px; flex: none; }
.tl-name {
  flex: 1; min-width: 0; font-size: 13px; color: var(--el-text-color-primary, #1f2937);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.tl-time { flex: none; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.tl-empty { color: var(--el-text-color-secondary, #9ca3af); text-align: center; padding: 40px 0; font-size: 13px; }
</style>
