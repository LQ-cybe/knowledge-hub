<script setup lang="ts">
// 只读标签展示：虚线矩形占位 + 椭圆标签。整块点击 → emit('open')，由父级打开「加标签/打标」弹窗。
// 取代旧 TagSelect 的 popover 浮层触发器。
const props = defineProps<{ names: string[]; placeholder?: string }>();
const emit = defineEmits<{ (e: 'open'): void }>();
</script>

<template>
  <!-- 有标签：无外框，仅椭圆标签（可点击）＋省略箭头；无标签：虚线占位框 -->
  <div class="tc-wrap" :class="{ 'tc-filled': names.length > 0 }" title="点击管理标签" @click.stop="emit('open')">
    <span v-if="names.length === 0" class="tc-ph">{{ placeholder || '加标签' }}</span>
    <span v-for="(n, i) in names" :key="i" class="tc-chip" :title="n">{{ n }}</span>
  </div>
</template>

<style scoped>
.tc-wrap {
  display: inline-flex; align-items: center; gap: 4px; flex-wrap: wrap;
  max-width: 100%; min-height: 22px;
  border: 1px dashed var(--el-border-color, #dcdfe6);
  border-radius: 6px; cursor: pointer; padding: 1px 6px;
}
.tc-wrap:hover { border-color: var(--el-color-primary, #409eff); }
/* 有标签：去掉虚线外框 */
.tc-filled { border: none; padding: 0; }
.tc-chip {
  font-size: 11px; padding: 0 8px; line-height: 1.6; border-radius: 10px;
  background: var(--el-color-primary-light-9, #ecf5ff);
  color: var(--el-color-primary, #409eff); border: 1px solid var(--el-color-primary-light-5, #b3d8ff);
  white-space: nowrap;
}
.tc-ph { font-size: 12px; color: var(--el-text-color-secondary, #909399); }
</style>
