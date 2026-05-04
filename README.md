# FitSync

> Updated: 2026-05-03. FitLog iOS / SwiftUI 同步版工程入口；网页版 PWA 见 `apps/Fit_log/`。

## 读前判断

应该读本文件：
- 需要运行、理解或维护 FitLog iOS 版。
- 需要处理 SwiftUI 训练记录、HealthKit 同步、Live Activity、GitHub 同步链路。
- 用户说“FitLog iOS 版”“FitSync”“原生训练记录”。

不归本文件管：
- FitLog 网页版 / PWA → `apps/Fit_log/README.md`。
- 生活侧训练计划、训练复盘和健康档案 → `My_life/fitness/INDEX.md`。
- 具体审查历史 → `REVIEW_LOG.md`。

## 项目概览

FitSync 是 FitLog 的 iOS 原生实现，目标是在手机训练场景中获得比 PWA 更稳定的本地体验，并补上 HealthKit 和 Live Activity 能力。

核心链路：
1. 从 GitHub 拉取 `My_life/fitness/exchange/outbox/` 中的训练计划。
2. 训练中记录动作、组数、重量、次数、RPE、有氧、热身/拉伸和随笔。
3. 结束后生成 `my_life.fitness.result` 训练结果 JSON。
4. 推送到 `My_life/fitness/exchange/inbox/`。
5. 可同步 HealthKit 指标，生成与 `My_life/scripts/fitness/merge_sync.py` 对齐的健康数据 payload。

## 技术栈

| 层 | 选择 | 说明 |
|---|---|---|
| 客户端 | SwiftUI | 主 App 位于 `FitSync/` |
| 健康数据 | HealthKit | 心率、睡眠、步数、训练等指标 |
| 同步 | GitHub Contents API | 计划拉取、结果上传、历史同步 |
| 密钥 | Keychain | GitHub token 等敏感配置 |
| 本地状态 | Swift Observation / Codable 持久化 | 训练草稿、历史和设置 |
| 小组件 | Widget / ActivityKit | `FitSyncWidget/`，用于训练计时等实时状态 |

## 目录结构

| 路径 | 职责 |
|---|---|
| `FitSync.xcodeproj/` | Xcode 项目 |
| `FitSync/FitSyncApp.swift` | App 入口 |
| `FitSync/Models/` | 训练计划、训练结果、健康同步 payload、训练状态模型 |
| `FitSync/Services/` | GitHub、HealthKit、Live Activity、本地存储服务 |
| `FitSync/ViewModels/` | 首页和同步视图状态 |
| `FitSync/Views/Workout/` | 训练流程视图 |
| `FitSync/Views/Health/` | 健康数据同步视图 |
| `FitSync/Views/Settings/` | 设置页 |
| `FitSyncWidget/` | Widget / Live Activity 相关代码 |
| `REVIEW_LOG.md` | 关键流程审查和修复记录 |

## 数据契约

训练结果：
- schema: `my_life.fitness.result`
- 默认目标：`fitness/exchange/inbox`
- 关键字段在 `FitSync/Models/ResultModels.swift`。

健康同步：
- payload 字段需严格对齐 `My_life/scripts/fitness/merge_sync.py` 的 `METRIC_MAP`。
- 关键结构在 `FitSync/Models/SyncPayload.swift`。
- 字段名、单位和日期粒度变更时，必须同步检查生活仓库的合并脚本和 fitness 索引。

权威边界：
- App 是采集和同步工具，不是长期健康结论源。
- 长期训练计划、训练复盘、健康指标解释归 `My_life/fitness/`。

## 常用操作

```text
用 Xcode 打开 FitSync.xcodeproj
选择 FitSync target
连接 iPhone 或选择模拟器
Run
```

说明：
- HealthKit 能力需要真机和权限授权；模拟器只能覆盖部分 UI 流程。
- 涉及 Live Activity / Widget 时，需要同时检查主 App 和 `FitSyncWidget/`。

## 维护规则

- 任何训练结果字段变更，都要同时检查 `apps/Fit_log` 的同名契约，避免 Web / iOS 双轨分裂。
- 任何健康同步字段变更，都要同步检查 `My_life/scripts/fitness/merge_sync.py`。
- GitHub token 和其他敏感配置只应保存在 Keychain 或本机设置中，不写入仓库。
- 若新增长期文档超过 3 篇，再建立 `docs/INDEX.md`；当前不预建空 docs 目录。
