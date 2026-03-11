import Foundation

enum DifficultyConfig {
    static let maxDifficultyScore: CGFloat = 800

    static let speedMin: CGFloat = 180
    static let speedMax: CGFloat = 500

    static let platformGapMin: CGFloat = 160
    static let platformGapMax: CGFloat = 240

    static let platformWidthMin: CGFloat = 120
    static let platformWidthMax: CGFloat = 45

    static let restPlatformInterval: Int = 15
    static let restPlatformWidthMultiplier: CGFloat = 1.5
    static let restPlatformGapMultiplier: CGFloat = 0.8

    static let basePlatformWidthMax: CGFloat = 150

    static func getDifficulty(score: Int, platformCount: Int = 0) -> Difficulty {
        let progress = CGFloat.clamp(CGFloat(score) / maxDifficultyScore, min: 0, max: 1)

        let riseSpeed = CGFloat.lerp(from: speedMin, to: speedMax, t: progress)
        let currentGap = CGFloat.lerp(from: platformGapMin, to: platformGapMax, t: progress)
        let currentWidth = CGFloat.lerp(from: platformWidthMin, to: platformWidthMax, t: progress)

        let isRestPlatform = platformCount > 0 && platformCount % restPlatformInterval == 0

        let finalGap = isRestPlatform ? currentGap * restPlatformGapMultiplier : currentGap
        let finalWidth = isRestPlatform ? currentWidth * restPlatformWidthMultiplier : currentWidth

        let spawnInterval = Double(finalGap / riseSpeed)

        return Difficulty(
            riseSpeed: riseSpeed,
            spawnInterval: spawnInterval,
            platformWidthMin: finalWidth * 0.9,
            platformWidthMax: finalWidth * 1.1,
            isRestPlatform: isRestPlatform
        )
    }
}
