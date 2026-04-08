import SpriteKit

final class VisualEffects {
    private weak var scene: SKScene?
    private var gameWidth: CGFloat { scene?.size.width ?? 375 }
    private var gameHeight: CGFloat { scene?.size.height ?? 667 }

    // Trail
    private struct TrailParticle {
        let node: SKShapeNode
        var life: CGFloat
    }
    private var trailParticles: [TrailParticle] = []
    private var lastTrailX: CGFloat = 0
    private var lastTrailY: CGFloat = 0
    private let trailInterval: CGFloat = 8

    // Stars
    private struct Star {
        let node: SKShapeNode
        let baseAlpha: CGFloat
        let pulseSpeed: CGFloat
        let pulsePhase: CGFloat
    }
    private var stars: [Star] = []

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Star Field

    func createStarField() {
        guard let scene else { return }
        removeStars()

        let colors = ThemeManager.shared.currentTheme.colors.effects.starColors

        for i in 0..<20 {
            let size = CGFloat.random(in: 2...5)
            let color = colors[i % colors.count]
            let alpha = CGFloat.random(in: 0.2...0.6)

            let star = SKShapeNode(rectOf: CGSize(width: size, height: size))
            star.fillColor = color
            star.strokeColor = .clear
            star.alpha = alpha
            star.position = CGPoint(
                x: CGFloat.random(in: 0...gameWidth),
                y: CGFloat.random(in: 0...gameHeight)
            )
            star.zPosition = -5
            scene.addChild(star)

            stars.append(Star(
                node: star,
                baseAlpha: alpha,
                pulseSpeed: CGFloat.random(in: 1...3),
                pulsePhase: CGFloat.random(in: 0...(CGFloat.pi * 2))
            ))
        }
    }

    func updateStars(deltaSeconds: TimeInterval, riseSpeed: CGFloat) {
        let time = CGFloat(CACurrentMediaTime())
        let dt = CGFloat(deltaSeconds)

        for star in stars {
            star.node.position.y += riseSpeed * 0.3 * dt

            let pulse = sin(time * star.pulseSpeed + star.pulsePhase)
            star.node.alpha = star.baseAlpha * (0.5 + pulse * 0.5)

            if star.node.position.y > gameHeight + 20 {
                star.node.position.y = -20
                star.node.position.x = CGFloat.random(in: 0...gameWidth)
            }
        }
    }

    func removeStars() {
        for star in stars {
            star.node.removeFromParent()
        }
        stars.removeAll()
    }

    // MARK: - Player Trail

    func createPlayerTrail(player: PlayerNode) {
        guard let scene else { return }

        let dx = abs(player.position.x - lastTrailX)
        let dy = abs(player.position.y - lastTrailY)
        let distance = sqrt(dx * dx + dy * dy)
        guard distance >= trailInterval else { return }

        lastTrailX = player.position.x
        lastTrailY = player.position.y

        let trailColor = ThemeManager.shared.currentTheme.colors.effects.trailColor
        let size = player.size.width * 0.6

        let trail = SKShapeNode(rectOf: CGSize(width: size, height: size))
        trail.fillColor = trailColor.withAlphaComponent(0.4)
        trail.strokeColor = trailColor.withAlphaComponent(0.6)
        trail.lineWidth = 2
        trail.position = player.position
        trail.zPosition = player.zPosition - 1
        scene.addChild(trail)

        trailParticles.append(TrailParticle(node: trail, life: 1))
    }

    func updateTrailEffect(delta: TimeInterval) {
        let fadeSpeed = CGFloat(delta) / 0.2 // 200ms full fade

        for i in stride(from: trailParticles.count - 1, through: 0, by: -1) {
            trailParticles[i].life -= fadeSpeed

            if trailParticles[i].life <= 0 {
                trailParticles[i].node.removeFromParent()
                trailParticles.remove(at: i)
            } else {
                let life = trailParticles[i].life
                trailParticles[i].node.alpha = life * 0.4
                trailParticles[i].node.setScale(life * 0.8 + 0.2)
            }
        }
    }

    func resetTrail() {
        for p in trailParticles {
            p.node.removeFromParent()
        }
        trailParticles.removeAll()
        lastTrailX = 0
        lastTrailY = 0
    }

    // MARK: - Impact Effects

    func createImpactParticles(at position: CGPoint, scheme: PlatformColorScheme) {
        guard let scene else { return }

        // Square particles
        for i in 0..<8 {
            let angle = -CGFloat.pi / 6 - (CGFloat.pi * 2 / 3) * (CGFloat(i) / 8)
            let speed = CGFloat.random(in: 100...250)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed
            let color = i % 2 == 0 ? scheme.primary : scheme.secondary
            let particleSize = CGFloat.random(in: 4...8)

            let particle = SKShapeNode(rectOf: CGSize(width: particleSize, height: particleSize))
            particle.fillColor = color.withAlphaComponent(0.8)
            particle.strokeColor = UIColor.white.withAlphaComponent(0.5)
            particle.lineWidth = 1
            particle.position = position
            particle.zPosition = 100
            scene.addChild(particle)

            let move = SKAction.moveBy(x: vx * 0.35, y: vy * 0.35, duration: 0.4)
            move.timingMode = .easeOut
            let fade = SKAction.fadeAlpha(to: 0, duration: 0.4)
            let scale = SKAction.scale(to: 0.1, duration: 0.4)
            let rotate = SKAction.rotate(byAngle: .pi, duration: 0.4)
            let group = SKAction.group([move, fade, scale, rotate])
            particle.run(group) { particle.removeFromParent() }
        }

        // Spark lines
        for _ in 0..<6 {
            let angle = -CGFloat.pi / 4 - (CGFloat.pi / 2) * CGFloat.random(in: 0...1)
            let speed = CGFloat.random(in: 60...150)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed

            let spark = SKShapeNode(rectOf: CGSize(width: 2, height: 6))
            spark.fillColor = UIColor.white.withAlphaComponent(0.9)
            spark.strokeColor = .clear
            spark.position = CGPoint(x: position.x + CGFloat.random(in: -8...8), y: position.y)
            spark.zPosition = 101
            scene.addChild(spark)

            let move = SKAction.moveBy(x: vx * 0.25, y: vy * 0.25, duration: 0.25)
            move.timingMode = .easeOut
            let fade = SKAction.fadeAlpha(to: 0, duration: 0.25)
            let scaleY = SKAction.scaleY(to: 0.2, duration: 0.25)
            let group = SKAction.group([move, fade, scaleY])
            spark.run(group) { spark.removeFromParent() }
        }
    }

    func createImpactRing(at position: CGPoint, scheme: PlatformColorScheme) {
        guard let scene else { return }

        for i in 0..<2 {
            let ring = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
            ring.fillColor = .clear
            ring.strokeColor = scheme.primary.withAlphaComponent(0.9)
            ring.lineWidth = CGFloat(3 - i)
            ring.position = position
            ring.zPosition = 99
            scene.addChild(ring)

            let targetScale = CGFloat(4 + i)
            let duration = 0.25 + Double(i) * 0.08
            let delay = Double(i) * 0.04

            let wait = SKAction.wait(forDuration: delay)
            let scaleAction = SKAction.scale(to: targetScale, duration: duration)
            scaleAction.timingMode = .easeOut
            let fade = SKAction.fadeAlpha(to: 0, duration: duration)
            let group = SKAction.group([scaleAction, fade])
            ring.run(SKAction.sequence([wait, group])) { ring.removeFromParent() }
        }
    }

    func createBallGlow(player: PlayerNode, scheme: PlatformColorScheme) {
        guard let scene else { return }

        let size = player.size.width * 0.85
        let glow = SKShapeNode(rectOf: CGSize(width: size, height: size))
        glow.fillColor = scheme.primary.withAlphaComponent(0.5)
        glow.strokeColor = .clear
        glow.position = player.position
        glow.zPosition = player.zPosition - 1
        glow.blendMode = .add
        scene.addChild(glow)

        let scale = SKAction.scale(to: 2, duration: 0.2)
        scale.timingMode = .easeOut
        let fade = SKAction.fadeAlpha(to: 0, duration: 0.2)
        let group = SKAction.group([scale, fade])
        glow.run(group) { glow.removeFromParent() }
    }

    func squashAnimation(player: PlayerNode, impactVelocity: CGFloat) {
        player.removeAllActions()

        let baseScaleX: CGFloat = 1.0
        let baseScaleY: CGFloat = 1.0
        let velocityFactor = min(impactVelocity / 200, 1)

        let squashX = baseScaleX * (1 + 0.15 * velocityFactor)
        let squashY = baseScaleY * (1 - 0.12 * velocityFactor)

        let squash = SKAction.scaleX(to: squashX, y: squashY, duration: 0.05)
        squash.timingMode = .easeOut

        let stretch = SKAction.scaleX(to: baseScaleX * 0.92, y: baseScaleY * 1.08, duration: 0.07)
        stretch.timingMode = .easeOut

        let recover = SKAction.scaleX(to: baseScaleX, y: baseScaleY, duration: 0.12)
        recover.timingMode = .easeOut

        player.run(SKAction.sequence([squash, stretch, recover]))
    }

    func flashPlatform(_ platform: PlatformNode) {
        let fadeDown = SKAction.fadeAlpha(to: 0.6, duration: 0.05)
        let fadeUp = SKAction.fadeAlpha(to: 1.0, duration: 0.05)
        platform.run(SKAction.sequence([fadeDown, fadeUp]))
    }

    func shakeCamera(scene: SKScene, intensity: CGFloat) {
        let shakeX = intensity * CGFloat.random(in: -1...1)
        let shakeY = intensity * CGFloat.random(in: -1...1)
        let moveA = SKAction.moveBy(x: shakeX, y: shakeY, duration: 0.02)
        let moveB = SKAction.moveBy(x: -shakeX, y: -shakeY, duration: 0.02)
        let shakeSequence = SKAction.sequence([moveA, moveB, moveA, moveB])

        if let camera = scene.camera {
            camera.run(shakeSequence)
        } else {
            scene.run(shakeSequence)
        }
    }

    // MARK: - Score Popup

    func showScorePopup(at position: CGPoint, points: Int, combo: Int, multiplier: CGFloat) {
        guard let scene else { return }

        let theme = ThemeManager.shared.currentTheme
        let text = "+\(points)"
        let fontSize: CGFloat = combo >= 8 ? 18 : (combo >= 4 ? 16 : 14)

        let label = SKLabelNode(text: text)
        label.fontName = "SFProDisplay-Bold"
        label.fontSize = fontSize
        label.fontColor = multiplier >= 2.0
            ? UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)
            : theme.colors.ui.textPrimary
        label.position = CGPoint(x: position.x, y: position.y + 15)
        label.zPosition = 200
        scene.addChild(label)

        let rise = SKAction.moveBy(x: 0, y: 30, duration: 0.5)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeAlpha(to: 0, duration: 0.5)
        label.run(SKAction.group([rise, fade])) { label.removeFromParent() }
    }

    // MARK: - Combo Flame Trail

    func createComboTrail(player: PlayerNode, combo: Int) {
        guard combo >= 4, let scene else { return }

        let intensity = min(CGFloat(combo - 4) / 8.0, 1.0)
        let size = player.size.width * (0.4 + intensity * 0.4)

        let flame = SKShapeNode(rectOf: CGSize(width: size, height: size))
        flame.fillColor = UIColor(red: 1, green: 0.4 + intensity * 0.4, blue: 0, alpha: 0.6)
        flame.strokeColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 0.4)
        flame.lineWidth = 1
        flame.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height / 2)
        flame.zPosition = player.zPosition - 1
        flame.blendMode = .add
        scene.addChild(flame)

        let rise = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: 15, duration: 0.2)
        let fade = SKAction.fadeAlpha(to: 0, duration: 0.2)
        let scale = SKAction.scale(to: 0.3, duration: 0.2)
        flame.run(SKAction.group([rise, fade, scale])) { flame.removeFromParent() }
    }

    // MARK: - Unlock Banner

    private var shownUnlocks: Set<String> = []

    func showUnlockBanner(text: String) {
        guard let scene else { return }
        guard !shownUnlocks.contains(text) else { return }
        shownUnlocks.insert(text)

        let theme = ThemeManager.shared.currentTheme

        let label = SKLabelNode(text: text)
        label.fontName = "SFProDisplay-Bold"
        label.fontSize = 16
        label.fontColor = theme.colors.ui.textAccent
        label.position = CGPoint(x: gameWidth / 2, y: 80)
        label.zPosition = 200
        label.alpha = 0
        scene.addChild(label)

        let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.3)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.3)
        label.run(SKAction.sequence([fadeIn, wait, fadeOut])) { label.removeFromParent() }
    }

    func resetUnlocks() {
        shownUnlocks.removeAll()
    }

    // MARK: - Shield Glow

    func addShieldGlow(to player: PlayerNode) {
        guard player.childNode(withName: "shield_glow") == nil else { return }

        let glow = SKShapeNode(circleOfRadius: player.size.width * 0.7)
        glow.name = "shield_glow"
        glow.fillColor = .clear
        glow.strokeColor = UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.6)
        glow.lineWidth = 2
        glow.zPosition = -1
        glow.glowWidth = 3
        player.addChild(glow)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8),
            SKAction.fadeAlpha(to: 0.8, duration: 0.8)
        ])
        glow.run(SKAction.repeatForever(pulse))
    }

    func removeShieldGlow(from player: PlayerNode) {
        if let glow = player.childNode(withName: "shield_glow") {
            let burst = SKAction.group([
                SKAction.scale(to: 3, duration: 0.3),
                SKAction.fadeAlpha(to: 0, duration: 0.3)
            ])
            glow.run(burst) { glow.removeFromParent() }
        }
    }

    // MARK: - Item Pickup Flash

    func showItemPickupFlash(at position: CGPoint, type: ItemType) {
        guard let scene else { return }

        let color: UIColor = type.isRare
            ? UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.8)
            : UIColor(white: 1, alpha: 0.6)

        for _ in 0..<6 {
            let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
            let speed = CGFloat.random(in: 40...100)

            let particle = SKShapeNode(rectOf: CGSize(width: 3, height: 3))
            particle.fillColor = color
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 150
            scene.addChild(particle)

            let move = SKAction.moveBy(x: cos(angle) * speed * 0.3, y: sin(angle) * speed * 0.3, duration: 0.3)
            let fade = SKAction.fadeAlpha(to: 0, duration: 0.3)
            particle.run(SKAction.group([move, fade])) { particle.removeFromParent() }
        }
    }

    // MARK: - Event Visuals

    func showEventWarning(event: GameEvent) {
        guard let scene else { return }

        // Warning border flash
        let border = SKShapeNode(rectOf: CGSize(width: gameWidth - 4, height: gameHeight - 4))
        border.fillColor = .clear
        border.strokeColor = UIColor.red.withAlphaComponent(0.6)
        border.lineWidth = 4
        border.position = CGPoint(x: gameWidth / 2, y: gameHeight / 2)
        border.zPosition = 300
        scene.addChild(border)

        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.2),
            SKAction.fadeAlpha(to: 0.8, duration: 0.2)
        ])
        let flashRepeat = SKAction.repeat(flash, count: 3)
        border.run(SKAction.sequence([flashRepeat, SKAction.removeFromParent()]))

        // Event name label
        let names: [GameEvent: String] = [
            .gravityReverse: "GRAVITY REVERSE",
            .fog: "FOG",
            .earthquake: "EARTHQUAKE",
            .speedStorm: "SPEED STORM",
            .platformShrink: "SHRINK",
            .chaosGravity: "CHAOS"
        ]
        let label = SKLabelNode(text: names[event] ?? "EVENT")
        label.fontName = "SFProDisplay-Black"
        label.fontSize = 22
        label.fontColor = .white
        label.position = CGPoint(x: gameWidth / 2, y: gameHeight / 2)
        label.zPosition = 301
        scene.addChild(label)

        label.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeAlpha(to: 0, duration: 0.5),
            SKAction.removeFromParent()
        ]))
    }

    func addFogOverlay() {
        guard let scene else { return }

        let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.85),
                                   size: CGSize(width: gameWidth, height: gameHeight))
        overlay.position = CGPoint(x: gameWidth / 2, y: gameHeight / 2)
        overlay.zPosition = 250
        overlay.name = "fog_overlay"
        scene.addChild(overlay)
    }

    func updateFogOverlay(playerPosition: CGPoint) {
        guard let overlay = scene?.childNode(withName: "fog_overlay") as? SKSpriteNode else { return }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: gameWidth, height: gameHeight))
        let image = renderer.image { ctx in
            UIColor.black.withAlphaComponent(0.85).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: gameWidth, height: gameHeight))

            let uikitY = gameHeight - playerPosition.y
            let holeRect = CGRect(x: playerPosition.x - 80, y: uikitY - 80, width: 160, height: 160)
            ctx.cgContext.setBlendMode(.clear)
            ctx.cgContext.fillEllipse(in: holeRect)
        }
        overlay.texture = SKTexture(image: image)
    }

    func removeFogOverlay() {
        scene?.childNode(withName: "fog_overlay")?.removeFromParent()
    }

    // MARK: - Effect Indicators

    private var effectIndicators: [ItemType: SKNode] = [:]

    func updateEffectIndicators(activeEffects: [ItemType: TimeInterval]) {
        guard let scene else { return }

        // Remove expired
        for (type, node) in effectIndicators {
            if activeEffects[type] == nil {
                node.removeFromParent()
                effectIndicators.removeValue(forKey: type)
            }
        }

        // Add/update
        var index: CGFloat = 0
        for (type, remaining) in activeEffects.sorted(by: { $0.key.duration > $1.key.duration }) {
            let x = 30 + index * 35
            let y = gameHeight - 100

            if let existing = effectIndicators[type] {
                existing.position = CGPoint(x: x, y: y)
                if let bar = existing.childNode(withName: "progress") as? SKSpriteNode {
                    let progress = type == .shield ? 1.0 : CGFloat(remaining / type.duration)
                    bar.xScale = max(0, progress)
                }
            } else {
                let container = SKNode()
                container.position = CGPoint(x: x, y: y)
                container.zPosition = 200

                let icon = SKSpriteNode(texture: ItemNode.generateTexture(for: type, size: 16),
                                         size: CGSize(width: 16, height: 16))
                container.addChild(icon)

                let bgBar = SKSpriteNode(color: UIColor(white: 0.3, alpha: 0.5),
                                          size: CGSize(width: 24, height: 3))
                bgBar.anchorPoint = CGPoint(x: 0, y: 0.5)
                bgBar.position = CGPoint(x: -12, y: -12)
                container.addChild(bgBar)

                let fillBar = SKSpriteNode(color: .white, size: CGSize(width: 24, height: 3))
                fillBar.name = "progress"
                fillBar.anchorPoint = CGPoint(x: 0, y: 0.5)
                fillBar.position = CGPoint(x: -12, y: -12)
                container.addChild(fillBar)

                scene.addChild(container)
                effectIndicators[type] = container
            }
            index += 1
        }
    }

    func clearEffectIndicators() {
        for (_, node) in effectIndicators {
            node.removeFromParent()
        }
        effectIndicators.removeAll()
    }

    // MARK: - Background Gradient

    static func makeGradientSprite(top: UIColor, bottom: UIColor, size: CGSize) -> SKSpriteNode {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }
            // In UIKit drawing, (0,0) is top-left
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
        let texture = SKTexture(image: image)
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return sprite
    }
}
