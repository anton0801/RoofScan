import Foundation
import Combine

@MainActor
final class Cockpit: ObservableObject {

    @Published var navigateToMain = false {
        didSet {
            if navigateToMain {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    @Published var navigateToWeb = false {
        didSet {
            if navigateToWeb {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    @Published var showPermissionPrompt = false
    @Published var showOfflineView = false

    private let pilot: Pilot
    private var cancellables = Set<AnyCancellable>()
    private var deadlineTask: Task<Void, Never>?

    private var uiLocked: Bool = false

    init() {
        self.pilot = Airfield.shared.launch(Pilot.self)
        bindShots()
    }

    deinit {
        deadlineTask?.cancel()
    }

    private func bindShots() {
        pilot.shotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shot in
                self?.handleShot(shot)
            }
            .store(in: &cancellables)
    }

    func ignite() {
        pilot.warmUp()
        armDeadline()
    }

    func ingestCapture(_ data: [String: Any]) {
        Task {
            pilot.loadCapture(data)
            await pilot.scan()
        }
    }

    func ingestPins(_ data: [String: Any]) {
        pilot.loadPins(data)
    }

    func acceptConsent() {
        pilot.grantClearance {
            self.showPermissionPrompt = false
        }
    }

    func skipConsent() {
        showPermissionPrompt = false
        pilot.skipClearance()
    }

    func networkConnectivityChanged(_ connected: Bool) {
        if !connected {
            showOfflineView = true
        }
    }

    private func handleShot(_ shot: Shot) {
        guard !uiLocked else { return }

        switch shot {
        case .scanning:
            break
        case .askClearance:
            showPermissionPrompt = true
        case .render:
            navigateToWeb = true
        case .aborted:
            navigateToMain = true
        }
    }

    private func armDeadline() {
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)

            guard let self = self else { return }

            if self.pilot.reportTimeout() {
                self.handleShot(.aborted)
            }
        }
    }
}
