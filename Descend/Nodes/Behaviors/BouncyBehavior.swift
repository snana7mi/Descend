import SpriteKit

final class BouncyBehavior: PlatformBehavior {
    private let bounceImpulse: CGFloat = 350

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        // Apply upward impulse
        player.physicsBody?.velocity.dy = bounceImpulse

        // Spring animation on platform
        let squash = SKAction.scaleY(to: 0.6, duration: 0.08)
        squash.timingMode = .easeOut
        let stretch = SKAction.scaleY(to: 1.2, duration: 0.1)
        stretch.timingMode = .easeOut
        let recover = SKAction.scaleY(to: 1.0, duration: 0.15)
        recover.timingMode = .easeInEaseOut
        platform.run(SKAction.sequence([squash, stretch, recover]), withKey: "bouncy_spring")
    }
}
