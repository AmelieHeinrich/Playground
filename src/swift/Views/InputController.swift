import SwiftUI

/// Controller for managing application input state
/// Used to disable camera/game input when UI elements (like text fields) have focus
@Observable
class InputController {
    var bridge: ApplicationBridge?

    init(bridge: ApplicationBridge? = nil) {
        self.bridge = bridge
    }

    func setInputEnabled(_ enabled: Bool) {
        bridge?.inputEnabled = enabled
    }
}

// Environment key for InputController
private struct InputControllerKey: EnvironmentKey {
    static let defaultValue: InputController? = nil
}

extension EnvironmentValues {
    var inputController: InputController? {
        get { self[InputControllerKey.self] }
        set { self[InputControllerKey.self] = newValue }
    }
}
