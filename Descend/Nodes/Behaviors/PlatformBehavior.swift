import SpriteKit

protocol PlatformBehavior: AnyObject {
    /// Called every frame while the platform is active
    func update(delta: TimeInterval, platform: PlatformNode)

    /// Called when the player lands on this platform
    func onPlayerLand(player: PlayerNode, platform: PlatformNode)

    /// Called when the platform is recycled back to pool
    func onRecycle()
}

// Default no-op implementations
extension PlatformBehavior {
    func update(delta: TimeInterval, platform: PlatformNode) {}
    func onPlayerLand(player: PlayerNode, platform: PlatformNode) {}
    func onRecycle() {}
}
