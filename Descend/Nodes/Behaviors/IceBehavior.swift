import SpriteKit

final class IceBehavior: PlatformBehavior {
    // Ice effect is handled by InputHandler checking platform type.
    // This behavior adds the visual sparkle effect on landing.

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        guard let scene = platform.scene else { return }

        for _ in 0..<4 {
            let sparkle = SKShapeNode(circleOfRadius: 2)
            sparkle.fillColor = UIColor(white: 1, alpha: 0.8)
            sparkle.strokeColor = .clear
            sparkle.position = CGPoint(
                x: platform.position.x + CGFloat.random(in: -platform.size.width/2...platform.size.width/2),
                y: platform.position.y + platform.size.height / 2
            )
            sparkle.zPosition = 50
            scene.addChild(sparkle)

            let rise = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: 20, duration: 0.5)
            let fade = SKAction.fadeAlpha(to: 0, duration: 0.5)
            sparkle.run(SKAction.group([rise, fade])) { sparkle.removeFromParent() }
        }
    }
}
