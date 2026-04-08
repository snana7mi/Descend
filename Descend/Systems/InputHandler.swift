import SpriteKit

final class InputHandler {
    private weak var player: PlayerNode?
    private let sceneWidth: CGFloat

    private(set) var isDragging = false
    private var targetX: CGFloat = 0
    private var lastPointerX: CGFloat = 0
    private var pointerVelocity: CGFloat = 0

    var isEnabled = true
    var onIcePlatform = false
    var magnetTarget: CGFloat? = nil

    init(player: PlayerNode, sceneWidth: CGFloat) {
        self.player = player
        self.sceneWidth = sceneWidth
    }

    func touchBegan(at location: CGPoint) {
        guard isEnabled, let player else { return }
        isDragging = true
        lastPointerX = location.x
        targetX = player.position.x
        pointerVelocity = 0
    }

    func touchMoved(to location: CGPoint) {
        guard isEnabled, isDragging, let player else { return }

        let deltaX = location.x - lastPointerX
        lastPointerX = location.x
        targetX += deltaX
        targetX = CGFloat.clamp(targetX, min: 20, max: sceneWidth - 20)

        let diff = targetX - player.position.x
        let rawVelocity = CGFloat.clamp(diff * 15, min: -400, max: 400)
        pointerVelocity = onIcePlatform ? rawVelocity * 1.5 : rawVelocity
        player.physicsBody?.velocity.dx = pointerVelocity
    }

    func touchEnded() {
        guard isEnabled else { return }
        isDragging = false
        player?.physicsBody?.velocity.dx = pointerVelocity * 0.5
    }

    func reset() {
        isDragging = false
        targetX = 0
        lastPointerX = 0
        pointerVelocity = 0
        onIcePlatform = false
        magnetTarget = nil
    }
}
