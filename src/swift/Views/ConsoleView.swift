import SwiftUI

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let level: LogLevel
    let timestamp: Date

    var levelColor: Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .primary
        case .warning:
            return .orange
        case .error:
            return .red
        @unknown default:
            return .primary
        }
    }

    var levelString: String {
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARN"
        case .error:
            return "ERROR"
        @unknown default:
            return "UNKNOWN"
        }
    }
}

@Observable
class ConsoleViewModel {
    var logs: [LogEntry] = []
    var filteredLogs: [LogEntry] = []
    var searchText: String = "" {
        didSet { filterLogs() }
    }
    var showDebug: Bool = true {
        didSet { filterLogs() }
    }
    var showInfo: Bool = true {
        didSet { filterLogs() }
    }
    var showWarning: Bool = true {
        didSet { filterLogs() }
    }
    var showError: Bool = true {
        didSet { filterLogs() }
    }
    var autoScroll: Bool = true
    var commandText: String = ""
    var commandHistory: [String] = []
    var commandHistoryIndex: Int = -1

    private let console = ConsoleBridge.shared()
    private let dateFormatter: DateFormatter

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        // Load existing log history
        if let history = console.logHistory as? [[String: Any]] {
            for entry in history {
                if let message = entry["message"] as? String,
                   let levelRaw = entry["level"] as? Int,
                   let timestamp = entry["timestamp"] as? Date {
                    let level = LogLevel(rawValue: levelRaw) ?? .info
                    logs.append(LogEntry(message: message, level: level, timestamp: timestamp))
                }
            }
        }
        filterLogs()

        // Set up callback for new logs
        console.setLogCallback { [weak self] message, level, timestamp in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if message == "__CLEAR__" {
                    self.logs.removeAll()
                    self.filteredLogs.removeAll()
                    return
                }

                let entry = LogEntry(message: message, level: level, timestamp: timestamp)
                self.logs.append(entry)

                if self.shouldShow(entry) {
                    self.filteredLogs.append(entry)
                }
            }
        }
    }

    func filterLogs() {
        filteredLogs = logs.filter { shouldShow($0) }
    }

    private func shouldShow(_ entry: LogEntry) -> Bool {
        // Filter by level
        switch entry.level {
        case .debug:
            if !showDebug { return false }
        case .info:
            if !showInfo { return false }
        case .warning:
            if !showWarning { return false }
        case .error:
            if !showError { return false }
        @unknown default:
            break
        }

        // Filter by search text
        if !searchText.isEmpty {
            return entry.message.localizedCaseInsensitiveContains(searchText)
        }

        return true
    }

    func executeCommand() {
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        commandHistory.append(command)
        commandHistoryIndex = commandHistory.count
        commandText = ""

        console.executeCommand(command)
    }

    func navigateHistory(direction: Int) {
        let newIndex = commandHistoryIndex + direction
        if newIndex >= 0 && newIndex < commandHistory.count {
            commandHistoryIndex = newIndex
            commandText = commandHistory[newIndex]
        } else if newIndex >= commandHistory.count {
            commandHistoryIndex = commandHistory.count
            commandText = ""
        }
    }

    func clearLogs() {
        console.clearLogs()
    }

    func formatTimestamp(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    func copyLogs() {
        let text = filteredLogs.map { entry in
            "[\(formatTimestamp(entry.timestamp))] [\(entry.levelString)] \(entry.message)"
        }.joined(separator: "\n")

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

struct ConsoleView: View {
    @State private var viewModel = ConsoleViewModel()
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ConsoleToolbar(viewModel: viewModel)

            Divider()

            // Log list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.filteredLogs) { entry in
                            ConsoleLogRow(entry: entry, viewModel: viewModel)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.filteredLogs.count) { _, _ in
                    if viewModel.autoScroll, let lastEntry = viewModel.filteredLogs.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Command input
            ConsoleCommandInput(viewModel: viewModel)
        }
    }
}

struct ConsoleToolbar: View {
    @Bindable var viewModel: ConsoleViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 200)

            Divider().frame(height: 20)

            // Level filters
            FilterToggle(label: "D", isOn: $viewModel.showDebug, color: .secondary)
            FilterToggle(label: "I", isOn: $viewModel.showInfo, color: .primary)
            FilterToggle(label: "W", isOn: $viewModel.showWarning, color: .orange)
            FilterToggle(label: "E", isOn: $viewModel.showError, color: .red)

            Divider().frame(height: 20)

            // Auto-scroll toggle
            Toggle(isOn: $viewModel.autoScroll) {
                Image(systemName: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            .help("Auto-scroll")

            Spacer()

            // Actions
            Button(action: viewModel.copyLogs) {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy logs")

            Button(action: viewModel.clearLogs) {
                Image(systemName: "trash")
            }
            .help("Clear logs")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct FilterToggle: View {
    let label: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(label)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundColor(isOn ? color : .secondary.opacity(0.5))
                .frame(width: 24, height: 24)
                .background(isOn ? color.opacity(0.2) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

struct ConsoleLogRow: View {
    let entry: LogEntry
    let viewModel: ConsoleViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(viewModel.formatTimestamp(entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text("[\(entry.levelString)]")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundColor(entry.levelColor)
                .frame(width: 50, alignment: .leading)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.levelColor)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct ConsoleCommandInput: View {
    @Bindable var viewModel: ConsoleViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(">")
                .font(.system(.body, design: .monospaced, weight: .bold))
                .foregroundColor(.accentColor)

            TextField("Enter command...", text: $viewModel.commandText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .focused($isFocused)
                .onSubmit {
                    viewModel.executeCommand()
                }
                .onKeyPress(.upArrow) {
                    viewModel.navigateHistory(direction: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    viewModel.navigateHistory(direction: 1)
                    return .handled
                }

            Button(action: viewModel.executeCommand) {
                Image(systemName: "return")
            }
            .disabled(viewModel.commandText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onTapGesture {
            // Claim focus when clicking anywhere in the command input area
            isFocused = true
        }
    }
}

#Preview {
    ConsoleView()
        .frame(width: 800, height: 400)
}
