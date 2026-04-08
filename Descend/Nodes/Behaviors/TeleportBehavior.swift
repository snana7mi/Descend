import SpriteKit

final class TeleportBehavior: PlatformBehavior {
    weak var pairedPlatform: PlatformNode?
    private var hasTriggered = false

    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {
        guard !hasTriggered else { return }
        guard let target = pairedPlatform, target.parent != nil else { return }
        hasTriggered = true

        // Blink out
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.15)
        let teleport = SKAction.run {
            player.position = CGPoint(x: target.position.x, y: target.position.y + target.size.height / 2 + player.size.height / 2)
            player.physicsBody?.velocity = .zero
        }
        let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.15)

        player.run(SKAction.sequence([fadeOut, teleport, fadeIn]))
    }

    func onRecycle() {
        pairedPlatform = nil
        hasTriggered = false
    }
}
