import UIKit

final class HapticsManager {
    static let shared = HapticsManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let errorGenerator = UINotificationFeedbackGenerator()

    private init() {
        prepare()
    }

    func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
    }

    func vibrate(_ type: VibrationType) {
        switch type {
        case .light:
            lightGenerator.impactOccurred()
            lightGenerator.prepare()
        case .medium:
            mediumGenerator.impactOccurred()
            mediumGenerator.prepare()
        case .heavy:
            heavyGenerator.impactOccurred()
            heavyGenerator.prepare()
        case .error:
            errorGenerator.notificationOccurred(.error)
        }
    }
}
