import UIKit

final class ThemeManager {
    static let shared = ThemeManager()

    private(set) var currentTheme: Theme
    private var subscribers: [UUID: (Theme) -> Void] = [:]

    private init() {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        currentTheme = isDark ? .dark : .light
    }

    var isDark: Bool { currentTheme.mode == .dark }

    func updateForTraitCollection(_ traitCollection: UITraitCollection) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let newTheme: Theme = isDark ? .dark : .light
        guard newTheme.mode != currentTheme.mode else { return }
        currentTheme = newTheme
        notifySubscribers()
    }

    @discardableResult
    func subscribe(_ callback: @escaping (Theme) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = callback
        return id
    }

    func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    private func notifySubscribers() {
        for (_, callback) in subscribers {
            callback(currentTheme)
        }
    }
}
