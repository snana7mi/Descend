# Gameplay Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 7 special platform types, 8 items, 6 random events, combo scoring, and time-based difficulty to the Descend endless falling game.

**Architecture:** Component-based system design. Each new mechanic is an independent system (`TimeBasedDifficulty`, `ItemSystem`, `EventSystem`, `ScoreSystem`) coordinated through a shared `Difficulty` struct. Platform behaviors use a protocol pattern — `PlatformNode` holds an optional `PlatformBehavior` that handles type-specific logic. Systems communicate via queries (e.g. `ItemSystem.isActive(.shield)`), not callbacks.

**Tech Stack:** Swift, SpriteKit, UIGraphicsImageRenderer for programmatic textures, AVFoundation for audio, SF Symbols for item icons.

**Build/run:** `xcodebuild -project Descend.xcodeproj -scheme Descend -destination 'platform=iOS Simulator,name=iPhone 16' build` or open in Xcode and Cmd+R. No unit test target exists — verify by building and play-testing.

**Spec:** `docs/superpowers/specs/2026-04-08-gameplay-enrichment-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `Systems/TimeBasedDifficulty.swift` | Time-driven difficulty with wave breathing, replaces `DifficultyConfig` |
| `Systems/ScoreSystem.swift` | Score tracking, combo multiplier, floating text |
| `Systems/ItemSystem.swift` | Item spawning, pickup detection, active effects management |
| `Systems/EventSystem.swift` | Random event scheduling, lifecycle, active event state |
| `Nodes/ItemNode.swift` | SKSpriteNode subclass for collectible items |
| `Nodes/Behaviors/PlatformBehavior.swift` | Protocol definition |
| `Nodes/Behaviors/MovingBehavior.swift` | Left-right oscillation |
| `Nodes/Behaviors/FragileBehavior.swift` | Crack + collapse after landing |
| `Nodes/Behaviors/IceBehavior.swift` | Zero X-axis drag on landing |
| `Nodes/Behaviors/BouncyBehavior.swift` | Upward impulse on landing |
| `Nodes/Behaviors/TeleportBehavior.swift` | Paired teleportation |
| `Nodes/Behaviors/ShrinkingBehavior.swift` | Width shrink per stomp |
| `Nodes/Behaviors/InvisibleBehavior.swift` | Proximity-based visibility |

### Modified Files

| File | Changes |
|------|---------|
| `Models/GameTypes.swift` | Add `PlatformType`, `ItemType`, `GameEvent`, `ScoreSource` enums; extend `Difficulty` struct |
| `Models/DifficultyConfig.swift` | Delete (replaced by `TimeBasedDifficulty`) |
| `Nodes/PlatformNode.swift` | Add `behavior: PlatformBehavior?`, `platformType: PlatformType`, update `activate`/`deactivate` |
| `Systems/PlatformSystem.swift` | Integrate behavior assignment, item spawn notifications, query `ItemSystem`/`EventSystem` |
| `Systems/PlatformSpawnStrategy.swift` | Add no-consecutive-same-type rule |
| `Systems/InputHandler.swift` | Query `ItemSystem` for ice/magnet effects |
| `Systems/VisualEffects.swift` | Add unlock banners, item pickup flash, combo flames, shield glow, event filters, score popups |
| `Managers/AudioManager.swift` | Add SFX playback via `SKAction.playSoundFileNamed` |
| `Scenes/GameScene.swift` | Wire up all new systems in update loop and collision handler |

---

## Phase 1: Foundation — Types, Difficulty, Score

### Task 1: Extend GameTypes with new enums and Difficulty struct

**Files:**
- Modify: `Descend/Models/GameTypes.swift`

- [ ] **Step 1: Add PlatformType enum**

Add after the existing `SpawnStrategyConfig` struct at the end of the file:

```swift
// MARK: - Platform Type

enum PlatformType: CaseIterable {
    case normal
    case rest
    case moving
    case fragile
    case ice
    case bouncy
    case teleport
    case shrinking
    case invisible
}
```

- [ ] **Step 2: Add ItemType enum**

```swift
// MARK: - Item Type

enum ItemType: CaseIterable {
    // Common (spawn on platforms)
    case slowDown
    case shield
    case wideScreen
    case magnet
    // Rare (floating in air)
    case doubleScore
    case ghost
    case freeze
    case bomb

    var isRare: Bool {
        switch self {
        case .doubleScore, .ghost, .freeze, .bomb: return true
        default: return false
        }
    }

    var duration: TimeInterval {
        switch self {
        case .slowDown: return 5
        case .shield: return .infinity // single use
        case .wideScreen: return 6
        case .magnet: return 4
        case .doubleScore: return 8
        case .ghost: return 3
        case .freeze: return 4
        case .bomb: return 0 // instant
        }
    }

    var baseScore: Int {
        return isRare ? 25 : 5
    }
}
```

- [ ] **Step 3: Add GameEvent enum**

```swift
// MARK: - Game Event

enum GameEvent: CaseIterable {
    case gravityReverse
    case fog
    case earthquake
    case speedStorm
    case platformShrink
    case chaosGravity

    var duration: TimeInterval {
        switch self {
        case .gravityReverse: return 6
        case .fog: return 8
        case .earthquake: return 5
        case .speedStorm: return 5
        case .platformShrink: return 7
        case .chaosGravity: return 6
        }
    }

    var warningDuration: TimeInterval { 1.5 }
    var cooldownDuration: TimeInterval { 3.0 }
}
```

- [ ] **Step 4: Add ScoreSource enum**

```swift
// MARK: - Score Source

enum ScoreSource {
    case normalPlatform      // 10
    case specialPlatform     // 15
    case dangerPlatform      // 20 (fragile, invisible)
    case commonItem          // 5
    case rareItem            // 25
    case surviveEvent        // 30

    var basePoints: Int {
        switch self {
        case .normalPlatform: return 10
        case .specialPlatform: return 15
        case .dangerPlatform: return 20
        case .commonItem: return 5
        case .rareItem: return 25
        case .surviveEvent: return 30
        }
    }
}
```

- [ ] **Step 5: Replace Difficulty struct**

Replace the existing `Difficulty` struct (lines 36-42) with:

```swift
struct Difficulty {
    let riseSpeed: CGFloat
    let spawnInterval: TimeInterval
    let platformWidthMin: CGFloat
    let platformWidthMax: CGFloat
    let isRestPlatform: Bool
    // New fields
    let gravity: CGFloat
    let maxFallSpeed: CGFloat
    let elapsedTime: TimeInterval
    let waveFactor: CGFloat
    let unlockedPlatformTypes: Set<PlatformType>
    let unlockedItemTypes: Set<ItemType>
    let eventsEnabled: Bool
    let specialPlatformChance: CGFloat
    let isBreathingPhase: Bool
}
```

- [ ] **Step 6: Build and verify**

Run: `xcodebuild -project Descend.xcodeproj -scheme Descend -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: Build will FAIL because `DifficultyConfig` and callers don't match the new `Difficulty` struct yet. That's expected — we fix it in Task 2.

- [ ] **Step 7: Commit**

```bash
git add Descend/Models/GameTypes.swift
git commit -m "feat: add PlatformType, ItemType, GameEvent, ScoreSource enums and extend Difficulty struct"
```

---

### Task 2: Create TimeBasedDifficulty system

**Files:**
- Create: `Descend/Systems/TimeBasedDifficulty.swift`
- Delete: `Descend/Models/DifficultyConfig.swift`

- [ ] **Step 1: Create TimeBasedDifficulty.swift**

Create file at `Descend/Systems/TimeBasedDifficulty.swift`:

```swift
import Foundation

final class TimeBasedDifficulty {
    // Caps
    private let maxTime: TimeInterval = 300 // 5 minutes

    // Rise speed
    private let riseSpeedMin: CGFloat = 180
    private let riseSpeedMax: CGFloat = 500

    // Gravity
    private let gravityMin: CGFloat = -200
    private let gravityMax: CGFloat = -600

    // Fall speed clamp
    private let fallSpeedMin: CGFloat = -120
    private let fallSpeedMax: CGFloat = -300

    // Platform gap
    private let gapMin: CGFloat = 160
    private let gapMax: CGFloat = 240

    // Platform width (lerps from wide to narrow)
    private let widthStart: CGFloat = 120
    private let widthEnd: CGFloat = 45

    // Rest platform interval (lerps from frequent to sparse)
    private let restIntervalStart: Int = 15
    private let restIntervalEnd: Int = 25

    // Special platform chance
    private let specialChanceMin: CGFloat = 0.1
    private let specialChanceMax: CGFloat = 0.4

    // Wave
    private let wavePeriod: TimeInterval = 60
    private let waveDepth: CGFloat = 0.15

    // Base platform width for texture generation
    static let basePlatformWidthMax: CGFloat = 150

    private(set) var elapsedTime: TimeInterval = 0

    func update(delta: TimeInterval) {
        elapsedTime += delta
    }

    func reset() {
        elapsedTime = 0
    }

    func getDifficulty(platformCount: Int) -> Difficulty {
        let progress = CGFloat(min(elapsedTime / maxTime, 1.0))
        let wave = waveFactor()

        let baseRiseSpeed = CGFloat.lerp(from: riseSpeedMin, to: riseSpeedMax, t: progress)
        let riseSpeed = baseRiseSpeed * wave

        let baseGravity = CGFloat.lerp(from: gravityMin, to: gravityMax, t: progress)
        let gravity = baseGravity * wave

        let baseFallSpeed = CGFloat.lerp(from: fallSpeedMin, to: fallSpeedMax, t: progress)
        let maxFallSpeed = baseFallSpeed * wave

        let baseGap = CGFloat.lerp(from: gapMin, to: gapMax, t: progress)
        let currentGap = baseGap * wave

        let currentWidth = CGFloat.lerp(from: widthStart, to: widthEnd, t: progress)

        let restInterval = Int(CGFloat.lerp(
            from: CGFloat(restIntervalStart),
            to: CGFloat(restIntervalEnd),
            t: progress
        ))
        let isRestPlatform = platformCount > 0 && platformCount % restInterval == 0

        let finalGap = isRestPlatform ? currentGap * 0.8 : currentGap
        let finalWidth = isRestPlatform ? currentWidth * 1.5 : currentWidth

        let spawnInterval = Double(finalGap / max(riseSpeed, 1))

        let specialChance: CGFloat
        if isBreathingPhase() {
            specialChance = CGFloat.lerp(from: specialChanceMin, to: specialChanceMax, t: progress) * 0.5
        } else {
            specialChance = CGFloat.lerp(from: specialChanceMin, to: specialChanceMax, t: progress)
        }

        return Difficulty(
            riseSpeed: riseSpeed,
            spawnInterval: spawnInterval,
            platformWidthMin: finalWidth * 0.9,
            platformWidthMax: finalWidth * 1.1,
            isRestPlatform: isRestPlatform,
            gravity: gravity,
            maxFallSpeed: maxFallSpeed,
            elapsedTime: elapsedTime,
            waveFactor: wave,
            unlockedPlatformTypes: unlockedPlatformTypes(),
            unlockedItemTypes: unlockedItemTypes(),
            eventsEnabled: elapsedTime >= 150,
            specialPlatformChance: specialChance,
            isBreathingPhase: isBreathingPhase()
        )
    }

    // MARK: - Wave

    private func wavePhase() -> CGFloat {
        let phase = CGFloat(elapsedTime.truncatingRemainder(dividingBy: wavePeriod)) / CGFloat(wavePeriod)
        return phase * .pi * 2
    }

    private func waveOffset() -> CGFloat {
        return waveDepth * sin(wavePhase())
    }

    private func waveFactorValue() -> CGFloat {
        return 1.0 - waveOffset()
    }

    func waveFactor() -> CGFloat {
        return waveFactorValue()
    }

    func isBreathingPhase() -> Bool {
        return waveOffset() > waveDepth * 0.5
    }

    // MARK: - Unlocks

    private func unlockedPlatformTypes() -> Set<PlatformType> {
        var types: Set<PlatformType> = [.normal, .rest]
        if elapsedTime >= 30  { types.insert(.moving) }
        if elapsedTime >= 60  { types.insert(.fragile) }
        if elapsedTime >= 90  { types.insert(.ice) }
        if elapsedTime >= 90  { types.insert(.bouncy) }
        if elapsedTime >= 120 { types.insert(.teleport) }
        if elapsedTime >= 150 { types.insert(.shrinking) }
        if elapsedTime >= 180 { types.insert(.invisible) }
        return types
    }

    private func unlockedItemTypes() -> Set<ItemType> {
        var types: Set<ItemType> = []
        if elapsedTime >= 60  { types.formUnion([.slowDown, .shield]) }
        if elapsedTime >= 90  { types.insert(.wideScreen) }
        if elapsedTime >= 120 { types.formUnion([.magnet, .doubleScore]) }
        if elapsedTime >= 150 { types.formUnion([.ghost, .freeze]) }
        if elapsedTime >= 180 { types.insert(.bomb) }
        return types
    }
}
```

- [ ] **Step 2: Delete DifficultyConfig.swift**

```bash
git rm Descend/Models/DifficultyConfig.swift
```

- [ ] **Step 3: Update PlatformSystem references to DifficultyConfig**

In `Descend/Systems/PlatformSystem.swift`, replace the two static references:

Line 37: Replace `DifficultyConfig.basePlatformWidthMax` with `TimeBasedDifficulty.basePlatformWidthMax`

Line 118: Replace `DifficultyConfig.getDifficulty(score: 0)` with a default initial difficulty. Change `createInitialPlatforms()` to accept a `Difficulty` parameter:

```swift
func createInitialPlatforms(difficulty: Difficulty) {
    let initialDiff = difficulty
    let playerStartY = gameHeight / 2 - 100
    let startPlatformY = playerStartY - 50

    let startWidth = min(
        120 * 1.2,  // widthStart * 1.2
        gameWidth - spawnHorizontalPadding * 2
    )
    createPlatform(x: gameWidth / 2, y: startPlatformY, difficulty: initialDiff, widthOverride: startWidth)

    let gap: CGFloat = 160  // gapMin
    // ... rest unchanged, replace DifficultyConfig.platformGapMin with 160
```

Line 128-129: Replace `DifficultyConfig.platformWidthMin * 1.2` with `120 * 1.2` and `DifficultyConfig.platformGapMin` with `160`.

- [ ] **Step 4: Update GameScene to use TimeBasedDifficulty**

In `Descend/Scenes/GameScene.swift`:

Add property:
```swift
private var difficulty: TimeBasedDifficulty!
```

In `didMove(to:)`, after creating `platformSystem`, add:
```swift
difficulty = TimeBasedDifficulty()
```

Change `createInitialPlatforms()` call to:
```swift
platformSystem.createInitialPlatforms(difficulty: difficulty.getDifficulty(platformCount: 0))
```

In `update(_:)`, replace the difficulty calculation:
```swift
// Old:
// let difficulty = DifficultyConfig.getDifficulty(score: score, platformCount: platformSystem.totalPlatformsGenerated)

// New:
difficulty.update(delta: dt)
let currentDifficulty = difficulty.getDifficulty(platformCount: platformSystem.totalPlatformsGenerated)

// Apply dynamic gravity
physicsWorld.gravity = CGVector(dx: 0, dy: currentDifficulty.gravity)
```

Update all references from `difficulty` to `currentDifficulty` in the update method (platformSystem.update, visualEffects.updateStars).

In `didSimulatePhysics()`, use difficulty to clamp fall speed:
```swift
let currentDifficulty = difficulty.getDifficulty(platformCount: platformSystem.totalPlatformsGenerated)
body.velocity.dy = CGFloat.clamp(body.velocity.dy, min: currentDifficulty.maxFallSpeed, max: 200)
```

In `restartGame()`, add:
```swift
difficulty.reset()
```

And update the `createInitialPlatforms` call in restartGame:
```swift
platformSystem.createInitialPlatforms(difficulty: difficulty.getDifficulty(platformCount: 0))
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project Descend.xcodeproj -scheme Descend -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED. Game should play identically to before at start, with difficulty now ramping by time instead of score.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: replace score-based difficulty with time-based system including wave breathing"
```

---

### Task 3: Create ScoreSystem with combo multiplier

**Files:**
- Create: `Descend/Systems/ScoreSystem.swift`

- [ ] **Step 1: Create ScoreSystem.swift**

Create file at `Descend/Systems/ScoreSystem.swift`:

```swift
import Foundation

final class ScoreSystem {
    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var multiplier: CGFloat = 1.0

    private var timeSinceLastLand: TimeInterval = 0
    private let comboTimeout: TimeInterval = 1.5
    private var isTracking = false

    // Callback for visual feedback: (points, position, isCombo)
    var onScoreAdded: ((_ points: Int, _ combo: Int, _ multiplier: CGFloat) -> Void)?

    func update(delta: TimeInterval) {
        if isTracking {
            timeSinceLastLand += delta
            if timeSinceLastLand > comboTimeout {
                breakCombo()
            }
        }
    }

    func addScore(source: ScoreSource, hasDoubleScore: Bool = false) {
        var points = source.basePoints
        if hasDoubleScore { points *= 2 }

        let finalPoints = Int(CGFloat(points) * multiplier)
        score += finalPoints

        onScoreAdded?(finalPoints, combo, multiplier)
    }

    func registerLanding() {
        combo += 1
        timeSinceLastLand = 0
        isTracking = true
        updateMultiplier()
    }

    func breakCombo() {
        combo = 0
        multiplier = 1.0
        isTracking = false
        timeSinceLastLand = 0
    }

    func shieldUsed() {
        breakCombo()
    }

    func reset() {
        score = 0
        combo = 0
        multiplier = 1.0
        timeSinceLastLand = 0
        isTracking = false
    }

    // MARK: - Private

    private func updateMultiplier() {
        switch combo {
        case 0...1:   multiplier = 1.0
        case 2...3:   multiplier = 1.2
        case 4...7:   multiplier = 1.5
        case 8...11:  multiplier = 2.0
        default:      multiplier = 3.0 // 12+ cap
        }
    }
}
```

- [ ] **Step 2: Integrate ScoreSystem into GameScene**

In `Descend/Scenes/GameScene.swift`:

Add property:
```swift
private var scoreSystem: ScoreSystem!
```

In `didMove(to:)`:
```swift
scoreSystem = ScoreSystem()
```

In `update(_:)`:
- Add `scoreSystem.update(delta: dt)` after the difficulty update
- Replace `score = platformSystem.score` with reading from scoreSystem:
```swift
score = scoreSystem.score
```

In `didBegin(_:)`, after `pNode.markOnPlatform()`:
```swift
scoreSystem.registerLanding()
scoreSystem.addScore(source: .normalPlatform)
```

Remove `var score: Int { passedPlatforms * 10 }` from PlatformSystem — scoring is now handled by ScoreSystem. Keep `passedPlatforms` for platform counting but remove the `score` computed property.

In `restartGame()`:
```swift
scoreSystem.reset()
```

- [ ] **Step 3: Remove score computed property from PlatformSystem**

In `Descend/Systems/PlatformSystem.swift`, remove:
```swift
var score: Int { passedPlatforms * 10 }
```

The `passedPlatforms` counter stays (used for counting platforms passed for other logic), but scoring moves entirely to `ScoreSystem`.

- [ ] **Step 4: Build and verify**

Expected: BUILD SUCCEEDED. Score should increment by 10 per platform with combo building on consecutive landings.

- [ ] **Step 5: Commit**

```bash
git add Descend/Systems/ScoreSystem.swift Descend/Scenes/GameScene.swift Descend/Systems/PlatformSystem.swift
git commit -m "feat: add ScoreSystem with combo multiplier"
```

---

## Phase 2: Platform Behaviors

### Task 4: Create PlatformBehavior protocol and update PlatformNode

**Files:**
- Create: `Descend/Nodes/Behaviors/PlatformBehavior.swift`
- Modify: `Descend/Nodes/PlatformNode.swift`

- [ ] **Step 1: Create Behaviors directory and PlatformBehavior protocol**

```bash
mkdir -p Descend/Nodes/Behaviors
```

Create `Descend/Nodes/Behaviors/PlatformBehavior.swift`:

```swift
import SpriteKit

protocol PlatformBehavior: AnyObject {
    /// Called every frame while the platform is active
    func update(delta: TimeInterval, platform: PlatformNode)

    /// Called when the player lands on this platform
    func onPlayerLand(player: PlayerNode, platform: PlatformNode)

    /// Called when the platform is recycled back to pool
    func onRecycle()
}

// Default no-op implementations
extension PlatformBehavior {
    func update(delta: TimeInterval, platform: PlatformNode) {}
    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {}
    func onRecycle() {}
}
```

- [ ] **Step 2: Update PlatformNode**

In `Descend/Nodes/PlatformNode.swift`, add properties:

```swift
var platformType: PlatformType = .normal
var behavior: PlatformBehavior?
```

Update `activate` method signature to include type and behavior:

```swift
func activate(at position: CGPoint, width: CGFloat, height: CGFloat,
              texture: SKTexture, scheme: PlatformColorScheme,
              type: PlatformType = .normal, behavior: PlatformBehavior? = nil) {
    self.position = position
    self.texture = texture
    self.size = CGSize(width: width, height: height)
    self.colorScheme = scheme
    self.isCounted = false
    self.isHidden = false
    self.platformType = type
    self.behavior = behavior
    configurePhysics(width: width, height: height)
}
```

Update `deactivate`:

```swift
func deactivate() {
    behavior?.onRecycle()
    behavior = nil
    platformType = .normal
    self.isHidden = true
    self.physicsBody = nil
    self.removeFromParent()
}
```

- [ ] **Step 3: Build and verify**

Expected: BUILD SUCCEEDED. No behavior changes — all platforms still get `behavior = nil`.

- [ ] **Step 4: Commit**

```bash
git add Descend/Nodes/Behaviors/PlatformBehavior.swift Descend/Nodes/PlatformNode.swift
git commit -m "feat: add PlatformBehavior protocol and update PlatformNode"
```

---

### Task 5: Implement MovingBehavior

**Files:**
- Create: `Descend/Nodes/Behaviors/MovingBehavior.swift`

- [ ] **Step 1: Create MovingBehavior.swift**

```swift
import SpriteKit

final class MovingBehavior: PlatformBehavior {
    private let speed: CGFloat
    private var direction: CGFloat
    private let minX: CGFloat
    private let maxX: CGFloat

    init(speed: CGFloat? = nil, gameWidth: CGFloat, padding: CGFloat) {
        self.speed = speed ?? CGFloat.random(in: 40...80)
        self.direction = Bool.random() ? 1 : -1
        self.minX = padding
        self.maxX = gameWidth - padding
    }

    func update(delta: TimeInterval, platform: PlatformNode) {
        let halfWidth = platform.size.width / 2
        platform.position.x += speed * direction * CGFloat(delta)

        if platform.position.x - halfWidth < minX {
            platform.position.x = minX + halfWidth
            direction = 1
        } else if platform.position.x + halfWidth > maxX {
            platform.position.x = maxX - halfWidth
            direction = -1
        }
    }

    func onRecycle() {
        direction = Bool.random() ? 1 : -1
    }
}
```

- [ ] **Step 2: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Descend/Nodes/Behaviors/MovingBehavior.swift
git commit -m "feat: add MovingBehavior for left-right platform oscillation"
```

---

### Task 6: Implement FragileBehavior

**Files:**
- Create: `Descend/Nodes/Behaviors/FragileBehavior.swift`

- [ ] **Step 1: Create FragileBehavior.swift**

```swift
import SpriteKit

final class FragileBehavior: PlatformBehavior {
    private let collapseDelay: TimeInterval = 0.5
    private var isCollapsing = false

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        guard !isCollapsing else { return }
        isCollapsing = true

        // Shake animation
        let shakeRight = SKAction.moveBy(x: 3, y: 0, duration: 0.05)
        let shakeLeft = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
        let shakeBack = SKAction.moveBy(x: 3, y: 0, duration: 0.05)
        let shake = SKAction.sequence([shakeRight, shakeLeft, shakeBack])
        let repeatedShake = SKAction.repeat(shake, count: 3)

        // Collapse after delay
        let wait = SKAction.wait(forDuration: collapseDelay)
        let collapse = SKAction.group([
            SKAction.fadeAlpha(to: 0, duration: 0.2),
            SKAction.scaleY(to: 0.1, duration: 0.2)
        ])
        let remove = SKAction.run { [weak platform] in
            platform?.physicsBody = nil
        }

        platform.run(SKAction.sequence([repeatedShake, wait, collapse, remove]),
                     withKey: "fragile_collapse")
    }

    func onRecycle() {
        isCollapsing = false
    }
}
```

- [ ] **Step 2: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Descend/Nodes/Behaviors/FragileBehavior.swift
git commit -m "feat: add FragileBehavior with shake and collapse animation"
```

---

### Task 7: Implement IceBehavior

**Files:**
- Create: `Descend/Nodes/Behaviors/IceBehavior.swift`

- [ ] **Step 1: Create IceBehavior.swift**

The ice effect works by notifying `InputHandler` to disable drag. We use a flag on `PlatformNode` that `InputHandler` can check.

First, add a property to `PlatformNode`:

In `Descend/Nodes/PlatformNode.swift`, add:
```swift
var isIcePlatform: Bool { platformType == .ice }
```

Create `Descend/Nodes/Behaviors/IceBehavior.swift`:

```swift
import SpriteKit

final class IceBehavior: PlatformBehavior {
    // Ice effect is handled by InputHandler checking platform type.
    // This behavior adds the visual sparkle effect on landing.

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        // Ice sparkle particles
        guard let scene = platform.scene else { return }

        for _ in 0..<4 {
            let sparkle = SKShapeNode(circleOfRadius: 2)
            sparkle.fillColor = UIColor(white: 1, alpha: 0.8)
            sparkle.strokeColor = .clear
            sparkle.position = CGPoint(
                x: platform.position.x + CGFloat.random(in: -platform.size.width/2...platform.size.width/2),
                y: platform.position.y + platform.size.height / 2
            )
            sparkle.zPosition = 50
            scene.addChild(sparkle)

            let rise = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: 20, duration: 0.5)
            let fade = SKAction.fadeAlpha(to: 0, duration: 0.5)
            sparkle.run(SKAction.group([rise, fade])) { sparkle.removeFromParent() }
        }
    }
}
```

- [ ] **Step 2: Update InputHandler to check ice**

In `Descend/Systems/InputHandler.swift`, add a property:

```swift
var onIcePlatform = false
```

In `touchMoved(to:)`, modify the velocity calculation:
```swift
let diff = targetX - player.position.x
let rawVelocity = CGFloat.clamp(diff * 15, min: -400, max: 400)
// On ice: velocity is unclamped by drag, amplified
pointerVelocity = onIcePlatform ? rawVelocity * 1.5 : rawVelocity
player.physicsBody?.velocity.dx = pointerVelocity
```

In `reset()`, add:
```swift
onIcePlatform = false
```

- [ ] **Step 3: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Descend/Nodes/Behaviors/IceBehavior.swift Descend/Nodes/PlatformNode.swift Descend/Systems/InputHandler.swift
git commit -m "feat: add IceBehavior with reduced friction and sparkle effect"
```

---

### Task 8: Implement BouncyBehavior

**Files:**
- Create: `Descend/Nodes/Behaviors/BouncyBehavior.swift`

- [ ] **Step 1: Create BouncyBehavior.swift**

```swift
import SpriteKit

final class BouncyBehavior: PlatformBehavior {
    private let bounceImpulse: CGFloat = 350

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        // Apply upward impulse
        player.physicsBody?.velocity.dy = bounceImpulse

        // Spring animation on platform
        let squash = SKAction.scaleY(to: 0.6, duration: 0.08)
        squash.timingMode = .easeOut
        let stretch = SKAction.scaleY(to: 1.2, duration: 0.1)
        stretch.timingMode = .easeOut
        let recover = SKAction.scaleY(to: 1.0, duration: 0.15)
        recover.timingMode = .easeInEaseOut
        platform.run(SKAction.sequence([squash, stretch, recover]), withKey: "bouncy_spring")
    }
}
```

- [ ] **Step 2: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Descend/Nodes/Behaviors/BouncyBehavior.swift
git commit -m "feat: add BouncyBehavior with upward impulse and spring animation"
```

---

### Task 9: Implement TeleportBehavior

**Files:**
- Create: `Descend/Nodes/Behaviors/TeleportBehavior.swift`

- [ ] **Step 1: Create TeleportBehavior.swift**

```swift
import SpriteKit

final class TeleportBehavior: PlatformBehavior {
    weak var pairedPlatform: PlatformNode?
    private var hasTriggered = false

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        guard !hasTriggered else { return }
        guard let target = pairedPlatform, target.parent != nil else { return }
        hasTriggered = true

        // Blink out
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.15)
        let teleport = SKAction.run {
            player.position = CGPoint(x: target.position.x, y: target.position.y + target.size.height / 2 + player.size.height / 2)
            player.physicsBody?.velocity = .zero
        }
        let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.15)

        player.run(SKAction.sequence([fadeOut, teleport, fadeIn]))
    }

    func onRecycle() {
        pairedPlatform = nil
        hasTriggered = false
    }
}
```

- [ ] **Step 2: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Descend/Nodes/Behaviors/TeleportBehavior.swift
git commit -m "feat: add TeleportBehavior with paired platform teleportation"
```

---

### Task 10: Implement ShrinkingBehavior

**Files:**
- Create: `Descend/Nodes/Behaviors/ShrinkingBehavior.swift`

- [ ] **Step 1: Create ShrinkingBehavior.swift**

```swift
import SpriteKit

final class ShrinkingBehavior: PlatformBehavior {
    private let shrinkFactor: CGFloat = 0.7  // 30% reduction
    private let minWidth: CGFloat = 25
    private var stompCount = 0

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        stompCount += 1
        let newWidth = platform.size.width * shrinkFactor

        if newWidth < minWidth {
            // Too small — collapse
            let shrink = SKAction.group([
                SKAction.resize(toWidth: 0, duration: 0.2),
                SKAction.fadeAlpha(to: 0, duration: 0.2)
            ])
            platform.run(shrink) { [weak platform] in
                platform?.physicsBody = nil
            }
        } else {
            // Shrink with animation
            let shrinkAction = SKAction.resize(toWidth: newWidth, duration: 0.15)
            shrinkAction.timingMode = .easeOut
            platform.run(shrinkAction) { [weak platform] in
                guard let platform else { return }
                // Update physics body to match new size
                platform.configurePhysics(width: newWidth, height: platform.size.height)
            }
        }
    }

    func onRecycle() {
        stompCount = 0
    }
}
```

- [ ] **Step 2: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Descend/Nodes/Behaviors/ShrinkingBehavior.swift
git commit -m "feat: add ShrinkingBehavior with progressive width reduction"
```

---

### Task 11: Implement InvisibleBehavior

**Files:**
- Create: `Descend/Nodes/Behaviors/InvisibleBehavior.swift`

- [ ] **Step 1: Create InvisibleBehavior.swift**

```swift
import SpriteKit

final class InvisibleBehavior: PlatformBehavior {
    private let revealDistance: CGFloat = 80
    private var isRevealed = false
    private weak var playerRef: PlayerNode?

    func setPlayer(_ player: PlayerNode) {
        playerRef = player
    }

    func update(delta: TimeInterval, platform: PlatformNode) {
        guard let player = playerRef else {
            // If no player ref, keep semi-visible
            platform.alpha = 0.15
            return
        }

        let dx = player.position.x - platform.position.x
        let dy = player.position.y - platform.position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < revealDistance {
            if !isRevealed {
                isRevealed = true
                let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: 0.2)
                platform.run(fadeIn, withKey: "invisible_reveal")
            }
        } else {
            if isRevealed {
                isRevealed = false
                let fadeOut = SKAction.fadeAlpha(to: 0.15, duration: 0.3)
                platform.run(fadeOut, withKey: "invisible_reveal")
            }
        }
    }

    func onRecycle() {
        isRevealed = false
        playerRef = nil
    }
}
```

- [ ] **Step 2: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Descend/Nodes/Behaviors/InvisibleBehavior.swift
git commit -m "feat: add InvisibleBehavior with proximity-based reveal"
```

---

### Task 12: Wire behaviors into PlatformSystem

**Files:**
- Modify: `Descend/Systems/PlatformSystem.swift`
- Modify: `Descend/Systems/PlatformSpawnStrategy.swift`

- [ ] **Step 1: Add behavior assignment to PlatformSystem**

In `Descend/Systems/PlatformSystem.swift`, add a player reference and behavior factory:

Add property:
```swift
weak var playerNode: PlayerNode?
private var lastPlatformType: PlatformType = .normal
private var teleportPending: TeleportBehavior? = nil
private var teleportCountdown: Int = 0
```

Add method after `reset()`:

```swift
// MARK: - Behavior Assignment

private func choosePlatformType(difficulty: Difficulty) -> PlatformType {
    guard !difficulty.isRestPlatform else { return .normal }

    // Check if we owe a teleport pair
    if teleportCountdown > 0 {
        teleportCountdown -= 1
        if teleportCountdown == 0 {
            return .teleport
        }
    }

    guard CGFloat.random(in: 0...1) < difficulty.specialPlatformChance else {
        return .normal
    }

    // Filter to unlocked types, exclude normal/rest, exclude last type
    var candidates = difficulty.unlockedPlatformTypes
        .subtracting([.normal, .rest])
    candidates.remove(lastPlatformType)

    // Don't start a new teleport pair if one is pending
    if teleportPending != nil {
        candidates.remove(.teleport)
    }

    guard let chosen = candidates.randomElement() else { return .normal }
    return chosen
}

private func makeBehavior(for type: PlatformType) -> PlatformBehavior? {
    switch type {
    case .normal, .rest:
        return nil
    case .moving:
        return MovingBehavior(gameWidth: gameWidth, padding: spawnHorizontalPadding)
    case .fragile:
        return FragileBehavior()
    case .ice:
        return IceBehavior()
    case .bouncy:
        return BouncyBehavior()
    case .teleport:
        if let pending = teleportPending {
            // This is the second of a pair
            let behavior = TeleportBehavior()
            // We'll link them after platform is created
            teleportPending = nil
            return behavior
        } else {
            // First of a pair — schedule second in 2-4 platforms
            let behavior = TeleportBehavior()
            teleportPending = behavior
            teleportCountdown = Int.random(in: 2...4)
            return behavior
        }
    case .shrinking:
        return ShrinkingBehavior()
    case .invisible:
        let behavior = InvisibleBehavior()
        behavior.setPlayer(playerNode!)
        return behavior
    }
}
```

- [ ] **Step 2: Update createPlatform to assign behavior**

Modify the `createPlatform` method to accept a `PlatformType` parameter:

```swift
private func createPlatform(x: CGFloat, y: CGFloat, difficulty: Difficulty,
                            widthOverride: CGFloat? = nil, type: PlatformType = .normal) {
    guard let scene else { return }

    let maxAllowedWidth = max(1, gameWidth - spawnHorizontalPadding * 2)
    let width = min(widthOverride ?? CGFloat.random(in: difficulty.platformWidthMin...difficulty.platformWidthMax), maxAllowedWidth)
    let safeX = validatePlatformX(x: x, width: width)

    let idx = Int.random(in: 0..<platformTextures.count)
    let textureInfo = platformTextures[idx]

    let platform: PlatformNode
    if let pooled = platformPool.popLast() {
        platform = pooled
    } else {
        platform = PlatformNode(texture: textureInfo.texture, colorScheme: textureInfo.scheme)
    }

    let behavior = makeBehavior(for: type)

    platform.activate(
        at: CGPoint(x: safeX, y: y),
        width: width,
        height: platformHeight,
        texture: textureInfo.texture,
        scheme: textureInfo.scheme,
        type: type,
        behavior: behavior
    )

    // Link teleport pairs
    if type == .teleport, let teleportBehavior = behavior as? TeleportBehavior {
        if let pending = teleportPending {
            // pending is the first, teleportBehavior is the second
            pending.pairedPlatform = platform
            teleportBehavior.pairedPlatform = findPlatformWithBehavior(pending)
        }
    }

    scene.addChild(platform)
    activePlatforms.append(platform)
    lastPlatformType = type
}

private func findPlatformWithBehavior(_ behavior: PlatformBehavior) -> PlatformNode? {
    return activePlatforms.first { $0.behavior === behavior }
}
```

- [ ] **Step 3: Update generateNewPlatform to choose type**

```swift
private func generateNewPlatform(difficulty: Difficulty) {
    totalPlatformsGenerated += 1
    let spawn = spawnStrategy.getNextPlatform(difficulty: difficulty)
    let bufferTime: CGFloat = 2.5
    let newY = -(difficulty.riseSpeed * bufferTime)
    let type = choosePlatformType(difficulty: difficulty)
    createPlatform(x: spawn.x, y: newY, difficulty: difficulty, widthOverride: spawn.width, type: type)
}
```

- [ ] **Step 4: Update platform update loop to call behaviors**

In the `update` method, add behavior updates for active platforms:

```swift
func update(delta: TimeInterval, difficulty: Difficulty) {
    let riseAmount = difficulty.riseSpeed * CGFloat(delta)

    for i in stride(from: activePlatforms.count - 1, through: 0, by: -1) {
        let platform = activePlatforms[i]
        platform.position.y += riseAmount

        // Update behavior
        platform.behavior?.update(delta: delta, platform: platform)

        if platform.position.y > gameHeight + 50 {
            if !platform.isCounted {
                passedPlatforms += 1
                platform.isCounted = true
            }
            recyclePlatform(at: i)
        }
    }

    spawnTimer += delta
    while spawnTimer >= difficulty.spawnInterval {
        generateNewPlatform(difficulty: difficulty)
        spawnTimer -= difficulty.spawnInterval
    }
}
```

- [ ] **Step 5: Add reset for teleport state**

In `reset()`, add:
```swift
lastPlatformType = .normal
teleportPending = nil
teleportCountdown = 0
```

- [ ] **Step 6: Update GameScene to pass playerNode to PlatformSystem**

In `Descend/Scenes/GameScene.swift` `didMove(to:)`, after creating playerNode:
```swift
platformSystem.playerNode = playerNode
```

- [ ] **Step 7: Update GameScene collision to call behavior.onPlayerLand**

In `didBegin(_:)`, after the existing visual feedback code, add:

```swift
// Behavior callback
platNode.behavior?.onPlayerLand(player: pNode, platform: platNode)

// Ice platform effect on input
inputHandler.onIcePlatform = platNode.isIcePlatform

// Score based on platform type
let source: ScoreSource
switch platNode.platformType {
case .fragile, .invisible:
    source = .dangerPlatform
case .normal, .rest:
    source = .normalPlatform
default:
    source = .specialPlatform
}
scoreSystem.registerLanding()
scoreSystem.addScore(source: source)
```

Remove the previous `scoreSystem.registerLanding()` and `scoreSystem.addScore(source: .normalPlatform)` lines added in Task 3, replacing with the above.

- [ ] **Step 8: Build and verify**

Expected: BUILD SUCCEEDED. Special platforms should start appearing at the times defined in the unlock schedule.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: wire platform behaviors into PlatformSystem with type selection and GameScene collision"
```

---

## Phase 3: Item System

### Task 13: Create ItemNode

**Files:**
- Create: `Descend/Nodes/ItemNode.swift`

- [ ] **Step 1: Create ItemNode.swift**

```swift
import SpriteKit

final class ItemNode: SKSpriteNode {
    let itemType: ItemType
    private let iconSize: CGFloat = 24

    init(type: ItemType) {
        self.itemType = type

        let texture = ItemNode.generateTexture(for: type, size: 24)
        super.init(texture: texture, color: .clear, size: CGSize(width: 24, height: 24))
        zPosition = 15

        // Idle bobbing animation
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 6, duration: 0.8),
            SKAction.moveBy(x: 0, y: -6, duration: 0.8)
        ])
        bob.timingMode = .easeInEaseOut
        run(SKAction.repeatForever(bob), withKey: "bob")

        // Gentle glow pulse
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])
        run(SKAction.repeatForever(pulse), withKey: "pulse")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func deactivate() {
        removeAllActions()
        removeFromParent()
    }

    // MARK: - Texture Generation

    private static func generateTexture(for type: ItemType, size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let gc = ctx.cgContext

            switch type {
            case .slowDown:
                // Blue clock
                UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1).setFill()
                gc.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
                UIColor.white.setStroke()
                gc.setLineWidth(2)
                gc.move(to: CGPoint(x: size/2, y: size/2))
                gc.addLine(to: CGPoint(x: size/2, y: size * 0.25))
                gc.move(to: CGPoint(x: size/2, y: size/2))
                gc.addLine(to: CGPoint(x: size * 0.7, y: size/2))
                gc.strokePath()

            case .shield:
                // Gold circle
                UIColor(red: 1, green: 0.84, blue: 0, alpha: 1).setFill()
                UIColor(red: 1, green: 0.65, blue: 0, alpha: 1).setStroke()
                gc.setLineWidth(2)
                gc.fillEllipse(in: rect.insetBy(dx: 3, dy: 3))
                gc.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))

            case .wideScreen:
                // Green horizontal arrows
                UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1).setFill()
                let arrowPath = UIBezierPath()
                arrowPath.move(to: CGPoint(x: 2, y: size/2))
                arrowPath.addLine(to: CGPoint(x: 8, y: size/2 - 5))
                arrowPath.addLine(to: CGPoint(x: 8, y: size/2 + 5))
                arrowPath.close()
                arrowPath.fill()
                let rightArrow = UIBezierPath()
                rightArrow.move(to: CGPoint(x: size - 2, y: size/2))
                rightArrow.addLine(to: CGPoint(x: size - 8, y: size/2 - 5))
                rightArrow.addLine(to: CGPoint(x: size - 8, y: size/2 + 5))
                rightArrow.close()
                rightArrow.fill()
                gc.fill(CGRect(x: 7, y: size/2 - 1.5, width: size - 14, height: 3))

            case .magnet:
                // Red U-shape
                UIColor.red.setStroke()
                gc.setLineWidth(3)
                let magnetPath = UIBezierPath()
                magnetPath.addArc(withCenter: CGPoint(x: size/2, y: size * 0.55),
                                  radius: size * 0.3,
                                  startAngle: 0, endAngle: .pi, clockwise: true)
                magnetPath.stroke()
                // Arms
                gc.move(to: CGPoint(x: size * 0.2, y: size * 0.55))
                gc.addLine(to: CGPoint(x: size * 0.2, y: size * 0.2))
                gc.move(to: CGPoint(x: size * 0.8, y: size * 0.55))
                gc.addLine(to: CGPoint(x: size * 0.8, y: size * 0.2))
                gc.strokePath()

            case .doubleScore:
                // Gold "×2"
                let font = UIFont.boldSystemFont(ofSize: size * 0.55)
                let text = "×2" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)
                ]
                let textSize = text.size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (size - textSize.width) / 2,
                    y: (size - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attrs)

            case .ghost:
                // White semi-transparent circle
                UIColor(white: 1, alpha: 0.5).setFill()
                gc.fillEllipse(in: rect.insetBy(dx: 3, dy: 3))
                UIColor(white: 1, alpha: 0.8).setStroke()
                gc.setLineWidth(1)
                gc.setLineDash(phase: 0, lengths: [3, 3])
                gc.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))

            case .freeze:
                // Ice blue snowflake (simple star)
                let center = CGPoint(x: size/2, y: size/2)
                UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 1).setStroke()
                gc.setLineWidth(2)
                for angle in stride(from: 0.0, to: CGFloat.pi * 2, by: CGFloat.pi / 3) {
                    gc.move(to: center)
                    gc.addLine(to: CGPoint(
                        x: center.x + cos(angle) * size * 0.35,
                        y: center.y + sin(angle) * size * 0.35
                    ))
                }
                gc.strokePath()

            case .bomb:
                // Red circle with fuse
                UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1).setFill()
                gc.fillEllipse(in: rect.insetBy(dx: 4, dy: 5))
                UIColor(red: 1, green: 0.6, blue: 0, alpha: 1).setStroke()
                gc.setLineWidth(2)
                gc.move(to: CGPoint(x: size/2, y: 5))
                gc.addLine(to: CGPoint(x: size * 0.65, y: 1))
                gc.strokePath()
            }
        }
        return SKTexture(image: image)
    }
}
```

- [ ] **Step 2: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Descend/Nodes/ItemNode.swift
git commit -m "feat: add ItemNode with programmatic icon textures for 8 item types"
```

---

### Task 14: Create ItemSystem

**Files:**
- Create: `Descend/Systems/ItemSystem.swift`

- [ ] **Step 1: Create ItemSystem.swift**

```swift
import SpriteKit

final class ItemSystem {
    private weak var scene: SKScene?
    private let gameWidth: CGFloat
    private let gameHeight: CGFloat

    private var activeItems: [ItemNode] = []
    private var itemPool: [ItemNode] = []
    private let poolMaxSize = 10
    private let maxActiveItems = 2

    private(set) var activeEffects: [ItemType: TimeInterval] = [:]
    private var platformsSinceLastCommon = 0
    private var platformsSinceLastRare = 0
    private let commonInterval = (min: 8, max: 15)
    private let rareInterval = (min: 20, max: 30)
    private var nextCommonAt: Int
    private var nextRareAt: Int

    // Pickup radius
    private let pickupRadius: CGFloat = 20

    // Callbacks
    var onItemPickup: ((_ type: ItemType, _ position: CGPoint) -> Void)?
    var onGhostExpired: (() -> Void)?

    init(scene: SKScene) {
        self.scene = scene
        self.gameWidth = scene.size.width
        self.gameHeight = scene.size.height
        self.nextCommonAt = Int.random(in: commonInterval.min...commonInterval.max)
        self.nextRareAt = Int.random(in: rareInterval.min...rareInterval.max)
    }

    // MARK: - Queries

    func isActive(_ type: ItemType) -> Bool {
        return activeEffects[type] != nil
    }

    // MARK: - Update

    func update(delta: TimeInterval, player: PlayerNode, difficulty: Difficulty) {
        // Tick down active effects
        var expiredEffects: [ItemType] = []
        for (type, remaining) in activeEffects {
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                expiredEffects.append(type)
            } else {
                activeEffects[type] = newRemaining
            }
        }
        for type in expiredEffects {
            activeEffects.removeValue(forKey: type)
            if type == .ghost {
                onGhostExpired?()
            }
        }

        // Ghost warning: flash player when < 0.5s remaining
        if let ghostRemaining = activeEffects[.ghost], ghostRemaining < 0.5 {
            let blinkPhase = Int(ghostRemaining * 10) % 2
            player.alpha = blinkPhase == 0 ? 0.3 : 0.8
        } else if !isActive(.ghost) {
            // Restore alpha if ghost just ended
            if player.alpha < 1.0 {
                player.alpha = 1.0
            }
        }

        // Check pickups
        for i in stride(from: activeItems.count - 1, through: 0, by: -1) {
            let item = activeItems[i]

            // Move with platform rise
            item.position.y += difficulty.riseSpeed * CGFloat(delta)

            // Remove if off screen
            if item.position.y > gameHeight + 30 {
                recycleItem(at: i)
                continue
            }

            // Pickup detection
            let dx = player.position.x - item.position.x
            let dy = player.position.y - item.position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < pickupRadius {
                applyItem(item.itemType)
                onItemPickup?(item.itemType, item.position)
                recycleItem(at: i)
            }
        }
    }

    // MARK: - Spawn Notification (called by PlatformSystem)

    func onPlatformSpawned(position: CGPoint, width: CGFloat, difficulty: Difficulty) {
        guard activeItems.count < maxActiveItems else { return }
        guard !difficulty.unlockedItemTypes.isEmpty else { return }

        platformsSinceLastCommon += 1
        platformsSinceLastRare += 1

        // Check common item
        let commonTypes = difficulty.unlockedItemTypes.filter { !$0.isRare }
        if platformsSinceLastCommon >= nextCommonAt, !commonTypes.isEmpty {
            // Breathing phase: boost chance
            let spawn = difficulty.isBreathingPhase ? true : CGFloat.random(in: 0...1) < 0.8
            if spawn, let type = commonTypes.randomElement() {
                let itemPos = CGPoint(x: position.x, y: position.y + 20)
                spawnItem(type: type, at: itemPos)
                platformsSinceLastCommon = 0
                nextCommonAt = Int.random(in: commonInterval.min...commonInterval.max)
                return
            }
        }

        // Check rare item
        let rareTypes = difficulty.unlockedItemTypes.filter { $0.isRare }
        if platformsSinceLastRare >= nextRareAt, !rareTypes.isEmpty {
            if let type = rareTypes.randomElement() {
                // Rare items float between platforms — offset from platform position
                let offsetX = CGFloat.random(in: -60...60)
                let offsetY = CGFloat.random(in: 40...80)
                let itemPos = CGPoint(
                    x: CGFloat.clamp(position.x + offsetX, min: 30, max: gameWidth - 30),
                    y: position.y + offsetY
                )
                spawnItem(type: type, at: itemPos)
                platformsSinceLastRare = 0
                nextRareAt = Int.random(in: rareInterval.min...rareInterval.max)
            }
        }
    }

    // MARK: - Item Effects

    private func applyItem(_ type: ItemType) {
        switch type {
        case .bomb:
            // Instant effect — handled by callback, no duration
            break
        case .shield:
            activeEffects[type] = .infinity
        default:
            activeEffects[type] = type.duration
        }
    }

    // MARK: - Spawn / Recycle

    private func spawnItem(type: ItemType, at position: CGPoint) {
        guard let scene else { return }

        let item = ItemNode(type: type)
        item.position = position
        scene.addChild(item)
        activeItems.append(item)
    }

    private func recycleItem(at index: Int) {
        let item = activeItems.remove(at: index)
        item.deactivate()
    }

    // MARK: - Bomb Effect

    /// Returns true if bomb was consumed (caller should replace special platforms)
    func consumeBomb() -> Bool {
        guard activeEffects[.bomb] != nil || activeEffects.keys.contains(.bomb) else { return false }
        // Bomb is instant — no duration tracking needed, but flag it was picked up
        return true
    }

    // MARK: - Reset

    func reset() {
        for item in activeItems {
            item.deactivate()
        }
        activeItems.removeAll()
        itemPool.removeAll()
        activeEffects.removeAll()
        platformsSinceLastCommon = 0
        platformsSinceLastRare = 0
        nextCommonAt = Int.random(in: commonInterval.min...commonInterval.max)
        nextRareAt = Int.random(in: rareInterval.min...rareInterval.max)
    }
}
```

- [ ] **Step 2: Wire ItemSystem into GameScene**

In `Descend/Scenes/GameScene.swift`:

Add property:
```swift
private var itemSystem: ItemSystem!
```

In `didMove(to:)`, after creating platformSystem:
```swift
itemSystem = ItemSystem(scene: self)
```

In `update(_:)`, after platformSystem.update:
```swift
itemSystem.update(delta: dt, player: playerNode, difficulty: currentDifficulty)
```

In `restartGame()`:
```swift
itemSystem.reset()
```

- [ ] **Step 3: Wire PlatformSystem to notify ItemSystem on spawn**

In `Descend/Systems/PlatformSystem.swift`, add property:
```swift
weak var itemSystem: ItemSystem?
```

In `createPlatform`, after `activePlatforms.append(platform)`:
```swift
// Notify item system of new platform
if type == .normal || type == .rest {
    // Items only spawn on normal/rest platforms
} else {
    // Don't spawn items on special platforms
}
// Actually, items can spawn on any platform. Notify always:
itemSystem?.onPlatformSpawned(position: platform.position, width: width, difficulty: difficulty)
```

Wait — `createPlatform` doesn't have `difficulty` in scope currently. Add it as a parameter. The method signature becomes:

```swift
private func createPlatform(x: CGFloat, y: CGFloat, difficulty: Difficulty,
                            widthOverride: CGFloat? = nil, type: PlatformType = .normal)
```

It already has `difficulty` as a parameter. Add the notification at the end:

```swift
itemSystem?.onPlatformSpawned(position: platform.position, width: width, difficulty: difficulty)
```

In `Descend/Scenes/GameScene.swift` `didMove(to:)`, after creating itemSystem:
```swift
platformSystem.itemSystem = itemSystem
```

- [ ] **Step 4: Handle item effects in GameScene collision**

In `didBegin(_:)`, update death check to respect shield:

In `update(_:)`, replace the death check:
```swift
// Death check
if playerNode.position.y > size.height - 35 || playerNode.position.y < 50 {
    if itemSystem.isActive(.shield) {
        // Shield saves — bounce player back
        itemSystem.activeEffects.removeValue(forKey: .shield)
        scoreSystem.shieldUsed()
        if playerNode.position.y > size.height - 35 {
            playerNode.position.y = size.height - 60
            playerNode.physicsBody?.velocity.dy = -100
        } else {
            playerNode.position.y = 80
            playerNode.physicsBody?.velocity.dy = 100
        }
        HapticsManager.shared.vibrate(.heavy)
    } else if itemSystem.isActive(.ghost) {
        // Ghost mode — no death
    } else {
        triggerGameOver()
        return
    }
}
```

- [ ] **Step 5: Handle magnet effect in InputHandler**

In `Descend/Systems/InputHandler.swift`, add:
```swift
var magnetTarget: CGFloat? = nil  // Set by GameScene when magnet is active
```

In `touchMoved(to:)`, after calculating `pointerVelocity`, add:
```swift
if let magX = magnetTarget {
    let pull = (magX - player.position.x) * 5
    player.physicsBody?.velocity.dx += pull * CGFloat(1.0/60.0) // approximate
}
```

In `reset()`:
```swift
magnetTarget = nil
```

- [ ] **Step 6: Handle freeze and slowDown in GameScene update**

In `update(_:)`, after getting `currentDifficulty`:
```swift
// Apply item effects to difficulty
var modifiedRiseSpeed = currentDifficulty.riseSpeed
if itemSystem.isActive(.freeze) {
    modifiedRiseSpeed = 0
}
if itemSystem.isActive(.slowDown) {
    modifiedRiseSpeed *= 0.6
}
```

Pass `modifiedRiseSpeed` to platform system. The cleanest way: create a modified difficulty or just update the rise speed directly. Since `Difficulty` is a struct, create a copy helper.

Add to `GameTypes.swift`:
```swift
extension Difficulty {
    func withRiseSpeed(_ speed: CGFloat) -> Difficulty {
        Difficulty(riseSpeed: speed, spawnInterval: spawnInterval,
                   platformWidthMin: platformWidthMin, platformWidthMax: platformWidthMax,
                   isRestPlatform: isRestPlatform, gravity: gravity, maxFallSpeed: maxFallSpeed,
                   elapsedTime: elapsedTime, waveFactor: waveFactor,
                   unlockedPlatformTypes: unlockedPlatformTypes, unlockedItemTypes: unlockedItemTypes,
                   eventsEnabled: eventsEnabled, specialPlatformChance: specialPlatformChance,
                   isBreathingPhase: isBreathingPhase)
    }
}
```

Then in `update(_:)`:
```swift
let effectiveDifficulty = currentDifficulty.withRiseSpeed(modifiedRiseSpeed)
platformSystem.update(delta: dt, difficulty: effectiveDifficulty)
```

- [ ] **Step 7: Handle ghost collision bypass**

In `didBegin(_:)`, at the very top after the guard:
```swift
// Ghost mode — no platform collision
guard !itemSystem.isActive(.ghost) else { return }
```

- [ ] **Step 8: Handle wideScreen effect in PlatformSystem**

In `PlatformSystem`, add property:
```swift
weak var itemSystemRef: ItemSystem?
```

Wait — we already have `weak var itemSystem: ItemSystem?`. Use that. In `createPlatform`, adjust width:

```swift
var width = min(widthOverride ?? CGFloat.random(in: difficulty.platformWidthMin...difficulty.platformWidthMax), maxAllowedWidth)
if itemSystem?.isActive(.wideScreen) == true {
    width = min(width * 1.5, maxAllowedWidth)
}
```

- [ ] **Step 9: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: add ItemSystem with 8 item types, pickup detection, and effect management"
```

---

## Phase 4: Event System

### Task 15: Create EventSystem

**Files:**
- Create: `Descend/Systems/EventSystem.swift`

- [ ] **Step 1: Create EventSystem.swift**

```swift
import Foundation

final class EventSystem {
    enum EventState {
        case idle
        case warning(event: GameEvent, remaining: TimeInterval)
        case active(event: GameEvent, remaining: TimeInterval)
        case cooldown(remaining: TimeInterval)
    }

    private(set) var state: EventState = .idle

    var activeEvent: GameEvent? {
        if case .active(let event, _) = state { return event }
        return nil
    }

    var warningEvent: GameEvent? {
        if case .warning(let event, _) = state { return event }
        return nil
    }

    private var timeSinceLastEvent: TimeInterval = 0
    private var nextEventDelay: TimeInterval
    private var lastEventType: GameEvent?

    // Callback for visual/audio feedback
    var onEventWarning: ((_ event: GameEvent) -> Void)?
    var onEventStart: ((_ event: GameEvent) -> Void)?
    var onEventEnd: ((_ event: GameEvent) -> Void)?

    init() {
        self.nextEventDelay = TimeInterval.random(in: 30...60)
    }

    func update(delta: TimeInterval, difficulty: Difficulty) {
        guard difficulty.eventsEnabled else { return }
        guard !difficulty.isBreathingPhase else {
            // Don't trigger new events during breathing, but continue active ones
            updateCurrentState(delta: delta)
            return
        }

        updateCurrentState(delta: delta)
    }

    private func updateCurrentState(delta: TimeInterval) {
        switch state {
        case .idle:
            timeSinceLastEvent += delta
            if timeSinceLastEvent >= nextEventDelay {
                triggerRandomEvent()
            }

        case .warning(let event, let remaining):
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                state = .active(event: event, remaining: event.duration)
                onEventStart?(event)
            } else {
                state = .warning(event: event, remaining: newRemaining)
            }

        case .active(let event, let remaining):
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                state = .cooldown(remaining: event.cooldownDuration)
                onEventEnd?(event)
                lastEventType = event
            } else {
                state = .active(event: event, remaining: newRemaining)
            }

        case .cooldown(let remaining):
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                state = .idle
                timeSinceLastEvent = 0
                // Interval shortens over time (handled by adjusting range)
                nextEventDelay = TimeInterval.random(in: 20...40)
            } else {
                state = .cooldown(remaining: newRemaining)
            }
        }
    }

    private func triggerRandomEvent() {
        var candidates = GameEvent.allCases
        if let last = lastEventType {
            candidates.removeAll { $0 == last }
        }
        guard let event = candidates.randomElement() else { return }

        state = .warning(event: event, remaining: event.warningDuration)
        onEventWarning?(event)
    }

    func reset() {
        state = .idle
        timeSinceLastEvent = 0
        nextEventDelay = TimeInterval.random(in: 30...60)
        lastEventType = nil
    }
}
```

- [ ] **Step 2: Wire EventSystem into GameScene**

In `Descend/Scenes/GameScene.swift`:

Add property:
```swift
private var eventSystem: EventSystem!
```

In `didMove(to:)`:
```swift
eventSystem = EventSystem()
```

In `update(_:)`, after itemSystem.update:
```swift
eventSystem.update(delta: dt, difficulty: currentDifficulty)
```

Apply event effects to physics/gameplay:
```swift
// Event effects
if let event = eventSystem.activeEvent {
    switch event {
    case .gravityReverse:
        physicsWorld.gravity = CGVector(dx: 0, dy: -currentDifficulty.gravity)
    case .speedStorm:
        modifiedRiseSpeed *= 1.5
    case .earthquake:
        // Handled per-platform in PlatformSystem
        break
    case .fog, .platformShrink, .chaosGravity:
        break
    }
}

// Chaos gravity: random horizontal component every 1.5s
if eventSystem.activeEvent == .chaosGravity {
    let chaosX = CGFloat.random(in: -100...100)
    physicsWorld.gravity = CGVector(dx: chaosX, dy: currentDifficulty.gravity)
}
```

Move `physicsWorld.gravity` assignment after event checks so events can override it.

In `restartGame()`:
```swift
eventSystem.reset()
```

- [ ] **Step 3: Handle earthquake in PlatformSystem**

In `PlatformSystem`, add:
```swift
weak var eventSystem: EventSystem?
```

In `update(delta:difficulty:)`, during platform loop, after `platform.position.y += riseAmount`:
```swift
// Earthquake shake
if eventSystem?.activeEvent == .earthquake {
    platform.position.x += CGFloat.random(in: -15...15) * CGFloat(delta) * 10
    platform.position.x = CGFloat.clamp(platform.position.x, min: 0, max: gameWidth)
}
```

In GameScene `didMove(to:)`:
```swift
platformSystem.eventSystem = eventSystem
```

- [ ] **Step 4: Handle platformShrink event**

In `PlatformSystem.update`, when `.platformShrink` is active, shrink existing platforms once:

Add a flag:
```swift
private var platformShrinkApplied = false
```

In update:
```swift
if eventSystem?.activeEvent == .platformShrink {
    if !platformShrinkApplied {
        platformShrinkApplied = true
        for platform in activePlatforms {
            let newWidth = platform.size.width * 0.75
            platform.run(SKAction.resize(toWidth: newWidth, duration: 0.3))
            platform.configurePhysics(width: newWidth, height: platformHeight)
        }
    }
} else {
    platformShrinkApplied = false
}
```

- [ ] **Step 5: Handle gravity reverse death zone swap**

In GameScene `update(_:)`, update the death check:
```swift
let isReversed = eventSystem.activeEvent == .gravityReverse
let topDeath = isReversed ? (playerNode.position.y < 50) : (playerNode.position.y > size.height - 35)
let bottomDeath = isReversed ? (playerNode.position.y > size.height - 35) : (playerNode.position.y < 50)

if topDeath || bottomDeath {
    // ... existing shield/ghost/death logic
}
```

- [ ] **Step 6: Score for surviving events**

In EventSystem, when an event ends, wire a callback. In GameScene `didMove(to:)`:

```swift
eventSystem.onEventEnd = { [weak self] event in
    self?.scoreSystem.addScore(source: .surviveEvent,
                               hasDoubleScore: self?.itemSystem.isActive(.doubleScore) ?? false)
}
```

- [ ] **Step 7: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add EventSystem with 6 random events and GameScene integration"
```

---

## Phase 5: Visual & Audio Polish

### Task 16: Add SFX support to AudioManager

**Files:**
- Modify: `Descend/Managers/AudioManager.swift`

- [ ] **Step 1: Add SFX enum and playback**

Add to `AudioManager`:

```swift
// MARK: - Sound Effects

enum SFX: String {
    case land = "land"
    case landSpecial = "land_special"
    case fragileCrack = "fragile_crack"
    case bounce = "bounce"
    case teleport = "teleport"
    case iceSlide = "ice_slide"
    case itemCommon = "item_common"
    case itemRare = "item_rare"
    case eventWarning = "event_warning"
    case eventEnd = "event_end"
    case comboUp = "combo_up"
    case comboBreak = "combo_break"
    case shieldBreak = "shield_break"
    case death = "death"
}

func playSFX(_ sfx: SFX, on node: SKNode) {
    // Uses SKAction for non-blocking SFX playback
    // Falls back silently if file doesn't exist yet (placeholder-friendly)
    let fileName = "SFX/\(sfx.rawValue).wav"
    guard Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav", subdirectory: "SFX") != nil else {
        // File not yet added — skip silently
        return
    }
    node.run(SKAction.playSoundFileNamed(fileName, waitForCompletion: false))
}
```

Note: `SKAction.playSoundFileNamed` doesn't throw if the file is missing in some iOS versions, it just logs a warning. The guard check makes it explicit.

- [ ] **Step 2: Create SFX directory placeholder**

```bash
mkdir -p Descend/Audio/SFX
```

Create a `.gitkeep` file so the directory is tracked:
```bash
touch Descend/Audio/SFX/.gitkeep
```

- [ ] **Step 3: Wire SFX calls into GameScene collision**

In `didBegin(_:)`, after visual feedback:

```swift
// SFX
let sfx: AudioManager.SFX = platNode.platformType == .normal || platNode.platformType == .rest
    ? .land : .landSpecial
AudioManager.shared.playSFX(sfx, on: self)

// Platform-specific SFX
switch platNode.platformType {
case .bouncy: AudioManager.shared.playSFX(.bounce, on: self)
case .ice: AudioManager.shared.playSFX(.iceSlide, on: self)
case .teleport: AudioManager.shared.playSFX(.teleport, on: self)
default: break
}
```

Wire ghost safety in GameScene `didMove(to:)`:
```swift
itemSystem.onGhostExpired = { [weak self] in
    guard let self else { return }
    // Check if any platform is below the player
    let hasFloor = self.platformSystem.nearestPlatformX(to: self.playerNode.position) != nil
    if !hasFloor {
        let diff = self.difficulty.getDifficulty(platformCount: self.platformSystem.totalPlatformsGenerated)
        self.platformSystem.spawnSafetyPlatform(at: self.playerNode.position, difficulty: diff)
    }
}
```

In item pickup callback:
```swift
itemSystem.onItemPickup = { [weak self] type, position in
    guard let self else { return }
    let sfx: AudioManager.SFX = type.isRare ? .itemRare : .itemCommon
    AudioManager.shared.playSFX(sfx, on: self)
}
```

In event callbacks:
```swift
eventSystem.onEventWarning = { [weak self] event in
    guard let self else { return }
    AudioManager.shared.playSFX(.eventWarning, on: self)
}
eventSystem.onEventEnd = { [weak self] event in
    guard let self else { return }
    AudioManager.shared.playSFX(.eventEnd, on: self)
    self.scoreSystem.addScore(source: .surviveEvent,
                              hasDoubleScore: self.itemSystem.isActive(.doubleScore))
}
```

In `triggerGameOver()`:
```swift
AudioManager.shared.playSFX(.death, on: self)
```

- [ ] **Step 4: Build and verify**

Expected: BUILD SUCCEEDED. SFX calls will be no-ops until audio files are added.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add SFX support to AudioManager with placeholder directory"
```

---

### Task 17: Add score popup and combo visual effects

**Files:**
- Modify: `Descend/Systems/VisualEffects.swift`
- Modify: `Descend/Scenes/GameScene.swift`

- [ ] **Step 1: Add floating score popup to VisualEffects**

Add to `VisualEffects`:

```swift
// MARK: - Score Popup

func showScorePopup(at position: CGPoint, points: Int, combo: Int, multiplier: CGFloat) {
    guard let scene else { return }

    let theme = ThemeManager.shared.currentTheme
    let text = "+\(points)"
    let fontSize: CGFloat = combo >= 8 ? 18 : (combo >= 4 ? 16 : 14)

    let label = SKLabelNode(text: text)
    label.fontName = "SFProDisplay-Bold"
    label.fontSize = fontSize
    label.fontColor = multiplier >= 2.0
        ? UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)  // Gold for high combo
        : theme.colors.ui.textPrimary
    label.position = CGPoint(x: position.x, y: position.y + 15)
    label.zPosition = 200
    scene.addChild(label)

    let rise = SKAction.moveBy(x: 0, y: 30, duration: 0.5)
    rise.timingMode = .easeOut
    let fade = SKAction.fadeAlpha(to: 0, duration: 0.5)
    label.run(SKAction.group([rise, fade])) { label.removeFromParent() }
}

// MARK: - Combo Flame Trail

func createComboTrail(player: PlayerNode, combo: Int) {
    guard combo >= 4, let scene else { return }

    let intensity = min(CGFloat(combo - 4) / 8.0, 1.0)
    let size = player.size.width * (0.4 + intensity * 0.4)

    let flame = SKShapeNode(rectOf: CGSize(width: size, height: size))
    flame.fillColor = UIColor(red: 1, green: 0.4 + intensity * 0.4, blue: 0, alpha: 0.6)
    flame.strokeColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 0.4)
    flame.lineWidth = 1
    flame.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height / 2)
    flame.zPosition = player.zPosition - 1
    flame.blendMode = .add
    scene.addChild(flame)

    let rise = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: 15, duration: 0.2)
    let fade = SKAction.fadeAlpha(to: 0, duration: 0.2)
    let scale = SKAction.scale(to: 0.3, duration: 0.2)
    flame.run(SKAction.group([rise, fade, scale])) { flame.removeFromParent() }
}
```

- [ ] **Step 2: Wire score popup into ScoreSystem callback**

In `GameScene.didMove(to:)`:

```swift
scoreSystem.onScoreAdded = { [weak self] points, combo, multiplier in
    guard let self else { return }
    let pos = self.playerNode.position
    self.visualEffects.showScorePopup(at: pos, points: points, combo: combo, multiplier: multiplier)
}
```

- [ ] **Step 3: Add combo trail in update loop**

In `GameScene.update(_:)`, after the existing trail code:
```swift
visualEffects.createComboTrail(player: playerNode, combo: scoreSystem.combo)
```

- [ ] **Step 4: Add combo label next to score**

In GameScene, add property:
```swift
private var comboLabel: SKLabelNode!
```

In `setupScoreLabel(theme:)`, after the score label setup:
```swift
comboLabel = UIFactory.makeLabel(
    text: "",
    fontSize: 24,
    color: UIColor(red: 1, green: 0.84, blue: 0, alpha: 1),
    strokeColor: nil,
    strokeWidth: 0
)
comboLabel.fontName = "SFProDisplay-Bold"
comboLabel.horizontalAlignmentMode = .left
comboLabel.verticalAlignmentMode = .top
comboLabel.position = CGPoint(x: size.width / 2 + 40, y: size.height - 60)
comboLabel.zPosition = 100
addChild(comboLabel)
```

In `update(_:)`, after score update:
```swift
// Combo display
if scoreSystem.combo >= 2 {
    comboLabel.text = "×\(scoreSystem.combo)"
    comboLabel.setScale(scoreSystem.combo >= 8 ? 1.3 : 1.0)
} else {
    comboLabel.text = ""
}
```

- [ ] **Step 5: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add floating score popups, combo trail flames, and combo label"
```

---

### Task 18: Add unlock banner and item effect indicators

**Files:**
- Modify: `Descend/Systems/VisualEffects.swift`
- Modify: `Descend/Scenes/GameScene.swift`

- [ ] **Step 1: Add unlock banner to VisualEffects**

```swift
// MARK: - Unlock Banner

private var shownUnlocks: Set<String> = []

func showUnlockBanner(text: String) {
    guard let scene else { return }
    guard !shownUnlocks.contains(text) else { return }
    shownUnlocks.insert(text)

    let theme = ThemeManager.shared.currentTheme

    let label = SKLabelNode(text: text)
    label.fontName = "SFProDisplay-Bold"
    label.fontSize = 16
    label.fontColor = theme.colors.ui.textAccent
    label.position = CGPoint(x: gameWidth / 2, y: 80)
    label.zPosition = 200
    label.alpha = 0
    scene.addChild(label)

    let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.3)
    let wait = SKAction.wait(forDuration: 1.5)
    let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.3)
    label.run(SKAction.sequence([fadeIn, wait, fadeOut])) { label.removeFromParent() }
}

func resetUnlocks() {
    shownUnlocks.removeAll()
}
```

- [ ] **Step 2: Add shield glow effect**

```swift
// MARK: - Shield Glow

func addShieldGlow(to player: PlayerNode) {
    guard player.childNode(withName: "shield_glow") == nil else { return }

    let glow = SKShapeNode(circleOfRadius: player.size.width * 0.7)
    glow.name = "shield_glow"
    glow.fillColor = .clear
    glow.strokeColor = UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.6)
    glow.lineWidth = 2
    glow.zPosition = -1
    glow.glowWidth = 3
    player.addChild(glow)

    let pulse = SKAction.sequence([
        SKAction.fadeAlpha(to: 0.3, duration: 0.8),
        SKAction.fadeAlpha(to: 0.8, duration: 0.8)
    ])
    glow.run(SKAction.repeatForever(pulse))
}

func removeShieldGlow(from player: PlayerNode) {
    if let glow = player.childNode(withName: "shield_glow") {
        let burst = SKAction.group([
            SKAction.scale(to: 3, duration: 0.3),
            SKAction.fadeAlpha(to: 0, duration: 0.3)
        ])
        glow.run(burst) { glow.removeFromParent() }
    }
}
```

- [ ] **Step 3: Add item pickup flash**

```swift
// MARK: - Item Pickup Flash

func showItemPickupFlash(at position: CGPoint, type: ItemType) {
    guard let scene else { return }

    let color: UIColor = type.isRare
        ? UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.8)
        : UIColor(white: 1, alpha: 0.6)

    for _ in 0..<6 {
        let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
        let speed = CGFloat.random(in: 40...100)

        let particle = SKShapeNode(rectOf: CGSize(width: 3, height: 3))
        particle.fillColor = color
        particle.strokeColor = .clear
        particle.position = position
        particle.zPosition = 150
        scene.addChild(particle)

        let move = SKAction.moveBy(x: cos(angle) * speed * 0.3, y: sin(angle) * speed * 0.3, duration: 0.3)
        let fade = SKAction.fadeAlpha(to: 0, duration: 0.3)
        particle.run(SKAction.group([move, fade])) { particle.removeFromParent() }
    }
}
```

- [ ] **Step 4: Wire unlock banners in GameScene**

Track last known unlocked types to detect new unlocks. In `GameScene`, add property:
```swift
private var lastUnlockedPlatformCount = 2  // normal + rest
private var lastUnlockedItemCount = 0
```

In `update(_:)`, after getting `currentDifficulty`:
```swift
// Check for new unlocks
let platformCount = currentDifficulty.unlockedPlatformTypes.count
if platformCount > lastUnlockedPlatformCount {
    let newTypes = currentDifficulty.unlockedPlatformTypes.subtracting([.normal, .rest])
    // Find the newest type by checking what we didn't have before
    for type in newTypes {
        let name = "\(type)"
        visualEffects.showUnlockBanner(text: "New: \(name) platform!")
    }
    lastUnlockedPlatformCount = platformCount
}

let itemCount = currentDifficulty.unlockedItemTypes.count
if itemCount > lastUnlockedItemCount {
    lastUnlockedItemCount = itemCount
}
```

- [ ] **Step 5: Wire shield glow**

In GameScene `update(_:)`:
```swift
// Shield visual
if itemSystem.isActive(.shield) {
    visualEffects.addShieldGlow(to: playerNode)
} else {
    visualEffects.removeShieldGlow(from: playerNode)
}
```

Wire item pickup flash in the onItemPickup callback:
```swift
itemSystem.onItemPickup = { [weak self] type, position in
    guard let self else { return }
    let sfx: AudioManager.SFX = type.isRare ? .itemRare : .itemCommon
    AudioManager.shared.playSFX(sfx, on: self)
    self.visualEffects.showItemPickupFlash(at: position, type: type)

    // Bomb: clear all special/dangerous platforms, replace with normal
    if type == .bomb {
        self.platformSystem.replaceSpecialPlatformsWithNormal()
    }
}
```

Add to `PlatformSystem`:
```swift
func nearestPlatformX(to position: CGPoint) -> CGFloat? {
    var closest: CGFloat? = nil
    var minDist: CGFloat = .greatestFiniteMagnitude
    for platform in activePlatforms {
        let dy = abs(platform.position.y - position.y)
        if dy < minDist && platform.physicsBody != nil {
            minDist = dy
            closest = platform.position.x
        }
    }
    return closest
}

/// Spawn a temporary safety platform under the player (for ghost expiry)
func spawnSafetyPlatform(at position: CGPoint, difficulty: Difficulty) {
    let safeY = position.y - 30
    createPlatform(x: position.x, y: safeY, difficulty: difficulty, widthOverride: 100, type: .normal)
}

func replaceSpecialPlatformsWithNormal() {
    for platform in activePlatforms where platform.platformType != .normal && platform.platformType != .rest {
        platform.behavior?.onRecycle()
        platform.behavior = nil
        platform.platformType = .normal
        platform.alpha = 1.0
        platform.removeAllActions()
        // Restore physics in case fragile removed it
        platform.configurePhysics(width: platform.size.width, height: platformHeight)
        // Flash effect
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        platform.run(SKAction.repeat(flash, count: 2))
    }
}
```

- [ ] **Step 6: Reset unlock tracking in restartGame**

```swift
lastUnlockedPlatformCount = 2
lastUnlockedItemCount = 0
visualEffects.resetUnlocks()
```

- [ ] **Step 7: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add unlock banners, shield glow, and item pickup flash effects"
```

---

### Task 19: Add event visual effects

**Files:**
- Modify: `Descend/Systems/VisualEffects.swift`
- Modify: `Descend/Scenes/GameScene.swift`

- [ ] **Step 1: Add event warning and fog overlay to VisualEffects**

```swift
// MARK: - Event Visuals

func showEventWarning(event: GameEvent) {
    guard let scene else { return }

    // Warning border flash
    let border = SKShapeNode(rectOf: CGSize(width: gameWidth - 4, height: gameHeight - 4))
    border.fillColor = .clear
    border.strokeColor = UIColor.red.withAlphaComponent(0.6)
    border.lineWidth = 4
    border.position = CGPoint(x: gameWidth / 2, y: gameHeight / 2)
    border.zPosition = 300
    scene.addChild(border)

    let flash = SKAction.sequence([
        SKAction.fadeAlpha(to: 0.2, duration: 0.2),
        SKAction.fadeAlpha(to: 0.8, duration: 0.2)
    ])
    let flashRepeat = SKAction.repeat(flash, count: 3)
    let remove = SKAction.removeFromParent()
    border.run(SKAction.sequence([flashRepeat, remove]))

    // Event name label
    let label = SKLabelNode(text: eventDisplayName(event))
    label.fontName = "SFProDisplay-Black"
    label.fontSize = 22
    label.fontColor = .white
    label.position = CGPoint(x: gameWidth / 2, y: gameHeight / 2)
    label.zPosition = 301
    scene.addChild(label)

    let labelFade = SKAction.sequence([
        SKAction.wait(forDuration: 1.0),
        SKAction.fadeAlpha(to: 0, duration: 0.5),
        SKAction.removeFromParent()
    ])
    label.run(labelFade)
}

func addFogOverlay() -> SKCropNode? {
    guard let scene else { return nil }

    // Dark overlay covering the whole scene
    let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.85), size: CGSize(width: gameWidth, height: gameHeight))
    overlay.position = CGPoint(x: gameWidth / 2, y: gameHeight / 2)
    overlay.zPosition = 250

    // Crop node with circular mask around player
    let cropNode = SKCropNode()
    cropNode.zPosition = 250

    let maskNode = SKShapeNode(circleOfRadius: 80)
    maskNode.fillColor = .white
    maskNode.strokeColor = .clear
    maskNode.name = "fog_mask"

    // Invert: we want everything EXCEPT the circle to be dark
    // Use overlay approach instead of crop
    overlay.name = "fog_overlay"
    scene.addChild(overlay)

    return nil  // We'll update mask position in update loop
}

func updateFogOverlay(playerPosition: CGPoint) {
    guard let scene else { return }
    guard let overlay = scene.childNode(withName: "fog_overlay") as? SKSpriteNode else { return }

    // Create a hole texture centered on player
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: gameWidth, height: gameHeight))
    let image = renderer.image { ctx in
        UIColor.black.withAlphaComponent(0.85).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: gameWidth, height: gameHeight))

        // Clear a circle around the player (in UIKit coords: Y flipped)
        let uikitY = gameHeight - playerPosition.y
        let holeRect = CGRect(x: playerPosition.x - 80, y: uikitY - 80, width: 160, height: 160)
        ctx.cgContext.setBlendMode(.clear)
        ctx.cgContext.fillEllipse(in: holeRect)
    }
    overlay.texture = SKTexture(image: image)
}

func removeFogOverlay() {
    scene?.childNode(withName: "fog_overlay")?.removeFromParent()
}

private func eventDisplayName(_ event: GameEvent) -> String {
    switch event {
    case .gravityReverse: return "GRAVITY REVERSE"
    case .fog: return "FOG"
    case .earthquake: return "EARTHQUAKE"
    case .speedStorm: return "SPEED STORM"
    case .platformShrink: return "SHRINK"
    case .chaosGravity: return "CHAOS"
    }
}
```

- [ ] **Step 2: Wire event visuals in GameScene**

In `didMove(to:)`, set up event callbacks:

```swift
eventSystem.onEventWarning = { [weak self] event in
    guard let self else { return }
    AudioManager.shared.playSFX(.eventWarning, on: self)
    self.visualEffects.showEventWarning(event: event)
}
eventSystem.onEventStart = { [weak self] event in
    guard let self else { return }
    if event == .fog {
        _ = self.visualEffects.addFogOverlay()
    }
}
eventSystem.onEventEnd = { [weak self] event in
    guard let self else { return }
    AudioManager.shared.playSFX(.eventEnd, on: self)
    self.scoreSystem.addScore(source: .surviveEvent,
                              hasDoubleScore: self.itemSystem.isActive(.doubleScore))
    if event == .fog {
        self.visualEffects.removeFogOverlay()
    }
}
```

In `update(_:)`, update fog position:
```swift
if eventSystem.activeEvent == .fog {
    visualEffects.updateFogOverlay(playerPosition: playerNode.position)
}
```

- [ ] **Step 3: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add event warning borders, fog overlay, and event name displays"
```

---

### Task 20: Add active effect indicator HUD

**Files:**
- Modify: `Descend/Scenes/GameScene.swift`
- Modify: `Descend/Systems/VisualEffects.swift`

- [ ] **Step 1: Add effect indicator bar to VisualEffects**

```swift
// MARK: - Effect Indicators

private var effectIndicators: [ItemType: SKNode] = [:]

func updateEffectIndicators(activeEffects: [ItemType: TimeInterval]) {
    guard let scene else { return }

    // Remove indicators for expired effects
    for (type, node) in effectIndicators {
        if activeEffects[type] == nil {
            node.removeFromParent()
            effectIndicators.removeValue(forKey: type)
        }
    }

    // Add/update indicators for active effects
    var index: CGFloat = 0
    for (type, remaining) in activeEffects.sorted(by: { $0.key.duration > $1.key.duration }) {
        let x = 30 + index * 35
        let y = gameHeight - 100

        if let existing = effectIndicators[type] {
            existing.position = CGPoint(x: x, y: y)
            // Update progress bar
            if let bar = existing.childNode(withName: "progress") as? SKSpriteNode {
                let progress = type == .shield ? 1.0 : CGFloat(remaining / type.duration)
                bar.xScale = max(0, progress)
            }
        } else {
            let container = SKNode()
            container.position = CGPoint(x: x, y: y)
            container.zPosition = 200

            // Icon (small colored square as placeholder)
            let icon = SKSpriteNode(texture: ItemNode.generateTextureStatic(for: type, size: 16),
                                     size: CGSize(width: 16, height: 16))
            icon.position = .zero
            container.addChild(icon)

            // Progress bar background
            let bgBar = SKSpriteNode(color: UIColor(white: 0.3, alpha: 0.5), size: CGSize(width: 24, height: 3))
            bgBar.position = CGPoint(x: 0, y: -12)
            bgBar.anchorPoint = CGPoint(x: 0, y: 0.5)
            bgBar.position.x = -12
            container.addChild(bgBar)

            // Progress bar fill
            let fillBar = SKSpriteNode(color: .white, size: CGSize(width: 24, height: 3))
            fillBar.name = "progress"
            fillBar.anchorPoint = CGPoint(x: 0, y: 0.5)
            fillBar.position = CGPoint(x: -12, y: -12)
            container.addChild(fillBar)

            scene.addChild(container)
            effectIndicators[type] = container
        }
        index += 1
    }
}

func clearEffectIndicators() {
    for (_, node) in effectIndicators {
        node.removeFromParent()
    }
    effectIndicators.removeAll()
}
```

Wait — `ItemNode.generateTexture` is a private static method. We need to make it accessible. Rename to a static method or add a public static accessor.

- [ ] **Step 2: Make ItemNode texture generation accessible**

In `Descend/Nodes/ItemNode.swift`, rename the private method to a static public method:

Change `private static func generateTexture` to:

```swift
static func generateTexture(for type: ItemType, size: CGFloat) -> SKTexture {
```

(Remove the `private` keyword)

- [ ] **Step 3: Wire effect indicators in GameScene update**

In `update(_:)`, after item system update:
```swift
visualEffects.updateEffectIndicators(activeEffects: itemSystem.activeEffects)
```

In `restartGame()`:
```swift
visualEffects.clearEffectIndicators()
```

- [ ] **Step 4: Build and verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add active effect indicator HUD with progress bars"
```

---

## Phase 6: Integration & Polish

### Task 21: Full integration pass — verify all systems work together

**Files:**
- Modify: `Descend/Scenes/GameScene.swift` (cleanup and ordering)

- [ ] **Step 1: Review and consolidate GameScene.update**

Read the full `GameScene.swift` and ensure the update loop follows this order:

```swift
override func update(_ currentTime: TimeInterval) {
    // 1. Delta time
    let dt = ...
    guard gameState == .playing else { return }
    guard dt > 0, dt < 0.1 else { return }

    // 2. Record player state
    playerNode.recordVelocity()
    playerNode.checkAirborne()

    // 3. Update difficulty
    difficulty.update(delta: dt)
    let currentDifficulty = difficulty.getDifficulty(platformCount: platformSystem.totalPlatformsGenerated)

    // 4. Apply item effects to rise speed
    var modifiedRiseSpeed = currentDifficulty.riseSpeed
    if itemSystem.isActive(.freeze) { modifiedRiseSpeed = 0 }
    if itemSystem.isActive(.slowDown) { modifiedRiseSpeed *= 0.6 }

    // 5. Apply event effects
    if let event = eventSystem.activeEvent {
        switch event {
        case .speedStorm: modifiedRiseSpeed *= 1.5
        default: break
        }
    }
    let effectiveDifficulty = currentDifficulty.withRiseSpeed(modifiedRiseSpeed)

    // 6. Update gravity
    var gravityY = currentDifficulty.gravity
    if eventSystem.activeEvent == .gravityReverse {
        gravityY = -gravityY
    }
    if eventSystem.activeEvent == .chaosGravity {
        let chaosX = CGFloat.random(in: -100...100)
        physicsWorld.gravity = CGVector(dx: chaosX, dy: gravityY)
    } else {
        physicsWorld.gravity = CGVector(dx: 0, dy: gravityY)
    }

    // 7. Update systems
    platformSystem.update(delta: dt, difficulty: effectiveDifficulty)
    itemSystem.update(delta: dt, player: playerNode, difficulty: currentDifficulty)
    eventSystem.update(delta: dt, difficulty: currentDifficulty)
    scoreSystem.update(delta: dt)

    // 8. Magnet effect: find nearest platform X and feed to InputHandler
    if itemSystem.isActive(.magnet) {
        let nearestX = platformSystem.nearestPlatformX(to: playerNode.position)
        inputHandler.magnetTarget = nearestX
    } else {
        inputHandler.magnetTarget = nil
    }

    // 9. Ghost safety: when ghost expires, spawn safety platform if needed
    // (handled by checking if ghost was active last frame but isn't now)

    // 10. Player physics
    applyPlayerPhysics(dt: dt)

    // 9. Death check (with shield/ghost/reverse)
    let isReversed = eventSystem.activeEvent == .gravityReverse
    let hitTop = isReversed ? playerNode.position.y < 50 : playerNode.position.y > size.height - 35
    let hitBottom = isReversed ? playerNode.position.y > size.height - 35 : playerNode.position.y < 50
    if hitTop || hitBottom {
        if itemSystem.isActive(.shield) {
            itemSystem.activeEffects.removeValue(forKey: .shield)
            scoreSystem.shieldUsed()
            visualEffects.removeShieldGlow(from: playerNode)
            AudioManager.shared.playSFX(.shieldBreak, on: self)
            HapticsManager.shared.vibrate(.heavy)
            if hitTop {
                playerNode.position.y = isReversed ? 80 : size.height - 60
                playerNode.physicsBody?.velocity.dy = isReversed ? 100 : -100
            } else {
                playerNode.position.y = isReversed ? size.height - 60 : 80
                playerNode.physicsBody?.velocity.dy = isReversed ? -100 : 100
            }
        } else if itemSystem.isActive(.ghost) {
            // Ghost — ignore death
        } else {
            triggerGameOver()
            return
        }
    }

    // Score display
    score = scoreSystem.score
    if score != lastDisplayedScore {
        scoreLabel.text = "\(score)"
        lastDisplayedScore = score
    }
    if scoreSystem.combo >= 2 {
        comboLabel.text = "×\(scoreSystem.combo)"
    } else {
        comboLabel.text = ""
    }

    // 11. Unlock banners
    let platformCount = currentDifficulty.unlockedPlatformTypes.count
    if platformCount > lastUnlockedPlatformCount {
        for type in currentDifficulty.unlockedPlatformTypes.subtracting([.normal, .rest]) {
            visualEffects.showUnlockBanner(text: "New: \(type) platform!")
        }
        lastUnlockedPlatformCount = platformCount
    }

    // 12. Shield visual
    if itemSystem.isActive(.shield) {
        visualEffects.addShieldGlow(to: playerNode)
    }

    // 13. Fog
    if eventSystem.activeEvent == .fog {
        visualEffects.updateFogOverlay(playerPosition: playerNode.position)
    }

    // 14. Effect indicators
    visualEffects.updateEffectIndicators(activeEffects: itemSystem.activeEffects)

    // 15. Visuals
    visualEffects.createPlayerTrail(player: playerNode)
    visualEffects.createComboTrail(player: playerNode, combo: scoreSystem.combo)
    visualEffects.updateTrailEffect(delta: dt)
    visualEffects.updateStars(deltaSeconds: dt, riseSpeed: effectiveDifficulty.riseSpeed)
}
```

- [ ] **Step 2: Consolidate restartGame**

Ensure `restartGame()` resets all systems:

```swift
private func restartGame() {
    HapticsManager.shared.vibrate(.light)

    gameOverOverlay?.removeFromParent()
    gameOverOverlay = nil

    // Reset all systems
    platformSystem.reset()
    itemSystem.reset()
    eventSystem.reset()
    scoreSystem.reset()
    inputHandler.reset()
    playerNode.resetFlags()
    difficulty.reset()
    visualEffects.resetTrail()
    visualEffects.resetUnlocks()
    visualEffects.clearEffectIndicators()
    visualEffects.removeFogOverlay()

    // Reset state
    score = 0
    lastDisplayedScore = -1
    scoreLabel.text = "0"
    comboLabel.text = ""
    lastUpdateTime = 0
    lastUnlockedPlatformCount = 2
    lastUnlockedItemCount = 0

    // Reposition player
    playerNode.position = CGPoint(x: size.width / 2, y: size.height / 2 - 100)
    playerNode.physicsBody?.velocity = .zero
    playerNode.alpha = 1.0

    // Reset gravity
    physicsWorld.gravity = CGVector(dx: 0, dy: -200)

    // Recreate platforms
    platformSystem.createInitialPlatforms(difficulty: difficulty.getDifficulty(platformCount: 0))

    showStartOverlay()
}
```

- [ ] **Step 3: Ensure didSimulatePhysics uses dynamic fall speed**

```swift
override func didSimulatePhysics() {
    guard gameState == .playing else { return }
    guard let body = playerNode.physicsBody else { return }

    let currentDifficulty = difficulty.getDifficulty(platformCount: platformSystem.totalPlatformsGenerated)
    body.velocity.dx = CGFloat.clamp(body.velocity.dx, min: -300, max: 300)
    body.velocity.dy = CGFloat.clamp(body.velocity.dy, min: currentDifficulty.maxFallSpeed, max: 200)
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -project Descend.xcodeproj -scheme Descend -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: consolidate full game loop integration with all systems"
```

---

### Task 22: Add new files to Xcode project

**Files:**
- Modify: `Descend.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add all new Swift files to Xcode project**

The new files need to be registered in the Xcode project. The cleanest way is to open Xcode and drag them in, but via CLI we can use `ruby` to modify the pbxproj or use `xcodegen`. Since neither is set up, the pragmatic approach:

Open the project in Xcode:
```bash
open Descend.xcodeproj
```

Then in Xcode: right-click the appropriate groups → "Add Files to Descend" and add:
- `Systems/TimeBasedDifficulty.swift`
- `Systems/ScoreSystem.swift`
- `Systems/ItemSystem.swift`
- `Systems/EventSystem.swift`
- `Nodes/ItemNode.swift`
- `Nodes/Behaviors/PlatformBehavior.swift`
- `Nodes/Behaviors/MovingBehavior.swift`
- `Nodes/Behaviors/FragileBehavior.swift`
- `Nodes/Behaviors/IceBehavior.swift`
- `Nodes/Behaviors/BouncyBehavior.swift`
- `Nodes/Behaviors/TeleportBehavior.swift`
- `Nodes/Behaviors/ShrinkingBehavior.swift`
- `Nodes/Behaviors/InvisibleBehavior.swift`

Alternatively, use a script to add file references:

```bash
# Use ruby to add files to pbxproj - this is complex and error-prone.
# Recommended: use Xcode GUI or install xcodeproj gem:
# gem install xcodeproj
# Then run a script to add files programmatically.
```

If using `xcodeproj` gem is available, create a quick Ruby script. Otherwise, manual Xcode addition is safest.

- [ ] **Step 2: Build in Xcode to verify all files compile**

Cmd+B in Xcode. Fix any compilation errors.

- [ ] **Step 3: Commit the project file changes**

```bash
git add Descend.xcodeproj/project.pbxproj
git commit -m "chore: add new source files to Xcode project"
```

---

### Task 23: Play-test and tune parameters

This is a manual verification task.

- [ ] **Step 1: Run on simulator**

Build and run on iPhone 16 simulator. Play through the following checkpoints:

- [ ] **Step 2: Verify 0-30s** — Only normal/rest platforms. Score increments by 10. Gravity feels like starting value (-200).

- [ ] **Step 3: Verify 30-60s** — Moving platforms appear. Arrow markers visible on them. They oscillate left-right.

- [ ] **Step 4: Verify 60-90s** — Fragile platforms appear (crack texture). They collapse ~0.5s after landing. Common items (slowDown, shield) start spawning on platforms.

- [ ] **Step 5: Verify 90-120s** — Ice and bouncy platforms. Ice causes sliding. Bouncy launches player up. WideScreen item appears.

- [ ] **Step 6: Verify 120-150s** — Teleport pairs appear (purple). Landing teleports to paired platform. Magnet and doubleScore items appear.

- [ ] **Step 7: Verify 150s+** — Random events start. Shrinking and invisible platforms. Ghost and freeze items in air.

- [ ] **Step 8: Verify wave breathing** — Around every 60s there should be a noticeable difficulty dip.

- [ ] **Step 9: Verify combo** — Land quickly on consecutive platforms. "×N" label appears. Score popups show multiplied values.

- [ ] **Step 10: Verify shield** — Pick up shield (gold circle). Gold glow appears on player. Hitting death zone bounces back instead of dying.

- [ ] **Step 11: Tune if needed** — Adjust timing/values in `TimeBasedDifficulty` based on feel.

- [ ] **Step 12: Final commit**

```bash
git add -A
git commit -m "chore: parameter tuning after play-test"
```
