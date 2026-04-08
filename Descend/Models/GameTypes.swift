import UIKit

// MARK: - Physics Bitmasks

enum PhysicsMask {
    static let player: UInt32   = 0x1
    static let platform: UInt32 = 0x2
    static let boundary: UInt32 = 0x4
}

// MARK: - Vibration

enum VibrationType {
    case light
    case medium
    case heavy
    case error
}

// MARK: - Platform Color Scheme

struct PlatformColorScheme: Sendable {
    let primary: UIColor
    let secondary: UIColor
}

// MARK: - Platform Spawn Result

struct PlatformSpawnResult {
    let x: CGFloat
    let width: CGFloat
}

// MARK: - Difficulty

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

// MARK: - Game State

enum GameState {
    case waitingToStart
    case playing
    case gameOver
}

// MARK: - Spawn Strategy Config

struct SpawnStrategyConfig {
    let jumpDistanceMax: CGFloat
    let jumpDistanceMin: CGFloat
    let narrowWidthThreshold: CGFloat
    let sideSwitchChance: CGFloat
    let maxSameSideCount: Int
}

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
