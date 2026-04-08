import Foundation

final class ScoreSystem {
    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var multiplier: CGFloat = 1.0

    private var timeSinceLastLand: TimeInterval = 0
    private let comboTimeout: TimeInterval = 1.5
    private var isTracking = false

    // Survival scoring: 1 point per second, scaling with elapsed time
    private var survivalAccumulator: TimeInterval = 0
    private let survivalInterval: TimeInterval = 1.0 // award points every 1 second

    // Callback for visual feedback: (points, combo, multiplier)
    var onScoreAdded: ((_ points: Int, _ combo: Int, _ multiplier: CGFloat) -> Void)?

    func update(delta: TimeInterval, elapsedTime: TimeInterval) {
        if isTracking {
            timeSinceLastLand += delta
            if timeSinceLastLand > comboTimeout {
                breakCombo()
            }
        }

        // Survival scoring: scales with time (1 pt/s at start, up to 5 pt/s at 300s)
        survivalAccumulator += delta
        if survivalAccumulator >= survivalInterval {
            survivalAccumulator -= survivalInterval
            let timeScale = 1 + Int(min(elapsedTime / 75, 4)) // 1→5 over 300s
            score += timeScale
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
        survivalAccumulator = 0
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
