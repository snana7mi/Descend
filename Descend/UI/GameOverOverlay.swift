import SpriteKit

final class GameOverOverlay: SKNode {
    var onRestart: (() -> Void)?

    init(sceneSize: CGSize, score: Int, theme: Theme) {
        super.init()
        zPosition = 200
        isUserInteractionEnabled = true
        buildUI(sceneSize: sceneSize, score: score, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(sceneSize: CGSize, score: Int, theme: Theme) {
        let centerX = sceneSize.width / 2
        let centerY = sceneSize.height / 2
        let isDark = theme.mode == .dark
        let ui = theme.colors.ui

        // Panel
        let panel = UIFactory.makePanel(
            size: CGSize(width: 280, height: 260),
            bgColor: ui.panelBg,
            bgAlpha: 0.75,
            cornerRadius: isDark ? 8 : 25,
            borderColor: isDark ? ui.neonPrimary : .white,
            borderWidth: isDark ? 2 : 1.5,
            isDark: isDark
        )
        panel.position = CGPoint(x: centerX, y: centerY)
        addChild(panel)

        // Game Over title
        let gameOverText = String(localized: "gameOver")
        let title = UIFactory.makeLabel(
            text: gameOverText,
            fontSize: 36,
            color: ui.textDanger,
            strokeColor: isDark ? ui.textStroke : nil,
            strokeWidth: isDark ? 5 : 0
        )
        title.position = CGPoint(x: centerX, y: centerY + 80)
        addChild(title)

        // Score
        let scoreLabel = UIFactory.makeLabel(
            text: "\(score)",
            fontSize: 64,
            color: ui.textAccent,
            strokeColor: isDark ? ui.textStroke : nil,
            strokeWidth: isDark ? 6 : 0
        )
        scoreLabel.fontName = "SFProDisplay-Black"
        scoreLabel.position = CGPoint(x: centerX, y: centerY - 10)
        addChild(scoreLabel)

        // Restart hint
        let restartText = String(localized: "tapToRestart")
        let restart = UIFactory.makePulsingLabel(
            text: restartText,
            fontSize: 22,
            color: ui.textSuccess
        )
        restart.position = CGPoint(x: centerX, y: centerY - 80)
        addChild(restart)
    }

    func show(in scene: SKScene) {
        alpha = 0
        scene.addChild(self)
        run(SKAction.fadeIn(withDuration: 0.3))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onRestart?()
    }
}
