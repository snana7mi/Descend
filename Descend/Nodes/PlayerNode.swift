import SpriteKit

final class PlayerNode: SKSpriteNode {
    var wasOnPlatform = false
    var lastVelocityY: CGFloat = 0

    init() {
        let texture = SKTexture(imageNamed: "player")
        let displaySize = CGSize(width: 28, height: 28)
        super.init(texture: texture, color: .clear, size: displaySize)

        zPosition = 10

        let bodySize = CGSize(
            width: displaySize.width * 0.85,
            height: displaySize.height * 0.85
        )
        let body = SKPhysicsBody(rectangleOf: bodySize)
        body.categoryBitMask = PhysicsMask.player
        body.collisionBitMask = PhysicsMask.platform
        body.contactTestBitMask = PhysicsMask.platform
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func recordVelocity() {
        lastVelocityY = physicsBody?.velocity.dy ?? 0
    }

    func checkAirborne() {
        if (physicsBody?.velocity.dy ?? 0) < -5 {
            wasOnPlatform = false
        }
    }

    func markOnPlatform() {
        wasOnPlatform = true
    }

    func resetFlags() {
        wasOnPlatform = false
        lastVelocityY = 0
    }
}
