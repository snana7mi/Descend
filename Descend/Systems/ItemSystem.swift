import SpriteKit

final class ItemSystem {
    private weak var scene: SKScene?
    private let gameWidth: CGFloat
    private let gameHeight: CGFloat

    private var activeItems: [ItemNode] = []
    private let maxActiveItems = 2

    private(set) var activeEffects: [ItemType: TimeInterval] = [:]
    private var platformsSinceLastCommon = 0
    private var platformsSinceLastRare = 0
    private let commonInterval = (min: 8, max: 15)
    private let rareInterval = (min: 20, max: 30)
    private var nextCommonAt: Int
    private var nextRareAt: Int

    private let pickupRadius: CGFloat = 20

    // Callbacks
    var onItemPickup: ((_ type: ItemType, _ position: CGPoint) -> Void)?
    var onGhostExpired: (() -> Void)?

    init(scene: SKScene) {
        self.scene = scene
        self.gameWidth = scene.size.width
        self.gameHeight = scene.size.height
        self.nextCommonAt = Int.random(in: commonInterval.min...commonInterval.max)
        self.nextRareAt = Int.random(in: rareInterval.min...rareInterval.max)
    }

    // MARK: - Queries

    func isActive(_ type: ItemType) -> Bool {
        return activeEffects[type] != nil
    }

    func removeEffect(_ type: ItemType) {
        activeEffects.removeValue(forKey: type)
    }

    // MARK: - Update

    func update(delta: TimeInterval, player: PlayerNode, difficulty: Difficulty) {
        // Tick down active effects
        var expiredEffects: [ItemType] = []
        for (type, remaining) in activeEffects {
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                expiredEffects.append(type)
            } else {
                activeEffects[type] = newRemaining
            }
        }
        for type in expiredEffects {
            activeEffects.removeValue(forKey: type)
            if type == .ghost {
                onGhostExpired?()
            }
        }

        // Ghost warning: flash player when < 0.5s remaining
        if let ghostRemaining = activeEffects[.ghost], ghostRemaining < 0.5 {
            let blinkPhase = Int(ghostRemaining * 10) % 2
            player.alpha = blinkPhase == 0 ? 0.3 : 0.8
        } else if !isActive(.ghost) && player.alpha < 1.0 {
            player.alpha = 1.0
        }

        // Check pickups
        for i in stride(from: activeItems.count - 1, through: 0, by: -1) {
            let item = activeItems[i]

            // Move with platform rise
            item.position.y += difficulty.riseSpeed * CGFloat(delta)

            // Remove if off screen
            if item.position.y > gameHeight + 30 {
                recycleItem(at: i)
                continue
            }

            // Pickup detection
            let dx = player.position.x - item.position.x
            let dy = player.position.y - item.position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < pickupRadius {
                applyItem(item.itemType)
                onItemPickup?(item.itemType, item.position)
                recycleItem(at: i)
            }
        }
    }

    // MARK: - Spawn Notification (called by PlatformSystem)

    func onPlatformSpawned(position: CGPoint, width: CGFloat, difficulty: Difficulty) {
        guard activeItems.count < maxActiveItems else { return }
        guard !difficulty.unlockedItemTypes.isEmpty else { return }

        platformsSinceLastCommon += 1
        platformsSinceLastRare += 1

        // Check common item
        let commonTypes = difficulty.unlockedItemTypes.filter { !$0.isRare }
        if platformsSinceLastCommon >= nextCommonAt, !commonTypes.isEmpty {
            let spawn = difficulty.isBreathingPhase ? true : CGFloat.random(in: 0...1) < 0.8
            if spawn, let type = commonTypes.randomElement() {
                let itemPos = CGPoint(x: position.x, y: position.y + 20)
                spawnItem(type: type, at: itemPos)
                platformsSinceLastCommon = 0
                nextCommonAt = Int.random(in: commonInterval.min...commonInterval.max)
                return
            }
        }

        // Check rare item
        let rareTypes = difficulty.unlockedItemTypes.filter { $0.isRare }
        if platformsSinceLastRare >= nextRareAt, !rareTypes.isEmpty {
            if let type = rareTypes.randomElement() {
                let offsetX = CGFloat.random(in: -60...60)
                let offsetY = CGFloat.random(in: 40...80)
                let itemPos = CGPoint(
                    x: CGFloat.clamp(position.x + offsetX, min: 30, max: gameWidth - 30),
                    y: position.y + offsetY
                )
                spawnItem(type: type, at: itemPos)
                platformsSinceLastRare = 0
                nextRareAt = Int.random(in: rareInterval.min...rareInterval.max)
            }
        }
    }

    // MARK: - Item Effects

    private func applyItem(_ type: ItemType) {
        switch type {
        case .bomb:
            break // Instant — handled by callback
        case .shield:
            activeEffects[type] = .infinity
        default:
            activeEffects[type] = type.duration
        }
    }

    // MARK: - Spawn / Recycle

    private func spawnItem(type: ItemType, at position: CGPoint) {
        guard let scene else { return }

        let item = ItemNode(type: type)
        item.position = position
        scene.addChild(item)
        activeItems.append(item)
    }

    private func recycleItem(at index: Int) {
        let item = activeItems.remove(at: index)
        item.deactivate()
    }

    // MARK: - Reset

    func reset() {
        for item in activeItems {
            item.deactivate()
        }
        activeItems.removeAll()
        activeEffects.removeAll()
        platformsSinceLastCommon = 0
        platformsSinceLastRare = 0
        nextCommonAt = Int.random(in: commonInterval.min...commonInterval.max)
        nextRareAt = Int.random(in: rareInterval.min...rareInterval.max)
    }
}
