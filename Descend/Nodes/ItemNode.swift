import SpriteKit

final class ItemNode: SKSpriteNode {
    let itemType: ItemType

    init(type: ItemType) {
        self.itemType = type

        let texture = ItemNode.generateTexture(for: type, size: 24)
        super.init(texture: texture, color: .clear, size: CGSize(width: 24, height: 24))
        zPosition = 15

        // Idle bobbing animation
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 6, duration: 0.8),
            SKAction.moveBy(x: 0, y: -6, duration: 0.8)
        ])
        run(SKAction.repeatForever(bob), withKey: "bob")

        // Gentle glow pulse
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])
        run(SKAction.repeatForever(pulse), withKey: "pulse")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func deactivate() {
        removeAllActions()
        removeFromParent()
    }

    // MARK: - Texture Generation

    static func generateTexture(for type: ItemType, size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext

            switch type {
            case .slowDown:
                // Blue clock
                UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1).setFill()
                gc.fillEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
                UIColor.white.setStroke()
                gc.setLineWidth(2)
                gc.move(to: CGPoint(x: size/2, y: size/2))
                gc.addLine(to: CGPoint(x: size/2, y: size * 0.25))
                gc.move(to: CGPoint(x: size/2, y: size/2))
                gc.addLine(to: CGPoint(x: size * 0.7, y: size/2))
                gc.strokePath()

            case .shield:
                // Gold circle
                UIColor(red: 1, green: 0.84, blue: 0, alpha: 1).setFill()
                UIColor(red: 1, green: 0.65, blue: 0, alpha: 1).setStroke()
                gc.setLineWidth(2)
                gc.fillEllipse(in: CGRect(x: 3, y: 3, width: size - 6, height: size - 6))
                gc.strokeEllipse(in: CGRect(x: 3, y: 3, width: size - 6, height: size - 6))

            case .wideScreen:
                // Green horizontal arrows
                UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1).setFill()
                let arrowPath = UIBezierPath()
                arrowPath.move(to: CGPoint(x: 2, y: size/2))
                arrowPath.addLine(to: CGPoint(x: 8, y: size/2 - 5))
                arrowPath.addLine(to: CGPoint(x: 8, y: size/2 + 5))
                arrowPath.close()
                arrowPath.fill()
                let rightArrow = UIBezierPath()
                rightArrow.move(to: CGPoint(x: size - 2, y: size/2))
                rightArrow.addLine(to: CGPoint(x: size - 8, y: size/2 - 5))
                rightArrow.addLine(to: CGPoint(x: size - 8, y: size/2 + 5))
                rightArrow.close()
                rightArrow.fill()
                gc.fill(CGRect(x: 7, y: size/2 - 1.5, width: size - 14, height: 3))

            case .magnet:
                // Red U-shape
                UIColor.red.setStroke()
                gc.setLineWidth(3)
                let magnetPath = UIBezierPath()
                magnetPath.addArc(withCenter: CGPoint(x: size/2, y: size * 0.55),
                                  radius: size * 0.3,
                                  startAngle: 0, endAngle: .pi, clockwise: true)
                magnetPath.stroke()
                gc.move(to: CGPoint(x: size * 0.2, y: size * 0.55))
                gc.addLine(to: CGPoint(x: size * 0.2, y: size * 0.2))
                gc.move(to: CGPoint(x: size * 0.8, y: size * 0.55))
                gc.addLine(to: CGPoint(x: size * 0.8, y: size * 0.2))
                gc.strokePath()

            case .doubleScore:
                // Gold "×2"
                let font = UIFont.boldSystemFont(ofSize: size * 0.55)
                let text = "×2" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)
                ]
                let textSize = text.size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (size - textSize.width) / 2,
                    y: (size - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attrs)

            case .ghost:
                // White semi-transparent circle
                UIColor(white: 1, alpha: 0.5).setFill()
                gc.fillEllipse(in: CGRect(x: 3, y: 3, width: size - 6, height: size - 6))
                UIColor(white: 1, alpha: 0.8).setStroke()
                gc.setLineWidth(1)
                gc.setLineDash(phase: 0, lengths: [3, 3])
                gc.strokeEllipse(in: CGRect(x: 3, y: 3, width: size - 6, height: size - 6))

            case .freeze:
                // Ice blue snowflake
                let center = CGPoint(x: size/2, y: size/2)
                UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 1).setStroke()
                gc.setLineWidth(2)
                for angle in stride(from: 0.0, to: CGFloat.pi * 2, by: CGFloat.pi / 3) {
                    gc.move(to: center)
                    gc.addLine(to: CGPoint(
                        x: center.x + cos(angle) * size * 0.35,
                        y: center.y + sin(angle) * size * 0.35
                    ))
                }
                gc.strokePath()

            case .bomb:
                // Red circle with fuse
                UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1).setFill()
                gc.fillEllipse(in: CGRect(x: 4, y: 5, width: size - 8, height: size - 9))
                UIColor(red: 1, green: 0.6, blue: 0, alpha: 1).setStroke()
                gc.setLineWidth(2)
                gc.move(to: CGPoint(x: size/2, y: 5))
                gc.addLine(to: CGPoint(x: size * 0.65, y: 1))
                gc.strokePath()
            }
        }
        return SKTexture(image: image)
    }
}
