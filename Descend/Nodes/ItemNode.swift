import SpriteKit

final class ItemNode: SKSpriteNode {
    let itemType: ItemType

    init(type: ItemType) {
        self.itemType = type

        let texture = ItemNode.generateTexture(for: type, size: 24)
        super.init(texture: texture, color: .clear, size: CGSize(width: 24, height: 24))
        zPosition = 15

        // Idle bobbing animation
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 6, duration: 0.8),
            SKAction.moveBy(x: 0, y: -6, duration: 0.8)
        ])
        run(SKAction.repeatForever(bob), withKey: "bob")

        // Gentle glow pulse
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])
        run(SKAction.repeatForever(pulse), withKey: "pulse")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func deactivate() {
        removeAllActions()
        removeFromParent()
    }

    // MARK: - Texture (Kenney Abstract Platformer sprites)

    private static let spriteNames: [ItemType: String] = [
        .slowDown: "item_slowdown",
        .shield: "item_shield",
        .wideScreen: "item_widescreen",
        .magnet: "item_magnet",
        .doubleScore: "item_doublescore",
        .ghost: "item_ghost",
        .freeze: "item_freeze",
        .bomb: "item_bomb"
    ]

    static func generateTexture(for type: ItemType, size: CGFloat) -> SKTexture {
        let name = spriteNames[type] ?? "item_slowdown"
        return SKTexture(imageNamed: name)
    }
}
