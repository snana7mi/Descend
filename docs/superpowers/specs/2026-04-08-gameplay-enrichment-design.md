# Descend 玩法丰富化设计文档

> 日期: 2026-04-08
> 范围: 特殊平台 + 道具 + 随机事件 + 计分改造 + 视觉音效反馈
> 不包含: 排行榜、持久化、暂停功能（后续迭代）

---

## 1. 总体架构：组件化系统

采用组件化方案，三套新机制各自独立为系统，通过统一的时间驱动难度管理器协调。

### 系统交互图

```
GameScene.update(dt)
  │
  ├─→ TimeBasedDifficulty.update(dt)
  │     └─→ 输出: Difficulty (含重力、速度、解锁状态、波浪系数)
  │
  ├─→ PlatformSystem.update(dt, difficulty)
  │     ├─→ PlatformSpawnStrategy.getNextPlatform()
  │     ├─→ 分配 PlatformBehavior (基于解锁状态 + 概率)
  │     └─→ 通知 ItemSystem 新平台位置 (用于道具生成)
  │
  ├─→ ItemSystem.update(dt, player, difficulty)
  │     ├─→ 生成/回收道具
  │     ├─→ 拾取检测
  │     └─→ 效果倒计时
  │
  ├─→ EventSystem.update(dt, difficulty)
  │     ├─→ 调度新事件
  │     └─→ 管理激活中事件生命周期
  │
  ├─→ ScoreSystem (被动，由碰撞/拾取触发 addScore)
  │
  ├─→ 物理: physicsWorld.gravity = difficulty.gravity
  │
  └─→ VisualEffects.update(...)
```

### 系统间查询（解耦）

- `InputHandler` 查询 `ItemSystem.isActive(.ice)` 决定阻力
- `GameScene` 碰撞处理查询 `ItemSystem.isActive(.shield)` 决定是否免死
- `PlatformSystem` 查询 `ItemSystem.isActive(.wideScreen)` 决定宽度倍率
- `PlatformSystem` 查询 `EventSystem.activeEvent` 决定抖动/缩减
- `TimeBasedDifficulty` 查询 `ItemSystem.isActive(.freeze)` 决定是否暂停上升
- `ScoreSystem` 查询 `ItemSystem.isActive(.doubleScore)` 决定是否翻倍

---

## 2. 时间驱动难度系统

替换现有 score-based `DifficultyConfig`，改为时间驱动 + 波浪式 + 封顶。

### 核心参数

| 参数 | 起始 | 封顶值 | 封顶时间 |
|------|------|--------|----------|
| 上升速度 | 180 px/s | 500 px/s | 300s (5min) |
| 重力 | -200 | -600 | 300s |
| 平台间距 | 160 px | 240 px | 300s |
| 平台宽度 | 120 px | 45 px | 300s |
| 最大下落速度 | -120 | -300 | 300s |
| 休息平台间隔 | 每 15 个 | 每 25 个 | 300s |

### 波浪机制

- 周期：60 秒
- 波谷（喘息）：难度回退 15%，持续约 8 秒
- 公式：`effectiveDifficulty = baseDifficulty * (1 - 0.15 * sin(wavePhase))`
- 波谷期间上升速度、间距、重力都同步放松

### 内容解锁时间线

| 时间 | 解锁内容 |
|------|----------|
| 0s | 普通平台 + 休息平台 |
| 30s | 移动平台 |
| 60s | 易碎平台、常见道具开始出现 |
| 90s | 冰面平台、弹跳平台 |
| 120s | 传送平台、稀有道具（空中漂浮）|
| 150s | 缩小平台、第一种随机事件 |
| 180s | 隐形平台、更多随机事件 |
| 210s+ | 所有内容已解锁，概率随时间继续调整 |

### Difficulty 结构体扩展

现有 `Difficulty` 结构体新增以下字段：

```swift
struct Difficulty {
    // 现有
    let riseSpeed: CGFloat
    let spawnInterval: TimeInterval
    let platformWidthMin: CGFloat
    let platformWidthMax: CGFloat
    let isRestPlatform: Bool
    // 新增
    let gravity: CGFloat              // -200 → -600
    let maxFallSpeed: CGFloat         // -120 → -300
    let elapsedTime: TimeInterval     // 已存活秒数
    let waveFactor: CGFloat           // 0.85 ~ 1.0，波浪系数
    let unlockedPlatformTypes: Set<PlatformType>
    let unlockedItemTypes: Set<ItemType>
    let eventsEnabled: Bool           // 事件是否已解锁
    let specialPlatformChance: CGFloat // 0.1 → 0.4
    let isBreathingPhase: Bool        // 当前是否处于波浪喘息期
}
```

### 新文件

- `Systems/TimeBasedDifficulty.swift` — 替代 `DifficultyConfig`，持有 `elapsedTime`，输出包含解锁状态的扩展 `Difficulty` 结构体

---

## 3. 特殊平台系统

### 架构

引入 `PlatformBehavior` 协议，每种特殊行为独立实现。`PlatformNode` 持有可选的 `behavior` 属性。

```
Nodes/
├── PlatformNode.swift          # 持有 behavior: PlatformBehavior?
├── Behaviors/
│   ├── PlatformBehavior.swift  # 协议: update(dt:), onPlayerLand(player:), onRecycle()
│   ├── MovingBehavior.swift
│   ├── FragileBehavior.swift
│   ├── IceBehavior.swift
│   ├── BouncyBehavior.swift
│   ├── TeleportBehavior.swift
│   ├── ShrinkingBehavior.swift
│   └── InvisibleBehavior.swift
```

普通平台和休息平台 `behavior = nil`，零开销。

### 7 种特殊平台

| 类型 | 解锁 | 行为 | 视觉提示 |
|------|------|------|----------|
| **移动平台** | 30s | 左右匀速移动，速度 40-80 px/s，到边缘反弹 | 两端有小箭头标记 |
| **易碎平台** | 60s | 落上去后 0.5s 碎裂消失，有碎裂粒子效果 | 裂纹纹理，颜色偏暗 |
| **冰面平台** | 90s | 落上去后 X 轴阻力降为 0，玩家会滑行 | 半透明浅蓝，表面有光泽 |
| **弹跳平台** | 90s | 落上去后给一个向上的冲量，弹飞玩家 | 亮绿色，有弹簧纹理 |
| **传送平台** | 120s | 成对出现，落上去瞬移到配对平台位置（带 0.3s 闪烁动画）。若配对平台已滚出屏幕则退化为普通平台 | 紫色旋涡纹理，两个一组 |
| **缩小平台** | 150s | 每次被踩宽度缩小 30%，缩到阈值以下消失 | 踩上去有收缩动画 |
| **隐形平台** | 180s | 平时不可见，玩家靠近时（距离 < 80px）渐显 | 若隐若现的虚线轮廓 |

### 生成规则

- 特殊平台概率随时间增加：解锁时 10% → 逐步升至 40%
- 不连续生成同类型特殊平台（避免连续 3 个易碎让人无处站）
- 传送平台必须成对生成，第二个在 2-4 个平台后出现
- 休息平台永远是普通平台，保证喘息
- 波浪喘息期间特殊平台概率降低 50%

### 对象池扩展

现有 `PlatformSystem` 的池化机制不变，回收时 `behavior = nil` 重置为普通平台，重新分配时按需赋予新 behavior。

### 纹理生成

延续现有程序化生成方式（`UIGraphicsImageRenderer`），为每种特殊平台类型生成带视觉标记的纹理，按主题色 + 类型缓存为 `SKTexture`。

---

## 4. 道具系统

### 架构

```
Nodes/
├── ItemNode.swift              # SKSpriteNode 子类，持有 itemType
Systems/
├── ItemSystem.swift            # 生成、回收、拾取检测、效果管理
Models/
├── GameTypes.swift             # ItemType 枚举新增于此
```

`ItemSystem` 拥有独立对象池（max 10），每帧检测玩家与道具的距离进行拾取（不走物理碰撞，避免增加碰撞矩阵复杂度）。

### 常见道具（平台上方生成，落到平台自动拾取）

| 道具 | 解锁 | 效果 | 持续时间 | 视觉 |
|------|------|------|----------|------|
| **减速** | 60s | 上升速度降低 40% | 5s | 蓝色时钟图标 |
| **护盾** | 60s | 免疫一次死亡（触顶/触底弹回） | 单次 | 金色圆环包围玩家 |
| **宽屏** | 90s | 所有新生成平台宽度 ×1.5 | 6s | 绿色横向箭头 |
| **磁铁** | 120s | 玩家自动吸附最近平台的 X 中心 | 4s | 红色 U 形磁铁 |

### 稀有道具（空中漂浮，需要主动偏移路线拾取）

| 道具 | 解锁 | 效果 | 持续时间 | 视觉 |
|------|------|------|----------|------|
| **2x 分数** | 120s | 所有得分翻倍 | 8s | 金色 "×2" |
| **幽灵** | 150s | 穿透平台不碰撞，自由下落。效果结束前 0.5s 玩家闪烁警告；结束瞬间若下方无平台则在玩家脚下生成一个临时普通平台 | 3s | 白色半透明玩家 |
| **冻结** | 150s | 平台停止上升 | 4s | 冰蓝色雪花 |
| **炸弹** | 180s | 清除屏幕上所有特殊/危险平台，替换为普通平台 | 即时 | 红色炸弹 |

### 生成规则

- 常见道具：每 8-15 个平台随机出现一个，放在平台上方 20px
- 稀有道具：每 20-30 个平台随机出现一个，位置在两个平台之间的空隙中偏移
- 同时最多存在 2 个道具
- 同一效果不能叠加，重复拾取刷新持续时间
- 波浪喘息期间道具生成概率提高（奖励存活）

### 效果管理

`ItemSystem` 维护 `activeEffects: [ItemType: TimeInterval]` 字典，每帧倒计时。外部系统通过 `ItemSystem.isActive(_:)` 查询。

### 视觉反馈

- 护盾图标在玩家身上显示金色光环
- 其他持续性效果在屏幕顶部显示小图标 + 倒计时进度条

---

## 5. 随机事件系统

### 架构

```
Systems/
├── EventSystem.swift           # 事件调度、激活、结束
Models/
├── GameTypes.swift             # GameEvent 枚举新增于此
```

`EventSystem` 独立运行计时器，随机触发全局事件。事件生命周期：预告（1.5s 警告动画）→ 激活 → 结束。

### 6 种随机事件

| 事件 | 解锁 | 效果 | 持续时间 | 预告提示 |
|------|------|------|----------|----------|
| **重力反转** | 150s | 重力翻转为正值，玩家向上"下落"，平台向下移动。死亡区交换：顶部变为"底部"死亡区，底部变为"顶部"死亡区。结束时重力平滑过渡回正常（0.5s 线性插值） | 6s | 屏幕中央闪烁 ↑↑↑ 箭头 |
| **迷雾** | 150s | 视野缩小到玩家周围圆形区域，其余变暗 | 8s | 屏幕边缘黑雾渐入 |
| **地震** | 180s | 所有平台随机水平抖动 ±15px | 5s | 屏幕微震 + 警告条纹 |
| **加速风暴** | 180s | 上升速度暴增 50% | 5s | 屏幕两侧出现速度线 |
| **平台缩减** | 210s | 所有现存平台宽度缩小 25% | 7s | 平台边缘闪烁 |
| **混乱重力** | 210s | 重力方向每 1.5s 随机偏移（加入水平分量） | 6s | 屏幕颜色失真 |

### 调度规则

- 首次事件不早于 150s
- 每两次事件间隔：最短 30s，最长 60s（随时间缩短至 20-40s）
- 同时只能有一个事件激活
- 事件不在波浪喘息期间触发（让喘息真正安全）
- 重力反转期间不触发其他事件
- 事件结束后有 3s 的"冷却安全期"

### 预告系统

每个事件触发前 1.5s 显示预告动画，给玩家反应时间：
- 屏幕边缘闪烁主题色警告条
- 中央显示事件图标 + 名称（本地化），1.5s 后淡出
- 预告期间游戏正常进行，不暂停

### 与其他系统的交互

- 重力反转：`TimeBasedDifficulty` 输出反向重力值，`PlatformSystem` 反向移动平台
- 迷雾：`VisualEffects` 添加遮罩层，玩家周围用 `SKCropNode` 开洞
- 护盾道具不能抵消事件（事件是全局的，护盾只防死亡）
- 冻结道具生效期间如果触发事件，事件正常进行但平台不动

---

## 6. 计分系统

### 得分来源

| 来源 | 基础分 | 说明 |
|------|--------|------|
| 普通平台 | 10 | 不变 |
| 特殊平台 | 15 | 有风险多给 |
| 易碎/隐形平台 | 20 | 高风险额外奖励 |
| 拾取常见道具 | 5 | 小奖励 |
| 拾取稀有道具 | 25 | 冒险值得 |
| 存活事件 | 30 | 撑过一次随机事件的奖励 |

### 连击系统

- 连续落在平台上（中间不超过 1.5s 滞空）触发连击
- 连击倍率：1x → 2 连 1.2x → 4 连 1.5x → 8 连 2.0x → 12 连 3.0x（封顶）
- 倍率应用于所有得分来源
- 滞空超过 1.5s 或触发护盾保命，连击重置

### 视觉反馈

- 连击数在分数旁显示（"×8"），高倍率时字体放大 + 颜色变亮
- 每次得分在平台位置弹出 "+10" 浮动文字，0.5s 上飘消失
- 连击加分时浮动文字带金色
- 2x 道具期间浮动文字显示双倍值

### 新文件

- `Systems/ScoreSystem.swift` — 管理得分、连击倍率、2x 叠加，提供 `addScore(source:)` 接口

---

## 7. 视觉与音效反馈

### 新增视觉效果（扩展 VisualEffects.swift）

| 效果 | 触发时机 | 表现 |
|------|----------|------|
| 平台解锁提示 | 新类型首次出现 | 屏幕底部弹出横幅 "新平台: 移动平台!"，1.5s 淡出 |
| 道具拾取闪光 | 拾取道具 | 玩家位置放射状光芒 + 道具图标上飘消失 |
| 道具倒计时条 | 持续性道具激活中 | 屏幕顶部小图标 + 缩短进度条 |
| 事件预告 | 事件触发前 1.5s | 屏幕边缘警告条闪烁 + 中央图标 |
| 事件激活滤镜 | 事件进行中 | 迷雾遮罩、重力反转背景偏移、地震抖动等 |
| 连击火焰 | 连击 ≥ 4 | 玩家尾部拖出火焰拖尾，连击越高越亮 |
| 护盾光环 | 护盾激活中 | 玩家周围金色半透明圆环，受击时碎裂动画 |

### 图片素材方案

全程序化生成为主，SF Symbols 补充：
- **特殊平台纹理** — `UIGraphicsImageRenderer` 程序化绘制，延续现有风格，按主题色 + 类型缓存
- **道具图标** — `UIBezierPath` 绘制几何图形（圆环、闪电、U 形等），自动适配主题色
- **个别复杂图标** — 用 `UIImage(systemName:)` 从 SF Symbols 获取（iOS 16+ 全部可用）
- 零外部图片依赖，两套主题自动适配

### 音效规划

扩展 `AudioManager`，新增 SFX 播放（`SKAction.playSoundFileNamed`）。

| 音效 | 触发时机 | 风格 |
|------|----------|------|
| `land.wav` | 落到平台 | 短促 thud，pitch 随冲击力变化 |
| `land_special.wav` | 落到特殊平台 | 带电子音色的 thud |
| `fragile_crack.wav` | 易碎平台碎裂 | 玻璃碎裂声 |
| `bounce.wav` | 弹跳平台弹起 | 弹簧 boing |
| `teleport.wav` | 传送平台传送 | 空间扭曲音 |
| `ice_slide.wav` | 冰面平台滑行 | 冰面摩擦声 |
| `item_common.wav` | 拾取常见道具 | 清脆 ding |
| `item_rare.wav` | 拾取稀有道具 | 华丽上升音阶 |
| `event_warning.wav` | 事件预告 | 低频警报 |
| `event_end.wav` | 事件结束 | 解除音效 |
| `combo_up.wav` | 连击提升 | 递增音调，越高越亮 |
| `combo_break.wav` | 连击断裂 | 短促下降音 |
| `shield_break.wav` | 护盾消耗 | 碎裂 + 回响 |
| `death.wav` | 死亡 | 低沉坠落音 |

音效文件放在 `Descend/Audio/SFX/` 目录下。

### 音效素材来源

- **Kenney.nl**（CC0，免费商用无需署名）— 游戏音效包覆盖 80% 需求：Impact Sounds、UI Audio、Digital Audio
- **freesound.org**（CC0/CC-BY）— 补充特殊音效（传送、冰面滑行等）

---

## 8. 文件结构总览

### 新增/修改文件清单

```
Descend/
├── Models/
│   ├── GameTypes.swift            # [修改] 新增 PlatformType、ItemType、GameEvent 枚举
│   ├── DifficultyConfig.swift     # [删除] 被 TimeBasedDifficulty 替代
│
├── Nodes/
│   ├── PlatformNode.swift         # [修改] 新增 behavior 属性 + 类型标记
│   ├── ItemNode.swift             # [新增] 道具精灵节点
│   ├── Behaviors/
│   │   ├── PlatformBehavior.swift # [新增] 协议
│   │   ├── MovingBehavior.swift   # [新增]
│   │   ├── FragileBehavior.swift  # [新增]
│   │   ├── IceBehavior.swift      # [新增]
│   │   ├── BouncyBehavior.swift   # [新增]
│   │   ├── TeleportBehavior.swift # [新增]
│   │   ├── ShrinkingBehavior.swift# [新增]
│   │   └── InvisibleBehavior.swift# [新增]
│
├── Systems/
│   ├── TimeBasedDifficulty.swift  # [新增] 替代 DifficultyConfig
│   ├── ItemSystem.swift           # [新增] 道具生成/拾取/效果管理
│   ├── EventSystem.swift          # [新增] 随机事件调度
│   ├── ScoreSystem.swift          # [新增] 计分 + 连击
│   ├── PlatformSystem.swift       # [修改] 对接 behavior 分配 + 道具生成通知
│   ├── PlatformSpawnStrategy.swift# [修改] 特殊平台不连续规则
│   ├── VisualEffects.swift        # [修改] 新增道具/事件/连击视觉效果
│   └── InputHandler.swift         # [修改] 冰面阻力、磁铁吸附查询 ItemSystem
│
├── Managers/
│   └── AudioManager.swift         # [修改] 新增 SFX 播放
│
├── Scenes/
│   └── GameScene.swift            # [修改] 组装新系统、更新循环
│
├── Audio/
│   └── SFX/                       # [新增] 音效文件目录 (14 个 wav 文件)
```
