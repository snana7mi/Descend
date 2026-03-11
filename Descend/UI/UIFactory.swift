import SpriteKit

enum UIFactory {
    static func makeLabel(
        text: String,
        fontSize: CGFloat,
        color: UIColor,
        strokeColor: UIColor? = nil,
        strokeWidth: CGFloat = 0
    ) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "SFProDisplay-Bold"
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 100

        if let stroke = strokeColor, strokeWidth > 0 {
            let attributed = NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                    .foregroundColor: color,
                    .strokeColor: stroke,
                    .strokeWidth: -strokeWidth,
                ]
            )
            label.attributedText = attributed
        }

        return label
    }

    static func makePanel(
        size: CGSize,
        bgColor: UIColor,
        bgAlpha: CGFloat,
        cornerRadius: CGFloat,
        borderColor: UIColor,
        borderWidth: CGFloat,
        isDark: Bool
    ) -> SKShapeNode {
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let panel = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        panel.fillColor = bgColor.withAlphaComponent(bgAlpha)
        panel.strokeColor = isDark ? borderColor.withAlphaComponent(0.8) : UIColor.white.withAlphaComponent(0.6)
        panel.lineWidth = borderWidth
        panel.zPosition = 90
        return panel
    }

    static func makePulsingLabel(
        text: String,
        fontSize: CGFloat,
        color: UIColor
    ) -> SKLabelNode {
        let label = makeLabel(text: text, fontSize: fontSize, color: color)
        let fadeOut = SKAction.fadeAlpha(to: 0.5, duration: 0.8)
        fadeOut.timingMode = .easeInEaseOut
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        fadeIn.timingMode = .easeInEaseOut
        label.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
        return label
    }
}
