import SpriteKit

final class PlatformNode: SKSpriteNode {
    var colorScheme: PlatformColorScheme
    var isCounted = false
    var platformType: PlatformType = .normal
    var behavior: PlatformBehavior?

    var isIcePlatform: Bool { platformType == .ice }

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

    func activate(at position: CGPoint, width: CGFloat, height: CGFloat,
                  texture: SKTexture, scheme: PlatformColorScheme,
                  type: PlatformType = .normal, behavior: PlatformBehavior? = nil) {
        self.position = position
        self.texture = texture
        self.size = CGSize(width: width, height: height)
        self.colorScheme = scheme
        self.isCounted = false
        self.isHidden = false
        self.platformType = type
        self.behavior = behavior
        configurePhysics(width: width, height: height)
    }

    func deactivate() {
        behavior?.onRecycle()
        behavior = nil
        platformType = .normal
        self.isHidden = true
        self.physicsBody = nil
        self.removeFromParent()
    }
}
