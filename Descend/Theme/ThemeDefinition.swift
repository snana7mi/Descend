import UIKit

// MARK: - Theme Mode

enum ThemeMode: Sendable {
    case dark
    case light
}

// MARK: - Theme Colors

struct ThemeColors: Sendable {
    struct Background: Sendable {
        let top: UIColor
        let bottom: UIColor
    }

    struct Danger: Sendable {
        let fill: UIColor
        let fillAlpha: CGFloat
        let line: UIColor
        let lineAlpha: CGFloat
    }

    struct UI: Sendable {
        let panelBg: UIColor
        let panelBgAlpha: CGFloat
        let buttonBg: UIColor
        let buttonBgAlpha: CGFloat
        let buttonBorder: UIColor
        let textPrimary: UIColor
        let textAccent: UIColor
        let textSuccess: UIColor
        let textDanger: UIColor
        let textStroke: UIColor?
        let textStrokeWidth: CGFloat
        let neonPrimary: UIColor
        let neonSecondary: UIColor
    }

    struct Effects: Sendable {
        let trailColor: UIColor
        let starColors: [UIColor]
        let particlePrimary: UIColor
        let particleSecondary: UIColor
    }

    let background: Background
    let danger: Danger
    let platformSchemes: [PlatformColorScheme]
    let ui: UI
    let effects: Effects
}

// MARK: - Theme

struct Theme: Sendable {
    let mode: ThemeMode
    let colors: ThemeColors
    let bgmFileName: String
}
