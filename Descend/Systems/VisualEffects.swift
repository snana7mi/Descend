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
