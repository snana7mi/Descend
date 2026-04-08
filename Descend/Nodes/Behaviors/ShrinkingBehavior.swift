import SpriteKit

final class ShrinkingBehavior: PlatformBehavior {
    private let shrinkFactor: CGFloat = 0.7  // 30% reduction
    private let minWidth: CGFloat = 25
    private var stompCount = 0

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        stompCount += 1
        let newWidth = platform.size.width * shrinkFactor

        if newWidth < minWidth {
            // Too small — collapse
            let shrink = SKAction.group([
                SKAction.resize(toWidth: 0, duration: 0.2),
                SKAction.fadeAlpha(to: 0, duration: 0.2)
            ])
            platform.run(shrink) { [weak platform] in
                platform?.physicsBody = nil
            }
        } else {
            // Shrink with animation
            let shrinkAction = SKAction.resize(toWidth: newWidth, duration: 0.15)
            shrinkAction.timingMode = .easeOut
            platform.run(shrinkAction) { [weak platform] in
                guard let platform else { return }
                platform.configurePhysics(width: newWidth, height: platform.size.height)
            }
        }
    }

    func onRecycle() {
        stompCount = 0
    }
}
