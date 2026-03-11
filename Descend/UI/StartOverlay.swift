import SpriteKit

final class StartOverlay: SKNode {
    init(sceneSize: CGSize, theme: Theme) {
        super.init()
        zPosition = 200
        buildUI(sceneSize: sceneSize, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(sceneSize: CGSize, theme: Theme) {
        let centerX = sceneSize.width / 2
        let centerY = sceneSize.height / 2
        let isDark = theme.mode == .dark
        let ui = theme.colors.ui

        // Panel
        let panel = UIFactory.makePanel(
            size: CGSize(width: 300, height: 200),
            bgColor: ui.panelBg,
            bgAlpha: isDark ? 0.65 : 0.75,
            cornerRadius: isDark ? 8 : 20,
            borderColor: isDark ? ui.neonPrimary : .white,
            borderWidth: isDark ? 2 : 1,
            isDark: isDark
        )
        panel.position = CGPoint(x: centerX, y: centerY)
        addChild(panel)

        // Title
        let title = UIFactory.makeLabel(
            text: "Descend",
            fontSize: 42,
            color: ui.textPrimary,
            strokeColor: isDark ? ui.textStroke : nil,
            strokeWidth: isDark ? 6 : 0
        )
        title.position = CGPoint(x: centerX, y: centerY + 40)
        addChild(title)

        // Hint
        let hintText = String(localized: "tapToStart")
        let hint = UIFactory.makePulsingLabel(
            text: hintText,
            fontSize: 22,
            color: ui.textAccent
        )
        hint.position = CGPoint(x: centerX, y: centerY - 40)
        addChild(hint)
    }

    func show(in scene: SKScene) {
        alpha = 0
        scene.addChild(self)
        run(SKAction.fadeIn(withDuration: 0.3))
    }

    func dismiss(completion: @escaping () -> Void) {
        run(SKAction.fadeOut(withDuration: 0.2)) {
            self.removeFromParent()
            completion()
        }
    }
}
