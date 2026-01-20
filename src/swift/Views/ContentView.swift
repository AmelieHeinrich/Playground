import SwiftUI

struct ContentView: View {
    let bridge: ApplicationBridge

    #if os(iOS)
    @State private var showSettings = false
    #endif

    @State private var selectedLeftPanel: LeftPanelTab = .settings
    @State private var selectedBottomPanel: BottomPanelTab = .console
    @State private var showLeftPanel = true
    @State private var showBottomPanel = true

    var body: some View {
        #if os(macOS)
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left sidebar (Settings)
                if showLeftPanel {
                    VStack(spacing: 0) {
                        // Left panel header
                        HStack {
                            Text("Settings")
                                .font(.headline)
                                .padding(.leading, 12)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(Color(nsColor: .windowBackgroundColor))

                        Divider()

                        // Settings content
                        ScrollView {
                            CVarSettingsView()
                        }
                    }
                    .frame(width: 380)
                    .background(Color(nsColor: .windowBackgroundColor))

                    Divider()
                }

                // Center content (Metal view + bottom panel)
                VStack(spacing: 0) {
                    // Metal viewport
                    MetalViewRepresentable(bridge: bridge)
                        .frame(minWidth: 400, minHeight: 300)

                    // Bottom panel
                    if showBottomPanel {
                        Divider()

                        VStack(spacing: 0) {
                            // Bottom panel tabs
                            HStack {
                                Picker("", selection: $selectedBottomPanel) {
                                    ForEach(BottomPanelTab.allCases) { tab in
                                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 300)

                                Spacer()
                            }
                            .padding(8)
                            .background(Color(nsColor: .windowBackgroundColor))

                            Divider()

                            // Bottom panel content
                            switch selectedBottomPanel {
                            case .console:
                                ConsoleView()
                            case .performance:
                                PerformanceView()
                            }
                        }
                        .frame(height: 280)
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    Button(action: { showLeftPanel.toggle() }) {
                        Image(systemName: "sidebar.left")
                    }
                    .help("Toggle Settings Panel")

                    Button(action: { showBottomPanel.toggle() }) {
                        Image(systemName: "rectangle.bottomthird.inset.filled")
                    }
                    .help("Toggle Console/Performance Panel")
                }
            }

            ToolbarItem(placement: .principal) {
                ActionsToolbarView()
            }
        }
        #else
        // iOS: Floating button that opens sheet
        ZStack(alignment: .topTrailing) {
            MetalViewRepresentable(bridge: bridge)
                .ignoresSafeArea()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                TabView(selection: $selectedLeftPanel) {
                    CVarSettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "slider.horizontal.3")
                        }
                        .tag(LeftPanelTab.settings)

                    ConsoleView()
                        .tabItem {
                            Label("Console", systemImage: "terminal")
                        }

                    ActionsView()
                        .tabItem {
                            Label("Actions", systemImage: "bolt.fill")
                        }

                    PerformanceView(viewModel: PerformanceViewModel())
                        .tabItem {
                            Label("Performance", systemImage: "gauge.with.dots.needle.33percent")
                        }
                }
                .navigationTitle("Settings")
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
        #endif
    }
}

enum LeftPanelTab: String, CaseIterable, Identifiable {
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .settings: return "slider.horizontal.3"
        }
    }
}

enum BottomPanelTab: String, CaseIterable, Identifiable {
    case console = "Console"
    case performance = "Performance"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .console: return "terminal"
        case .performance: return "gauge.with.dots.needle.33percent"
        }
    }
}

// Actions toolbar for quick access
struct ActionsToolbarView: View {
    private let actionsBridge = ActionsBridge.shared()
    @State private var allActions: [ActionItem] = []

    var body: some View {
        HStack(spacing: 8) {
            ForEach(allActions.prefix(8)) { action in
                Button(action: {
                    actionsBridge.triggerAction(action.key)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: iconForAction(action))
                            .font(.system(size: 11))
                        Text(action.displayName)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderless)
                .help(action.shortcutHint ?? action.displayName)
            }

            if allActions.count > 8 {
                Menu {
                    ForEach(allActions.dropFirst(8)) { action in
                        Button(action.displayName) {
                            actionsBridge.triggerAction(action.key)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11))
                        Text("More")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .onAppear {
            refreshActions()
        }
    }

    private func refreshActions() {
        let actions = (actionsBridge.allActions() as? [[String: Any]] ?? [])
            .map { ActionItem(from: $0) }
        allActions = actions
    }

    private func iconForAction(_ action: ActionItem) -> String {
        let lower = action.displayName.lowercased()
        if lower.contains("capture") || lower.contains("screenshot") {
            return "camera"
        } else if lower.contains("reload") || lower.contains("refresh") {
            return "arrow.clockwise"
        } else if lower.contains("toggle") {
            return "switch.2"
        } else if lower.contains("freeze") {
            return "pause"
        } else if lower.contains("clear") {
            return "trash"
        } else if lower.contains("add") {
            return "plus"
        } else if lower.contains("debug") {
            return "ladybug"
        }
        return "bolt.fill"
    }
}

#Preview {
    ContentView(bridge: ApplicationBridge(device: MTLCreateSystemDefaultDevice()!)!)
}
