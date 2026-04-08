import SpriteKit

final class BackgroundSystem {
    private weak var scene: SKScene?
    private let gameWidth: CGFloat
    private let gameHeight: CGFloat

    // Two sprites per layer for seamless vertical scrolling
    private var hillsA: SKSpriteNode?
    private var hillsB: SKSpriteNode?

    private let hillsSpeed: CGFloat = 0.15 // fraction of rise speed

    init(scene: SKScene) {
        self.scene = scene
        self.gameWidth = scene.size.width
        self.gameHeight = scene.size.height
    }

    func applyTheme(_ theme: Theme) {
        // Remove old layers
        hillsA?.removeFromParent()
        hillsB?.removeFromParent()

        let hillsName = theme.mode == .dark ? "bg_dark_hills" : "bg_light_hills"
        let hillsTexture = SKTexture(imageNamed: hillsName)

        // Scale hills to fill screen width, maintain aspect ratio
        let texSize = hillsTexture.size()
        guard texSize.width > 0 else { return }
        let scale = gameWidth / texSize.width
        let scaledHeight = texSize.height * scale

        // Create two copies for seamless vertical loop
        hillsA = SKSpriteNode(texture: hillsTexture, size: CGSize(width: gameWidth, height: scaledHeight))
        hillsA?.anchorPoint = CGPoint(x: 0.5, y: 0)
        hillsA?.position = CGPoint(x: gameWidth / 2, y: 0)
        hillsA?.zPosition = -8
        hillsA?.alpha = 0.4

        hillsB = SKSpriteNode(texture: hillsTexture, size: CGSize(width: gameWidth, height: scaledHeight))
        hillsB?.anchorPoint = CGPoint(x: 0.5, y: 0)
        hillsB?.position = CGPoint(x: gameWidth / 2, y: scaledHeight)
        hillsB?.zPosition = -8
        hillsB?.alpha = 0.4

        if let a = hillsA { scene?.addChild(a) }
        if let b = hillsB { scene?.addChild(b) }
    }

    func update(delta: TimeInterval, riseSpeed: CGFloat) {
        guard let a = hillsA, let b = hillsB else { return }

        let movement = riseSpeed * hillsSpeed * CGFloat(delta)
        a.position.y += movement
        b.position.y += movement

        let h = a.size.height

        // Wrap: when a layer scrolls fully off the top, move it below the other
        if a.position.y >= gameHeight + h {
            a.position.y = b.position.y - h
        }
        if b.position.y >= gameHeight + h {
            b.position.y = a.position.y - h
        }
    }

    func reset() {
        guard let a = hillsA, let b = hillsB else { return }
        a.position = CGPoint(x: gameWidth / 2, y: 0)
        b.position = CGPoint(x: gameWidth / 2, y: a.size.height)
    }
}
