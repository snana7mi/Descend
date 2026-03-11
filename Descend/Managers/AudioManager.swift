import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private var currentPlayer: AVAudioPlayer?
    private var currentThemeMode: ThemeMode?
    private var themeSubscriptionID: UUID?
    private let bgmVolume: Float = 0.5
    private let fadeDuration: TimeInterval = 1.0

    private init() {}

    func start() {
        guard themeSubscriptionID == nil else { return }
        themeSubscriptionID = ThemeManager.shared.subscribe { [weak self] newTheme in
            self?.onThemeChange(newTheme)
        }
    }

    // MARK: - Playback

    func playBGM() {
        let theme = ThemeManager.shared.currentTheme
        guard theme.mode != currentThemeMode else { return }
        stopBGM()

        guard let url = Bundle.main.url(forResource: theme.bgmFileName, withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = bgmVolume
            player.prepareToPlay()
            player.play()
            currentPlayer = player
            currentThemeMode = theme.mode
        } catch {
            print("[AudioManager] Failed to play BGM: \(error)")
        }
    }

    func stopBGM() {
        currentPlayer?.stop()
        currentPlayer = nil
        currentThemeMode = nil
    }

    // MARK: - Theme Change

    private func onThemeChange(_ theme: Theme) {
        guard currentPlayer != nil else { return }
        guard theme.mode != currentThemeMode else { return }
        crossfadeTo(theme: theme)
    }

    private func crossfadeTo(theme: Theme) {
        guard let url = Bundle.main.url(forResource: theme.bgmFileName, withExtension: "mp3") else { return }

        let oldPlayer = currentPlayer

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0
            newPlayer.prepareToPlay()
            newPlayer.play()
            currentPlayer = newPlayer
            currentThemeMode = theme.mode

            // Crossfade using Timer
            let steps = 20
            let interval = fadeDuration / Double(steps)
            let volumeStep = bgmVolume / Float(steps)

            var step = 0
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                step += 1
                newPlayer.volume = min(self.bgmVolume, Float(step) * volumeStep)
                oldPlayer?.volume = max(0, self.bgmVolume - Float(step) * volumeStep)

                if step >= steps {
                    timer.invalidate()
                    oldPlayer?.stop()
                }
            }
        } catch {
            print("[AudioManager] Failed to crossfade BGM: \(error)")
        }
    }

    // MARK: - Cleanup

    func destroy() {
        stopBGM()
        if let id = themeSubscriptionID {
            ThemeManager.shared.unsubscribe(id)
            themeSubscriptionID = nil
        }
    }
}
