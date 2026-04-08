# Descend — Native Swift/SpriteKit

从 Phaser 3 + TypeScript + Capacitor 迁移而来的原生 iOS 休闲手游。

## 项目概况

- **游戏类型**: 无尽下落休闲游戏，玩家控制角色在不断上升的平台间穿梭
- **技术栈**: Swift + SpriteKit（全 SpriteKit，不含 SwiftUI）
- **最低支持**: iOS 16.0+
- **Bundle ID**: `com.cheung.Descend`
- **原始项目**: `/Users/cheung/workspace/falling/`（Phaser 3 版本，仅作参考）

## 项目结构

```
Descend/
├── Descend/                      # 唯一 target，所有源码和资源
│   ├── AppDelegate.swift         # App 生命周期
│   ├── GameViewController.swift  # SKView 配置
│   ├── Base.lproj/               # Storyboard
│   ├── Assets.xcassets/          # 图片资源
│   │   ├── AppIcon.appiconset/
│   │   ├── player.imageset/      # 玩家精灵 (128x128, 显示 28x28)
│   │   └── splash.imageset/
│   ├── Audio/                    # 音频资源
│   │   ├── pixel-heartbeat.mp3   # 暗色主题 BGM
│   │   └── sugar-sky.mp3         # 亮色主题 BGM
│   ├── Localizable.xcstrings     # 本地化
│   ├── Scenes/
│   │   └── GameScene.swift       # SKScene 主场景
│   ├── Models/                   # 数据类型和配置
│   │   ├── DifficultyConfig.swift
│   │   └── GameTypes.swift
│   ├── Theme/                    # 主题系统
│   │   ├── ThemeManager.swift
│   │   ├── ThemeDefinition.swift
│   │   ├── DarkTheme.swift
│   │   └── LightTheme.swift
│   ├── Nodes/                    # SpriteKit 节点
│   │   ├── PlayerNode.swift
│   │   └── PlatformNode.swift
│   ├── Systems/                  # 游戏系统
│   │   ├── PlatformSystem.swift
│   │   ├── PlatformSpawnStrategy.swift
│   │   ├── InputHandler.swift
│   │   └── VisualEffects.swift
│   ├── UI/                       # SpriteKit UI 组件
│   │   ├── UIFactory.swift
│   │   ├── StartOverlay.swift
│   │   └── GameOverOverlay.swift
│   ├── Managers/                 # 音频/触觉管理
│   │   ├── AudioManager.swift
│   │   └── HapticsManager.swift
│   └── Extensions/
│       ├── CGFloat+Lerp.swift
│       └── UIColor+Hex.swift
│
└── Descend.xcodeproj/
```

## 游戏核心参数

### 物理
| 参数 | 值 |
|------|-----|
| 场景尺寸 | 375 × 667 pt |
| 重力 | `CGVector(dx: 0, dy: -600)` |
| 玩家尺寸 | 28×28 (scale 0.22 from 128px) |
| 最大速度 | X: 300, Y: 200 px/s |
| X 轴阻力 | 100 (手动逐帧衰减) |
| 碰撞体 | 显示尺寸的 85% |
| 平台高度 | 20px |

### 输入
| 参数 | 值 |
|------|-----|
| 速度计算 | `diff * 15`, 夹紧 ±400 |
| 释放动量 | 当前速度 × 0.5 |
| X 位置范围 | 20 ~ sceneWidth-20 |

### 难度曲线 (score 0 → 800)
| 参数 | 起始 | 终值 |
|------|------|------|
| 上升速度 | 180 px/s | 500 px/s |
| 平台间距 | 160 px | 240 px |
| 平台宽度 | 120 px | 45 px |
| 休息平台 | 每 15 个 | 宽×1.5, 间距×0.8 |

### 生成策略
- 侧向切换概率: 70%
- 最大连续同侧: 2
- 跳跃距离: 40-200 px
- 宽度随机: ±10%
- 对象池: max 20
- 提前生成: 2.5 秒缓冲

### 碰撞反馈
- 相机震动: 80ms, intensity = velocity/200 * 0.008
- 触觉: velocity > 300 → medium, 否则 light
- 挤压动画: 50ms 压 → 70ms 弹 → 120ms Elastic 恢复
- 粒子: 8 块 + 6 火花, 400ms
- 冲击环: 2 个, 250ms/330ms

### 失败条件
- 顶部: `player.y > sceneHeight - 35` (SpriteKit 坐标)
- 底部: `player.y < 50`

## 主题系统

### 暗色 (Neon Cyberpunk)
- 背景: `#0A0A2E` → `#1A0A1A`
- 平台 5 色: cyan `#00FFFF`, magenta `#FF00FF`, green `#00FF88`, yellow `#FFFF00`, pink `#FF0088`
- UI 文字: cyan `#00FFFF`, 4px 黑色描边
- 危险区: `#FF0088`, alpha 0.25
- BGM: `pixel-heartbeat.mp3`

### 亮色 (Glassmorphism Pastel)
- 背景: `#E8F4FD` → `#FDF4E8`
- 平台 5 色: coral `#FF8A65`, mint `#81C784`, sky `#64B5F6`, sunflower `#FFD54F`, lavender `#BA68C8`
- UI 文字: slate `#1A1A2E`, 无描边
- 危险区: `#FF6B6B`, alpha 0.08
- BGM: `sugar-sky.mp3`

### 主题切换
- 跟随系统 `UITraitCollection.userInterfaceStyle`
- 实时切换: 重新生成平台纹理、更新背景/UI/星星、BGM 交叉淡入淡出 (1000ms)

## 本地化

4 语言: zh (简中), zh-Hant (繁中), en (英), ja (日)

关键文本:
- `tapToStart`: 点击屏幕开始 / 點擊屏幕開始 / Tap to Start / タップして開始
- `gameOver`: 游戏结束! / 遊戲結束! / Game Over! / ゲームオーバー!
- `tapToRestart`: 点击重新开始 / 點擊重新開始 / Tap to Restart / タップして再開

## 坐标系注意

**Phaser** Y=0 在顶部, **SpriteKit** Y=0 在底部。所有从原始代码移植的 Y 值需要翻转:
```swift
let skY = sceneHeight - phaserY
```
- 重力: Phaser `{y: 600}` → SpriteKit `{dx: 0, dy: -600}`
- 平台上升: Phaser `velocity.y = -speed` → SpriteKit `position.y += speed * dt`

## 原始 TypeScript 参考

迁移时对照的源文件（在 `/Users/cheung/workspace/falling/src/` 下）:

| Swift 目标 | TypeScript 源 | 行数 |
|-----------|--------------|------|
| GameScene.swift | game-scene.ts | 511 |
| PlatformSystem.swift | platform-system.ts | 350 |
| VisualEffects.swift | visual-effects.ts | 414 |
| UIFactory/Overlays | ui-components.ts | 452 |
| AudioManager.swift | audio-manager.ts | 343 |
| PlatformSpawnStrategy.swift | platform-spawn-strategy.ts | 191 |
| DifficultyConfig.swift | game-config.ts | 129 |
| InputHandler.swift | input-handler.ts | 103 |
| GameTypes.swift | types.ts | 99 |
| PlayerNode.swift | player-controller.ts | 70 |
| Theme/* | theme/* | 296 |
| HapticsManager.swift | haptics.ts | 32 |

## 开发规范

- 使用 SpriteKit 原生 API，不引入第三方依赖
- 对象池模式管理平台节点（避免频繁 alloc/dealloc）
- 平台纹理用 `UIGraphicsImageRenderer` 程序化生成，缓存为 `SKTexture`
- 物理碰撞用位掩码: `player = 0x1`, `platform = 0x2`, `boundary = 0x4`
- 手动限制最大速度和 X 轴阻力（SpriteKit 内置 linearDamping 影响 Y 轴不适用）
- 分数 dirty check: 仅值变化时更新 SKLabelNode
