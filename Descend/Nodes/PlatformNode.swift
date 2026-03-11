import SpriteKit

final class PlatformNode: SKSpriteNode {
    var colorScheme: PlatformColorScheme
    var isCounted = false

    init(texture: SKTexture, colorScheme: PlatformColorScheme) {
        self.colorScheme = colorScheme
        super.init(texture: texture, color: .clear, size: texture.size())
        zPosition = 5
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configurePhysics(width: CGFloat, height: CGFloat) {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: width, height: height))
        body.isDynamic = false
        body.categoryBitMask = PhysicsMask.platform
        body.collisionBitMask = PhysicsMask.player
        body.contactTestBitMask = PhysicsMask.player
        body.friction = 0
        body.restitution = 0
        physicsBody = body
    }

    func activate(at position: CGPoint, width: CGFloat, height: CGFloat, texture: SKTexture, scheme: PlatformColorScheme) {
        self.position = position
        self.texture = texture
        self.size = CGSize(width: width, height: height)
        self.colorScheme = scheme
        self.isCounted = false
        self.isHidden = false
        configurePhysics(width: width, height: height)
    }

    func deactivate() {
        self.isHidden = true
        self.physicsBody = nil
        self.removeFromParent()
    }
}
