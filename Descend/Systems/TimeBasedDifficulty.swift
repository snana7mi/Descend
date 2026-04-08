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

    func waveFactor() -> CGFloat {
        return 1.0 - waveDepth * sin(wavePhase())
    }

    func isBreathingPhase() -> Bool {
        return waveDepth * sin(wavePhase()) > waveDepth * 0.5
    }

    private func wavePhase() -> CGFloat {
        let phase = CGFloat(elapsedTime.truncatingRemainder(dividingBy: wavePeriod)) / CGFloat(wavePeriod)
        return phase * .pi * 2
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
