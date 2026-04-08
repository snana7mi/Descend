import Foundation

final class EventSystem {
    enum EventState {
        case idle
        case warning(event: GameEvent, remaining: TimeInterval)
        case active(event: GameEvent, remaining: TimeInterval)
        case cooldown(remaining: TimeInterval)
    }

    private(set) var state: EventState = .idle

    var activeEvent: GameEvent? {
        if case .active(let event, _) = state { return event }
        return nil
    }

    var warningEvent: GameEvent? {
        if case .warning(let event, _) = state { return event }
        return nil
    }

    private var timeSinceLastEvent: TimeInterval = 0
    private var nextEventDelay: TimeInterval
    private var lastEventType: GameEvent?

    // Callbacks
    var onEventWarning: ((_ event: GameEvent) -> Void)?
    var onEventStart: ((_ event: GameEvent) -> Void)?
    var onEventEnd: ((_ event: GameEvent) -> Void)?

    init() {
        self.nextEventDelay = TimeInterval.random(in: 30...60)
    }

    func update(delta: TimeInterval, difficulty: Difficulty) {
        guard difficulty.eventsEnabled else { return }

        // Don't trigger new events during breathing, but continue active ones
        if difficulty.isBreathingPhase {
            updateCurrentState(delta: delta)
            return
        }

        updateCurrentState(delta: delta)
    }

    private func updateCurrentState(delta: TimeInterval) {
        switch state {
        case .idle:
            timeSinceLastEvent += delta
            if timeSinceLastEvent >= nextEventDelay {
                triggerRandomEvent()
            }

        case .warning(let event, let remaining):
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                state = .active(event: event, remaining: event.duration)
                onEventStart?(event)
            } else {
                state = .warning(event: event, remaining: newRemaining)
            }

        case .active(let event, let remaining):
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                state = .cooldown(remaining: event.cooldownDuration)
                onEventEnd?(event)
                lastEventType = event
            } else {
                state = .active(event: event, remaining: newRemaining)
            }

        case .cooldown(let remaining):
            let newRemaining = remaining - delta
            if newRemaining <= 0 {
                state = .idle
                timeSinceLastEvent = 0
                nextEventDelay = TimeInterval.random(in: 20...40)
            } else {
                state = .cooldown(remaining: newRemaining)
            }
        }
    }

    private func triggerRandomEvent() {
        var candidates = GameEvent.allCases
        if let last = lastEventType {
            candidates.removeAll { $0 == last }
        }
        guard let event = candidates.randomElement() else { return }

        state = .warning(event: event, remaining: event.warningDuration)
        onEventWarning?(event)
    }

    func reset() {
        state = .idle
        timeSinceLastEvent = 0
        nextEventDelay = TimeInterval.random(in: 30...60)
        lastEventType = nil
    }
}
