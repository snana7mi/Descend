import SpriteKit

final class MovingBehavior: PlatformBehavior {
    private let speed: CGFloat
    private var direction: CGFloat
    private let minX: CGFloat
    private let maxX: CGFloat

    init(speed: CGFloat? = nil, gameWidth: CGFloat, padding: CGFloat) {
        self.speed = speed ?? CGFloat.random(in: 40...80)
        self.direction = Bool.random() ? 1 : -1
        self.minX = padding
        self.maxX = gameWidth - padding
    }

    func update(delta: TimeInterval, platform: PlatformNode) {
        let halfWidth = platform.size.width / 2
        platform.position.x += speed * direction * CGFloat(delta)

        if platform.position.x - halfWidth < minX {
            platform.position.x = minX + halfWidth
            direction = 1
        } else if platform.position.x + halfWidth > maxX {
            platform.position.x = maxX - halfWidth
            direction = -1
        }
    }

    func onRecycle() {
        direction = Bool.random() ? 1 : -1
    }
}
