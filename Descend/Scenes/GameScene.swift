import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    private var gameState: GameState = .waitingToStart
    private var score: Int = 0
    private var lastDisplayedScore: Int = -1

    private var playerNode: PlayerNode!
    private var platformSystem: PlatformSystem!
    private var inputHandler: InputHandler!
    private var visualEffects: VisualEffects!
    private var scoreSystem: ScoreSystem!
    private var itemSystem: ItemSystem!
    private var eventSystem: EventSystem!

    private var scoreLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var lastUnlockedPlatformCount = 2
    private var lastUnlockedItemCount = 0
    private var startOverlay: StartOverlay?
    private var gameOverOverlay: GameOverOverlay?

    private var backgroundNode: SKSpriteNode!
    private var topDangerZone: SKSpriteNode!
    private var topDangerLine: SKSpriteNode!
    private var bottomDangerZone: SKSpriteNode!
    private var bottomDangerLine: SKSpriteNode!

    private var difficulty: TimeBasedDifficulty!

    private var themeSubscriptionID: UUID?
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        let theme = ThemeManager.shared.currentTheme

        // Physics
        physicsWorld.gravity = CGVector(dx: 0, dy: -200)
        physicsWorld.contactDelegate = self

        // Background
        setupBackground(theme: theme)
        setupDangerZones(theme: theme)

        // Visual effects
        visualEffects = VisualEffects(scene: self)
        visualEffects.createStarField()

        // Difficulty
        difficulty = TimeBasedDifficulty()

        // Platform system
        platformSystem = PlatformSystem(scene: self)
        platformSystem.createInitialPlatforms(difficulty: difficulty.getDifficulty(platformCount: 0))

        // Player
        playerNode = PlayerNode()
        playerNode.position = CGPoint(x: size.width / 2, y: size.height / 2 - 100)
        addChild(playerNode)

        // Wire player to platform system
        platformSystem.playerNode = playerNode

        // Input
        inputHandler = InputHandler(player: playerNode, sceneWidth: size.width)
        inputHandler.isEnabled = false

        // Item system
        itemSystem = ItemSystem(scene: self)
        platformSystem.itemSystem = itemSystem

        // Item callbacks
        itemSystem.onItemPickup = { [weak self] type, position in
            guard let self else { return }
            let sfx: AudioManager.SFX = type.isRare ? .itemRare : .itemCommon
            AudioManager.shared.playSFX(sfx, on: self)
            self.visualEffects.showItemPickupFlash(at: position, type: type)
            if type == .bomb {
                self.platformSystem.replaceSpecialPlatformsWithNormal()
            }
        }
        itemSystem.onGhostExpired = { [weak self] in
            guard let self else { return }
            let diff = self.difficulty.getDifficulty(platformCount: self.platformSystem.totalPlatformsGenerated)
            self.platformSystem.spawnSafetyPlatform(at: self.playerNode.position, difficulty: diff)
        }

        // Event system
        eventSystem = EventSystem()
        platformSystem.eventSystem = eventSystem
        eventSystem.onEventWarning = { [weak self] event in
            guard let self else { return }
            AudioManager.shared.playSFX(.eventWarning, on: self)
            self.visualEffects.showEventWarning(event: event)
        }
        eventSystem.onEventStart = { [weak self] event in
            guard let self else { return }
            if event == .fog {
                self.visualEffects.addFogOverlay()
            }
        }
        eventSystem.onEventEnd = { [weak self] event in
            guard let self else { return }
            AudioManager.shared.playSFX(.eventEnd, on: self)
            self.scoreSystem.addScore(source: .surviveEvent,
                                      hasDoubleScore: self.itemSystem.isActive(.doubleScore))
            if event == .fog {
                self.visualEffects.removeFogOverlay()
            }
        }

        // Score system
        scoreSystem = ScoreSystem()
        scoreSystem.onScoreAdded = { [weak self] points, combo, multiplier in
            guard let self else { return }
            self.visualEffects.showScorePopup(at: self.playerNode.position, points: points, combo: combo, multiplier: multiplier)
        }

        // Score label
        setupScoreLabel(theme: theme)

        // Theme subscription
        themeSubscriptionID = ThemeManager.shared.subscribe { [weak self] newTheme in
            self?.onThemeChange(newTheme)
        }

        // Audio
        AudioManager.shared.start()

        // Show start screen
        showStartOverlay()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        guard gameState == .playing else { return }
        guard dt > 0, dt < 0.1 else { return }

        // Record pre-physics velocity for landing detection
        playerNode.recordVelocity()
        playerNode.checkAirborne()

        // Difficulty
        difficulty.update(delta: dt)
        let currentDifficulty = difficulty.getDifficulty(platformCount: platformSystem.totalPlatformsGenerated)

        // Apply item effects to rise speed
        var modifiedRiseSpeed = currentDifficulty.riseSpeed
        if itemSystem.isActive(.freeze) { modifiedRiseSpeed = 0 }
        if itemSystem.isActive(.slowDown) { modifiedRiseSpeed *= 0.6 }

        // Apply event effects
        var gravityY = currentDifficulty.gravity
        if let event = eventSystem.activeEvent {
            switch event {
            case .gravityReverse:
                gravityY = -gravityY
            case .speedStorm:
                modifiedRiseSpeed *= 1.5
            case .chaosGravity:
                let chaosX = CGFloat.random(in: -100...100)
                physicsWorld.gravity = CGVector(dx: chaosX, dy: gravityY)
            default:
                break
            }
        }

        let effectiveDifficulty = currentDifficulty.withRiseSpeed(modifiedRiseSpeed)

        // Apply dynamic gravity (unless chaosGravity already set it)
        if eventSystem.activeEvent != .chaosGravity {
            physicsWorld.gravity = CGVector(dx: 0, dy: gravityY)
        }

        // Platforms
        platformSystem.update(delta: dt, difficulty: effectiveDifficulty)

        // Items
        itemSystem.update(delta: dt, player: playerNode, difficulty: currentDifficulty)

        // Events
        eventSystem.update(delta: dt, difficulty: currentDifficulty)

        // Magnet effect
        if itemSystem.isActive(.magnet) {
            inputHandler.magnetTarget = platformSystem.nearestPlatformX(to: playerNode.position)
        } else {
            inputHandler.magnetTarget = nil
        }

        // Player physics
        applyPlayerPhysics(dt: dt)

        // Death check
        if playerNode.position.y > size.height - 35 || playerNode.position.y < 50 {
            if itemSystem.isActive(.shield) {
                itemSystem.removeEffect(.shield)
                scoreSystem.shieldUsed()
                HapticsManager.shared.vibrate(.heavy)
                if playerNode.position.y > size.height - 35 {
                    playerNode.position.y = size.height - 60
                    playerNode.physicsBody?.velocity.dy = -100
                } else {
                    playerNode.position.y = 80
                    playerNode.physicsBody?.velocity.dy = 100
                }
            } else if itemSystem.isActive(.ghost) {
                // Ghost — ignore death
            } else {
                triggerGameOver()
                return
            }
        }

        // Score
        scoreSystem.update(delta: dt)
        score = scoreSystem.score
        if score != lastDisplayedScore {
            scoreLabel.text = "\(score)"
            lastDisplayedScore = score
        }
        if scoreSystem.combo >= 2 {
            comboLabel.text = "×\(scoreSystem.combo)"
            comboLabel.setScale(scoreSystem.combo >= 8 ? 1.3 : 1.0)
        } else {
            comboLabel.text = ""
        }

        // Unlock banners
        let platformUnlockCount = currentDifficulty.unlockedPlatformTypes.count
        if platformUnlockCount > lastUnlockedPlatformCount {
            for type in currentDifficulty.unlockedPlatformTypes.subtracting([.normal, .rest]) {
                visualEffects.showUnlockBanner(text: "New: \(type) platform!")
            }
            lastUnlockedPlatformCount = platformUnlockCount
        }

        // Shield visual
        if itemSystem.isActive(.shield) {
            visualEffects.addShieldGlow(to: playerNode)
        }

        // Fog
        if eventSystem.activeEvent == .fog {
            visualEffects.updateFogOverlay(playerPosition: playerNode.position)
        }

        // Effect indicators
        visualEffects.updateEffectIndicators(activeEffects: itemSystem.activeEffects)

        // Visual updates
        visualEffects.createPlayerTrail(player: playerNode)
        visualEffects.createComboTrail(player: playerNode, combo: scoreSystem.combo)
        visualEffects.updateTrailEffect(delta: dt)
        visualEffects.updateStars(deltaSeconds: dt, riseSpeed: effectiveDifficulty.riseSpeed)
    }

    // MARK: - Player Physics

    private func applyPlayerPhysics(dt: TimeInterval) {
        guard let body = playerNode.physicsBody else { return }

        // X-axis drag when not dragging
        if !inputHandler.isDragging {
            let dragRate: CGFloat = 100
            let dragAmount = dragRate * CGFloat(dt)
            if body.velocity.dx > 0 {
                body.velocity.dx = max(0, body.velocity.dx - dragAmount)
            } else if body.velocity.dx < 0 {
                body.velocity.dx = min(0, body.velocity.dx + dragAmount)
            }
        }

        // Clamp position
        playerNode.position.x = CGFloat.clamp(playerNode.position.x, min: 20, max: size.width - 20)
    }

    override func didSimulatePhysics() {
        guard gameState == .playing else { return }
        guard let body = playerNode.physicsBody else { return }

        // Clamp velocity after physics simulation so gravity can't exceed limits
        let currentDifficulty = difficulty.getDifficulty(platformCount: platformSystem.totalPlatformsGenerated)
        body.velocity.dx = CGFloat.clamp(body.velocity.dx, min: -300, max: 300)
        body.velocity.dy = CGFloat.clamp(body.velocity.dy, min: currentDifficulty.maxFallSpeed, max: 200)
    }

    // MARK: - Collision

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }

        // Ghost mode — no platform collision
        guard !itemSystem.isActive(.ghost) else { return }

        let (playerBody, platformBody) = sortContactBodies(contact)
        guard let pNode = playerBody?.node as? PlayerNode,
              let platNode = platformBody?.node as? PlatformNode else { return }

        // Only trigger on landing from above
        guard pNode.position.y > platNode.position.y else { return }

        let impactVelocity = abs(pNode.lastVelocityY)
        guard impactVelocity > 10 else { return }
        guard !pNode.wasOnPlatform else { return }

        pNode.markOnPlatform()

        // Behavior callback
        platNode.behavior?.onPlayerLand(player: pNode, platform: platNode)

        // Ice platform effect on input
        inputHandler.onIcePlatform = platNode.isIcePlatform

        // Score based on platform type
        let source: ScoreSource
        switch platNode.platformType {
        case .fragile, .invisible:
            source = .dangerPlatform
        case .normal, .rest:
            source = .normalPlatform
        default:
            source = .specialPlatform
        }
        scoreSystem.registerLanding()
        scoreSystem.addScore(source: source)

        let contactPoint = CGPoint(
            x: pNode.position.x,
            y: pNode.position.y - pNode.size.height / 2
        )

        // Visual feedback
        visualEffects.createImpactRing(at: contactPoint, scheme: platNode.colorScheme)
        visualEffects.createBallGlow(player: pNode, scheme: platNode.colorScheme)
        visualEffects.createImpactParticles(at: contactPoint, scheme: platNode.colorScheme)
        visualEffects.squashAnimation(player: pNode, impactVelocity: impactVelocity)
        visualEffects.flashPlatform(platNode)

        // Camera shake
        let shakeIntensity = min(impactVelocity / 200, 1) * 0.008
        visualEffects.shakeCamera(scene: self, intensity: shakeIntensity * 100)

        // SFX
        let sfx: AudioManager.SFX = platNode.platformType == .normal || platNode.platformType == .rest ? .land : .landSpecial
        AudioManager.shared.playSFX(sfx, on: self)
        switch platNode.platformType {
        case .bouncy: AudioManager.shared.playSFX(.bounce, on: self)
        case .ice: AudioManager.shared.playSFX(.iceSlide, on: self)
        case .teleport: AudioManager.shared.playSFX(.teleport, on: self)
        default: break
        }

        // Haptic
        HapticsManager.shared.vibrate(impactVelocity > 300 ? .medium : .light)
    }

    private func sortContactBodies(_ contact: SKPhysicsContact) -> (player: SKPhysicsBody?, platform: SKPhysicsBody?) {
        if contact.bodyA.categoryBitMask == PhysicsMask.player {
            return (contact.bodyA, contact.bodyB)
        } else {
            return (contact.bodyB, contact.bodyA)
        }
    }

    // MARK: - Game Flow

    private func showStartOverlay() {
        gameState = .waitingToStart
        let theme = ThemeManager.shared.currentTheme
        let overlay = StartOverlay(sceneSize: size, theme: theme)
        startOverlay = overlay
        overlay.show(in: self)
    }

    private func startGame() {
        startOverlay?.dismiss { [weak self] in
            self?.startOverlay = nil
        }
        gameState = .playing
        inputHandler.isEnabled = true
        AudioManager.shared.playBGM()
        HapticsManager.shared.vibrate(.light)
    }

    private func triggerGameOver() {
        gameState = .gameOver
        inputHandler.isEnabled = false
        HapticsManager.shared.vibrate(.error)
        AudioManager.shared.playSFX(.death, on: self)
        AudioManager.shared.stopBGM()

        let theme = ThemeManager.shared.currentTheme
        let overlay = GameOverOverlay(sceneSize: size, score: score, theme: theme)
        overlay.onRestart = { [weak self] in
            self?.restartGame()
        }
        gameOverOverlay = overlay
        overlay.show(in: self)
    }

    private func restartGame() {
        HapticsManager.shared.vibrate(.light)

        // Remove overlays
        gameOverOverlay?.removeFromParent()
        gameOverOverlay = nil

        // Reset systems
        platformSystem.reset()
        inputHandler.reset()
        playerNode.resetFlags()
        visualEffects.resetTrail()
        difficulty.reset()
        scoreSystem.reset()
        itemSystem.reset()
        eventSystem.reset()
        visualEffects.resetUnlocks()
        visualEffects.clearEffectIndicators()
        visualEffects.removeFogOverlay()
        visualEffects.removeShieldGlow(from: playerNode)

        // Reset state
        score = 0
        lastDisplayedScore = -1
        scoreLabel.text = "0"
        comboLabel.text = ""
        lastUpdateTime = 0
        lastUnlockedPlatformCount = 2
        lastUnlockedItemCount = 0

        // Reposition player
        playerNode.position = CGPoint(x: size.width / 2, y: size.height / 2 - 100)
        playerNode.physicsBody?.velocity = .zero
        playerNode.alpha = 1.0

        // Reset gravity
        physicsWorld.gravity = CGVector(dx: 0, dy: -200)

        // Recreate platforms
        platformSystem.createInitialPlatforms(difficulty: difficulty.getDifficulty(platformCount: 0))

        // Show start screen
        showStartOverlay()
    }

    // MARK: - Background & Theme

    private func setupBackground(theme: Theme) {
        backgroundNode = VisualEffects.makeGradientSprite(
            top: theme.colors.background.top,
            bottom: theme.colors.background.bottom,
            size: size
        )
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundNode.zPosition = -10
        addChild(backgroundNode)
    }

    private func setupDangerZones(theme: Theme) {
        let danger = theme.colors.danger

        // Top danger zone (high Y in SpriteKit)
        topDangerZone = SKSpriteNode(color: danger.fill.withAlphaComponent(danger.fillAlpha), size: CGSize(width: size.width, height: 50))
        topDangerZone.position = CGPoint(x: size.width / 2, y: size.height - 25)
        topDangerZone.zPosition = -1
        addChild(topDangerZone)

        topDangerLine = SKSpriteNode(color: danger.line.withAlphaComponent(danger.lineAlpha), size: CGSize(width: size.width, height: 2))
        topDangerLine.position = CGPoint(x: size.width / 2, y: size.height - 50)
        topDangerLine.zPosition = -1
        addChild(topDangerLine)

        // Bottom danger zone (low Y in SpriteKit)
        bottomDangerZone = SKSpriteNode(color: danger.fill.withAlphaComponent(danger.fillAlpha), size: CGSize(width: size.width, height: 50))
        bottomDangerZone.position = CGPoint(x: size.width / 2, y: 25)
        bottomDangerZone.zPosition = -1
        addChild(bottomDangerZone)

        bottomDangerLine = SKSpriteNode(color: danger.line.withAlphaComponent(danger.lineAlpha), size: CGSize(width: size.width, height: 2))
        bottomDangerLine.position = CGPoint(x: size.width / 2, y: 50)
        bottomDangerLine.zPosition = -1
        addChild(bottomDangerLine)
    }

    private func setupScoreLabel(theme: Theme) {
        let isDark = theme.mode == .dark
        let ui = theme.colors.ui
        scoreLabel = UIFactory.makeLabel(
            text: "0",
            fontSize: 64,
            color: ui.textPrimary,
            strokeColor: isDark ? ui.textStroke : nil,
            strokeWidth: isDark ? ui.textStrokeWidth * 2 : 0
        )
        scoreLabel.fontName = "SFProDisplay-Black"
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 60)
        scoreLabel.zPosition = 100
        addChild(scoreLabel)

        comboLabel = SKLabelNode(text: "")
        comboLabel.fontName = "SFProDisplay-Bold"
        comboLabel.fontSize = 24
        comboLabel.fontColor = UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)
        comboLabel.horizontalAlignmentMode = .left
        comboLabel.verticalAlignmentMode = .top
        comboLabel.position = CGPoint(x: size.width / 2 + 40, y: size.height - 60)
        comboLabel.zPosition = 100
        addChild(comboLabel)
    }

    private func onThemeChange(_ theme: Theme) {
        // Background
        backgroundNode.removeFromParent()
        setupBackground(theme: theme)

        // Danger zones
        let danger = theme.colors.danger
        topDangerZone.color = danger.fill.withAlphaComponent(danger.fillAlpha)
        topDangerLine.color = danger.line.withAlphaComponent(danger.lineAlpha)
        bottomDangerZone.color = danger.fill.withAlphaComponent(danger.fillAlpha)
        bottomDangerLine.color = danger.line.withAlphaComponent(danger.lineAlpha)

        // Score label
        let isDark = theme.mode == .dark
        let ui = theme.colors.ui
        scoreLabel.fontColor = ui.textPrimary

        if isDark, let stroke = ui.textStroke {
            let attributed = NSAttributedString(
                string: scoreLabel.text ?? "0",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 64, weight: .black),
                    .foregroundColor: ui.textPrimary,
                    .strokeColor: stroke,
                    .strokeWidth: -(ui.textStrokeWidth * 2),
                ]
            )
            scoreLabel.attributedText = attributed
        } else {
            scoreLabel.attributedText = nil
            scoreLabel.fontColor = ui.textPrimary
        }

        // Platform textures
        platformSystem.regenerateTextures()

        // Stars
        visualEffects.removeStars()
        visualEffects.createStarField()

        // Rebuild start overlay if visible
        if let oldOverlay = startOverlay {
            oldOverlay.removeFromParent()
            let newOverlay = StartOverlay(sceneSize: size, theme: theme)
            startOverlay = newOverlay
            newOverlay.show(in: self)
        }
    }

    // MARK: - Cleanup

    deinit {
        if let id = themeSubscriptionID {
            ThemeManager.shared.unsubscribe(id)
        }
    }
}

// MARK: - Touch Handling

#if os(iOS) || os(tvOS)
extension GameScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        switch gameState {
        case .waitingToStart:
            startGame()
        case .playing:
            inputHandler.touchBegan(at: location)
        case .gameOver:
            break // Handled by GameOverOverlay
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing, let touch = touches.first else { return }
        inputHandler.touchMoved(to: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        inputHandler.touchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        inputHandler.touchEnded()
    }
}
#endif
