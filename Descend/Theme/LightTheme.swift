import UIKit

extension Theme {
    static let light = Theme(
        mode: .light,
        colors: ThemeColors(
            background: .init(
                top: UIColor(hex: "E8F4FD"),
                bottom: UIColor(hex: "FDF4E8")
            ),
            danger: .init(
                fill: UIColor(hex: "FF6B6B"),
                fillAlpha: 0.08,
                line: UIColor(hex: "FF6B6B"),
                lineAlpha: 0.25
            ),
            platformSchemes: [
                PlatformColorScheme(primary: UIColor(hex: "FF8A65"), secondary: UIColor(hex: "FFE0D6")),
                PlatformColorScheme(primary: UIColor(hex: "81C784"), secondary: UIColor(hex: "D5EED7")),
                PlatformColorScheme(primary: UIColor(hex: "64B5F6"), secondary: UIColor(hex: "D6EBFC")),
                PlatformColorScheme(primary: UIColor(hex: "FFD54F"), secondary: UIColor(hex: "FFF3D0")),
                PlatformColorScheme(primary: UIColor(hex: "BA68C8"), secondary: UIColor(hex: "EDD6F2")),
            ],
            ui: .init(
                panelBg: .white,
                panelBgAlpha: 0.75,
                buttonBg: .white,
                buttonBgAlpha: 0.9,
                buttonBorder: UIColor(hex: "E8E8E8"),
                textPrimary: UIColor(hex: "1A1A2E"),
                textAccent: UIColor(hex: "FF6B6B"),
                textSuccess: UIColor(hex: "00D9A5"),
                textDanger: UIColor(hex: "FF6B6B"),
                textStroke: nil,
                textStrokeWidth: 0,
                neonPrimary: UIColor(hex: "E0E0E0"),
                neonSecondary: UIColor(hex: "F5F5F5")
            ),
            effects: .init(
                trailColor: UIColor(hex: "64B5F6"),
                starColors: [
                    UIColor(hex: "FFD54F"),
                    UIColor(hex: "81C784"),
                    UIColor(hex: "64B5F6"),
                    UIColor(hex: "BA68C8"),
                ],
                particlePrimary: UIColor(hex: "FF8A65"),
                particleSecondary: UIColor(hex: "64B5F6")
            )
        ),
        bgmFileName: "sugar-sky"
    )
}
