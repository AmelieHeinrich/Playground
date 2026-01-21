import SwiftUI
import MetalKit

// Main Debug View with tabs for different debug panels
struct DebugView: View {
    @State var selectedTab: DebugTab

    init(selectedTab: DebugTab = .performance) {
        self.selectedTab = selectedTab
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("Debug Panel", selection: $selectedTab) {
                ForEach(DebugTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .performance:
                    PerformanceView()
                case .memory:
                    MemoryView()
                case .encoders:
                    EncodersView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }
}

enum DebugTab: String, CaseIterable, Identifiable {
    case performance = "Performance"
    case memory = "Memory"
    case encoders = "Encoders"

    var id: String { rawValue }
}

// MARK: - Performance View

@Observable
class PerformanceViewModel {
    var frameTimeHistory: [Double] = []
    var cpuTimeHistory: [Double] = []
    var gpuTimeHistory: [Double] = []
    var averageFrameTime: Double = 0
    var averageCPUTime: Double = 0
    var averageGPUTime: Double = 0
    var currentFPS: Double = 0
    var minFrameTime: Double = 0
    var maxFrameTime: Double = 0

    private let debugBridge = DebugBridge.shared()
    private var timer: Timer?

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        frameTimeHistory = (debugBridge.frameTimeHistory(120) as [NSNumber]).map { $0.doubleValue }
        cpuTimeHistory = (debugBridge.cpuTimeHistory(120) as [NSNumber]).map { $0.doubleValue }
        gpuTimeHistory = (debugBridge.gpuTimeHistory(120) as [NSNumber]).map { $0.doubleValue }
        averageFrameTime = debugBridge.averageFrameTime()
        averageCPUTime = debugBridge.averageCPUTime()
        averageGPUTime = debugBridge.averageGPUTime()
        currentFPS = debugBridge.currentFPS()
        minFrameTime = debugBridge.minFrameTime()
        maxFrameTime = debugBridge.maxFrameTime()
    }
}

struct PerformanceView: View {
    @State private var viewModel = PerformanceViewModel()
    @State private var showCPU = true
    @State private var showGPU = true
    @State private var showFrameTime = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Stats header
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CompactStatBox(title: "FPS", value: String(format: "%.1f", viewModel.currentFPS), color: .green)
                        CompactStatBox(title: "Frame", value: String(format: "%.2f ms", viewModel.averageFrameTime), color: .blue)
                        CompactStatBox(title: "CPU", value: String(format: "%.2f ms", viewModel.averageCPUTime), color: .orange)
                        CompactStatBox(title: "GPU", value: String(format: "%.2f ms", viewModel.averageGPUTime), color: .purple)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)

                Divider()

                // Graph toggles
                HStack {
                    Toggle("Frame Time", isOn: $showFrameTime)
                    Toggle("CPU Time", isOn: $showCPU)
                    Toggle("GPU Time", isOn: $showGPU)
                }
                .padding(.horizontal)

                // Frame time graph
                PerformanceGraph(
                    frameTimeHistory: showFrameTime ? viewModel.frameTimeHistory : [],
                    cpuTimeHistory: showCPU ? viewModel.cpuTimeHistory : [],
                    gpuTimeHistory: showGPU ? viewModel.gpuTimeHistory : []
                )
                .frame(height: 200)
                .padding()

                // Min/Max info
                HStack {
                    Text("Min: \(String(format: "%.2f ms", viewModel.minFrameTime))")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Max: \(String(format: "%.2f ms", viewModel.maxFrameTime))")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.title2, design: .monospaced, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(minWidth: 80)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PerformanceGraph: View {
    let frameTimeHistory: [Double]
    let cpuTimeHistory: [Double]
    let gpuTimeHistory: [Double]

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(
                frameTimeHistory.max() ?? 16.67,
                cpuTimeHistory.max() ?? 0,
                gpuTimeHistory.max() ?? 0,
                16.67
            ) * 1.1

            ZStack {
                // Background grid
                GraphGrid(maxValue: maxValue)

                // Frame time line
                if !frameTimeHistory.isEmpty {
                    GraphLine(values: frameTimeHistory, maxValue: maxValue, color: .blue)
                }

                // CPU time line
                if !cpuTimeHistory.isEmpty {
                    GraphLine(values: cpuTimeHistory, maxValue: maxValue, color: .orange)
                }

                // GPU time line
                if !gpuTimeHistory.isEmpty {
                    GraphLine(values: gpuTimeHistory, maxValue: maxValue, color: .purple)
                }

                // 16.67ms target line (60 FPS)
                TargetLine(targetValue: 16.67, maxValue: maxValue)
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
        .cornerRadius(8)
    }
}

struct GraphGrid: View {
    let maxValue: Double

    var body: some View {
        GeometryReader { geometry in
            let lineCount = 4

            ForEach(0..<lineCount, id: \.self) { i in
                let y = geometry.size.height * CGFloat(i) / CGFloat(lineCount - 1)
                let value = maxValue * Double(lineCount - 1 - i) / Double(lineCount - 1)

                HStack {
                    Text(String(format: "%.1f", value))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width - 50, y: y))
                    }
                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
        }
    }
}

struct GraphLine: View {
    let values: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 50
            let height = geometry.size.height

            Path { path in
                guard values.count > 1 else { return }

                let xStep = width / CGFloat(values.count - 1)

                for (index, value) in values.enumerated() {
                    let x = 50 + CGFloat(index) * xStep
                    let y = height - (CGFloat(value / maxValue) * height)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}

struct TargetLine: View {
    let targetValue: Double
    let maxValue: Double

    var body: some View {
        GeometryReader { geometry in
            let y = geometry.size.height - (CGFloat(targetValue / maxValue) * geometry.size.height)

            HStack {
                Spacer().frame(width: 50)

                ZStack(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width - 50, y: y))
                    }
                    .stroke(Color.green.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [6, 3]))

                    Text("60 FPS")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.green)
                        .position(x: geometry.size.width - 80, y: y - 10)
                }
            }
        }
    }
}

// MARK: - Memory View

struct MemoryView: View {
    @State private var allocations: [[String: Any]] = []
    @State private var totalMemory: UInt64 = 0
    @State private var memoryByType: [Int: UInt64] = [:]
    @State private var sortOrder: [KeyPathComparator<AllocationItem>] = [.init(\.bytes, order: .reverse)]

    private let debugBridge = DebugBridge.shared()

    var body: some View {
        VStack(spacing: 0) {
            // Memory summary
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Memory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(totalMemory))
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 100)

                    Divider().frame(height: 30)

                    // Memory by type
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(memoryByType.keys.sorted()), id: \.self) { typeRaw in
                                let type = ResourceType(rawValue: typeRaw) ?? .other
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(typeName(for: type))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatBytes(memoryByType[typeRaw] ?? 0))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(typeColor(for: type))
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 60)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button("Refresh") {
                        refresh()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
            .frame(height: 80)

            Divider()

            // Allocations table
            #if os(macOS)
            Table(allocationItems, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { item in
                    Text(item.name)
                        .font(.system(.body, design: .monospaced))
                }

                TableColumn("Size", value: \.bytes) { item in
                    Text(formatBytes(item.bytes))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .width(100)

                TableColumn("Type", value: \.typeRaw) { item in
                    Text(typeName(for: ResourceType(rawValue: item.typeRaw) ?? .other))
                        .foregroundColor(typeColor(for: ResourceType(rawValue: item.typeRaw) ?? .other))
                }
                .width(100)

                TableColumn("Heap", value: \.heapTypeRaw) { item in
                    Text(heapTypeName(for: HeapType(rawValue: item.heapTypeRaw) ?? .private))
                }
                .width(80)
            }
            .onChange(of: sortOrder) { _, newOrder in
                // Table handles sorting automatically
            }
            .frame(maxHeight: .infinity)
            #else
            // iOS: Use List instead of Table
            List(allocationItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(formatBytes(item.bytes))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        Label(typeName(for: ResourceType(rawValue: item.typeRaw) ?? .other), systemImage: "memorychip")
                            .font(.caption)
                            .foregroundColor(typeColor(for: ResourceType(rawValue: item.typeRaw) ?? .other))

                        Label(heapTypeName(for: HeapType(rawValue: item.heapTypeRaw) ?? .private), systemImage: "square.stack.3d.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refresh()
        }
    }

    private var allocationItems: [AllocationItem] {
        allocations.map { dict in
            AllocationItem(
                name: dict["name"] as? String ?? "",
                bytes: (dict["bytes"] as? NSNumber)?.uint64Value ?? 0,
                typeRaw: (dict["type"] as? NSNumber)?.intValue ?? 0,
                heapTypeRaw: (dict["heapType"] as? NSNumber)?.intValue ?? 0
            )
        }
        .sorted(using: sortOrder)
    }

    private func refresh() {
        allocations = debugBridge.allAllocations() as? [[String: Any]] ?? []
        totalMemory = UInt64(debugBridge.totalMemoryUsed())

        let byType = debugBridge.memoryByType()
        memoryByType = Dictionary(uniqueKeysWithValues: byType.map {
            ($0.key.intValue, $0.value.uint64Value)
        })
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func typeName(for type: ResourceType) -> String {
        switch type {
        case .buffer: return "Buffer"
        case .texture2D: return "Texture 2D"
        case .texture3D: return "Texture 3D"
        case .cube: return "Cube"
        case .textureArray: return "Array"
        case .heap: return "Heap"
        case .accelerationStructure: return "Accel Struct"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }

    private func typeColor(for type: ResourceType) -> Color {
        switch type {
        case .buffer: return .blue
        case .texture2D: return .green
        case .texture3D: return .purple
        case .cube: return .orange
        case .textureArray: return .cyan
        case .heap: return .yellow
        case .accelerationStructure: return .red
        case .other: return .secondary
        @unknown default: return .secondary
        }
    }

    private func heapTypeName(for type: HeapType) -> String {
        switch type {
        case .private: return "Private"
        case .shared: return "Shared"
        case .managed: return "Managed"
        @unknown default: return "Unknown"
        }
    }
}

struct AllocationItem: Identifiable {
    let id = UUID()
    let name: String
    let bytes: UInt64
    let typeRaw: Int
    let heapTypeRaw: Int
}

// MARK: - Encoders View

struct EncodersView: View {
    @State private var frameHierarchy: [String: Any] = [:]
    @State private var totalDrawCalls: Int = 0
    @State private var totalDispatches: Int = 0
    @State private var totalCopies: Int = 0
    @State private var totalExecuteIndirects: Int = 0
    @State private var totalAccelerationBuilds: Int = 0
    @State private var totalVertices: Int64 = 0
    @State private var totalInstances: Int64 = 0

    private let debugBridge = DebugBridge.shared()

    var body: some View {
        VStack(spacing: 0) {
            // Stats header
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CompactStatBox(title: "Draw Calls", value: "\(totalDrawCalls)", color: .blue)
                        CompactStatBox(title: "Dispatches", value: "\(totalDispatches)", color: .purple)
                        CompactStatBox(title: "Copies", value: "\(totalCopies)", color: .orange)
                        CompactStatBox(title: "Execute Indirect", value: "\(totalExecuteIndirects)", color: .pink)
                        CompactStatBox(title: "AS Builds", value: "\(totalAccelerationBuilds)", color: .cyan)
                        CompactStatBox(title: "Vertices", value: formatNumber(totalVertices), color: .green)
                        CompactStatBox(title: "Instances", value: formatNumber(totalInstances), color: .yellow)
                    }
                }

                HStack {
                    Spacer()
                    Button("Refresh") {
                        refresh()
                    }
                    .buttonStyle(.borderless)

                    if debugBridge.gpuCaptureAvailable {
                        Button("Capture GPU") {
                            debugBridge.triggerGPUCapture()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding()
            .frame(height: 80)

            Divider()

            // Encoder hierarchy
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let encoders = frameHierarchy["encoders"] as? [[String: Any]] {
                        ForEach(Array(encoders.enumerated()), id: \.offset) { index, encoder in
                            EncoderRow(encoder: encoder, index: index)
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        frameHierarchy = debugBridge.currentFrameHierarchy() as? [String: Any] ?? [:]
        totalDrawCalls = Int(debugBridge.totalDrawCalls)
        totalDispatches = Int(debugBridge.totalDispatches)
        totalCopies = Int(debugBridge.totalCopies)
        totalExecuteIndirects = Int(debugBridge.totalExecuteIndirects)
        totalAccelerationBuilds = Int(debugBridge.totalAccelerationBuilds)
        totalVertices = debugBridge.totalVertices
        totalInstances = debugBridge.totalInstances
    }

    private func formatNumber(_ value: Int64) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000.0)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000.0)
        }
        return "\(value)"
    }
}

struct CompactStatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(minWidth: 60)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct EncoderRow: View {
    let encoder: [String: Any]
    let index: Int

    @State private var isExpanded = false

    var body: some View {
        let name = encoder["name"] as? String ?? "Unknown"
        let typeRaw = (encoder["type"] as? NSNumber)?.intValue ?? 0
        let type = EncoderType(rawValue: typeRaw) ?? .render
        let draws = encoder["draws"] as? [[String: Any]] ?? []
        let dispatches = encoder["dispatches"] as? [[String: Any]] ?? []
        let copies = (encoder["copies"] as? NSNumber)?.intValue ?? 0
        let executeIndirects = (encoder["executeIndirects"] as? NSNumber)?.intValue ?? 0
        let accelerationBuilds = (encoder["accelerationBuilds"] as? NSNumber)?.intValue ?? 0

        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                if !draws.isEmpty {
                    Text("Draws: \(draws.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(draws.enumerated()), id: \.offset) { drawIndex, draw in
                        let vertexCount = (draw["vertexCount"] as? NSNumber)?.intValue ?? 0
                        let instanceCount = (draw["instanceCount"] as? NSNumber)?.intValue ?? 0
                        let indexed = (draw["indexed"] as? NSNumber)?.boolValue ?? false

                        HStack {
                            Text("  Draw \(drawIndex)")
                                .font(.system(.caption, design: .monospaced))
                            Text("\(vertexCount) verts")
                                .foregroundColor(.secondary)
                            if instanceCount > 1 {
                                Text("x\(instanceCount)")
                                    .foregroundColor(.orange)
                            }
                            if indexed {
                                Text("indexed")
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }

                if !dispatches.isEmpty {
                    Text("Dispatches: \(dispatches.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    ForEach(Array(dispatches.enumerated()), id: \.offset) { dispatchIndex, dispatch in
                        let tgX = (dispatch["threadgroupsX"] as? NSNumber)?.intValue ?? 0
                        let tgY = (dispatch["threadgroupsY"] as? NSNumber)?.intValue ?? 0
                        let tgZ = (dispatch["threadgroupsZ"] as? NSNumber)?.intValue ?? 0

                        Text("  Dispatch \(dispatchIndex): [\(tgX), \(tgY), \(tgZ)]")
                        .font(.system(.caption, design: .monospaced))
                }
            }

            if copies > 0 {
                Text("Copies: \(copies)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            if executeIndirects > 0 {
                Text("Execute Indirect: \(executeIndirects)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            if accelerationBuilds > 0 {
                Text("Acceleration Structure Builds: \(accelerationBuilds)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.leading, 16)
    } label: {
            HStack {
                Image(systemName: encoderIcon(for: type))
                    .foregroundColor(encoderColor(for: type))

                Text("\(index). \(name)")
                    .font(.system(.body, design: .monospaced, weight: .medium))

                Spacer()

                Text(encoderTypeName(for: type))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(encoderColor(for: type).opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private func encoderTypeName(for type: EncoderType) -> String {
        switch type {
        case .render: return "Render"
        case .compute: return "Compute"
        case .blit: return "Blit"
        case .acceleration: return "AccelStruct"
        @unknown default: return "Unknown"
        }
    }

    private func encoderIcon(for type: EncoderType) -> String {
        switch type {
        case .render: return "paintpalette"
        case .compute: return "cpu"
        case .blit: return "arrow.right.arrow.left"
        case .acceleration: return "cube.transparent"
        @unknown default: return "questionmark"
        }
    }

    private func encoderColor(for type: EncoderType) -> Color {
        switch type {
        case .render: return .green
        case .compute: return .purple
        case .blit: return .orange
        case .acceleration: return .cyan
        @unknown default: return .secondary
        }
    }
}
