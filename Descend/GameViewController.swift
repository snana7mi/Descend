import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let scene = GameScene(size: CGSize(width: 375, height: 667))
        scene.scaleMode = .aspectFill

        let skView = self.view as! SKView
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif

        // Initial theme sync
        ThemeManager.shared.updateForTraitCollection(traitCollection)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            ThemeManager.shared.updateForTraitCollection(traitCollection)
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
