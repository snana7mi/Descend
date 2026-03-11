import UIKit

extension Theme {
    static let dark = Theme(
        mode: .dark,
        colors: ThemeColors(
            background: .init(
                top: UIColor(hex: "0A0A2E"),
                bottom: UIColor(hex: "1A0A1A")
            ),
            danger: .init(
                fill: UIColor(hex: "FF0088"),
                fillAlpha: 0.25,
                line: UIColor(hex: "FF0088"),
                lineAlpha: 0.8
            ),
            platformSchemes: [
                PlatformColorScheme(primary: UIColor(hex: "00FFFF"), secondary: UIColor(hex: "0088FF")),
                PlatformColorScheme(primary: UIColor(hex: "FF00FF"), secondary: UIColor(hex: "8800FF")),
                PlatformColorScheme(primary: UIColor(hex: "00FF88"), secondary: UIColor(hex: "00FFCC")),
                PlatformColorScheme(primary: UIColor(hex: "FFFF00"), secondary: UIColor(hex: "FF8800")),
                PlatformColorScheme(primary: UIColor(hex: "FF0088"), secondary: UIColor(hex: "FF00FF")),
            ],
            ui: .init(
                panelBg: UIColor(hex: "0A0A2E"),
                panelBgAlpha: 0.85,
                buttonBg: .black,
                buttonBgAlpha: 0.5,
                buttonBorder: UIColor(hex: "00FFFF"),
                textPrimary: UIColor(hex: "00FFFF"),
                textAccent: UIColor(hex: "FF00FF"),
                textSuccess: UIColor(hex: "00FF88"),
                textDanger: UIColor(hex: "FF0088"),
                textStroke: .black,
                textStrokeWidth: 4,
                neonPrimary: UIColor(hex: "00FFFF"),
                neonSecondary: UIColor(hex: "FF00FF")
            ),
            effects: .init(
                trailColor: UIColor(hex: "FF88AA"),
                starColors: [
                    UIColor(hex: "00FFFF"),
                    UIColor(hex: "FF00FF"),
                    UIColor(hex: "00FF88"),
                    UIColor(hex: "FFFF00"),
                ],
                particlePrimary: UIColor(hex: "00FFFF"),
                particleSecondary: UIColor(hex: "0088FF")
            )
        ),
        bgmFileName: "pixel-heartbeat"
    )
}
