# ScreenGuardian — 详细设计文档（V1.0.7）

> **产品名称：** ScreenGuardian（屏幕守护者）
> **版本：** V1.0.7
> **开发者：** TimberTrail
> **设计日期：** 2026-07-09
> **更新日期：** 2026-08-01
> **授权：** 免费使用

---

## 目录

- [第一部分：总体架构](#第一部分总体架构)
  - [1.1 产品概述与设计目标](#11-产品概述与设计目标)
  - [1.2 平台与技术选型](#12-平台与技术选型)
  - [1.3 系统总体架构图](#13-系统总体架构图)
  - [1.4 模块划分与依赖关系](#14-模块划分与依赖关系)
- [第二部分：数据模型与存储](#第二部分数据模型与存储)
  - [2.1 数据实体总览](#21-数据实体总览)
  - [2.2 ScreenSession 实体详细定义](#22-screensession-实体详细定义)
  - [2.3 DailySummary 实体详细定义](#23-dailysummary-实体详细定义)
  - [2.4 WeeklyPlan 实体详细定义](#24-weeklyplan-实体详细定义)
  - [2.5 DeviceInfo 实体详细定义](#25-deviceinfo-实体详细定义)
  - [2.6 AppConfig 实体详细定义](#26-appconfig-实体详细定义)
  - [2.7 LLMRankingRecord 实体详细定义](#27-llmrankingrecord-实体详细定义)
  - [2.8 SyncMeta 实体详细定义](#28-syncmeta-实体详细定义)
  - [2.9 本地存储方案](#29-本地存储方案)
  - [~~2.10 网盘同步文件格式与目录结构~~（已移除）](#210-网盘同步文件格式与目录结构已移除)
- [第三部分：核心模块详细设计](#第三部分核心模块详细设计)
  - [3.1 模块 M1 — 系统启动与常驻](#31-模块-m1--系统启动与常驻)
  - [3.2 模块 M2 — 屏幕状态检测](#32-模块-m2--屏幕状态检测)
  - [3.3 模块 M3 — 屏幕用时记录引擎](#33-模块-m3--屏幕用时记录引擎)
  - [3.4 模块 M4 — 用眼休息提醒（20-20-20）](#34-模块-m4--用眼休息提醒20-20-20)
  - [~~3.5 模块 M5 — 姿势切换提醒~~（已合并至 M4）](#35-模块-m5--姿势切换提醒已合并至-m4)
  - [3.6 模块 M6 — 菜单系统](#36-模块-m6--菜单系统)
  - [3.7 模块 M7 — 报告引擎](#37-模块-m7--报告引擎)
  - [3.8 模块 M8 — 设置管理](#38-模块-m8--设置管理)
  - [3.9 模块 M9 — 多设备数据同步](#39-模块-m9--多设备数据同步)
  - [3.10 模块 M10 — 每周用时总结](#310-模块-m10--每周用时总结)
  - [3.11 模块 M11 — 超时提醒](#311-模块-m11--超时提醒)
  - [3.12 模块 M12 — LLM Ranking 跟踪](#312-模块-m12--llm-ranking-跟踪)
- [第四部分：界面与交互设计](#第四部分界面与交互设计)
  - [4.1 设计规范](#41-设计规范)
  - [4.2 桌面端界面线框图](#42-桌面端界面线框图)
  - [4.3 移动端界面线框图](#43-移动端界面线框图)
  - [4.4 弹窗交互规范](#44-弹窗交互规范)
- [第五部分：国际化](#第五部分国际化)
- [第六部分：异常与边界处理](#第六部分异常与边界处理)
- [第七部分：性能指标与约束](#第七部分性能指标与约束)
- [第八部分：开发里程碑与验收标准](#第八部分开发里程碑与验收标准)
- [附录](#附录)

---

# 第一部分：总体架构

## 1.1 产品概述与设计目标

### 产品定义

ScreenGuardian 是一款跨平台屏幕用时管理工具，覆盖 Windows PC、MacBook、Android 手机、Android Pad、iPhone、iPad 六类设备。核心目标是帮助用户精确追踪屏幕使用时间、定时健康提醒、跨设备数据汇聚、以及用时计划管理。

### 设计目标

| 目标 | 说明 |
|------|------|
| **精确性** | 屏幕用时记录误差 < 1 秒，状态切换延迟 < 500ms |
| **可靠性** | 应用崩溃不丢数据，每次状态变更立即持久化 |
| **跨设备一致性** | 所有设备共享同一份数据，同步延迟 < 30 秒 |
| **低资源占用** | 后台驻留时 CPU < 1%，内存 < 100MB（桌面）/ 50MB（移动） |
| **无感运行** | 用户无需主动操作，自动记录、自动提醒 |
| **隐私安全** | 所有数据仅存储在用户本地设备，通过 P2P 局域网加密同步，不使用任何云服务、不上传任何第三方服务器 |

---

## 1.2 平台与技术选型

### 选型矩阵

| 维度 | Windows | macOS | Android | iOS |
|------|---------|-------|---------|-----|
| **框架** | Electron 28+ | Electron 28+ | Flutter 3.x | Flutter 3.x |
| **语言** | TypeScript + Node.js | TypeScript + Node.js | Dart + Kotlin | Dart + Swift |
| **UI 层** | HTML/CSS/JS | HTML/CSS/JS | Flutter Widget | Flutter Widget |
| **原生能力** | node-ffi / native addon | node-ffi / native addon | Platform Channel | Platform Channel |
| **打包** | electron-builder (.exe/.msi) | electron-builder (.dmg) | Flutter build (.apk/.aab) | Flutter build (.ipa) |
| **自启动** | 注册表 Run Key | Login Items / launchd | Boot Broadcast + Service | 无（用户手动） |
| **屏幕检测** | WM_POWERBROADCAST + SessionSwitch | NSWorkspace + CGSession | BroadcastReceiver | **ScreenTime API (DeviceActivityMonitor)** |
| **托盘/驻留** | 系统托盘（Tray） | 菜单栏（NSStatusItem） | Foreground Service + 通知 | Live Activity |

> **V1.0.7 变更**：iOS 改用 ScreenTime API（DeviceActivityMonitor Extension），由系统管理扩展生命周期，无需自启动，不会被杀。需要 Family Controls 授权。

### 为什么不统一框架

桌面端需要系统托盘、菜单栏驻留、屏幕锁定事件等深度原生集成，Electron 在此方面成熟稳定。移动端 Flutter 性能好、跨平台效率高。两者业务逻辑层通过统一的数据格式和状态机规范对齐，代码独立但行为一致。

---

## 1.3 系统总体架构图

```
┌──────────────────────────────────────────────────────────────────────┐
│                          用户设备层                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                │
│  │ Windows  │ │  macOS   │ │ Android  │ │   iOS    │                │
│  │  PC      │ │ MacBook  │ │ 手机/Pad │ │ iPhone/  │                │
│  │          │ │          │ │          │ │ iPad     │                │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘                │
│       │             │            │             │                     │
│  ┌────▼─────────────▼──┐   ┌────▼─────────────▼──┐                  │
│  │   Electron 桌面端    │   │   Flutter 移动端     │                  │
│  │ ┌─────────────────┐ │   │ ┌─────────────────┐ │                  │
│  │ │   UI 渲染层     │ │   │ │  Flutter Widget │ │                  │
│  │ │ (HTML/CSS/JS)   │ │   │ │   (Dart UI)     │ │                  │
│  │ └────────┬────────┘ │   │ └────────┬────────┘ │                  │
│  │ ┌────────▼────────┐ │   │ ┌────────▼────────┐ │                  │
│  │ │  业务逻辑层     │ │   │ │  业务逻辑层     │ │                  │
│  │ │  (TypeScript)   │ │   │ │   (Dart)        │ │                  │
│  │ │ ┌─────────────┐ │ │   │ │ ┌─────────────┐ │ │                  │
│  │ │ │SessionMgr   │ │ │   │ │ │SessionMgr   │ │ │                  │
│  │ │ │P2PSync      │ │ │   │ │ │P2PSync      │ │ │                  │
│  │ │ │ReportEngine  │ │ │   │ │ │ReportEngine  │ │ │                  │
│  │ │ │ReminderMgr   │ │ │   │ │ │ReminderMgr   │ │ │                  │
│  │ │ └─────────────┘ │ │   │ │ └─────────────┘ │ │                  │
│  │ └────────┬────────┘ │   │ └────────┬────────┘ │                  │
│  │ ┌────────▼────────┐ │   │ ┌────────▼────────┐ │                  │
│  │ │  平台适配层     │ │   │ │  平台适配层     │ │                  │
│  │ │ (Native Module) │ │   │ │(Platform Channel│ │                  │
│  │ │ ┌────┐ ┌────┐  │ │   │ │ ┌────┐ ┌────┐  │ │                  │
│  │ │ │Win │ │Mac │  │ │   │ │ │And │ │iOS │  │ │                  │
│  │ │ └────┘ └────┘  │ │   │ │ └────┘ └────┘  │ │                  │
│  │ └─────────────────┘ │   │ └─────────────────┘ │                  │
│  └──────────────────────┘   └──────────────────────┘                  │
│           │                            │                              │
│           └──────────┬─────────────────┘                              │
│               ┌──────▼──────┐                                         │
│               │  本地存储    │                                         │
│               │ (JSON 文件)  │                                         │
│               └──────┬──────┘                                         │
│               ┌──────▼──────┐                                         │
│               │  P2P 同步   │  ← mDNS 发现 + HTTP 交换 + 加密         │
│               │(局域网直连)  │  ← 无云服务、无第三方服务器               │
│               └─────────────┘                                         │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1.4 模块划分与依赖关系

### 模块清单

| 模块 ID | 模块名称 | 优先级 | 依赖 |
|---------|---------|--------|------|
| M1 | 系统启动与常驻 | P0 | — |
| M2 | 屏幕状态检测 | P0 | M1 |
| M3 | 屏幕用时记录引擎 | P0 | M2 |
| M4 | 用眼休息 + 姿势切换提醒（合并） | P0 | M3 |
| M6 | 菜单系统 | P0 | M1 |
| M7 | 报告引擎 | P1 | M3 |
| M8 | 设置管理 | P0 | — |
| M9 | 多设备数据同步（P2P mDNS） | P1 | M3, M8 |
| M10 | 每周用时总结 | P1 | M3, M9 |
| M11 | 超时提醒 | P1 | M3, M10 |
| M12 | LLM Ranking 跟踪 | P2 | M8, M9 |

### 依赖关系图

```
M1 (启动常驻) ──→ M2 (屏幕检测) ──→ M3 (记录引擎) ──→ M4 (用眼休息 + 姿势切换)
                    │                   │                M7 (报告引擎)
                    │                   │                M11 (超时提醒)
                    │                   │
                    │                   └──→ M9 (P2P 同步) ──→ M10 (周总结)
                    │                                       M12 (LLM Ranking)
                    │
                    └──→ M6 (菜单系统)

M8 (设置管理) ──→ M4, M9, M12 (各模块读取设置)
```

---

# 第二部分：数据模型与存储

## 2.1 数据实体总览

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ScreenSession│────→│DailySummary │←────│ WeeklyPlan  │
│ (1:N 关系)  │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       │ deviceId
       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ DeviceInfo  │     │ AppConfig   │     │ SyncMeta    │
│             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘

┌─────────────────┐
│LLMRankingRecord │ (独立实体，按周归档)
└─────────────────┘
```

---

## 2.2 ScreenSession 实体详细定义

**实体描述**：一条屏幕使用记录，代表一次从"屏幕打开"到"屏幕关闭/中断"的完整使用会话。

### 字段定义

| 字段名 | 类型 | 必填 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| `id` | string | ✅ | 自动生成 | UUID v4 格式，全局唯一 | 记录唯一标识 |
| `deviceId` | string | ✅ | 自动填充 | 长度 36 字符 | 创建该记录的设备 ID |
| `deviceName` | string | ✅ | 自动填充 | 长度 1~50 字符 | 设备显示名称 |
| `platform` | enum | ✅ | 自动填充 | 枚举值见下方 | 设备平台类型 |
| `startTime` | ISO 8601 | ✅ | — | 必须早于 endTime | 屏幕打开时间 |
| `endTime` | ISO 8601 | ❌ | null | 必须晚于 startTime | 屏幕关闭时间，null 表示正在使用中 |
| `durationSeconds` | integer | ❌ | null | ≥ 0 | 使用时长（秒），endTime 存在时自动计算 |
| `stopReason` | enum | ❌ | null | 枚举值见下方 | 停止原因 |
| `date` | string | ✅ | 自动填充 | 格式 YYYY-MM-DD，本地时区 | 所属日期 |
| `createdAt` | ISO 8601 | ✅ | 自动生成 | — | 记录创建时间 |
| `updatedAt` | ISO 8601 | ✅ | 自动更新 | — | 记录最后更新时间 |
| `version` | integer | ✅ | 1 | ≥ 1 | 乐观锁版本号，用于冲突检测 |

### platform 枚举

| 值 | 中文名 | 说明 |
|----|--------|------|
| `windows` | Windows PC | Windows 桌面电脑 |
| `macos` | MacBook | macOS 笔记本/台式 |
| `android_phone` | 安卓手机 | Android 手机设备 |
| `android_pad` | 安卓平板 | Android 平板设备 |
| `iphone` | 苹果手机 | iPhone 设备 |
| `ipad` | iPad | iPad 设备 |

### stopReason 枚举

| 值 | 中文名 | 英文名 | 触发场景 | 说明 |
|----|--------|--------|----------|------|
| `eye_rest` | 用眼休息 | Eye Rest | M4 定时器触发 | 20 分钟用眼休息提醒弹出 |
| `posture_change` | 姿势切换 | Posture Change | M5 定时器触发 | 姿势切换提醒弹出 |
| `lock_screen` | 锁屏 | Lock Screen | 用户锁屏 | Win+L / macOS 锁屏 / 手机锁屏 |
| `screensaver` | 屏保 | Screensaver | 系统屏保激活 | 仅桌面端 |
| `standby` | 待机/休眠 | Standby | 系统进入待机或休眠 | 系统电源状态变化 |
| `shutdown` | 关机 | Shutdown | 系统关机 | 应用收到关机信号 |
| `user_exit` | 用户退出 | User Exit | 用户点击退出菜单 | 应用正常退出 |
| `meeting_override` | 会议模式关闭 | Meeting Override | 会议模式下手动关闭提醒 | 用户在会议模式下手动关闭弹窗 |

### JSON 示例

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "deviceId": "dev-001-windows-xyz",
  "deviceName": "张三的工作电脑",
  "platform": "windows",
  "startTime": "2026-07-01T09:15:30.000+08:00",
  "endTime": "2026-07-01T09:35:30.000+08:00",
  "durationSeconds": 1200,
  "stopReason": "eye_rest",
  "date": "2026-07-01",
  "createdAt": "2026-07-01T09:15:30.000+08:00",
  "updatedAt": "2026-07-01T09:35:30.000+08:00",
  "version": 2
}
```

---

## 2.3 DailySummary 实体详细定义

**实体描述**：某一天的屏幕使用汇总数据，由 ScreenSession 记录聚合生成。

### 字段定义

| 字段名 | 类型 | 必填 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| `date` | string | ✅ | — | 格式 YYYY-MM-DD，主键 | 日期 |
| `totalSeconds` | integer | ✅ | 0 | ≥ 0 | 当日总屏幕用时（秒） |
| `sessionCount` | integer | ✅ | 0 | ≥ 0 | 当日会话数量 |
| `devices` | string[] | ✅ | [] | 数组长度 ≥ 0 | 涉及的设备 ID 列表 及其对应屏幕使用时间|
| `firstSessionStart` | ISO 8601 | ❌ | null | — | 当日第一次使用开始时间 |
| `lastSessionEnd` | ISO 8601 | ❌ | null | — | 当日最后一次使用结束时间 |
| `sessionIds` | string[] | ✅ | [] | 数组长度 ≥ 0 | 当日所有 Session ID 列表 |
| `updatedAt` | ISO 8601 | ✅ | 自动更新 | — | 最后更新时间 |

### 聚合计算规则

```
// 1. 收集当日所有已完成 session 的时间段 [(startTime, endTime), ...]
// 2. 对时间段做区间合并去重（合并重叠时段，避免多设备同时使用时重复统计）
// 3. 计算合并后的总秒数
totalSeconds = MERGED_DURATION(sessions WHERE date=this.date AND endTime!=null)

sessionCount = COUNT(sessions) WHERE session.date = this.date
devices = DISTINCT(session.deviceId) WHERE session.date = this.date
firstSessionStart = MIN(session.startTime) WHERE session.date = this.date
lastSessionEnd = MAX(session.endTime) WHERE session.date = this.date AND session.endTime != null
```

### 跨设备时间去重算法

当多台设备同时使用时（如手机 9:00-10:00 + 电脑 9:00-10:00），`totalSeconds` 应为 1 小时而非 2 小时。

算法：区间合并（Interval Merge）

```
输入: [(9:00, 10:00), (9:00, 10:00), (10:30, 11:00), (10:45, 11:30)]
         ↑ 手机       ↑ 电脑       ↑ 手机        ↑ 电脑

1. 按 startTime 排序
2. 遍历区间，若当前 start <= 上一个 end，则合并（取 max end）
3. 否则开启新区间

输出: [(9:00, 10:00), (10:30, 11:30)]
总用时: 1h + 1h = 2h（而非 3.25h）
```

### JSON 示例

```json
{
  "date": "2026-07-01",
  "totalSeconds": 29700,
  "sessionCount": 15,
  "devices": ["dev-001-windows-xyz, 3 hours 35 minutes", "dev-002-iphone-abc, 2 hours 25 minutes"],
  "firstSessionStart": "2026-07-01T08:30:00.000+08:00",
  "lastSessionEnd": "2026-07-01T18:45:00.000+08:00",
  "sessionIds": ["a1b2c3d4-...", "b2c3d4e5-...", "..."],
  "updatedAt": "2026-07-01T18:45:00.000+08:00"
}
```

---

## 2.4 WeeklyPlan 实体详细定义

**实体描述**：用户设定的每周屏幕使用计划。

### 字段定义

| 字段名 | 类型 | 必填 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| `weekStart` | string | ✅ | — | 格式 YYYY-MM-DD，周一日期，主键 | 本周起始日期（周一） |
| `plannedDailyMinutes` | integer | ✅ | — | 30 ~ 720（0.5~12 小时） | 每天计划用时（分钟） |
| `source` | enum | ✅ | — | `user_input` / `auto_from_last_week` | 计划来源 |
| `createdAt` | ISO 8601 | ✅ | 自动生成 | — | 创建时间 |

### source 枚举

| 值 | 说明 |
|----|------|
| `user_input` | 用户手动输入 |
| `auto_from_last_week` | 系统根据上周日均自动填入（用户未修改时） |

### JSON 示例

```json
{
  "weekStart": "2026-06-30",
  "plannedDailyMinutes": 450,
  "source": "user_input",
  "createdAt": "2026-06-30T09:00:00.000+08:00"
}
```

---

## 2.5 DeviceInfo 实体详细定义

**实体描述**：已注册设备的信息记录。

### 字段定义

| 字段名 | 类型 | 必填 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| `deviceId` | string | ✅ | 自动生成 | UUID v4，主键 | 设备唯一标识 |
| `deviceName` | string | ✅ | 系统默认 | 1~50 字符 | 用户可自定义的设备名称 |
| `platform` | enum | ✅ | 自动检测 | 同 ScreenSession.platform | 设备平台 |
| `registeredAt` | ISO 8601 | ✅ | 自动生成 | — | 首次注册时间 |
| `lastSyncAt` | ISO 8601 | ❌ | null | — | 最后同步时间 |
| `lastActiveAt` | ISO 8601 | ❌ | null | — | 最后活跃时间 |
| `appVersion` | string | ✅ | 自动填充 | 语义化版本号 | 应用版本 |

### 设备名称默认值规则

| 平台 | 默认名称格式 | 示例 |
|------|-------------|------|
| Windows | `{用户名}的Windows电脑` | 张三的Windows电脑 |
| macOS | `{用户名}的MacBook` | 张三的MacBook |
| Android Phone | `{用户名}的{品牌} {型号}` | 张三的Xiaomi 14 |
| Android Pad | `{用户名}的{品牌} {型号}` | 张三的Samsung Galaxy Tab S9 |
| iPhone | `{用户名}的iPhone` | 张三的iPhone |
| iPad | `{用户名}的iPad` | 张三的iPad |

### JSON 示例

```json
{
  "deviceId": "dev-001-windows-xyz",
  "deviceName": "张三的工作电脑",
  "platform": "windows",
  "registeredAt": "2026-07-01T08:00:00.000+08:00",
  "lastSyncAt": "2026-07-01T18:00:00.000+08:00",
  "lastActiveAt": "2026-07-01T18:45:00.000+08:00",
  "appVersion": "1.0.7"
}
```

---

## 2.6 AppConfig 实体详细定义

**实体描述**：应用全局配置，跨设备同步。

### 字段定义

| 字段名 | 类型 | 必填 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| `language` | enum | ✅ | `system` | `zh-CN` / `en` / `system` | 界面语言 |
| `trackingTargets` | string[] | ✅ | `["llm_ranking"]` | 数组，目前仅支持 `llm_ranking` | 跟踪对象列表 |
| `meetingMode` | boolean | ✅ | false | — | 会议模式开关 |
| `deviceName` | string | ❌ | null | 1~50 字符 | 当前设备名称（覆盖默认值） |
| `eyeRestEnabled` | boolean | ✅ | true | — | 用眼休息提醒开关（每 20 分钟） |
| `postureEnabled` | boolean | ✅ | true | — | 姿势切换提醒开关（每 40 分钟，与用眼休息合并） |
| `overtimeEnabled` | boolean | ✅ | true | — | 超时提醒开关 |
| `updatedAt` | ISO 8601 | ✅ | 自动更新 | — | 最后更新时间 |
| `updatedBy` | string | ✅ | 自动填充 | deviceId | 最后更新设备 |

> **V1.0.7 变更**：
> - 移除 `postureIntervalMinutes`：姿势切换间隔现在固定为用眼休息间隔的 2 倍（默认 40 分钟），无需用户配置。
> - 移除 `syncFolderPath`：网盘同步方案已移除，改用 P2P 局域网同步。

### language 枚举

| 值 | 说明 |
|----|------|
| `system` | 跟随系统语言 |
| `zh-CN` | 简体中文 |
| `en` | English |

### JSON 示例

```json
{
  "language": "zh-CN",
  "trackingTargets": ["llm_ranking"],
  "meetingMode": false,
  "deviceName": "张三的MacBook",
  "eyeRestEnabled": true,
  "postureEnabled": true,
  "overtimeEnabled": true,
  "updatedAt": "2026-07-01T09:00:00.000+08:00",
  "updatedBy": "dev-002-macos-abc"
}
```

---

## 2.7 LLMRankingRecord 实体详细定义

**实体描述**：LLM Ranking 数据记录，按周归档。

### 字段定义

| 字段名 | 类型 | 必填 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| `weekStart` | string | ✅ | — | 格式 YYYY-MM-DD，主键 | 数据所属周的周一日期 |
| `weekEnd` | string | ✅ | — | 格式 YYYY-MM-DD | 数据所属周的周日日期 |
| `fetchedAt` | ISO 8601 | ✅ | — | — | 数据获取时间 |
| `fetchedBy` | string | ✅ | — | deviceId | 获取数据的设备 |
| `source` | string | ✅ | — | URL | 数据来源 API |
| `data` | RankingEntry[] | ✅ | [] | 数组长度 > 0 | 排名数据条目数组 |

### RankingEntry 子对象

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `rank` | integer | ✅ | 排名序号 |
| `modelId` | string | ✅ | 模型标识（如 `anthropic/claude-3.5-sonnet`） |
| `modelName` | string | ✅ | 模型显示名称 |
| `provider` | string | ✅ | 提供商名称 |
| `score` | number | ✅ | 综合评分 |
| `contextLength` | integer | ❌ | 上下文长度 |
| `category` | string | ❌ | 分类标签 |

### JSON 示例

```json
{
  "weekStart": "2026-06-30",
  "weekEnd": "2026-07-06",
  "fetchedAt": "2026-07-01T09:00:00.000+08:00",
  "fetchedBy": "dev-001-windows-xyz",
  "source": "https://openrouter.ai/api/v1/rankings/overall",
  "data": [
    {
      "rank": 1,
      "modelId": "anthropic/claude-3.5-sonnet",
      "modelName": "Claude 3.5 Sonnet",
      "provider": "Anthropic",
      "score": 95.2,
      "contextLength": 200000,
      "category": "overall"
    }
  ]
}
```

---

## 2.8 SyncMeta 实体详细定义

**实体描述**：同步元数据，记录各设备的同步状态。

### 字段定义

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `lastGlobalSyncAt` | ISO 8601 | ✅ | 最后一次全局同步时间 |
| `devices` | object | ✅ | 各设备同步状态，key 为 deviceId |

### devices 子对象

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `lastSyncAt` | ISO 8601 | 该设备最后同步时间 |
| `lastSessionSynced` | string | 该设备最后同步的 session ID |
| `version` | integer | 该设备的数据版本号 |

### JSON 示例

```json
{
  "lastGlobalSyncAt": "2026-07-01T18:00:00.000+08:00",
  "devices": {
    "dev-001-windows-xyz": {
      "lastSyncAt": "2026-07-01T18:00:00.000+08:00",
      "lastSessionSynced": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "version": 42
    },
    "dev-002-macos-abc": {
      "lastSyncAt": "2026-07-01T17:55:00.000+08:00",
      "lastSessionSynced": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "version": 38
    }
  }
}
```

---

## 2.9 本地存储方案

### 桌面端（Electron）

**存储位置**：

| 平台 | 路径 |
|------|------|
| Windows | `{安装路径}` |
| macOS | `~/Library/Application Support/ScreenGuardian/` |

？？？目录改为 当前exe所在目录

**目录结构**：

```
ScreenGuardian/
├── config.json              # 本地配置（与网盘 config.json 同步）
├── device.json              # 当前设备信息（仅本地）
├── sessions/
│   ├── 2026-07.json         # 当月 Session 记录数组
│   ├── 2026-06.json         # 上月（归档）
├── summaries/
│   ├── 2026-07.json         # 当月 DailySummary 记录数组
├── plans/
│   └── weekly.json          # 周计划记录数组
├── tracking/
│   └── llm-ranking/
│       ├── 2026-W27.json    # 按周归档
│       └── 2026-W28.json
└── state.json               # 运行时状态（当前 Session、定时器状态等）
```

### 移动端（Flutter）

**存储位置**：

| 平台 | 路径 |
|------|------|
| Android | `/data/data/com.timbertrail.screenguardian/` |
| iOS | `{App沙箱}/Documents/ScreenGuardian/` |

？？？目录改为 app所在目录


**目录结构**：与桌面端一致。

### state.json 详细定义

**用途**：记录运行时状态，用于崩溃恢复。

```json
{
  "currentSessionId": "a1b2c3d4-...",  // 当前活跃 Session ID，null 表示无活跃 Session
  "eyeRestTimerRemainingMs": 840000,    // 用眼休息定时器剩余毫秒
  "postureTimerRemainingMs": 1500000,   // 姿势切换定时器剩余毫秒
  "lastScreenState": "active",          // 最后已知屏幕状态
  "meetingMode": false,                 // 当前会议模式状态
  "lastWeeklySummaryWeek": "2026-W26",  // 上次触发周总结的周
  "overtimeAlertedToday": false,        // 今天是否已触发超时提醒
  "lastOvertimeReminderAt": null        // 上次超时提醒时间
}
```

---

## ~~2.10 网盘同步文件格式与目录结构~~（已移除）

> **V1.0.7 变更**：网盘同步方案已完全移除。改用 P2P 局域网同步（mDNS 发现 + HTTP 数据交换），详见 [3.9 模块 M9](#39-模块-m9--多设备数据同步p2p-mdns)。
> 
> 所有数据仅存储在本地设备上，不依赖任何云服务。

---

# 第三部分：核心模块详细设计

## 3.1 模块 M1 — 系统启动与常驻

### 3.1.1 功能描述

应用在系统启动时自动启动，启动后驻留在后台（桌面端隐藏到系统托盘/菜单栏，移动端最小化）。

### 3.1.2 接口定义

#### I1.1 — 注册开机自启

```
接口名称：registerAutoStart()
参数：无
返回值：boolean（是否成功）
平台实现：
  - Windows：写入注册表 HKCU\Software\Microsoft\Windows\CurrentVersion\Run
    键名：ScreenGuardian
    键值："{安装路径}\ScreenGuardian.exe" --hidden
  - macOS：写入 ~/Library/LaunchAgents/com.timbertrail.screenguardian.plist
    或使用 SMLoginItemSetEnabled
  - Android：AndroidManifest.xml 注册 RECEIVE_BOOT_COMPLETED + 启动 Foreground Service
  - iOS：无法实现，引导用户手动开启"后台 App 刷新"
```

#### I1.2 — 启动并隐藏

```
接口名称：startHidden()
参数：无
返回值：无
平台实现：
  - Windows：
    1. 创建主窗口但不显示（show: false）
    2. 创建系统托盘图标（Tray）
    3. 托盘图标 tooltip："ScreenGuarding V1.1 — 运行中"
    4. 监听所有窗口关闭事件，阻止关闭（隐藏而非退出）
  - macOS：
    1. 创建主窗口但不显示
    2. 创建 NSStatusItem（菜单栏图标）
    3. 菜单栏图标 tooltip："ScreenGuardian V{version}"（从 package.json 读取）
    4. 设置 activationPolicy 为 accessory（不在 Dock 显示）
  - Android：
    1. 启动 Foreground Service
    2. 显示常驻通知："ScreenGuardian — 已运行 X 小时 X 分钟"
    3. 通知优先级：LOW（不发声）
  - iOS：
    1. App 进入后台
    2. 启动 Background App Refresh
    3. 可选：启动 Live Activity 显示当前用时
```

#### I1.3 — 获取启动状态

```
接口名称：isAutoStartEnabled()
参数：无
返回值：boolean
说明：检查当前是否已注册开机自启
```

#### I1.4 — 退出应用

```
接口名称：exitApplication()
参数：无
返回值：无
流程：
  1. 停止所有定时器
  2. 如果有活跃 Session，结束并保存
  3. 保存 state.json
  4. 触发一次数据同步
  5. 清理系统托盘/菜单栏图标
  6. 退出进程
```

### 3.1.3 状态机

```
┌─────────┐    启动     ┌──────────┐
│  未启动  │──────────→│  初始化中  │
└─────────┘           └────┬─────┘
                           │ 初始化完成
                    ┌──────▼──────┐
                    │   后台驻留   │←──────────────────┐
                    │ (隐藏运行)   │                    │
                    └──────┬──────┘                    │
                           │ 用户触发菜单               │
                    ┌──────▼──────┐                    │
                    │  界面显示中  │────────────────────┘
                    │ (弹窗/窗口)  │    关闭窗口/弹窗
                    └──────┬──────┘
                           │ 用户点击退出
                    ┌──────▼──────┐
                    │   退出中     │
                    └──────┬──────┘
                           │ 清理完成
                    ┌──────▼──────┐
                    │   已退出     │
                    └─────────────┘
```

### 3.1.4 异常处理

| 异常场景 | 处理方式 |
|----------|----------|
| 注册表/文件写入权限不足 | 提示用户以管理员身份运行，或引导手动设置开机自启 |
| 托盘图标创建失败 | 回退到显示主窗口 |
| 应用被强制杀死（Task Manager/kill -9） | 依赖 state.json 恢复，下次启动时检查并修复数据 |
| 多实例启动 | 使用单实例锁（app.requestSingleInstanceLock），新实例通知已有实例并退出 |

---

## 3.2 模块 M2 — 屏幕状态检测

### 3.2.1 功能描述

检测设备屏幕的打开/关闭/锁定/待机/屏保状态变化，产生状态事件供 M3 模块消费。

### 3.2.2 屏幕状态定义

| 状态 | 值 | 说明 | 是否计时 |
|------|----|------|----------|
| `ACTIVE` | `active` | 屏幕亮起且解锁，用户正在使用 | ✅ 计时 |
| `LOCKED` | `locked` | 屏幕锁定（Win+L / 手机锁屏） | ❌ 停止 |
| `SCREENSAVER` | `screensaver` | 系统屏保激活 | ❌ 停止 |
| `SLEEP` | `sleep` | 屏幕关闭/系统待机 | ❌ 停止 |
| `SHUTDOWN` | `shutdown` | 系统正在关机 | ❌ 停止 |

### 3.2.3 接口定义

#### I2.1 — 初始化屏幕检测器

```
接口名称：ScreenDetector.init()
参数：callback: (event: ScreenEvent) => void
返回值：void
说明：初始化平台特定的屏幕状态监听器，状态变化时调用 callback
```

#### I2.2 — 屏幕事件结构

```
ScreenEvent {
  type: 'state_change'
  fromState: ScreenState     // 变化前状态
  toState: ScreenState       // 变化后状态
  timestamp: ISO 8601        // 事件发生时间（系统时间）
  source: string             // 事件来源标识
}
```

#### I2.3 — 获取当前屏幕状态

```
接口名称：ScreenDetector.getCurrentState()
参数：无
返回值：ScreenState
说明：查询当前屏幕状态（用于崩溃恢复后重新同步）
```

### 3.2.4 各平台实现细节

#### Windows

```
事件源：
  1. WM_POWERBROADCAST 消息
     - PBT_APMSUSPEND → SLEEP（系统待机）
     - PBT_APMRESUMEAUTOMATIC → ACTIVE（系统唤醒）
     - PBT_APMRESUMESUSPEND → ACTIVE（系统恢复）
  2. SystemEvents.SessionSwitch
     - SessionLock → LOCKED
     - SessionUnlock → ACTIVE
  3. 屏保检测
     - SystemParametersInfo(SPI_GETSCREENSAVERRUNNING) 定时轮询（每 2 秒）
     - 或使用 WinEventHook 监听 EVENT_SYSTEM_SCREENSAVERSTART
  4. WM_SYSCOMMAND
     - SC_SCREENSAVE → SCREENSAVER

检测流程：
  ON WM_POWERBROADCAST:
    IF wParam == PBT_APMSUSPEND:
      emit(SCREEN_EVENT(SLEEP))
    IF wParam == PBT_APMRESUMEAUTOMATIC:
      emit(SCREEN_EVENT(ACTIVE))

  ON SessionSwitch:
    IF wParam == SessionLock:
      emit(SCREEN_EVENT(LOCKED))
    IF wParam == SessionUnlock:
      emit(SCREEN_EVENT(ACTIVE))

  ON SC_SCREENSAVE:
    emit(SCREEN_EVENT(SCREENSAVER))

  POLLING (every 2s):
    IF SystemParametersInfo(SPI_GETSCREENSAVERRUNNING):
      IF lastState != SCREENSAVER:
        emit(SCREEN_EVENT(SCREENSAVER))
    ELSE IF lastState == SCREENSAVER:
      emit(SCREEN_EVENT(ACTIVE))
```

#### macOS

```
事件源：
  1. NSWorkspace 通知
     - NSWorkspaceScreensDidSleepNotification → SLEEP
     - NSWorkspaceScreensDidWakeNotification → ACTIVE
     - NSWorkspaceSessionDidResignActiveNotification → LOCKED
     - NSWorkspaceSessionDidBecomeActiveNotification → ACTIVE
  2. CGSession 屏幕锁定
     - CGSessionCopyCurrentDictionary() 检查 CGSSessionScreenIsLocked
  3. 屏保
     - DistributedNotificationCenter
     - com.apple.screensaver.didstart → SCREENSAVER
     - com.apple.screensaver.didstop → ACTIVE

检测流程：
  ON NSWorkspaceScreensDidSleepNotification:
    emit(SCREEN_EVENT(SLEEP))
  ON NSWorkspaceScreensDidWakeNotification:
    emit(SCREEN_EVENT(ACTIVE))
  ON NSWorkspaceSessionDidResignActiveNotification:
    // 需要区分锁屏和屏保，检查屏保状态
    IF screensaver_running:
      emit(SCREEN_EVENT(SCREENSAVER))
    ELSE:
      emit(SCREEN_EVENT(LOCKED))
  ON com.apple.screensaver.didstart:
    emit(SCREEN_EVENT(SCREENSAVER))
  ON com.apple.screensaver.didstop:
    emit(SCREEN_EVENT(ACTIVE))
```

#### Android

```
事件源：
  1. BroadcastReceiver
     - Intent.ACTION_SCREEN_OFF → SLEEP
     - Intent.ACTION_SCREEN_ON → ACTIVE（屏幕亮起但可能仍锁定）
     - Intent.ACTION_USER_PRESENT → ACTIVE（解锁）
  2. KeyguardManager
     - isKeyguardLocked() → LOCKED
  3. PowerManager
     - isInteractive() → 判断屏幕是否亮起

检测流程：
  ON ACTION_SCREEN_OFF:
    emit(SCREEN_EVENT(SLEEP))
  ON ACTION_SCREEN_ON:
    // 屏幕亮了但可能还在锁屏
    IF KeyguardManager.isKeyguardLocked():
      emit(SCREEN_EVENT(LOCKED))  // 保持锁定状态，等 USER_PRESENT
    ELSE:
      emit(SCREEN_EVENT(ACTIVE))
  ON ACTION_USER_PRESENT:
    emit(SCREEN_EVENT(ACTIVE))

  // Android 无屏保概念，忽略
  // Android 待机 = SLEEP（屏幕关闭即待机）
```

#### iOS（V1.0.7 — ScreenTime API）

> **V1.0.7 重大变更**：iOS 完全改用 ScreenTime API，不再依赖 AppLifecycleState 推断。

```
架构：
  ┌─────────────────────────────────────────────────┐
  │  DeviceActivityMonitor Extension（独立进程）      │
  │  - 由 iOS 系统管理，不会被杀                      │
  │  - 监听设备活动，达到阈值时触发                   │
  │  - 通过 ManagedSettings 显示 Shield 全屏遮罩      │
  │  - 通过 App Group UserDefaults 与主 App 通信      │
  └─────────────────────────────────────────────────┘
           ↑ DeviceActivitySchedule 注册阈值
           │
  ┌─────────────────────────────────────────────────┐
  │  主 App（Flutter）                                │
  │  - 请求 Family Controls 授权                     │
  │  - 注册 DeviceActivitySchedule（20min/40min）     │
  │  - 读取 ScreenTime 使用报告                       │
  │  - 不负责实时提醒（扩展负责）                      │
  └─────────────────────────────────────────────────┘

事件源：
  1. DeviceActivityMonitor Extension
     - intervalDidStart → 达到阈值，显示 Shield 遮罩
     - intervalDidEnd → 移除遮罩，注册下一轮阈值
  2. 主 App AppLifecycleState（辅助）
     - resumed → 清除 Shield 遮罩，恢复 session
     - paused → 暂停 session

检测流程：
  启动时：
    1. 检查 Family Controls 授权状态
    2. 如果已授权 → 注册 DeviceActivitySchedule
    3. 如果未授权 → 引导用户到设置页授权

  20 分钟阈值触发（Extension 进程）：
    intervalDidStart("eyeRestReminder"):
      → ManagedSettings.shield = 全屏遮罩
        header: "👁️ 用眼休息"
        subtitle: "看 20 英尺外 20 秒"
      → 通过 App Group 记录事件

  40 分钟阈值触发（Extension 进程）：
    intervalDidStart("combinedReminder"):
      → ManagedSettings.shield = 全屏遮罩
        header: "🧘 + 👁️ 姿势切换 + 用眼休息"
        subtitle: "切换坐姿/站姿，并看向 20 英尺外 20 秒"

  遮罩移除（Extension 进程）：
    intervalDidEnd():
      → ManagedSettings.clearAllSettings()（移除遮罩）
      → 递增 triggerCount
      → 注册下一个阈值（20min 或 40min 交替）

Shield 遮罩特性：
  - iOS 系统级 UI，与来电界面同级别
  - 覆盖所有应用，用户无法绕过
  - 不需要 App 在前台
  - Extension 由系统管理，不会被杀进程
  - 需要 Family Controls 授权（家长监控权限）

App Group 共享数据：
  group.com.timbertrail.screenguardian
  - triggerCount: Int（触发计数器）
  - reminderEvents: [[String:String]]（事件日志）
  - extensionLogs: [String]（调试日志）
  - todayUsageSeconds: Int（当日用时）
```

### 3.2.5 防抖与去抖

**问题**：某些平台事件可能短时间内多次触发（如快速亮灭屏）。

**方案**：引入防抖机制。

```
DEBOUNCE_DELAY = 1000ms  // 1 秒防抖

ON screen_event(event):
  IF (now - lastEventTimestamp) < DEBOUNCE_DELAY:
    IF event.toState == lastEvent.toState:
      IGNORE  // 忽略重复事件
    ELSE:
      // 状态确实发生了变化，处理
      processEvent(event)
  ELSE:
    processEvent(event)
  lastEventTimestamp = now
  lastEvent = event
```

### 3.2.6 最短 Session 过滤

```
MIN_SESSION_DURATION_SECONDS = 60  // 最短 1 分钟

ON session_ended(session):
  IF session.durationSeconds < MIN_SESSION_DURATION_SECONDS:
    DISCARD  // 忽略过短的 Session（快速亮灭屏）
  ELSE:
    SAVE
```

---

## 3.3 模块 M3 — 屏幕用时记录引擎

### 3.3.1 功能描述

接收 M2 的屏幕状态事件，管理 ScreenSession 的生命周期（创建、更新、结束），维护 DailySummary。

### 3.3.2 接口定义

#### I3.1 — 初始化记录引擎

```
接口名称：SessionManager.init()
参数：
  - storage: StorageAdapter     // 存储适配器
  - deviceInfo: DeviceInfo      // 当前设备信息
返回值：void
流程：
  1. 读取 state.json，恢复上次状态
  2. 如果 state.currentSessionId != null：
     a. 读取该 Session
     b. 如果 Session.endTime == null（崩溃时未正常结束）：
        - 设置 endTime = now
        - 设置 stopReason = "shutdown"（推测为异常退出）
        - 计算 durationSeconds
        - 保存
  3. 注册屏幕事件监听
```

#### I3.2 — 处理屏幕事件

```
接口名称：SessionManager.handleScreenEvent(event: ScreenEvent)
参数：ScreenEvent（来自 M2）
返回值：void
流程（详见 3.3.3 状态机）
```

#### I3.3 — 暂停当前 Session

```
接口名称：SessionManager.pauseCurrentSession(reason: StopReason)
参数：reason: StopReason 枚举值
返回值：ScreenSession | null（被暂停的 Session，null 表示无活跃 Session）
说明：由 M4/M5 调用，用于休息提醒时暂停计时
```

#### I3.4 — 创建新 Session

```
接口名称：SessionManager.startNewSession()
参数：无
返回值：ScreenSession
说明：在暂停或结束后创建新的 Session
```

#### I3.5 — 获取当前 Session

```
接口名称：SessionManager.getCurrentSession()
参数：无
返回值：ScreenSession | null
```

#### I3.6 — 获取今日用时

```
接口名称：SessionManager.getTodayTotalSeconds()
参数：无
返回值：integer（秒）
说明：返回今日所有已完成 Session 的总时长 + 当前 Session 的已用时长
```

#### I3.7 — 查询历史 Session

```
接口名称：SessionManager.querySessions(filter: SessionFilter)
参数：
  filter: {
    startDate: string      // 起始日期 YYYY-MM-DD
    endDate: string        // 结束日期 YYYY-MM-DD
    deviceId?: string      // 可选：按设备过滤
    stopReason?: StopReason // 可选：按停止原因过滤
  }
返回值：ScreenSession[]
```

#### I3.8 — 查询 DailySummary

```
接口名称：SessionManager.querySummaries(filter: SummaryFilter)
参数：
  filter: {
    startDate: string
    endDate: string
  }
返回值：DailySummary[]
```

### 3.3.3 状态机（详细）

```
                           ┌─────────────────────────────────────────┐
                           │           SessionManager 状态机          │
                           └─────────────────────────────────────────┘

                              屏幕打开事件 (toState=ACTIVE)
                                     │
                                     ▼
                    ┌────────────────────────────────────┐
                    │  状态：IDLE（无活跃 Session）        │
                    │  动作：创建新 Session                │
                    │        startTime = now               │
                    │        endTime = null                │
                    │        保存到本地                    │
                    │        启动 eyeRestTimer             │
                    │        启动 postureTimer             │
                    └────────────────┬───────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────────┐
                    │  状态：ACTIVE（计时中）              │
                    │  当前 Session：startTime 已设置      │
                    │  endTime = null                      │
                    │  定时器运行中                        │
                    └───┬──────────┬──────────┬──────────┘
                        │          │          │
              屏幕关闭  │  用眼休息 │  姿势切换│
              /锁定/    │  定时器   │  定时器  │
              待机/关机  │  触发     │  触发    │
                        │          │          │
                        ▼          ▼          ▼
              ┌─────────────┐ ┌──────────┐ ┌──────────┐
              │ 结束 Session│ │暂停Session│ │暂停Session│
              │ endTime=now │ │endTime=now│ │endTime=now│
              │ 计算时长    │ │计算时长   │ │计算时长   │
              │ 设置原因    │ │原因=     │ │原因=     │
              │ 更新Summary │ │eye_rest  │ │posture_  │
              │ 保存        │ │更新Summary│ │change    │
              └──────┬──────┘ │保存      │ │更新Summary│
                     │        └────┬─────┘ │保存      │
                     │             │        └────┬─────┘
                     ▼             ▼             ▼
              ┌─────────────┐ ┌──────────────┐
              │  状态：IDLE  │ │ 弹窗显示中    │
              │             │ │ 等待用户确认  │
              │             │ │ （无关闭按钮）│
              │             │ └──────┬───────┘
              │             │        │ 用户确认/倒计时结束
              │             │        │ 关闭弹窗
              │             │        ▼
              │             │ ┌──────────────┐
              │             │ │ 创建新 Session│
              │             │ │ 回到 ACTIVE   │
              │             │ └──────────────┘
              │             │
              │  屏幕再次打开│
              └─────────────┘
```

### 3.3.4 Session 结束与 Summary 更新流程（详细）

```
END_SESSION(session, reason):
  1. session.endTime = now
  2. session.durationSeconds = Math.floor(
       (session.endTime - session.startTime) / 1000
     )
  3. session.stopReason = reason
  4. session.updatedAt = now
  5. session.version++
  6. SAVE session

  7. summary = READ summaries/{session.date}.json
  8. IF summary == null:
       summary = new DailySummary(date = session.date)
  9. summary.totalSeconds += session.durationSeconds
  10. summary.sessionCount++
  11. IF session.deviceId NOT IN summary.devices:
        summary.devices.push(session.deviceId)
  12. summary.sessionIds.push(session.id)
  13. IF summary.firstSessionStart == null OR session.startTime < summary.firstSessionStart:
        summary.firstSessionStart = session.startTime
  14. IF summary.lastSessionEnd == null OR session.endTime > summary.lastSessionEnd:
        summary.lastSessionEnd = session.endTime
  15. summary.updatedAt = now
  16. SAVE summary

  17. state.currentSessionId = null
  18. SAVE state
```

### 3.3.5 跨日处理

**场景**：用户在 23:58 打开屏幕，00:05 关闭屏幕。

**处理规则**：
- Session 归入 **startTime 所在日期**（即前一天）
- durationSeconds 正常计算跨越午夜的总时长
- DailySummary 归入 startTime 日期

```
// 跨日 Session
{
  "startTime": "2026-07-01T23:58:00+08:00",
  "endTime": "2026-07-02T00:05:00+08:00",
  "durationSeconds": 420,
  "date": "2026-07-01"  // 归入 7月1日
}
```

---

## 3.4 模块 M4 — 用眼休息 + 姿势切换提醒（合并）

> **V1.0.7 变更**：M4 和 M5 合并为统一的提醒模块。不再使用两个独立定时器。
>
> **合并逻辑**：
> - 单一定时器，每 20 分钟触发一次
> - **第 1 次**（20 分钟）→ 仅用眼休息：看 20ft 外 20 秒，倒计时 20 秒
> - **第 2 次**（40 分钟）→ 合并提醒：切换姿势 + 看 20ft 外 20 秒，倒计时 2 分钟
> - **第 3 次**（60 分钟）→ 仅用眼休息
> - **第 4 次**（80 分钟）→ 合并提醒
> - 如此循环...

### 3.4.1 功能描述

单一定时器每 20 分钟触发，内部维护触发计数器 `_triggerCount`。每 2 次触发（= 40 分钟）包含姿势切换提醒，弹出合并提醒窗口。会议模式下关闭按钮始终可见。

### 3.4.2 接口定义

#### I4.1 — 启动用眼休息定时器

```
接口名称：EyeRestManager.start()
参数：无
返回值：void
流程：
  1. 创建定时器，延迟 20 分钟（1,200,000 ms）
  2. 定时器触发时调用 onTimerFired()
```

#### I4.2 — 停止用眼休息定时器

```
接口名称：EyeRestManager.stop()
参数：无
返回值：void
```

#### I4.3 — 重置用眼休息定时器

```
接口名称：EyeRestManager.reset()
参数：无
返回值：void
说明：弹窗关闭后重置定时器，开始新的 20 分钟倒计时
```

#### I4.4 — 定时器触发回调

```
接口名称：EyeRestManager.onTimerFired()
参数：无
返回值：void
流程：
  1. 调用 SessionManager.pauseCurrentSession(reason: "eye_rest")
  2. 停止 postureTimer（避免重叠弹窗）
  3. 调用 UI.showEyeRestDialog()
  4. 弹窗关闭后：
     a. 调用 SessionManager.startNewSession()
     b. 调用 this.reset()（重启 20 分钟定时器）
     c. 调用 PostureManager.reset()（重启姿势定时器）
```

### 3.4.3 弹窗交互流程（详细）

```
showEyeRestDialog():

  ┌─────────────────────────────────────────────────────┐
  │  创建弹窗                                            │
  │  - 桌面端：创建 BrowserWindow（always on top,        │
  │    frame: false, resizable: false）                  │
  │  - 移动端：创建全屏 Dialog                           │
  │  - 弹窗不可关闭（无关闭按钮，ESC/Back 键禁用）       │
  └───────────────────────┬─────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  检查会议模式                                        │
  │  IF config.meetingMode == true:                      │
  │    显示关闭按钮（用户可随时关闭）                     │
  │  ELSE:                                               │
  │    隐藏关闭按钮                                      │
  └───────────────────────┬─────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  启动 20 秒倒计时                                    │
  │  countdown = 20                                      │
  │  WHILE countdown > 0:                                │
  │    更新倒计时显示                                     │
  │    等待 1 秒                                         │
  │    countdown--                                       │
  └───────────────────────┬─────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  倒计时结束                                          │
  │  显示关闭按钮                                        │
  │  更新提示文字："可以关闭了"                           │
  └───────────────────────┬─────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  等待用户点击关闭按钮                                │
  │  ON close_clicked:                                   │
  │    关闭弹窗                                          │
  │    触发回调 onDialogClosed()                         │
  └─────────────────────────────────────────────────────┘
```

### 3.4.4 弹窗 UI 详细规格

#### 桌面端弹窗

```
┌─────────────────────────────────────────────────────────┐
│  🛡️ ScreenGuardian                              [×]*   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│                    👁️                                   │
│                                                         │
│           用 眼 休 息 时 间 到 了                        │
│                                                         │
│     请看向 20 英尺（约 6 米）外的物体                    │
│              持续 20 秒                                  │
│                                                         │
│              ┌─────────────┐                            │
│              │   ⏱️ 15 秒   │                            │
│              └─────────────┘                            │
│                                                         │
│     [关闭]*                                              │
│                                                         │
│  * [×] 和 [关闭] 在倒计时期间隐藏                       │
│    会议模式下始终显示                                    │
└─────────────────────────────────────────────────────────┘

规格：
- 窗口尺寸：400 x 350 px
- 窗口位置：屏幕中央
- 窗口层级：always on top
- 窗口样式：无标题栏，圆角
- 背景色：#1a237e（深蓝）
- 文字色：#ffffff（白色）
- 倒计时字号：48px
- 倒计时圆环动画：SVG 圆环渐进
```

#### 移动端弹窗

```
┌──────────────────────────┐
│  ╔══════════════════════╗│
│  ║                      ║│
│  ║        👁️            ║│
│  ║                      ║│
│  ║    用眼休息时间到了   ║│
│  ║                      ║│
│  ║  请看向20英尺外的物体 ║│
│  ║     持续20秒         ║│
│  ║                      ║│
│  ║    ┌──────────┐      ║│
│  ║    │  ⏱️ 15秒 │      ║│
│  ║    └──────────┘      ║│
│  ║                      ║│
│  ║    [关闭]*            ║│
│  ║                      ║│
│  ╚══════════════════════╝│
└──────────────────────────┘

规格：
- 全屏覆盖（含状态栏）
- 背景色：#1a237e
- 触摸返回键：禁用（倒计时期间）
- 倒计时字号：64px
```

### 3.4.5 异常处理

| 场景 | 处理 |
|------|------|
| 弹窗期间收到屏幕关闭事件 | 关闭弹窗，正常结束 Session |
| 弹窗期间应用被强制退出 | 依赖 state.json 恢复 |
| 多个提醒同时触发 | 保证同时只显示一个弹窗，优先级：用眼休息 > 姿势切换 |
| 系统时间回拨 | 使用单调时钟（performance.now）计时，不受系统时间影响 |

---

## ~~3.5 模块 M5 — 姿势切换提醒~~（已合并至 M4）

> **V1.0.7 变更**：M5 已完全合并至 M4。姿势切换提醒现在是 M4 合并提醒的一部分，每 40 分钟（= 2 × 20 分钟用眼休息周期）触发一次合并弹窗，同时包含姿势切换和用眼休息提示。
>
> 独立的 `postureIntervalMinutes` 配置项已移除。姿势切换间隔固定为用眼休息间隔的 2 倍。
>
> 以下为历史设计保留，供参考。

### 3.5.1 历史功能描述

每 configurableInterval 分钟（默认 30，可配置 30~60），弹出姿势切换提示框。等待 2 分钟用户确认后才出现关闭按钮。

### 3.5.2 接口定义

#### I5.1 — 启动姿势切换定时器

```
接口名称：PostureManager.start()
参数：无
返回值：void
流程：
  1. 读取 config.postureIntervalMinutes（默认 30）
  2. 创建定时器，延迟 postureIntervalMinutes * 60 * 1000 ms
```

#### I5.2 — 停止姿势切换定时器

```
接口名称：PostureManager.stop()
参数：无
返回值：void
```

#### I5.3 — 重置姿势切换定时器

```
接口名称：PostureManager.reset()
参数：无
返回值：void
说明：弹窗关闭后重置定时器
```

#### I5.4 — 定时器触发回调

```
接口名称：PostureManager.onTimerFired()
参数：无
返回值：void
流程：
  1. 调用 SessionManager.pauseCurrentSession(reason: "posture_change")
  2. 停止 eyeRestTimer（避免重叠弹窗）
  3. 调用 UI.showPostureChangeDialog()
  4. 弹窗关闭后：
     a. 调用 SessionManager.startNewSession()
     b. 调用 this.reset()
     c. 调用 EyeRestManager.reset()
```

### 3.5.3 弹窗交互流程（详细）

```
showPostureChangeDialog():

  ┌─────────────────────────────────────────────────────┐
  │  创建弹窗（同 M4 规格）                              │
  │  隐藏关闭按钮                                        │
  │  IF meetingMode: 显示关闭按钮                        │
  └───────────────────────┬─────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  启动 2 分钟确认倒计时                               │
  │  countdown = 120 seconds                             │
  │  WHILE countdown > 0:                                │
  │    更新倒计时显示（分:秒格式）                        │
  │    等待 1 秒                                         │
  │    countdown--                                       │
  └───────────────────────┬─────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  倒计时结束                                          │
  │  显示"已完成切换"按钮                                │
  └───────────────────────┬─────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  等待用户点击"已完成切换"                            │
  │  ON button_clicked:                                  │
  │    关闭弹窗                                          │
  │    触发回调 onDialogClosed()                         │
  └─────────────────────────────────────────────────────┘
```

### 3.5.4 弹窗 UI 详细规格

```
┌─────────────────────────────────────────────────────────┐
│  🛡️ ScreenGuardian                              [×]*   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│                    🧘                                   │
│                                                         │
│           姿 势 切 换 时 间 到 了                        │
│                                                         │
│         请切换您的坐姿/站姿                              │
│      久坐伤身，适时站立活动有益健康 🏃                   │
│                                                         │
│              ┌─────────────┐                            │
│              │  ⏱️ 1:45    │                            │
│              └─────────────┘                            │
│                                                         │
│     [已完成切换]*                                        │
│                                                         │
│  * 倒计时期间隐藏，会议模式下始终显示                    │
└─────────────────────────────────────────────────────────┘

规格：
- 窗口尺寸：400 x 350 px
- 其他同 M4
```

---

## 3.6 模块 M6 — 菜单系统

### 3.6.1 功能描述

提供统一的菜单入口，各平台触发方式不同。

### 3.6.2 菜单结构定义

```
MenuStructure {
  items: [
    {
      id: "report",
      label: { zh: "报告", en: "Report" },
      icon: "📊",
      shortcut: { mac: "Cmd+R" },
      action: "openReport"
    },
    {
      id: "settings",
      label: { zh: "设置", en: "Settings" },
      icon: "⚙️",
      shortcut: { mac: "Cmd+," },
      action: "openSettings"
    },
    {
      id: "tracking",
      label: { zh: "跟踪", en: "Tracking" },
      icon: "📡",
      shortcut: { mac: "Cmd+T" },
      action: "openTracking"
    },
    { type: "separator" },
    {
      id: "about",
      label: { zh: "关于", en: "About" },
      icon: "ℹ️",
      action: "openAbout"
    },
    {
      id: "exit",
      label: { zh: "退出", en: "Exit" },
      icon: "🚪",
      shortcut: { mac: "Cmd+Q" },
      action: "exitApp"
    }
  ]
}
```

### 3.6.3 各平台实现

#### Windows — 系统托盘右键菜单

```
实现：Electron Tray API
触发：右键点击托盘图标
代码：
  const tray = new Tray(iconPath)
  const contextMenu = Menu.buildFromTemplate([
    { label: '🛡️ ScreenGuardian V1.1', enabled: false },
    { type: 'separator' },
    { label: '📊 报告', click: openReport },
    { label: '⚙️ 设置', click: openSettings },
    { label: '📡 跟踪', click: openTracking },
    { type: 'separator' },
    { label: 'ℹ️ 关于', click: openAbout },
    { label: '🚪 退出', click: exitApp }
  ])
  tray.setContextMenu(contextMenu)
  tray.setToolTip('ScreenGuardian V1.1 — 运行中')

双击行为：打开报告窗口
```

#### macOS — 菜单栏点击菜单

```
实现：Electron Tray API + NSMenu
触发：左键点击菜单栏图标
代码：
  const tray = new Tray(iconPath)
  tray.setTitle('🛡️')  // 或使用图标
  const contextMenu = Menu.buildFromTemplate([
    { label: '🛡️ ScreenGuardian V1.1', enabled: false },
    { type: 'separator' },
    { label: '📊 报告', accelerator: 'CmdOrCtrl+R', click: openReport },
    { label: '⚙️ 设置', accelerator: 'CmdOrCtrl+,', click: openSettings },
    { label: '📡 跟踪', accelerator: 'CmdOrCtrl+T', click: openTracking },
    { type: 'separator' },
    { label: 'ℹ️ 关于', click: openAbout },
    { label: '🚪 退出', accelerator: 'CmdOrCtrl+Q', click: exitApp }
  ])
  tray.setContextMenu(contextMenu)

注意：macOS 左键弹出菜单（与 Windows 右键不同）
```

#### Android / iOS — App 主界面

```
实现：Flutter MaterialApp
触发：切换到 App（App 打开后直接显示菜单界面）

布局：
  - 顶部：App Logo + 版本号 + 当前用时
  - 中部：2x2 宫格菜单项
  - 底部：退出按钮 + 当日用时统计

导航：
  - 点击菜单项 → Navigator.push 到对应页面
  - 不使用底部导航栏（菜单本身就是主界面）
```

### 3.6.4 菜单动作处理

```
ACTION_MAP:
  openReport:
    1. 检查是否已有报告窗口打开
    2. 如果有，聚焦到该窗口
    3. 如果没有，创建新窗口/导航到报告页面
    4. 桌面端：new BrowserWindow({ width: 800, height: 600 })
    5. 移动端：Navigator.push(MaterialPageRoute(ReportScreen))

  openSettings:
    同上，窗口/页面尺寸：600 x 500

  openTracking:
    同上，窗口/页面尺寸：700 x 500

  openAbout:
    1. 桌面端：dialog.showMessageBox({ type: 'info', ... })
    2. 移动端：showDialog(AboutDialog)

  exitApp:
    1. 调用 SessionManager.pauseCurrentSession("user_exit")
    2. 保存所有数据
    3. 触发同步
    4. app.quit()
```

---

## 3.7 模块 M7 — 报告引擎

### 3.7.1 功能描述

根据用户选择的日期范围，生成屏幕使用报告。

### 3.7.2 接口定义

#### I7.1 — 生成日报

```
接口名称：ReportEngine.generateDailyReport(date: string)
参数：date: string (YYYY-MM-DD)
返回值：DailyReport

DailyReport {
  date: string                    // 日期
  dayOfWeek: string               // 星期几
  totalSeconds: integer           // 总用时（秒）
  totalFormatted: string          // 格式化总用时（如 "8小时15分钟"）
  devices: DeviceBreakdown[]      // 设备明细
  sessions: SessionDetail[]       // 时段明细
}

DeviceBreakdown {
  deviceId: string
  deviceName: string
  platform: string
  totalSeconds: integer
  totalFormatted: string
  percentage: number              // 占比（%）
}

SessionDetail {
  startTime: string               // HH:MM
  endTime: string                 // HH:MM
  durationFormatted: string       // 如 "20分钟"
  deviceName: string
  stopReason: string              // 停止原因中文名
}
```

#### I7.2 — 生成多日报

```
接口名称：ReportEngine.generateRangeReport(startDate: string, endDate: string)
参数：
  startDate: string (YYYY-MM-DD)
  endDate: string (YYYY-MM-DD)
约束：endDate >= startDate，范围不超过 90 天
返回值：RangeReport

RangeReport {
  startDate: string
  endDate: string
  totalDays: integer              // 天数
  totalSeconds: integer           // 总用时
  totalFormatted: string
  averageDailySeconds: integer    // 日均用时
  averageDailyFormatted: string
  dailyBreakdown: DailyBreakdown[] // 逐日明细
  peakDay: { date, seconds }      // 最长一天
  lowestDay: { date, seconds }    // 最短一天
}

DailyBreakdown {
  date: string
  dayOfWeek: string
  totalSeconds: integer
  totalFormatted: string
  barWidth: number                // 柱状图宽度百分比 (0-100)
}
```

#### I7.3 — 导出报告

```
接口名称：ReportEngine.exportReport(report, format)
参数：
  report: DailyReport | RangeReport
  format: 'pdf' | 'csv'
返回值：file path (string)
```

### 3.7.3 报告生成算法

```
GENERATE_DAILY_REPORT(date):
  1. summaries = READ summaries/{date.substring(0,7)}.json
  2. summary = summaries.find(s => s.date == date)
  3. IF summary == null:
       RETURN empty_report(date)

  4. sessions = READ sessions/{date.substring(0,7)}.json
  5. daysSessions = sessions.filter(s => s.date == date AND s.endTime != null)
  6. SORT daysSessions BY startTime ASC

  7. devices = GROUP daysSessions BY deviceId
  8. FOR EACH device_group:
       device_info = READ devices/{deviceId}.json
       device.totalSeconds = SUM(s.durationSeconds)
       device.percentage = (device.totalSeconds / summary.totalSeconds) * 100

  9. sessionDetails = daysSessions.map(s => {
       startTime: formatTime(s.startTime),
       endTime: formatTime(s.endTime),
       durationFormatted: formatDuration(s.durationSeconds),
       deviceName: s.deviceName,
       stopReason: translateStopReason(s.stopReason)
     })

  10. RETURN DailyReport { ... }
```

### 3.7.4 报告 UI 详细规格

#### 桌面端报告窗口

```
┌──────────────────────────────────────────────────────────────┐
│  📊 屏幕用时报告                                    [×] [—]  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  模式：[日报 ▼]                                              │
│  日期：[2026-07-01] [📅]                                     │
│                                                              │
│  ── 或 ──                                                    │
│                                                              │
│  模式：[多日报 ▼]                                            │
│  起始：[2026-06-29] [📅]  结束：[2026-07-05] [📅]            │
│                                                              │
│  [生成报告]                                                  │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ═══ 屏幕用时日报 - 2026年7月1日 ═══                         │
│                                                              │
│  📅 2026-07-01（周三）                                       │
│  ⏱️ 总用时：8小时15分钟                                      │
│  📱 设备：张三的工作电脑, 张三的iPhone                        │
│                                                              │
│  ── 时段明细 ──────────────────────────────────────────────  │
│  ┌──────────┬──────────┬──────────┬────────────────┬──────┐ │
│  │ 开始时间 │ 结束时间 │   时长   │    设备        │ 原因 │ │
│  ├──────────┼──────────┼──────────┼────────────────┼──────┤ │
│  │  09:15   │  09:35   │  20分钟  │ 工作电脑       │用眼休│ │
│  │  09:35   │  10:05   │  30分钟  │ 工作电脑       │姿势切│ │
│  │  10:05   │  12:00   │ 1h55min  │ 工作电脑       │ 锁屏 │ │
│  │  13:00   │  13:20   │  20分钟  │ iPhone         │用眼休│ │
│  │  ...     │  ...     │  ...     │ ...            │ ...  │ │
│  └──────────┴──────────┴──────────┴────────────────┴──────┘ │
│                                                              │
│  ── 设备明细 ──────────────────────────────────────────────  │
│  ┌────────────────┬──────────┬──────┐                       │
│  │     设备       │   时长   │ 占比 │                       │
│  ├────────────────┼──────────┼──────┤                       │
│  │ 工作电脑       │ 6h 10min │ 75%  │                       │
│  │ iPhone         │ 2h 05min │ 25%  │                       │
│  └────────────────┴──────────┴──────┘                       │
│                                                              │
│  [导出 PDF]  [导出 CSV]                                      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 3.8 模块 M8 — 设置管理

### 3.8.1 功能描述

管理应用配置，支持跨设备同步。

### 3.8.2 接口定义

#### I8.1 — 读取配置

```
接口名称：ConfigManager.getConfig()
参数：无
返回值：AppConfig
```

#### I8.2 — 更新配置

```
接口名称：ConfigManager.updateConfig(patch: Partial<AppConfig>)
参数：patch: 部分配置字段
返回值：AppConfig（更新后的完整配置）
流程：
  1. 合并 patch 到当前配置
  2. 验证各字段约束
  3. 设置 updatedAt = now
  4. 设置 updatedBy = deviceId
  5. 保存到本地
  6. 触发同步
  7. 通知各模块配置已变更
```

#### I8.3 — 配置变更通知

```
接口名称：ConfigManager.onConfigChanged(callback: (config: AppConfig) => void)
参数：callback
返回值：unsubscribe function
说明：各模块注册监听，配置变更时收到通知
```

### 3.8.3 配置字段验证规则

| 字段 | 验证规则 | 错误提示 |
|------|----------|----------|
| `language` | 必须为 `zh-CN` / `en` / `system` | "不支持的语言" |
| `postureIntervalMinutes` | 30 ≤ value ≤ 60，整数 | "姿势切换间隔须在 30~60 分钟之间" |
| `trackingTargets` | 数组，每个元素须为已注册的跟踪目标 | "未知的跟踪目标" |
| `syncFolderPath` | 合法路径，目录须存在且可写 | "同步文件夹不可用" |
| `deviceName` | 1~50 字符，不含特殊字符 | "设备名称须为 1~50 个字符" |

### 3.8.4 设置界面字段映射

| UI 控件 | 配置字段 | 控件类型 | 选项/范围 |
|---------|----------|----------|-----------|
| 语言选择 | `language` | Dropdown | 跟随系统 / 简体中文 / English |
| 姿势切换间隔 | `postureIntervalMinutes` | Slider + Input | 30~60，步长 1 |
| 跟踪对象 | `trackingTargets` | Checkbox List | LLM Ranking |
| 会议模式 | `meetingMode` | Toggle Switch | 开/关 |
| 网盘同步路径 | `syncFolderPath` | File Picker + Text | 文件夹路径 |
| 设备名称 | `deviceName` | Text Input | 1~50 字符 |
| 用眼休息提醒 | `eyeRestEnabled` | Toggle Switch | 开/关 |
| 姿势切换提醒 | `postureEnabled` | Toggle Switch | 开/关 |
| 超时提醒 | `overtimeEnabled` | Toggle Switch | 开/关 |

### 3.8.5 配置同步策略

```
ON config_changed_locally:
  1. 保存到本地 config.json
  2. 复制到网盘 config.json（原子写入）
  3. 更新 sync-meta.json

ON sync_timer_fired:
  1. 读取网盘 config.json
  2. IF 网盘.updatedAt > 本地.updatedAt:
       合并策略：取 updatedAt 更新的版本
       IF 网盘.updatedBy != 本地.deviceId:
         本地覆盖为网盘版本
         通知各模块配置已变更
```

---

## 3.9 模块 M9 — 多设备数据同步（P2P mDNS）

> **V1.0.7 变更**：完全移除网盘同步方案，改用 P2P 局域网同步。所有数据仅存储在本地设备上，不依赖任何云服务。

### 3.9.1 功能描述

通过 mDNS（组播 DNS，与 Apple Bonjour 同协议）在局域网内自动发现其他 ScreenGuardian 设备，然后通过 HTTP REST API 直接交换数据。

**核心特性**：
- **零配置发现**：设备上电即自动广播 `_screenguardian._tcp` 服务，无需手动输入 IP
- **用户审批**：发现的设备默认为待确认状态，用户必须在设置界面手动批准
- **配对码加密**：用户设置配对码后，所有同步数据使用 AES 加密 + HMAC 完整性校验
- **时间段去重**：跨设备重叠时段不重复统计（详见 2.3 节跨设备时间去重算法）

### 3.9.2 mDNS 服务注册与发现

```
服务类型: _screenguardian._tcp.local
端口: 19090

注册（广播）:
  每 30 秒发送 mDNS 响应包，包含：
    PTR 记录: _screenguardian._tcp.local → <instance>
    SRV 记录: <instance> → port 19090
    TXT 记录: id=<deviceId>, name=<deviceName>, platform=<platform>, version=<version>

发现（监听）:
  监听 224.0.0.251:5353 组播地址
  收到 _screenguardian._tcp 响应时，解析 TXT 记录获取设备信息
  自动注册为待确认设备
```

### 3.9.3 接口定义

#### I9.1 — 启动 P2P 同步

```
接口名称：P2PSync.start(pairingCode?: string)
参数：pairingCode: 可选配对码
返回值：void
流程：
  1. 启动 HTTP 服务器监听 19090 端口
  2. 启动 mDNS 广播（注册 _screenguardian._tcp 服务）
  3. 启动 mDNS 监听（发现其他设备）
  4. 如果提供了配对码，启用加密
  5. 启动定时同步（每 60 秒）
```

#### I9.2 — 设备审批

```
接口名称：P2PSync.approveDevice(deviceId: string)
接口名称：P2PSync.rejectDevice(deviceId: string)

设备状态流转：
  discovered (mDNS 发现) → pending (等待审批) → approved (已批准)
                                                  → rejected (已拒绝)

只有 approved 状态的设备才能进行数据同步。
```

#### I9.3 — 配对验证

```
接口名称：P2PSync.pairDevice(deviceId: string, code: string)
流程：
  1. 本地验证配对码是否正确
  2. 向远程设备发送 POST /api/pair 请求
  3. 远程设备验证配对码
  4. 双方标记为已配对，启用加密通信
```

#### I9.4 — 同步流程

```
SYNC_WITH(device):
  1. GET /api/sync/sessions?month=currentMonth → 拉取远程 session
  2. 合并到本地（按 id 去重，updatedAt 取最新）
  3. POST /api/sync/sessions → 推送本地 session
  4. GET /api/sync/summaries → 拉取远程 summary
  5. 合并到本地
  6. POST /api/sync/summaries → 推送本地 summary

所有请求带 HMAC 签名：
  X-SG-Device: deviceId
  X-SG-Time: timestamp
  X-SG-Auth: HMAC-SHA256(pairingCode, deviceId:timestamp)
```

#### I9.5 — HTTP API 端点

| 端点 | 方法 | 认证 | 说明 |
|------|------|------|------|
| `/api/ping` | GET | 无 | 设备发现验证 |
| `/api/pair` | POST | 无 | 配对码验证 |
| `/api/sync/sessions` | GET | HMAC | 拉取 session 数据 |
| `/api/sync/sessions` | POST | HMAC | 推送 session 数据 |
| `/api/sync/summaries` | GET | HMAC | 拉取 summary 数据 |
| `/api/sync/summaries` | POST | HMAC | 推送 summary 数据 |

### 3.9.5 冲突解决策略汇总

| 数据类型 | 主键 | 冲突解决 |
|----------|------|----------|
| ScreenSession | `id` (UUID) | 以 `updatedAt` 取最新 |
| DailySummary | `date` | 合并后重新聚合（含时间段去重） |
| AppConfig | 全局单例 | 以 `updatedAt` 取最新 |
| WeeklyPlan | `weekStart` | 以 `createdAt` 取最新 |
| DeviceInfo | `deviceId` | 各设备自行注册，不冲突 |

### 3.9.6 安全模型

```
配对码 → SHA256 密钥派生（10000 轮迭代） → 256 位加密密钥
                                              ↓
                                  XOR 加密 + 随机 IV + HMAC 完整性校验
                                              ↓
                                  配对验证文件（.screenguardian-pair.json）
                                  只存哈希，不存明文码
```

## 3.10 模块 M10 — 每周用时总结

### 3.10.1 功能描述

每周一，第一台打开 App 的设备生成上周用时总结。弹窗显示上周统计，并询问本周计划用时。

### 3.10.2 接口定义

#### I10.1 — 检查并触发周总结

```
接口名称：WeeklySummaryManager.checkAndTrigger()
参数：无
返回值：void
调用时机：应用启动时 + 每周一首次激活时
流程：
  1. IF today != Monday:
       RETURN  // 非周一不触发

  2. currentWeekStart = getMonday(today)

  3. 读取网盘 weekly-triggers/{currentWeekStart}.json
  4. IF 文件存在 AND 文件.triggeredBy != this.deviceId:
       RETURN  // 已被其他设备触发

  5. IF 文件存在 AND 文件.triggeredBy == this.deviceId:
       IF 文件.triggeredAt 的日期 == today:
         RETURN  // 今天已触发过

  6. // 触发周总结
     lastWeekStart = currentWeekStart - 7 days
     lastWeekEnd = currentWeekStart - 1 day

  7. report = ReportEngine.generateRangeReport(lastWeekStart, lastWeekEnd)

  8. 显示周总结弹窗(report)

  9. // 记录触发
     写入 weekly-triggers/{currentWeekStart}.json:
     {
       "weekStart": currentWeekStart,
       "triggeredAt": now,
       "triggeredBy": this.deviceId
     }
```

#### I10.2 — 保存周计划

```
接口名称：WeeklySummaryManager.saveWeeklyPlan(plannedDailyMinutes: integer)
参数：plannedDailyMinutes: 用户输入的每天计划用时（分钟）
返回值：void
流程：
  1. plan = {
       weekStart: currentWeekStart,
       plannedDailyMinutes: plannedDailyMinutes,
       source: "user_input",
       createdAt: now
     }
  2. 保存到本地 plans/weekly.json（追加到数组）
  3. 同步到网盘
```

### 3.10.3 弹窗 UI 详细规格

```
┌─────────────────────────────────────────────────────────┐
│  🛡️ ScreenGuardian - 上周用时总结               [×]     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│                    📊                                   │
│                                                         │
│           上 周 用 时 总 结                              │
│                                                         │
│  📅 上周：2026/6/23 ~ 6/29                              │
│                                                         │
│  ┌─────────────────────────────────────────────┐       │
│  │  ⏱️ 上周总用时                               │       │
│  │     52小时30分钟                              │       │
│  │                                              │       │
│  │  📊 日均用时                                  │       │
│  │     7小时30分钟                               │       │
│  │                                              │       │
│  │  📈 最长：周六 9小时                          │       │
│  │  📉 最短：周日 5小时45分钟                    │       │
│  └─────────────────────────────────────────────┘       │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  📝 本周计划用时：                                      │
│  ┌─────────────────────────────────────┐               │
│  │  每天  [    7.5    ]  小时           │               │
│  └─────────────────────────────────────┘               │
│  （默认值为上周日均用时）                                │
│                                                         │
│                    [确认计划]                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3.10.4 默认计划用时逻辑

```
GET_DEFAULT_PLANNED_MINUTES():
  1. lastWeekStart = currentWeekStart - 7 days
  2. // 尝试读取上周计划
     lastWeekPlan = plans.find(p => p.weekStart == lastWeekStart)
  3. IF lastWeekPlan != null:
       RETURN lastWeekPlan.plannedDailyMinutes  // 上次用户输入

  4. // 没有上周计划，计算上周日均
     lastWeekReport = ReportEngine.generateRangeReport(lastWeekStart, lastWeekEnd)
  5. RETURN Math.round(lastWeekReport.averageDailySeconds / 60)  // 转为分钟
```

---

## 3.11 模块 M11 — 超时提醒

### 3.11.1 功能描述

当天累计屏幕用时超过计划用时时，弹出超时提示。用户确认后继续使用，每 25 分钟再提醒一次。

### 3.11.2 接口定义

#### I11.1 — 启动超时检测

```
接口名称：OvertimeManager.start()
参数：无
返回值：void
调用时机：每次 Session 开始时 + 每次 Session duration 更新时
```

#### I11.2 — 检查超时

```
接口名称：OvertimeManager.check()
参数：无
返回值：void
流程：
  1. IF NOT config.overtimeEnabled:
       RETURN

  2. todayPlan = plans.find(p => p.weekStart == getMonday(today))
  3. IF todayPlan == null:
       RETURN  // 没有计划，不检查

  4. todayTotalMinutes = SessionManager.getTodayTotalSeconds() / 60
  5. plannedMinutes = todayPlan.plannedDailyMinutes

  6. IF todayTotalMinutes <= plannedMinutes:
       RETURN  // 未超时

  7. IF NOT state.overtimeAlertedToday:
       // 首次超时
       state.overtimeAlertedToday = true
       SAVE state
       showOvertimeAlert(todayTotalMinutes, plannedMinutes)
       RETURN

  8. // 已经提醒过，检查是否需要再次提醒
     IF state.lastOvertimeReminderAt == null:
       RETURN
  9. minutesSinceLastReminder = (now - state.lastOvertimeReminderAt) / 60000
  10. IF minutesSinceLastReminder >= 25:
        state.lastOvertimeReminderAt = now
        SAVE state
        showOvertimeReminder(todayTotalMinutes, plannedMinutes)
```

#### I11.3 — 超时提醒弹窗

```
首次超时弹窗：
┌─────────────────────────────────────────────────────────┐
│  ⚠️ 屏幕用时已超计划                                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  📊 今日累计用时：8小时15分钟                            │
│  📝 您的计划用时：7小时30分钟                            │
│                                                         │
│  ⚡ 已超出：45分钟                                       │
│                                                         │
│  💡 建议适当休息，保护眼睛和身体                         │
│                                                         │
│                    [我知道了]                            │
│                                                         │
└─────────────────────────────────────────────────────────┘

后续 25 分钟提醒弹窗：
┌─────────────────────────────────────────────────────────┐
│  ⏰ 用时提醒                                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  📊 当前累计用时：9小时05分钟                            │
│  📝 您的计划用时：7小时30分钟                            │
│                                                         │
│  ⚡ 已超出：1小时35分钟                                  │
│                                                         │
│            [继续使用]    [休息一下]                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3.11.3 超时检测触发点

```
触发点：
  1. SessionManager.startNewSession() 后 → overtimeManager.check()
  2. SessionManager 每分钟更新当前 Session 时长时 → overtimeManager.check()
  3. SessionManager.pauseCurrentSession() 后 → overtimeManager.check()
  4. 每天 00:00 重置 state.overtimeAlertedToday = false
```

---

## 3.12 模块 M12 — LLM Ranking 跟踪

### 3.12.1 功能描述

从 OpenRouter API 获取 LLM Ranking 数据，按周缓存到网盘。

### 3.12.2 接口定义

#### I12.1 — 获取 Ranking 数据

```
接口名称：RankingService.getRanking()
参数：无
返回值：LLMRankingRecord
流程：
  1. currentWeekStart = getMonday(today)

  2. // 先检查本地缓存
     localData = READ tracking/llm-ranking/{year}-W{week}.json
  3. IF localData != null AND localData.weekStart == currentWeekStart:
       RETURN localData  // 本周数据已有

  4. // 检查网盘缓存
     cloudData = READ syncFolder/tracking/llm-ranking/{year}-W{week}.json
  5. IF cloudData != null AND cloudData.weekStart == currentWeekStart:
       SAVE cloudData 到本地
       RETURN cloudData  // 网盘有本周数据

  6. // 都没有，从 API 获取
     RETURN fetchFromAPI()
```

#### I12.2 — 从 API 获取数据

```
接口名称：RankingService.fetchFromAPI()
参数：无
返回值：LLMRankingRecord
流程：
  1. display("正在获取数据...")

  2. TRY:
       response = HTTP_GET("https://openrouter.ai/api/v1/rankings/overall")
       IF response.status != 200:
         THROW "API 请求失败: " + response.status

  3. CATCH error:
       display("获取失败：" + error.message)
       RETURN null

  4. record = {
       weekStart: currentWeekStart,
       weekEnd: currentWeekStart + 6 days,
       fetchedAt: now,
       fetchedBy: deviceId,
       source: "https://openrouter.ai/api/v1/rankings/overall",
       data: response.data.map((item, index) => ({
         rank: index + 1,
         modelId: item.id,
         modelName: item.name,
         provider: item.provider,
         score: item.score,
         contextLength: item.context_length,
         category: "overall"
       }))
     }

  5. SAVE record 到本地
  6. SAVE record 到网盘
  7. RETURN record
```

#### I12.3 — 跟踪界面显示

```
接口名称：RankingService.displayRanking()
参数：无
返回值：void
流程：
  1. data = getRanking()
  2. IF data == null:
       显示错误状态
       RETURN

  3. 显示表格：
     - 表头可点击排序
     - 默认按 rank 升序
     - 点击列头切换排序方向

排序逻辑：
  SORT_COLUMN = ['rank', 'modelName', 'provider', 'score', 'contextLength']
  当前排序列 = 'rank'
  当前排序方向 = 'asc'

  ON column_header_clicked(column):
    IF column == 当前排序列:
      当前排序方向 = 当前排序方向 == 'asc' ? 'desc' : 'asc'
    ELSE:
      当前排序列 = column
      当前排序方向 = 'desc'  // 默认降序
    refreshTable()
```

---

# 第四部分：界面与交互设计

## 4.1 设计规范

### 颜色方案

| 用途 | 颜色 | Hex |
|------|------|-----|
| 主色（深蓝） | ![#1a237e](https://via.placeholder.com/15/1a237e/1a237e.png) | `#1a237e` |
| 主色（浅蓝） | ![#42a5f5](https://via.placeholder.com/15/42a5f5/42a5f5.png) | `#42a5f5` |
| 强调色 | ![#ff6f00](https://via.placeholder.com/15/ff6f00/ff6f00.png) | `#ff6f00` |
| 背景色 | ![#f5f5f5](https://via.placeholder.com/15/f5f5f5/f5f5f5.png) | `#f5f5f5` |
| 卡片背景 | `#ffffff` | 白色 |
| 主文字 | `#212121` | 深灰 |
| 次文字 | `#757575` | 中灰 |
| 分割线 | `#e0e0e0` | 浅灰 |
| 成功 | `#4caf50` | 绿色 |
| 警告 | `#ff9800` | 橙色 |
| 错误 | `#f44336` | 红色 |

### 字体方案

| 平台 | 中文字体 | 英文字体 |
|------|----------|----------|
| Windows | 微软雅黑 | Segoe UI |
| macOS | 苹方 | SF Pro |
| Android | 思源黑体 | Roboto |
| iOS | 苹方 | SF Pro |

### 字号规范

| 级别 | 字号 | 行高 | 用途 |
|------|------|------|------|
| H1 | 28px | 36px | 页面标题 |
| H2 | 22px | 30px | 区域标题 |
| H3 | 18px | 26px | 小节标题 |
| Body | 14px | 22px | 正文 |
| Caption | 12px | 18px | 辅助文字 |
| Timer | 48px | 56px | 倒计时数字 |

### 间距规范

| 名称 | 值 | 用途 |
|------|----|------|
| xs | 4px | 紧凑间距 |
| sm | 8px | 元素内间距 |
| md | 16px | 元素间间距 |
| lg | 24px | 区域间间距 |
| xl | 32px | 大区域间距 |

### 圆角规范

| 名称 | 值 | 用途 |
|------|----|------|
| sm | 4px | 按钮、输入框 |
| md | 8px | 卡片 |
| lg | 16px | 弹窗 |
| full | 9999px | 圆形头像 |

---

## 4.2 桌面端界面线框图

### 4.2.1 报告窗口（详细）

```
┌──────────────────────────────────────────────────────────────────┐
│  📊 屏幕用时报告                                          [×] [—]│
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 模式：[日报 ▼]   日期：[2026-07-01] [📅]   [生成报告]    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 模式：[多日报 ▼]                                         │   │
│  │ 起始：[2026-06-29] [📅]  结束：[2026-07-05] [📅]         │   │
│  │                                        [生成报告]        │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ════════════════════════════════════════════════════════════    │
│                                                                  │
│  📅 2026-07-01（周三）                                           │
│  ⏱️ 总用时：8小时15分钟                                          │
│  📱 设备：张三的工作电脑, 张三的iPhone                            │
│                                                                  │
│  ┌─ 时段明细 ──────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  开始    结束     时长      设备              停止原因   │    │
│  │  ─────  ─────  ────────  ────────────────  ──────────  │    │
│  │  09:15  09:35   20分钟   张三的工作电脑      用眼休息   │    │
│  │  09:35  10:05   30分钟   张三的工作电脑      姿势切换   │    │
│  │  10:05  12:00  1h55min   张三的工作电脑      锁屏       │    │
│  │  13:00  13:20   20分钟   张三的iPhone        用眼休息   │    │
│  │  13:20  15:50  2h30min   张三的iPhone        姿势切换   │    │
│  │  15:50  16:10   20分钟   张三的工作电脑      用眼休息   │    │
│  │  16:10  18:00  1h50min   张三的工作电脑      关机       │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─ 设备明细 ──────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  设备                时长        占比     ████████████   │    │
│  │  ─────────────────  ────────  ────────  ─────────────  │    │
│  │  张三的工作电脑     6h 10min    75%     ████████████░░  │    │
│  │  张三的iPhone       2h 05min    25%     ████░░░░░░░░░░  │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│                              [导出 PDF]  [导出 CSV]              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2.2 设置窗口（详细）

```
┌──────────────────────────────────────────────────────────────────┐
│  ⚙️ 设置                                                  [×]    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─ 基本设置 ──────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  🌐 界面语言                                            │    │
│  │     [简体中文 ▼]                                        │    │
│  │     选择"跟随系统"将自动匹配系统语言                     │    │
│  │                                                         │    │
│  │  📱 设备名称                                            │    │
│  │     [张三的工作电脑________________________]            │    │
│  │     用于在多设备报告中区分不同设备                       │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─ 健康提醒 ──────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  👁️ 用眼休息提醒                        [●──] 开启      │    │
│  │     每 20 分钟提醒一次，遵循 20-20-20 法则              │    │
│  │                                                         │    │
│  │  🧘 姿势切换提醒                        [●──] 开启      │    │
│  │     间隔时间：[──────●────────] 30 分钟                  │    │
│  │              30         45         60                    │    │
│  │                                                         │    │
│  │  💬 会议模式                            [○──] 关闭      │    │
│  │     开启后，休息提醒弹窗将显示关闭按钮                   │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─ 用时管理 ──────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  ⏰ 超时提醒                            [●──] 开启      │    │
│  │     超过计划用时后提醒，之后每 25 分钟提醒一次           │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─ 数据同步 ──────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  📁 网盘同步路径                                        │    │
│  │     [/Users/zhang/OneDrive/ScreenGuardian___] [浏览...]  │    │
│  │     选择您的网盘同步文件夹，实现多设备数据同步           │    │
│  │     状态：✅ 同步正常  上次同步：2 分钟前                │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─ 跟踪设置 ──────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  📡 跟踪对象                                            │    │
│  │     ☑ LLM Ranking (OpenRouter)                         │    │
│  │     ☐ 其他跟踪目标（开发中...）                         │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│                                  [保存]  [重置默认值]            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2.3 跟踪窗口（详细）

```
┌──────────────────────────────────────────────────────────────────┐
│  📡 LLM Ranking                                            [×]   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  数据来源：OpenRouter                                            │
│  更新时间：2026-07-01 09:00                                      │
│  本周：2026-W27 (6/30 ~ 7/6)                                    │
│                                                                  │
│  [刷新数据]                                                      │
│                                                                  │
│  ┌────┬──────────────────────────┬────────────┬───────┬────────┐│
│  │排名│ 模型名称                  │   提供商   │  评分 │上下文长││
│  │ ↕️ │ ↕️                       │ ↕️         │ ↕️    │ ↕️     ││
│  ├────┼──────────────────────────┼────────────┼───────┼────────┤│
│  │  1 │ Claude 3.5 Sonnet        │ Anthropic  │ 95.2  │ 200K   ││
│  │  2 │ GPT-4o                   │ OpenAI     │ 93.8  │ 128K   ││
│  │  3 │ Gemini 1.5 Pro           │ Google     │ 92.1  │ 1M     ││
│  │  4 │ Claude 3 Opus            │ Anthropic  │ 91.5  │ 200K   ││
│  │  5 │ Llama 3.1 405B           │ Meta       │ 90.3  │ 128K   ││
│  │  6 │ Mistral Large 2          │ Mistral    │ 89.7  │ 128K   ││
│  │  7 │ Command R+               │ Cohere     │ 88.4  │ 128K   ││
│  │  8 │ Qwen 2 72B               │ Alibaba    │ 87.9  │ 128K   ││
│  │  9 │ DeepSeek V2              │ DeepSeek   │ 87.2  │ 128K   ││
│  │ 10 │ Phi-3 Medium             │ Microsoft  │ 86.5  │ 128K   ││
│  └────┴──────────────────────────┴────────────┴───────┴────────┘│
│                                                                  │
│  列标题可点击排序 ↑↓                                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2.4 关于对话框

```
┌────────────────────────────────────────────────┐
│           ℹ️ 关于 ScreenGuardian                │
├────────────────────────────────────────────────┤
│                                                │
│                  🛡️                            │
│           ScreenGuardian                       │
│            屏幕守护者                           │
│                                                │
│           版本：V1.1                           │
│           开发者：TimberTrail                   │
│           授权：免费使用                        │
│                                                │
│    跨平台屏幕用时管理工具                       │
│    守护您的眼睛和健康                           │
│                                                │
│                  [确定]                        │
│                                                │
└────────────────────────────────────────────────┘
```

---

## 4.3 移动端界面线框图

### 4.3.1 主菜单界面

```
┌──────────────────────────────┐
│  ┌────────────────────────┐  │
│  │     🛡️                 │  │
│  │  ScreenGuardian        │  │
│  │  V1.1                  │  │
│  │                        │  │
│  │  ⏱️ 当前用时：2h 15m   │  │
│  │  📊 今日总用时：5h 30m │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────┐┌────────────┐│
│  │     📊     ││     ⚙️     ││
│  │    报告    ││    设置    ││
│  │            ││            ││
│  └────────────┘└────────────┘│
│  ┌────────────┐┌────────────┐│
│  │     📡     ││     ℹ️     ││
│  │    跟踪    ││    关于    ││
│  │            ││            ││
│  └────────────┘└────────────┘│
│                              │
│  ┌──────────────────────────┐│
│  │        🚪 退出           ││
│  └──────────────────────────┘│
│                              │
│  本周计划：7.5h/天            │
│  今日剩余：2h 00m            │
│                              │
└──────────────────────────────┘
```

### 4.3.2 移动端报告页面

```
┌──────────────────────────────┐
│  ← 📊 报告                   │
├──────────────────────────────┤
│                              │
│  ┌────────────────────────┐  │
│  │ [日报] [多日报]         │  │
│  └────────────────────────┘  │
│                              │
│  日期：2026-07-01 [📅]       │
│                              │
│  ┌────────────────────────┐  │
│  │ ⏱️ 总用时               │  │
│  │ 8小时15分钟             │  │
│  │                        │  │
│  │ 📱 设备                 │  │
│  │ MacBook, iPhone         │  │
│  └────────────────────────┘  │
│                              │
│  ── 时段明细 ──────────────  │
│                              │
│  ┌────────────────────────┐  │
│  │ 09:15 - 09:35          │  │
│  │ 20分钟 · 工作电脑       │  │
│  │ 用眼休息               │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │ 09:35 - 10:05          │  │
│  │ 30分钟 · 工作电脑       │  │
│  │ 姿势切换               │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │ 10:05 - 12:00          │  │
│  │ 1h55min · 工作电脑      │  │
│  │ 锁屏                   │  │
│  └────────────────────────┘  │
│  ...                         │
│                              │
│  ── 设备明细 ──────────────  │
│                              │
│  ┌────────────────────────┐  │
│  │ 工作电脑    6h10m  75% │  │
│  │ ████████████░░░░░░░░░  │  │
│  │ iPhone      2h05m  25% │  │
│  │ ████░░░░░░░░░░░░░░░░░  │  │
│  └────────────────────────┘  │
│                              │
│  [导出]                      │
│                              │
└──────────────────────────────┘
```

### 4.3.3 移动端设置页面

```
┌──────────────────────────────┐
│  ← ⚙️ 设置                   │
├──────────────────────────────┤
│                              │
│  ── 基本设置 ──────────────  │
│                              │
│  语言        [简体中文    ▼]  │
│  设备名称    [张三的iPhone]   │
│                              │
│  ── 健康提醒 ──────────────  │
│                              │
│  用眼休息     [●────] 开启   │
│  姿势切换     [●────] 开启   │
│  姿势间隔     [──●──] 30分钟 │
│              30    45    60  │
│  会议模式     [○────] 关闭   │
│                              │
│  ── 用时管理 ──────────────  │
│                              │
│  超时提醒     [●────] 开启   │
│                              │
│  ── 数据同步 ──────────────  │
│                              │
│  同步路径                     │
│  /OneDrive/ScreenGuardian    │
│  [更改路径]                  │
│  状态：✅ 同步正常            │
│                              │
│  ── 跟踪 ──────────────────  │
│                              │
│  ☑ LLM Ranking              │
│                              │
│  ┌──────────────────────────┐│
│  │         保存设置          ││
│  └──────────────────────────┘│
│                              │
└──────────────────────────────┘
```

### 4.3.4 移动端用眼休息弹窗（全屏）

```
┌──────────────────────────────┐
│╔════════════════════════════╗│
│║                            ║│
│║          👁️                ║│
│║                            ║│
│║     用眼休息时间到了        ║│
│║                            ║│
│║   请看向 20 英尺外的物体    ║│
│║       持续 20 秒            ║│
│║                            ║│
│║      ┌──────────┐          ║│
│║      │  ⏱️ 15秒  │          ║│
│║      └──────────┘          ║│
│║                            ║│
│║      [关闭]*               ║│
│║                            ║│
│║  * 倒计时结束后出现         ║│
│║   会议模式下始终显示        ║│
│║                            ║│
│╚════════════════════════════╝│
└──────────────────────────────┘
```

---

## 4.4 弹窗交互规范

### 4.4.1 弹窗行为规范

| 规则 | 说明 |
|------|------|
| **置顶** | 所有提醒弹窗必须置顶显示（always on top） |
| **不可关闭** | 倒计时期间，禁用所有关闭手段（ESC、Back、点击外部区域、手势） |
| **声音** | 弹窗出现时播放提示音（可配置，默认开启） |
| **振动** | 移动端弹窗出现时振动（可配置，默认开启） |
| **单例** | 同时只能显示一个弹窗 |
| **优先级** | 用眼休息 > 姿势切换 > 超时提醒 > 周总结 |
| **屏幕锁定** | 弹窗期间如果屏幕锁定，关闭弹窗，正常结束 Session |

### 4.4.2 弹窗动画

| 平台 | 出现动画 | 消失动画 |
|------|----------|----------|
| Windows | 淡入 + 缩放 (300ms) | 淡出 (200ms) |
| macOS | 淡入 + 缩放 (300ms) | 淡出 (200ms) |
| Android | 从底部滑入 (300ms) | 向下滑出 (200ms) |
| iOS | 从底部滑入 (300ms) | 向下滑出 (200ms) |

### 4.4.3 倒计时动画

```
倒计时圆环动画（SVG）：
  - 圆环总长度：2πr
  - 每秒减少：2πr / totalSeconds
  - stroke-dashoffset 动画
  - 颜色渐变：绿色(>15s) → 黄色(5-15s) → 红色(<5s)
  - 数字跳动：使用 CSS transition
```

---

# 第五部分：国际化

## 5.1 翻译 Key 完整列表

```json
{
  "app.name": {
    "zh-CN": "ScreenGuardian 屏幕守护者",
    "en": "ScreenGuardian"
  },
  "app.version": {
    "zh-CN": "版本",
    "en": "Version"
  },

  "menu.report": {
    "zh-CN": "报告",
    "en": "Report"
  },
  "menu.settings": {
    "zh-CN": "设置",
    "en": "Settings"
  },
  "menu.tracking": {
    "zh-CN": "跟踪",
    "en": "Tracking"
  },
  "menu.about": {
    "zh-CN": "关于",
    "en": "About"
  },
  "menu.exit": {
    "zh-CN": "退出",
    "en": "Exit"
  },

  "eye_rest.title": {
    "zh-CN": "用眼休息时间到了",
    "en": "Time for an Eye Break"
  },
  "eye_rest.message": {
    "zh-CN": "请看向 20 英尺（约 6 米）外的物体，持续 20 秒",
    "en": "Look at something 20 feet (6m) away for 20 seconds"
  },
  "eye_rest.countdown": {
    "zh-CN": "倒计时：{seconds} 秒",
    "en": "Countdown: {seconds}s"
  },
  "eye_rest.close": {
    "zh-CN": "关闭",
    "en": "Close"
  },
  "eye_rest.ready": {
    "zh-CN": "可以关闭了",
    "en": "Ready to close"
  },

  "posture.title": {
    "zh-CN": "姿势切换时间到了",
    "en": "Time to Change Posture"
  },
  "posture.message": {
    "zh-CN": "请切换您的坐姿/站姿",
    "en": "Please switch between sitting and standing"
  },
  "posture.health_tip": {
    "zh-CN": "久坐伤身，适时站立活动有益健康",
    "en": "Sitting too long is harmful. Stand up and move!"
  },
  "posture.countdown": {
    "zh-CN": "确认倒计时：{minutes}:{seconds}",
    "en": "Confirm countdown: {minutes}:{seconds}"
  },
  "posture.confirm": {
    "zh-CN": "已完成切换",
    "en": "Done"
  },

  "report.title": {
    "zh-CN": "屏幕用时报告",
    "en": "Screen Time Report"
  },
  "report.daily": {
    "zh-CN": "日报",
    "en": "Daily"
  },
  "report.range": {
    "zh-CN": "多日报",
    "en": "Date Range"
  },
  "report.date": {
    "zh-CN": "日期",
    "en": "Date"
  },
  "report.start_date": {
    "zh-CN": "起始日期",
    "en": "Start Date"
  },
  "report.end_date": {
    "zh-CN": "结束日期",
    "en": "End Date"
  },
  "report.generate": {
    "zh-CN": "生成报告",
    "en": "Generate"
  },
  "report.total_time": {
    "zh-CN": "总用时",
    "en": "Total Time"
  },
  "report.daily_average": {
    "zh-CN": "日均用时",
    "en": "Daily Average"
  },
  "report.session_detail": {
    "zh-CN": "时段明细",
    "en": "Session Details"
  },
  "report.device_detail": {
    "zh-CN": "设备明细",
    "en": "Device Breakdown"
  },
  "report.export_pdf": {
    "zh-CN": "导出 PDF",
    "en": "Export PDF"
  },
  "report.export_csv": {
    "zh-CN": "导出 CSV",
    "en": "Export CSV"
  },
  "report.peak_day": {
    "zh-CN": "最长一天",
    "en": "Longest Day"
  },
  "report.lowest_day": {
    "zh-CN": "最短一天",
    "en": "Shortest Day"
  },

  "settings.language": {
    "zh-CN": "界面语言",
    "en": "Language"
  },
  "settings.language_system": {
    "zh-CN": "跟随系统",
    "en": "Follow System"
  },
  "settings.device_name": {
    "zh-CN": "设备名称",
    "en": "Device Name"
  },
  "settings.eye_rest": {
    "zh-CN": "用眼休息提醒",
    "en": "Eye Rest Reminder"
  },
  "settings.posture": {
    "zh-CN": "姿势切换提醒",
    "en": "Posture Change Reminder"
  },
  "settings.posture_interval": {
    "zh-CN": "姿势切换间隔",
    "en": "Posture Interval"
  },
  "settings.meeting_mode": {
    "zh-CN": "会议模式",
    "en": "Meeting Mode"
  },
  "settings.meeting_mode_desc": {
    "zh-CN": "开启后，休息提醒弹窗将显示关闭按钮",
    "en": "Show close button on break reminders when enabled"
  },
  "settings.overtime": {
    "zh-CN": "超时提醒",
    "en": "Overtime Reminder"
  },
  "settings.sync_path": {
    "zh-CN": "网盘同步路径",
    "en": "Sync Folder Path"
  },
  "settings.sync_status_ok": {
    "zh-CN": "同步正常",
    "en": "Sync OK"
  },
  "settings.sync_status_error": {
    "zh-CN": "同步异常",
    "en": "Sync Error"
  },
  "settings.tracking_targets": {
    "zh-CN": "跟踪对象",
    "en": "Tracking Targets"
  },
  "settings.save": {
    "zh-CN": "保存",
    "en": "Save"
  },
  "settings.reset": {
    "zh-CN": "重置默认值",
    "en": "Reset Defaults"
  },

  "tracking.title": {
    "zh-CN": "LLM Ranking",
    "en": "LLM Ranking"
  },
  "tracking.source": {
    "zh-CN": "数据来源",
    "en": "Source"
  },
  "tracking.updated_at": {
    "zh-CN": "更新时间",
    "en": "Updated"
  },
  "tracking.refresh": {
    "zh-CN": "刷新数据",
    "en": "Refresh"
  },
  "tracking.fetching": {
    "zh-CN": "正在获取数据...",
    "en": "Fetching data..."
  },
  "tracking.fetch_error": {
    "zh-CN": "获取失败：{error}",
    "en": "Fetch failed: {error}"
  },
  "tracking.rank": {
    "zh-CN": "排名",
    "en": "Rank"
  },
  "tracking.model": {
    "zh-CN": "模型",
    "en": "Model"
  },
  "tracking.provider": {
    "zh-CN": "提供商",
    "en": "Provider"
  },
  "tracking.score": {
    "zh-CN": "评分",
    "en": "Score"
  },
  "tracking.context_length": {
    "zh-CN": "上下文",
    "en": "Context"

  },

  "about.developer": {
    "zh-CN": "开发者：TimberTrail",
    "en": "Developer: TimberTrail"
  },
  "about.version": {
    "zh-CN": "版本：V1.1",
    "en": "Version: V1.1"
  },
  "about.license": {
    "zh-CN": "免费使用",
    "en": "Free to use"
  },
  "about.description": {
    "zh-CN": "跨平台屏幕用时管理工具，守护您的眼睛和健康",
    "en": "Cross-platform screen time manager, protecting your eyes and health"
  },

  "overtime.title": {
    "zh-CN": "屏幕用时已超计划",
    "en": "Screen Time Exceeded Plan"
  },
  "overtime.today_total": {
    "zh-CN": "今日累计用时",
    "en": "Today's Total"
  },
  "overtime.planned": {
    "zh-CN": "您的计划用时",
    "en": "Your Plan"
  },
  "overtime.exceeded": {
    "zh-CN": "已超出：{minutes} 分钟",
    "en": "Exceeded by: {minutes} min"
  },
  "overtime.suggestion": {
    "zh-CN": "建议适当休息，保护眼睛和身体",
    "en": "Consider taking a break to protect your eyes and health"
  },
  "overtime.acknowledge": {
    "zh-CN": "我知道了",
    "en": "Got it"
  },
  "overtime.reminder_title": {
    "zh-CN": "用时提醒",
    "en": "Time Reminder"
  },
  "overtime.continue": {
    "zh-CN": "继续使用",
    "en": "Continue"
  },
  "overtime.rest": {
    "zh-CN": "休息一下",
    "en": "Take a Break"
  },

  "weekly.title": {
    "zh-CN": "上周用时总结",
    "en": "Last Week Summary"
  },
  "weekly.last_week": {
    "zh-CN": "上周",
    "en": "Last Week"
  },
  "weekly.total": {
    "zh-CN": "上周总用时",
    "en": "Total"
  },
  "weekly.average": {
    "zh-CN": "日均用时",
    "en": "Daily Average"
  },
  "weekly.longest": {
    "zh-CN": "最长",
    "en": "Longest"
  },
  "weekly.shortest": {
    "zh-CN": "最短",
    "en": "Shortest"
  },
  "weekly.plan_prompt": {
    "zh-CN": "本周计划每天用时（小时）",
    "en": "Planned daily screen time this week (hours)"
  },
  "weekly.plan_default": {
    "zh-CN": "默认值为上周日均用时",
    "en": "Default is last week's daily average"
  },
  "weekly.confirm": {
    "zh-CN": "确认计划",
    "en": "Confirm Plan"
  },

  "stop_reason.eye_rest": {
    "zh-CN": "用眼休息",
    "en": "Eye Rest"
  },
  "stop_reason.posture_change": {
    "zh-CN": "姿势切换",
    "en": "Posture Change"
  },
  "stop_reason.lock_screen": {
    "zh-CN": "锁屏",
    "en": "Lock Screen"
  },
  "stop_reason.screensaver": {
    "zh-CN": "屏保",
    "en": "Screensaver"
  },
  "stop_reason.standby": {
    "zh-CN": "待机",
    "en": "Standby"
  },
  "stop_reason.shutdown": {
    "zh-CN": "关机",
    "en": "Shutdown"
  },
  "stop_reason.user_exit": {
    "zh-CN": "用户退出",
    "en": "User Exit"
  },
  "stop_reason.meeting_override": {
    "zh-CN": "会议模式关闭",
    "en": "Meeting Override"
  },
  "stop_reason.app_background": {
    "zh-CN": "App 切到后台",
    "en": "App Background"
  },

  "time.hours_minutes": {
    "zh-CN": "{hours}小时{minutes}分钟",
    "en": "{hours}h {minutes}m"
  },
  "time.minutes": {
    "zh-CN": "{minutes}分钟",
    "en": "{minutes}m"
  },
  "time.hours": {
    "zh-CN": "{hours}小时",
    "en": "{hours}h"
  },
  "time.days": {
    "zh-CN": "{days}天",
    "en": "{days} days"
  },

  "common.ok": {
    "zh-CN": "确定",
    "en": "OK"
  },
  "common.cancel": {
    "zh-CN": "取消",
    "en": "Cancel"
  },
  "common.save": {
    "zh-CN": "保存",
    "en": "Save"
  },
  "common.close": {
    "zh-CN": "关闭",
    "en": "Close"
  },
  "common.browse": {
    "zh-CN": "浏览...",
    "en": "Browse..."
  },
  "common.enabled": {
    "zh-CN": "开启",
    "en": "On"
  },
  "common.disabled": {
    "zh-CN": "关闭",
    "en": "Off"
  },
  "common.monday": {
    "zh-CN": "周一",
    "en": "Mon"
  },
  "common.tuesday": {
    "zh-CN": "周二",
    "en": "Tue"
  },
  "common.wednesday": {
    "zh-CN": "周三",
    "en": "Wed"
  },
  "common.thursday": {
    "zh-CN": "周四",
    "en": "Thu"
  },
  "common.friday": {
    "zh-CN": "周五",
    "en": "Fri"
  },
  "common.saturday": {
    "zh-CN": "周六",
    "en": "Sat"
  },
  "common.sunday": {
    "zh-CN": "周日",
    "en": "Sun"
  }
}
```

## 5.2 语言切换流程

```
ON language_changed(newLang):
  1. config.language = newLang
  2. IF newLang == "system":
       detectedLang = System.getLocale()  // zh-CN, en-US, etc.
       IF detectedLang.startsWith("zh"):
         effectiveLang = "zh-CN"
       ELSE:
         effectiveLang = "en"
  3. ELSE:
       effectiveLang = newLang

  4. loadTranslations(effectiveLang)
  5. updateAllUI()  // 刷新所有已打开的窗口/页面
  6. saveConfig()
```

---

# 第六部分：异常与边界处理

## 6.1 数据安全

| 场景 | 处理方式 | 恢复策略 |
|------|----------|----------|
| **应用崩溃** | 每次 Session 变更立即写入 state.json + sessions 文件 | 下次启动时读取 state.json，修复未关闭的 Session |
| **写入中断** | 使用原子写入（先写 .tmp 再 rename） | .tmp 文件存在则视为写入中断，重新写入 |
| **文件损坏** | 写入前备份为 .bak 文件 | 读取失败时尝试读取 .bak |
| **磁盘满** | 写入前检查可用空间 | 空间不足时警告用户，暂停记录 |
| **网盘同步冲突** | UUID 去重 + updatedAt 取最新 | 不丢数据，最终一致 |

## 6.2 时间边界

| 场景 | 处理方式 |
|------|----------|
| **午夜跨越** | Session 归入 startTime 所在日期 |
| **夏令时切换** | 使用 ISO 8601 存储（含时区偏移），计算时长用绝对时间差 |
| **时区变更** | 以当前系统时区为准，历史数据不重新计算 |
| **系统时间回拨** | 使用单调时钟（performance.now / System.nanoTime）计时，不依赖系统时间 |
| **系统时间前跳** | 检测到 > 1 小时的时间跳跃时，记录异常日志，正常处理 |

## 6.3 并发与多实例

| 场景 | 处理方式 |
|------|----------|
| **多实例启动** | 使用单实例锁，新实例通知已有实例并退出 |
| **多设备同时写入** | 网盘同步使用 .lock 文件 + UUID 去重 |
| **配置同时修改** | 以 updatedAt 取最新，合并后通知所有模块 |

## 6.4 网络与同步

| 场景 | 处理方式 |
|------|----------|
| **网盘文件夹不可用** | 本地继续工作，同步状态标记为"异常"，定期重试 |
| **网盘同步延迟** | 使用文件监听 + 定时轮询双保险 |
| **文件锁定超时** | .lock 文件超过 30 秒视为死锁，强制清除 |
| **首次同步数据量大** | 分批上传，显示进度条 |

## 6.5 用户操作边界

| 场景 | 处理方式 |
|------|----------|
| **快速开关屏（< 1 分钟）** | 忽略，不创建 Session |
| **弹窗期间锁屏** | 关闭弹窗，正常结束 Session |
| **弹窗期间应用被杀** | 依赖 state.json 恢复 |
| **设置为非法值** | 前端验证 + 后端兜底，不保存非法值 |
| **报告日期范围 > 90 天** | 提示用户缩小范围 |
| **无计划时超时检查** | 跳过，不弹窗 |

---

# 第七部分：性能指标与约束

| 指标 | 目标 | 测量方式 |
|------|------|----------|
| **内存占用（桌面端）** | < 100MB (RSS) | Task Manager / Activity Monitor |
| **内存占用（移动端）** | < 50MB | Android Profiler / Xcode Instruments |
| **CPU 占用（空闲时）** | < 1% | 系统监控 |
| **CPU 占用（计时中）** | < 0.1% | 系统监控 |
| **启动时间** | < 3 秒 | 从启动到后台驻留 |
| **弹窗响应时间** | < 500ms | 从定时器触发到弹窗显示 |
| **同步延迟** | < 30 秒 | 从数据变更到所有设备同步完成 |
| **本地存储（每月）** | < 50KB | 假设每天 30 条 Session |
| **网盘存储（每月）** | < 100KB | 含设备注册 + 配置 |
| **电池影响（移动端）** | < 2% / 天 | 系统电池统计 |

---

# 第八部分：开发里程碑与验收标准

## Phase 1：核心功能（第 1~2 周）

### 交付物
- [ ] 数据模型定义（所有实体）
- [ ] 本地存储层（JSON 文件读写）
- [ ] 屏幕状态检测（Windows + macOS + Android + iOS）
- [ ] 屏幕用时记录引擎（Session 创建/更新/结束）
- [ ] DailySummary 聚合
- [ ] 崩溃恢复（state.json）

### 验收标准
- [ ] 各平台能正确检测屏幕开/关/锁/待机事件
- [ ] Session 记录准确，误差 < 1 秒
- [ ] DailySummary 数据与 Session 一致
- [ ] 应用崩溃后重启，数据不丢失
- [ ] 快速开关屏（< 1 分钟）不创建记录

---

## Phase 2：提醒功能（第 3 周）

### 交付物
- [x] 用眼休息提醒（20 分钟触发，20 秒倒计时）
- [x] 姿势切换提醒（与用眼休息合并，40 分钟触发，2 分钟倒计时）
- [x] 合并弹窗 UI（桌面端 + 移动端）
- [x] 会议模式支持
- [x] 倒计时期间不可关闭

### 验收标准
- [x] 20 分钟定时器准确触发
- [x] 倒计时期间弹窗无法关闭
- [x] 会议模式下关闭按钮始终可见
- [x] 弹窗关闭后自动创建新 Session
- [x] 两个提醒不重叠（单一定时器 + 计数器）

---

## Phase 3：报告与设置（第 4 周）

### 交付物
- [ ] 日报生成
- [ ] 多日报生成
- [ ] 设置界面（所有配置项）
- [ ] 配置持久化
- [ ] 国际化（中/英）

### 验收标准
- [ ] 日报数据与 Session 记录一致
- [ ] 多日报日均计算正确
- [ ] 设置项保存后重启仍生效
- [ ] 中英文切换即时生效

---

## Phase 4：同步与总结（第 5~6 周）

### 交付物
- [x] P2P mDNS 局域网同步（替代原网盘方案）
- [x] mDNS 自动发现 + 设备审批
- [x] 配对码加密同步
- [x] 跨设备时间段去重
- [x] 每周用时总结
- [x] 超时提醒

### 验收标准
- [x] 两台设备在同一 WiFi 下自动发现
- [x] 用户手动批准后才能同步
- [x] 重叠时段不重复统计
- [x] 周一第一台设备正确触发周总结
- [x ] 超时提醒首次 + 每 25 分钟触发正确

---

## Phase 5：跟踪与完善（第 7 周）

### 交付物
- [ ] LLM Ranking 跟踪
- [ ] 跟踪界面（排序表格）
- [ ] 开机自启完善（各平台）
- [ ] 性能优化

### 验收标准
- [ ] OpenRouter 数据正确获取和缓存
- [ ] 表格排序功能正常
- [ ] 开机自启各平台正常工作
- [ ] 性能指标达标

---

## Phase 6：测试与发布（第 8 周）

### 交付物
- [ ] 全平台功能测试
- [ ] 边界情况测试
- [ ] 打包（Windows .exe/.msi, macOS .dmg, Android .apk, iOS .ipa）
- [ ] 用户文档

### 验收标准
- [ ] 所有验收标准通过
- [ ] 各平台打包成功
- [ ] 无 P0/P1 Bug

---

# 附录

## A. OpenRouter API 规格

### 请求

```
GET https://openrouter.ai/api/v1/rankings/overall
Authorization: Bearer {API_KEY}  // 可选，无 Key 有速率限制
```

### 响应

```json
{
  "data": [
    {
      "id": "anthropic/claude-3.5-sonnet",
      "name": "Claude 3.5 Sonnet",
      "provider": "Anthropic",
      "score": 95.2,
      "context_length": 200000
    }
  ]
}
```

### 错误处理

| 状态码 | 处理 |
|--------|------|
| 200 | 正常解析 |
| 429 | 等待 Retry-After 后重试，最多 3 次 |
| 5xx | 提示用户稍后重试 |
| 网络错误 | 提示用户检查网络 |

## B. 文件锁实现

```
ACQUIRE_LOCK(lockPath, timeoutMs = 30000):
  startTime = now
  WHILE (now - startTime) < timeoutMs:
    IF NOT EXISTS(lockPath):
      WRITE(lockPath, { pid: process.pid, timestamp: now })
      WAIT(100)  // 等待 100ms
      // 验证锁是否是自己写的（防止竞态）
      lockContent = READ(lockPath)
      IF lockContent.pid == process.pid:
        RETURN true
    WAIT(500)  // 等待 500ms 后重试
  RETURN false  // 超时

RELEASE_LOCK(lockPath):
  DELETE(lockPath)

// 死锁检测
CLEANUP_STALE_LOCKS(lockPath):
  IF EXISTS(lockPath):
    lockContent = READ(lockPath)
    IF (now - lockContent.timestamp) > 30000:  // 30 秒
      DELETE(lockPath)  // 清除死锁
```

## C. 时间格式化工具函数

```
formatDuration(seconds):
  hours = Math.floor(seconds / 3600)
  minutes = Math.floor((seconds % 3600) / 60)
  IF hours > 0 AND minutes > 0:
    RETURN i18n("time.hours_minutes", { hours, minutes })
  ELSE IF hours > 0:
    RETURN i18n("time.hours", { hours })
  ELSE:
    RETURN i18n("time.minutes", { minutes })

formatTime(iso8601):
  date = new Date(iso8601)
  RETURN date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })

formatDate(iso8601):
  date = new Date(iso8601)
  RETURN date.toLocaleDateString('zh-CN')

getMonday(date):
  d = new Date(date)
  day = d.getDay()
  diff = d.getDate() - day + (day == 0 ? -6 : 1)
  d.setDate(diff)
  RETURN d.toISOString().split('T')[0]
```

## D. 设备 ID 生成

```
generateDeviceId():
  // 首次运行时生成并持久化
  IF device.json EXISTS:
    RETURN device.json.deviceId

  platform = detectPlatform()
  uuid = generateUUID()
  shortId = uuid.split('-')[0]  // 取前 8 位
  deviceId = "dev-{platform}-{shortId}"

  deviceInfo = {
    deviceId: deviceId,
    deviceName: getDefaultDeviceName(),
    platform: platform,
    registeredAt: now,
    lastSyncAt: null,
    lastActiveAt: null,
    appVersion: APP_VERSION
  }

  WRITE(device.json, deviceInfo)
  RETURN deviceId
```

---

> **文档版本**：V2.1
> **最后更新**：2026-08-01
> **作者**：TimberTrail
> **页数**：约 130 页（A4 排版）

---

# 变更日志（Changelog）

## V1.0.7（2026-08-01）

### 重大变更

1. **同步方案重构：网盘 → P2P mDNS**
   - 完全移除网盘文件夹同步方案（SyncService）
   - 改用 mDNS（组播 DNS，与 Apple Bonjour 同协议）局域网自动发现
   - HTTP REST API 直接交换数据，端口 19090
   - 配对码加密：SHA256 密钥派生 + XOR 加密 + HMAC 完整性校验
   - 所有数据仅存储在本地设备，不依赖任何云服务

2. **提醒模块合并：M4 + M5**
   - 用眼休息（M4）和姿势切换（M5）合并为统一提醒模块
   - 单一定时器每 20 分钟触发，计数器控制
   - 第 1 次（20min）：仅用眼休息，倒计时 20 秒
   - 第 2 次（40min）：合并提醒（姿势切换 + 用眼休息），倒计时 2 分钟
   - 移除 `postureIntervalMinutes` 配置项（固定 = 2× 用眼休息间隔）

3. **跨设备时间段去重**
   - 新增区间合并算法（Interval Merge）
   - 多设备同时段使用不重复统计（如手机+电脑同时 9:00-10:00 只算 1 小时）
   - `getTodayTotalSeconds()` 和 `updateDailySummary()` 均使用去重计算

### 其他变更

4. **版本号单一来源**
   - Mobile: `constants.dart` 中定义 `appVersion`
   - Desktop: `package.json` 中定义，TypeScript 通过 `require()` 读取
   - 其他各处从上述来源引用，不再硬编码

5. **国际化完善**
   - 所有提醒窗口（包括桌面端 HTML 模板）全部通过 i18n 系统渲染
   - 移除所有 `isZh()` 硬编码判断
   - 设置成英文时，提醒窗口也全英文

6. **About 页面更新**
   - 新增「隐私与同步说明」卡片
   - 说明 P2P 同步机制、无云存储、设备审批机制

7. **设置页面更新**
   - P2P 设备审批集成到设置界面
   - 移除网盘同步路径配置
   - 移除姿势切换间隔滑块（改为固定 40 分钟说明）

8. **周计划管理（移动端新增）**
   - 新增 `weekly_plan_screen.dart`：设定每日目标、查看进度
   - 新增 `overtime_alert_dialog.dart`：超时提醒弹窗组件
   - 首页菜单从 2×2 扩展为 2×3，新增周计划入口

9. **iOS ScreenTime API 集成**
   - iOS 端完全改用 ScreenTime API（DeviceActivityMonitor Extension）
   - 由系统管理扩展生命周期，不会被杀进程
   - Shield 全屏遮罩作为提醒 UI，覆盖所有应用
   - App Group 共享数据（UserDefaults）
   - 需要 Family Controls 授权
   - Flutter ↔ Swift 桥接插件（MethodChannel）

### 涉及文件

| 平台 | 新增 | 修改 | 删除 |
|------|------|------|------|
| Mobile | `weekly_plan_screen.dart`, `overtime_alert_dialog.dart`, `combined_reminder_dialog.dart`, `screentime_service.dart` | `main.dart`, `reminder_manager.dart`, `p2p_sync_service.dart`, `local_store.dart`, `i18n.dart`, `home_screen.dart`, `settings_screen.dart`, `about_screen.dart`, `constants.dart`, `pubspec.yaml` | `sync_service.dart` |
| iOS Extension | `DeviceActivityMonitorExtension.swift`, `ScreenTimePlugin.swift`, `Info.plist`, entitlements ×2 | — | — |
| Desktop | `p2p-sync-service.ts` (mDNS) | `main.ts`, `reminder-manager.ts`, `local-store.ts`, `i18n.ts`, `types.ts`, `preload.ts`, `index.html`, `app.js`, `main.css`, `package.json` | `sync-service.ts` |
