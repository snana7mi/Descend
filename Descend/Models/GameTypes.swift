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
