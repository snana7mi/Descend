import SpriteKit

final class PlatformSystem {
    private weak var scene: SKScene?
    private let gameWidth: CGFloat
    private let gameHeight: CGFloat
    private let platformHeight: CGFloat = 20
    private let spawnHorizontalPadding: CGFloat = 80
    private let poolMaxSize = 20

    private var platformPool: [PlatformNode] = []
    private var activePlatforms: [PlatformNode] = []
    private var platformTextures: [(texture: SKTexture, scheme: PlatformColorScheme)] = []
    private var spawnTimer: TimeInterval = 0
    private var passedPlatforms: Int = 0
    private(set) var totalPlatformsGenerated: Int = 0

    private let spawnStrategy: PlatformSpawnStrategy

    // External references for behavior/item integration
    weak var playerNode: PlayerNode?
    weak var itemSystem: ItemSystem?
    weak var eventSystem: EventSystem?

    // Behavior state
    private var lastPlatformType: PlatformType = .normal
    private var teleportPending: TeleportBehavior? = nil
    private var teleportCountdown: Int = 0
    private var platformShrinkApplied = false
    private var preShrinkWidths: [ObjectIdentifier: CGFloat] = [:]

    init(scene: SKScene) {
        self.scene = scene
        self.gameWidth = scene.size.width
        self.gameHeight = scene.size.height
        self.spawnStrategy = PlatformSpawnStrategy(gameWidth: gameWidth, spawnPadding: spawnHorizontalPadding)
        regenerateTextures()
    }

    // MARK: - Tile Textures (Kenney Abstract Platformer)

    // Tile asset names mapped to platform types
    private static let tileNames: [PlatformType: String] = [
        .normal: "tile_blue",
        .rest: "tile_green",
        .moving: "tile_yellow",
        .fragile: "tile_brown",
        .ice: "tile_blue",
        .bouncy: "tile_green",
        .teleport: "tile_yellow",
        .shrinking: "tile_brown",
        .invisible: "tile_blue"
    ]

    func regenerateTextures() {
        platformTextures.removeAll()
        let theme = ThemeManager.shared.currentTheme
        let schemes = theme.colors.platformSchemes

        // Load Kenney tile textures and pair with color schemes
        let tileOrder: [String] = ["tile_blue", "tile_green", "tile_brown", "tile_yellow", "tile_blue"]
        for (i, tileName) in tileOrder.prefix(schemes.count).enumerated() {
            let texture = SKTexture(imageNamed: tileName)
            platformTextures.append((texture, schemes[i]))
        }

        // Update active platforms
        for platform in activePlatforms {
            let idx = Int.random(in: 0..<platformTextures.count)
            let info = platformTextures[idx]
            platform.texture = info.texture
            platform.colorScheme = info.scheme
        }
    }

    private func textureForType(_ type: PlatformType) -> SKTexture {
        let name = PlatformSystem.tileNames[type] ?? "tile_blue"
        return SKTexture(imageNamed: name)
    }

    // MARK: - Platform Creation

    func createInitialPlatforms(difficulty: Difficulty) {
        let initialDiff = difficulty
        // Player starts at sceneHeight/2 - 100 (SpriteKit coords, slightly below center)
        let playerStartY = gameHeight / 2 - 100
        let startPlatformY = playerStartY - 50

        let startWidth = min(
            120 * 1.2,
            gameWidth - spawnHorizontalPadding * 2
        )
        createPlatform(x: gameWidth / 2, y: startPlatformY, difficulty: initialDiff, widthOverride: startWidth)

        let gap: CGFloat = 160

        // Below starting platform (decreasing Y in SpriteKit)
        var y = startPlatformY - gap
        while y > -gap {
            let spawn = spawnStrategy.getNextPlatform(difficulty: initialDiff)
            createPlatform(x: spawn.x, y: y, difficulty: initialDiff, widthOverride: spawn.width)
            y -= gap
        }

        // Above starting platform (increasing Y in SpriteKit)
        y = startPlatformY + gap
        while y < gameHeight + gap {
            let spawn = spawnStrategy.getNextPlatform(difficulty: initialDiff)
            createPlatform(x: spawn.x, y: y, difficulty: initialDiff, widthOverride: spawn.width)
            y += gap
        }
    }

    // MARK: - Update

    func update(delta: TimeInterval, difficulty: Difficulty) {
        let riseAmount = difficulty.riseSpeed * CGFloat(delta)

        // Move platforms upward, update behaviors, count and recycle
        for i in stride(from: activePlatforms.count - 1, through: 0, by: -1) {
            let platform = activePlatforms[i]
            platform.position.y += riseAmount

            // Update behavior
            platform.behavior?.update(delta: delta, platform: platform)

            // Earthquake shake
            if eventSystem?.activeEvent == .earthquake {
                platform.position.x += CGFloat.random(in: -15...15) * CGFloat(delta) * 10
                platform.position.x = CGFloat.clamp(platform.position.x, min: 0, max: gameWidth)
            }

            if platform.position.y > gameHeight + 50 {
                if !platform.isCounted {
                    passedPlatforms += 1
                    platform.isCounted = true
                }
                recyclePlatform(at: i)
            }
        }

        // Platform shrink event
        if eventSystem?.activeEvent == .platformShrink {
            if !platformShrinkApplied {
                platformShrinkApplied = true
                preShrinkWidths.removeAll()
                for platform in activePlatforms {
                    let id = ObjectIdentifier(platform)
                    preShrinkWidths[id] = platform.size.width
                    let newWidth = platform.size.width * 0.75
                    platform.run(SKAction.resize(toWidth: newWidth, duration: 0.3))
                    platform.configurePhysics(width: newWidth, height: platformHeight)
                }
            }
        } else if platformShrinkApplied {
            platformShrinkApplied = false
            // Restore original widths
            for platform in activePlatforms {
                let id = ObjectIdentifier(platform)
                if let originalWidth = preShrinkWidths[id] {
                    platform.run(SKAction.resize(toWidth: originalWidth, duration: 0.3))
                    platform.configurePhysics(width: originalWidth, height: platformHeight)
                }
            }
            preShrinkWidths.removeAll()
        }

        // Spawn new platforms based on timer
        spawnTimer += delta
        while spawnTimer >= difficulty.spawnInterval {
            generateNewPlatform(difficulty: difficulty)
            spawnTimer -= difficulty.spawnInterval
        }
    }

    // MARK: - Reset

    func reset() {
        for platform in activePlatforms {
            platform.deactivate()
        }
        activePlatforms.removeAll()
        platformPool.removeAll()
        spawnTimer = 0
        passedPlatforms = 0
        totalPlatformsGenerated = 0
        spawnStrategy.reset()
        lastPlatformType = .normal
        teleportPending = nil
        teleportCountdown = 0
        platformShrinkApplied = false
    }

    // MARK: - Private

    private func generateNewPlatform(difficulty: Difficulty) {
        totalPlatformsGenerated += 1
        let spawn = spawnStrategy.getNextPlatform(difficulty: difficulty)
        let bufferTime: CGFloat = 2.5
        let newY = -(difficulty.riseSpeed * bufferTime)
        let type = choosePlatformType(difficulty: difficulty)
        createPlatform(x: spawn.x, y: newY, difficulty: difficulty, widthOverride: spawn.width, type: type)
    }

    private func createPlatform(x: CGFloat, y: CGFloat, difficulty: Difficulty,
                                widthOverride: CGFloat? = nil, type: PlatformType = .normal) {
        guard let scene else { return }

        let maxAllowedWidth = max(1, gameWidth - spawnHorizontalPadding * 2)
        var width = min(widthOverride ?? CGFloat.random(in: difficulty.platformWidthMin...difficulty.platformWidthMax), maxAllowedWidth)

        // WideScreen item effect
        if itemSystem?.isActive(.wideScreen) == true {
            width = min(width * 1.5, maxAllowedWidth)
        }

        let safeX = validatePlatformX(x: x, width: width)

        // Pick texture based on platform type, fall back to random for normal
        let texture: SKTexture
        let scheme: PlatformColorScheme
        if type == .normal || type == .rest {
            let idx = Int.random(in: 0..<platformTextures.count)
            texture = platformTextures[idx].texture
            scheme = platformTextures[idx].scheme
        } else {
            texture = textureForType(type)
            let idx = Int.random(in: 0..<platformTextures.count)
            scheme = platformTextures[idx].scheme
        }

        let platform: PlatformNode
        if let pooled = platformPool.popLast() {
            platform = pooled
        } else {
            platform = PlatformNode(texture: texture, colorScheme: scheme)
        }

        let behavior = makeBehavior(for: type)

        platform.activate(
            at: CGPoint(x: safeX, y: y),
            width: width,
            height: platformHeight,
            texture: texture,
            scheme: scheme,
            type: type,
            behavior: behavior
        )

        // Apply visual decoration for special platforms
        applyPlatformDecoration(platform, type: type)

        // Link teleport pairs — only link when this is the SECOND pad (not the pending one itself)
        if type == .teleport, let teleportBehavior = behavior as? TeleportBehavior {
            if let pending = teleportPending, pending !== teleportBehavior {
                pending.pairedPlatform = platform
                teleportBehavior.pairedPlatform = findPlatformWithBehavior(pending)
                teleportPending = nil
            }
        }

        scene.addChild(platform)
        activePlatforms.append(platform)
        lastPlatformType = type

        // Notify item system
        itemSystem?.onPlatformSpawned(position: platform.position, width: width, difficulty: difficulty)
    }

    private func recyclePlatform(at index: Int) {
        let platform = activePlatforms.remove(at: index)
        platform.deactivate()

        if platformPool.count < poolMaxSize {
            platformPool.append(platform)
        }
    }

    // MARK: - Behavior Assignment

    private func choosePlatformType(difficulty: Difficulty) -> PlatformType {
        guard !difficulty.isRestPlatform else { return .normal }

        // Check if we owe a teleport pair
        if teleportCountdown > 0 {
            teleportCountdown -= 1
            if teleportCountdown == 0 {
                return .teleport
            }
        }

        guard CGFloat.random(in: 0...1) < difficulty.specialPlatformChance else {
            return .normal
        }

        var candidates = difficulty.unlockedPlatformTypes.subtracting([.normal, .rest])
        candidates.remove(lastPlatformType)

        if teleportPending != nil {
            candidates.remove(.teleport)
        }

        guard let chosen = candidates.randomElement() else { return .normal }
        return chosen
    }

    private func makeBehavior(for type: PlatformType) -> PlatformBehavior? {
        switch type {
        case .normal, .rest:
            return nil
        case .moving:
            return MovingBehavior(gameWidth: gameWidth, padding: spawnHorizontalPadding)
        case .fragile:
            return FragileBehavior()
        case .ice:
            return IceBehavior()
        case .bouncy:
            return BouncyBehavior()
        case .teleport:
            let behavior = TeleportBehavior()
            if teleportPending == nil {
                teleportPending = behavior
                teleportCountdown = Int.random(in: 2...4)
            }
            return behavior
        case .shrinking:
            return ShrinkingBehavior()
        case .invisible:
            let behavior = InvisibleBehavior()
            if let player = playerNode {
                behavior.setPlayer(player)
            }
            return behavior
        }
    }

    private func findPlatformWithBehavior(_ behavior: PlatformBehavior) -> PlatformNode? {
        return activePlatforms.first { $0.behavior === behavior }
    }

    // MARK: - Public Helpers

    func nearestPlatformX(to position: CGPoint) -> CGFloat? {
        var closest: CGFloat? = nil
        var minDist: CGFloat = .greatestFiniteMagnitude
        for platform in activePlatforms {
            let dy = abs(platform.position.y - position.y)
            if dy < minDist && platform.physicsBody != nil {
                minDist = dy
                closest = platform.position.x
            }
        }
        return closest
    }

    func spawnSafetyPlatform(at position: CGPoint, difficulty: Difficulty) {
        let safeY = position.y - 30
        createPlatform(x: position.x, y: safeY, difficulty: difficulty, widthOverride: 100, type: .normal)
    }

    func replaceSpecialPlatformsWithNormal() {
        for platform in activePlatforms where platform.platformType != .normal && platform.platformType != .rest {
            platform.behavior?.onRecycle()
            platform.behavior = nil
            platform.platformType = .normal
            platform.alpha = 1.0
            platform.removeAllActions()
            platform.configurePhysics(width: platform.size.width, height: platformHeight)
            let flash = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            platform.run(SKAction.repeat(flash, count: 2))
        }
    }

    // MARK: - Platform Decoration

    private func applyPlatformDecoration(_ platform: PlatformNode, type: PlatformType) {
        // Remove old decorations
        platform.childNode(withName: "decoration")?.removeFromParent()

        guard type != .normal && type != .rest else { return }

        let w = platform.size.width
        let h = platform.size.height
        let isDark = ThemeManager.shared.currentTheme.mode == .dark

        switch type {
        case .moving:
            // Left/right arrows at edges
            let arrows = SKLabelNode(text: "◀ ▶")
            arrows.name = "decoration"
            arrows.fontSize = 8
            arrows.fontColor = isDark ? .white : UIColor(white: 0.3, alpha: 0.8)
            arrows.verticalAlignmentMode = .center
            arrows.position = CGPoint(x: 0, y: 0)
            platform.addChild(arrows)

        case .fragile:
            // Crack lines
            let crack = SKShapeNode()
            crack.name = "decoration"
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -w * 0.2, y: h * 0.15))
            path.addLine(to: CGPoint(x: 0, y: -h * 0.1))
            path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.1))
            crack.path = path
            crack.strokeColor = isDark ? UIColor(white: 1, alpha: 0.5) : UIColor(white: 0, alpha: 0.3)
            crack.lineWidth = 1.5
            platform.addChild(crack)

        case .ice:
            // Light blue tint overlay
            let tint = SKSpriteNode(color: UIColor(red: 0.7, green: 0.9, blue: 1, alpha: 0.3),
                                     size: CGSize(width: w, height: h))
            tint.name = "decoration"
            platform.addChild(tint)
            // Sparkle dots
            for _ in 0..<3 {
                let dot = SKShapeNode(circleOfRadius: 1.5)
                dot.fillColor = .white
                dot.strokeColor = .clear
                dot.alpha = 0.7
                dot.position = CGPoint(x: CGFloat.random(in: -w/3...w/3), y: 0)
                dot.name = "decoration"
                platform.addChild(dot)
            }

        case .bouncy:
            // Spring zigzag
            let spring = SKLabelNode(text: "⌇")
            spring.name = "decoration"
            spring.fontSize = 12
            spring.fontColor = UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.9)
            spring.verticalAlignmentMode = .center
            spring.position = CGPoint(x: 0, y: 0)
            platform.addChild(spring)

        case .teleport:
            // Purple glow + swirl
            let glow = SKShapeNode(circleOfRadius: 6)
            glow.name = "decoration"
            glow.fillColor = UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.4)
            glow.strokeColor = UIColor(red: 0.7, green: 0.3, blue: 1, alpha: 0.8)
            glow.lineWidth = 1.5
            glow.glowWidth = 3
            platform.addChild(glow)
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 2)
            glow.run(SKAction.repeatForever(rotate))

        case .shrinking:
            // Inward arrows
            let label = SKLabelNode(text: "▸◂")
            label.name = "decoration"
            label.fontSize = 8
            label.fontColor = UIColor(red: 1, green: 0.6, blue: 0, alpha: 0.8)
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 0)
            platform.addChild(label)

        case .invisible:
            // Dashed outline (platform itself starts at low alpha via behavior)
            let dash = SKShapeNode(rectOf: CGSize(width: w * 0.8, height: h * 0.6))
            dash.name = "decoration"
            dash.fillColor = .clear
            dash.strokeColor = isDark ? UIColor(white: 1, alpha: 0.3) : UIColor(white: 0, alpha: 0.2)
            dash.lineWidth = 1
            // SpriteKit doesn't support dashed lines natively on SKShapeNode,
            // so use a subtle dotted effect by lowering alpha
            dash.alpha = 0.5
            platform.addChild(dash)

        case .normal, .rest:
            break
        }
    }

    private func validatePlatformX(x: CGFloat, width: CGFloat) -> CGFloat {
        let halfWidth = width / 2
        let minX = spawnHorizontalPadding + halfWidth
        let maxX = gameWidth - spawnHorizontalPadding - halfWidth
        guard minX <= maxX else { return gameWidth / 2 }
        return CGFloat.clamp(x, min: minX, max: maxX)
    }
}
