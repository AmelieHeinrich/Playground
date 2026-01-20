import SwiftUI
import MetalKit

@main
struct PlaygroundApp: App {
    @State private var bridge: ApplicationBridge?
    @State private var initError: String?

    init() {
        // Create Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            _initError = State(initialValue: "Metal is not supported on this device")
            return
        }

        // Create application bridge
        guard let appBridge = ApplicationBridge(device: device) else {
            _initError = State(initialValue: "Failed to initialize application")
            return
        }

        _bridge = State(initialValue: appBridge)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = initError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Initialization Failed")
                            .font(.headline)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if let bridge = bridge {
                    ContentView(bridge: bridge)
                } else {
                    ProgressView("Initializing...")
                }
            }
        }
        #if os(macOS)
        .defaultSize(width: 1920, height: 1080)
        #endif
    }
}
