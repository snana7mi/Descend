import CoreGraphics

final class PlatformSpawnStrategy {
    private let gameWidth: CGFloat
    private let spawnPadding: CGFloat
    private let config: SpawnStrategyConfig

    private var lastPlatformX: CGFloat
    private var consecutiveSameSide: Int = 0
    private var consecutiveNarrow: Int = 0
    private var currentDirection: Int = 1

    init(gameWidth: CGFloat, spawnPadding: CGFloat) {
        self.gameWidth = gameWidth
        self.spawnPadding = spawnPadding
        self.config = SpawnStrategyConfig(
            jumpDistanceMax: 200,
            jumpDistanceMin: 40,
            narrowWidthThreshold: 70,
            sideSwitchChance: 0.7,
            maxSameSideCount: 2
        )
        self.lastPlatformX = gameWidth / 2
    }

    func reset() {
        lastPlatformX = gameWidth / 2
        consecutiveSameSide = 0
        consecutiveNarrow = 0
        currentDirection = 1
    }

    func getNextPlatform(difficulty: Difficulty) -> PlatformSpawnResult {
        let width = calculateNextWidth(difficulty: difficulty)
        let x = calculateNextX(width: width)
        updateState(x: x, width: width)
        return PlatformSpawnResult(x: x, width: width)
    }

    func setLastPlatform(x: CGFloat) {
        lastPlatformX = x
    }

    // MARK: - Private

    private func calculateNextWidth(difficulty: Difficulty) -> CGFloat {
        var minW = difficulty.platformWidthMin
        var maxW = difficulty.platformWidthMax

        if consecutiveNarrow >= 1 {
            minW = max(minW, config.narrowWidthThreshold + 10)
            maxW = max(maxW, minW + 20)
        }

        let availableScreen = gameWidth - spawnPadding * 2
        maxW = min(maxW, availableScreen)
        minW = min(minW, maxW)

        return CGFloat.random(in: minW...maxW)
    }

    private func calculateNextX(width: CGFloat) -> CGFloat {
        let halfWidth = width / 2
        let minScreenX = spawnPadding + halfWidth
        let maxScreenX = gameWidth - spawnPadding - halfWidth

        guard minScreenX <= maxScreenX else { return gameWidth / 2 }

        var tryDirection = currentDirection

        if CGFloat.random(in: 0...1) < config.sideSwitchChance {
            tryDirection *= -1
        }

        let isRightSide = lastPlatformX > gameWidth / 2
        let directionToCenter = isRightSide ? -1 : 1

        if consecutiveSameSide >= config.maxSameSideCount {
            tryDirection = directionToCenter
        }

        var result = computeTargetRange(direction: tryDirection, minScreenX: minScreenX, maxScreenX: maxScreenX)

        if result.validMin > result.validMax {
            tryDirection *= -1
            result = computeTargetRange(direction: tryDirection, minScreenX: minScreenX, maxScreenX: maxScreenX)
        }

        if result.validMin > result.validMax {
            let safeRange = config.jumpDistanceMax
            result.validMin = max(minScreenX, lastPlatformX - safeRange)
            result.validMax = min(maxScreenX, lastPlatformX + safeRange)
        }

        let nextX = CGFloat.random(in: result.validMin...max(result.validMin, result.validMax))
        currentDirection = nextX >= lastPlatformX ? 1 : -1

        return nextX
    }

    private func computeTargetRange(direction: Int, minScreenX: CGFloat, maxScreenX: CGFloat) -> (validMin: CGFloat, validMax: CGFloat) {
        let targetMin: CGFloat
        let targetMax: CGFloat

        if direction == 1 {
            targetMin = lastPlatformX + config.jumpDistanceMin
            targetMax = lastPlatformX + config.jumpDistanceMax
        } else {
            targetMin = lastPlatformX - config.jumpDistanceMax
            targetMax = lastPlatformX - config.jumpDistanceMin
        }

        let validMin = max(minScreenX, targetMin)
        let validMax = min(maxScreenX, targetMax)
        return (validMin, validMax)
    }

    private func updateState(x: CGFloat, width: CGFloat) {
        let centerX = gameWidth / 2
        let wasRight = lastPlatformX > centerX
        let isRight = x > centerX

        if wasRight == isRight {
            consecutiveSameSide += 1
        } else {
            consecutiveSameSide = 0
        }

        if width < config.narrowWidthThreshold {
            consecutiveNarrow += 1
        } else {
            consecutiveNarrow = 0
        }

        lastPlatformX = x
    }
}
