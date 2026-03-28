# Fit_sync 审查日志

## 流程追踪状态
- [x] 训练记录全链路（开始→记录→结束→保存+推送）— 2026-03-28 通过（修复 #1 后）
- [x] 草稿持久化与恢复 — 2026-03-28 通过（修复 #1 后）
- [x] GitHub 同步（上传/自动拉取/手动拉取）— 2026-03-28 通过（修复 #2 后）
- [x] HealthKit 数据同步 — 2026-03-28 通过
- [x] 计划获取流程 — 2026-03-28 通过
- [x] 动作详情流（导航/记录组/休息计时器/切换）— 2026-03-28 通过

## 发现记录
| # | 日期 | 问题 | 严重性 | 状态 |
|---|------|------|--------|------|
| 1 | 2026-03-28 | updateCardio/updateExerciseNotes/toggleWarmup/toggleCooldown 不持久化草稿，force-kill 丢数据 | 🚫 Important | ✅ 已修复 |
| 2 | 2026-03-28 | syncInboxResults 用 date-only 快捷过滤，跳过同日第二次训练 | 🚫 Important | ✅ 已修复 |

## 修复详情
### #1 草稿持久化
- **修复**：在 `updateCardio`、`updateExerciseNotes`、`toggleWarmup`、`toggleCooldown` 末尾加 `scheduleDraftSave()`
- **文件**：`FitSync/Models/WorkoutState.swift`
- **验证**：四个方法现在都触发 2 秒 debounce 存盘，与 `completeSet`/`startSet` 等行为一致

### #2 自动同步去重
- **修复**：移除 date-only `hasLocal` 快捷过滤，改用 `var localIds` composite key（`date|start_time`），循环内同步 `insert` 防同批重复
- **文件**：`FitSync/ViewModels/HomeViewModel.swift`
- **验证**：现在与 `WorkoutHistoryView.syncFromGitHub` 行为一致

## 上线就绪判定
- [x] 关键流程全部追踪通过
- [x] 0 条 🚫 未修复
- [x] 修复后验证通过（第 3 轮独立确认无新发现 2026-03-28）
