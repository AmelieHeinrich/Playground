import SwiftUI

// MARK: - Panel Configuration

enum DockPanel: String, CaseIterable, Identifiable {
    case settings = "Settings"
    case console = "Console"
    case debug = "Debug"
    case actions = "Actions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .settings: return "slider.horizontal.3"
        case .console: return "terminal"
        case .debug: return "chart.xyaxis.line"
        case .actions: return "bolt.fill"
        }
    }

    var defaultPosition: PanelPosition {
        switch self {
        case .settings: return .left
        case .console: return .bottom
        case .debug: return .right
        case .actions: return .bottom
        }
    }
}

enum PanelPosition {
    case left, right, bottom
}

// MARK: - Panel State

@Observable
class PanelState {
    var visiblePanels: Set<DockPanel> = [.console]
    var panelPositions: [DockPanel: PanelPosition] = [:]

    init() {
        // Initialize default positions
        for panel in DockPanel.allCases {
            panelPositions[panel] = panel.defaultPosition
        }
    }

    func toggle(_ panel: DockPanel) {
        if visiblePanels.contains(panel) {
            visiblePanels.remove(panel)
        } else {
            visiblePanels.insert(panel)
        }
    }

    func isVisible(_ panel: DockPanel) -> Bool {
        visiblePanels.contains(panel)
    }

    func panels(at position: PanelPosition) -> [DockPanel] {
        DockPanel.allCases.filter { panel in
            visiblePanels.contains(panel) && panelPositions[panel] == position
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    let bridge: ApplicationBridge
    @State private var inputController: InputController
    @State private var panelState = PanelState()

    init(bridge: ApplicationBridge) {
        self.bridge = bridge
        self._inputController = State(initialValue: InputController(bridge: bridge))
    }

    #if os(iOS)
    @State private var showSettings = false
    #endif

    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .environment(\.inputController, inputController)
    }

    #if os(macOS)
    private var macOSLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left panels
                if !panelState.panels(at: .left).isEmpty {
                    VStack(spacing: 0) {
                        ForEach(panelState.panels(at: .left)) { panel in
                            PanelContainer(panel: panel, bridge: bridge)
                        }
                    }
                    .frame(width: 380)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Divider()
                }

                // Center content (Metal view + bottom panels + right panels)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Metal viewport
                        MetalViewRepresentable(bridge: bridge)
                            .frame(minWidth: 400, minHeight: 300)

                        // Right panels
                        if !panelState.panels(at: .right).isEmpty {
                            Divider()

                            VStack(spacing: 0) {
                                ForEach(panelState.panels(at: .right)) { panel in
                                    PanelContainer(panel: panel, bridge: bridge)
                                }
                            }
                            .frame(width: 380)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }

                    // Bottom panels
                    if !panelState.panels(at: .bottom).isEmpty {
                        Divider()

                        HStack(spacing: 0) {
                            ForEach(Array(panelState.panels(at: .bottom).enumerated()), id: \.element) { index, panel in
                                if index > 0 {
                                    Divider()
                                }
                                PanelContainer(panel: panel, bridge: bridge)
                            }
                        }
                        .frame(height: 300)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: panelState.visiblePanels)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                DockView(panelState: panelState)
            }
        }
    }
    #else
    // iOS: Floating button that opens sheet
    private var iOSLayout: some View {
        ZStack(alignment: .topTrailing) {
            MetalViewRepresentable(bridge: bridge)
                .ignoresSafeArea()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "line.3.horizontal.circle.fill")
                    .font(.title2)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                TabView {
                    CVarSettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "slider.horizontal.3")
                        }

                    ConsoleView()
                        .tabItem {
                            Label("Console", systemImage: "terminal")
                        }

                    DebugView(selectedTab: .performance)
                        .tabItem {
                            Label("Debug", systemImage: "chart.xyaxis.line")
                        }

                    ActionsView()
                        .tabItem {
                            Label("Actions", systemImage: "bolt.fill")
                        }
                }
                .navigationTitle("Panels")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showSettings = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    #endif
}

// MARK: - Dock View

struct DockView: View {
    @Bindable var panelState: PanelState

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DockPanel.allCases) { panel in
                DockButton(panel: panel, isActive: panelState.isVisible(panel)) {
                    panelState.toggle(panel)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DockButton: View {
    let panel: DockPanel
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: panel.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(panel.rawValue)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Panel Container

struct PanelContainer: View {
    let panel: DockPanel
    let bridge: ApplicationBridge

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Image(systemName: panel.icon)
                    .foregroundColor(.accentColor)
                Text(panel.rawValue)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(uiColor: .systemBackground))
            #endif

            Divider()

            // Panel content
            Group {
                panelContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            #else
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.3))
            #endif
            .clipped()
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch panel {
        case .settings:
            CVarSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .console:
            ConsoleView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .debug:
            DebugView(selectedTab: .performance)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .actions:
            ActionsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(bridge: ApplicationBridge(device: MTLCreateSystemDefaultDevice()!)!)
        .frame(width: 1400, height: 900)
}
