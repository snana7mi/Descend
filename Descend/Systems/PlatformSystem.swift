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

        // Move platforms upward, count and recycle
        for i in stride(from: activePlatforms.count - 1, through: 0, by: -1) {
            let platform = activePlatforms[i]
            platform.position.y += riseAmount

            if platform.position.y > gameHeight + 50 {
                if !platform.isCounted {
                    passedPlatforms += 1
                    platform.isCounted = true
                }
                recyclePlatform(at: i)
            }
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
    }

    // MARK: - Private

    private func generateNewPlatform(difficulty: Difficulty) {
        totalPlatformsGenerated += 1
        let spawn = spawnStrategy.getNextPlatform(difficulty: difficulty)
        let bufferTime: CGFloat = 2.5
        let newY = -(difficulty.riseSpeed * bufferTime)
        createPlatform(x: spawn.x, y: newY, difficulty: difficulty, widthOverride: spawn.width)
    }

    private func createPlatform(x: CGFloat, y: CGFloat, difficulty: Difficulty, widthOverride: CGFloat? = nil) {
        guard let scene else { return }

        let maxAllowedWidth = max(1, gameWidth - spawnHorizontalPadding * 2)
        let width = min(widthOverride ?? CGFloat.random(in: difficulty.platformWidthMin...difficulty.platformWidthMax), maxAllowedWidth)
        let safeX = validatePlatformX(x: x, width: width)

        let idx = Int.random(in: 0..<platformTextures.count)
        let textureInfo = platformTextures[idx]

        let platform: PlatformNode
        if let pooled = platformPool.popLast() {
            platform = pooled
        } else {
            platform = PlatformNode(texture: textureInfo.texture, colorScheme: textureInfo.scheme)
        }

        platform.activate(
            at: CGPoint(x: safeX, y: y),
            width: width,
            height: platformHeight,
            texture: textureInfo.texture,
            scheme: textureInfo.scheme
        )
        scene.addChild(platform)
        activePlatforms.append(platform)
    }

    private func recyclePlatform(at index: Int) {
        let platform = activePlatforms.remove(at: index)
        platform.deactivate()

        if platformPool.count < poolMaxSize {
            platformPool.append(platform)
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
