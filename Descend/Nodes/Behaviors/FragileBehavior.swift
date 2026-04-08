import SpriteKit

final class FragileBehavior: PlatformBehavior {
    private let collapseDelay: TimeInterval = 0.5
    private var isCollapsing = false

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        guard !isCollapsing else { return }
        isCollapsing = true

        // Shake animation
        let shakeRight = SKAction.moveBy(x: 3, y: 0, duration: 0.05)
        let shakeLeft = SKAction.moveBy(x: -6, y: 0, duration: 0.05)
        let shakeBack = SKAction.moveBy(x: 3, y: 0, duration: 0.05)
        let shake = SKAction.sequence([shakeRight, shakeLeft, shakeBack])
        let repeatedShake = SKAction.repeat(shake, count: 3)

        // Collapse after delay
        let wait = SKAction.wait(forDuration: collapseDelay)
        let collapse = SKAction.group([
            SKAction.fadeAlpha(to: 0, duration: 0.2),
            SKAction.scaleY(to: 0.1, duration: 0.2)
        ])
        let remove = SKAction.run { [weak platform] in
            platform?.physicsBody = nil
        }

        platform.run(SKAction.sequence([repeatedShake, wait, collapse, remove]),
                     withKey: "fragile_collapse")
    }

    func onRecycle() {
        isCollapsing = false
    }
}
