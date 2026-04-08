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

    // MARK: - Texture Generation

    func regenerateTextures() {
        platformTextures.removeAll()
        let theme = ThemeManager.shared.currentTheme
        let schemes = theme.colors.platformSchemes
        let isDark = theme.mode == .dark
        let baseWidth = ceil(TimeBasedDifficulty.basePlatformWidthMax)
        let h = platformHeight

        for scheme in schemes.prefix(5) {
            let texture = generatePlatformTexture(
                width: baseWidth, height: h,
                scheme: scheme, isDark: isDark
            )
            platformTextures.append((texture, scheme))
        }

        // Update active platforms with new textures
        for platform in activePlatforms {
            let idx = Int.random(in: 0..<platformTextures.count)
            let info = platformTextures[idx]
            platform.texture = info.texture
            platform.colorScheme = info.scheme
        }
    }

    private func generatePlatformTexture(width: CGFloat, height: CGFloat, scheme: PlatformColorScheme, isDark: Bool) -> SKTexture {
        let padding: CGFloat = 8
        let totalWidth = width + padding
        let totalHeight = height + padding
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight))

        let image = renderer.image { ctx in
            let rect = CGRect(x: padding / 2, y: padding / 2, width: width, height: height)
            let radius = height / 2
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)

            if isDark {
                // Outer glow
                scheme.primary.withAlphaComponent(0.15).setFill()
                UIBezierPath(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: radius + 2).fill()

                // Middle glow
                scheme.primary.withAlphaComponent(0.3).setFill()
                UIBezierPath(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerRadius: radius + 1).fill()

                // Core fill
                UIColor.black.withAlphaComponent(0.4).setFill()
                path.fill()

                // Neon border
                scheme.primary.setStroke()
                path.lineWidth = 3
                path.stroke()

                // Inner highlight
                let innerPath = UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: radius - 1)
                UIColor.white.withAlphaComponent(0.6).setStroke()
                innerPath.lineWidth = 1
                innerPath.stroke()
            } else {
                // Soft shadow
                scheme.secondary.withAlphaComponent(0.2).setFill()
                UIBezierPath(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: radius + 2).fill()

                // Main fill
                scheme.primary.withAlphaComponent(0.9).setFill()
                path.fill()

                // Top highlight
                let highlightRect = CGRect(x: rect.minX + 2, y: rect.minY + 2, width: rect.width - 4, height: rect.height / 2 - 2)
                UIColor.white.withAlphaComponent(0.4).setFill()
                UIBezierPath(roundedRect: highlightRect, cornerRadius: radius - 1).fill()

                // Soft border
                scheme.secondary.withAlphaComponent(0.8).setStroke()
                path.lineWidth = 2
                path.stroke()
            }
        }

        return SKTexture(image: image)
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

        let idx = Int.random(in: 0..<platformTextures.count)
        let textureInfo = platformTextures[idx]

        let platform: PlatformNode
        if let pooled = platformPool.popLast() {
            platform = pooled
        } else {
            platform = PlatformNode(texture: textureInfo.texture, colorScheme: textureInfo.scheme)
        }

        let behavior = makeBehavior(for: type)

        platform.activate(
            at: CGPoint(x: safeX, y: y),
            width: width,
            height: platformHeight,
            texture: textureInfo.texture,
            scheme: textureInfo.scheme,
            type: type,
            behavior: behavior
        )

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

    private func validatePlatformX(x: CGFloat, width: CGFloat) -> CGFloat {
        let halfWidth = width / 2
        let minX = spawnHorizontalPadding + halfWidth
        let maxX = gameWidth - spawnHorizontalPadding - halfWidth
        guard minX <= maxX else { return gameWidth / 2 }
        return CGFloat.clamp(x, min: minX, max: maxX)
    }
}
