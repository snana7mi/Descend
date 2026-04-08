import SpriteKit

final class InvisibleBehavior: PlatformBehavior {
    private let revealDistance: CGFloat = 80
    private var isRevealed = false
    private weak var playerRef: PlayerNode?

    func setPlayer(_ player: PlayerNode) {
        playerRef = player
    }

    func update(delta: TimeInterval, platform: PlatformNode) {
        guard let player = playerRef else {
            platform.alpha = 0.15
            return
        }

        let dx = player.position.x - platform.position.x
        let dy = player.position.y - platform.position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < revealDistance {
            if !isRevealed {
                isRevealed = true
                let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: 0.2)
                platform.run(fadeIn, withKey: "invisible_reveal")
            }
        } else {
            if isRevealed {
                isRevealed = false
                let fadeOut = SKAction.fadeAlpha(to: 0.15, duration: 0.3)
                platform.run(fadeOut, withKey: "invisible_reveal")
            }
        }
    }

    func onRecycle() {
        isRevealed = false
        playerRef = nil
    }
}
