import SwiftUI
import MetalKit

// Main Debug View with tabs for different debug panels
struct DebugView: View {
    @State private var selectedTab: DebugTab = .performance

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
            switch selectedTab {
            case .performance:
                PerformanceView()
            case .memory:
                MemoryView()
            case .encoders:
                EncodersView()
            case .textures:
                TexturesView()
            }
        }
    }
}

enum DebugTab: String, CaseIterable, Identifiable {
    case performance = "Performance"
    case memory = "Memory"
    case encoders = "Encoders"
    case textures = "Textures"

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
        frameTimeHistory = (debugBridge.frameTimeHistory(120) as? [NSNumber])?.map { $0.doubleValue } ?? []
        cpuTimeHistory = (debugBridge.cpuTimeHistory(120) as? [NSNumber])?.map { $0.doubleValue } ?? []
        gpuTimeHistory = (debugBridge.gpuTimeHistory(120) as? [NSNumber])?.map { $0.doubleValue } ?? []
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
                HStack(spacing: 24) {
                    StatBox(title: "FPS", value: String(format: "%.1f", viewModel.currentFPS), color: .green)
                    StatBox(title: "Frame Time", value: String(format: "%.2f ms", viewModel.averageFrameTime), color: .blue)
                    StatBox(title: "CPU", value: String(format: "%.2f ms", viewModel.averageCPUTime), color: .orange)
                    StatBox(title: "GPU", value: String(format: "%.2f ms", viewModel.averageGPUTime), color: .purple)
                }
                .padding()

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

                Spacer()
            }
        }
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
        .background(Color(nsColor: .controlBackgroundColor))
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
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Total Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatBytes(totalMemory))
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                }

                Divider().frame(height: 40)

                // Memory by type
                ForEach(Array(memoryByType.keys.sorted()), id: \.self) { typeRaw in
                    let type = ResourceType(rawValue: typeRaw) ?? .other
                    VStack(alignment: .leading) {
                        Text(typeName(for: type))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(memoryByType[typeRaw] ?? 0))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(typeColor(for: type))
                    }
                }

                Spacer()

                Button("Refresh") {
                    refresh()
                }
            }
            .padding()

            Divider()

            // Allocations table
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
        }
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

        if let byType = debugBridge.memoryByType() as? [NSNumber: NSNumber] {
            memoryByType = Dictionary(uniqueKeysWithValues: byType.map {
                ($0.key.intValue, $0.value.uint64Value)
            })
        }
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
    @State private var totalVertices: Int64 = 0
    @State private var totalInstances: Int64 = 0

    private let debugBridge = DebugBridge.shared()

    var body: some View {
        VStack(spacing: 0) {
            // Stats header
            HStack(spacing: 24) {
                StatBox(title: "Draw Calls", value: "\(totalDrawCalls)", color: .blue)
                StatBox(title: "Dispatches", value: "\(totalDispatches)", color: .purple)
                StatBox(title: "Vertices", value: formatNumber(totalVertices), color: .green)
                StatBox(title: "Instances", value: formatNumber(totalInstances), color: .orange)

                Spacer()

                Button("Refresh") {
                    refresh()
                }

                if debugBridge.gpuCaptureAvailable {
                    Button("Capture GPU") {
                        debugBridge.triggerGPUCapture()
                    }
                }
            }
            .padding()

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
        }
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        frameHierarchy = debugBridge.currentFrameHierarchy() as? [String: Any] ?? [:]
        totalDrawCalls = Int(debugBridge.totalDrawCalls)
        totalDispatches = Int(debugBridge.totalDispatches)
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
        @unknown default: return "Unknown"
        }
    }

    private func encoderIcon(for type: EncoderType) -> String {
        switch type {
        case .render: return "paintpalette"
        case .compute: return "cpu"
        case .blit: return "arrow.right.arrow.left"
        @unknown default: return "questionmark"
        }
    }

    private func encoderColor(for type: EncoderType) -> Color {
        switch type {
        case .render: return .green
        case .compute: return .purple
        case .blit: return .orange
        @unknown default: return .secondary
        }
    }
}

// MARK: - Textures View

struct TextureItem: Identifiable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let depth: Int
    let format: Int
    let mipLevels: Int
    let arrayLength: Int

    init(from dict: [String: Any]) {
        self.name = dict["name"] as? String ?? UUID().uuidString
        self.id = self.name
        self.width = (dict["width"] as? NSNumber)?.intValue ?? 0
        self.height = (dict["height"] as? NSNumber)?.intValue ?? 0
        self.depth = (dict["depth"] as? NSNumber)?.intValue ?? 1
        self.format = (dict["format"] as? NSNumber)?.intValue ?? 0
        self.mipLevels = (dict["mipLevels"] as? NSNumber)?.intValue ?? 1
        self.arrayLength = (dict["arrayLength"] as? NSNumber)?.intValue ?? 1
    }

    var formatName: String {
        switch format {
        case 70: return "RGBA8"
        case 71: return "RGBA8_sRGB"
        case 80: return "BGRA8"
        case 81: return "BGRA8_sRGB"
        case 115: return "RGBA16F"
        case 125: return "RGBA32F"
        case 252: return "Depth32F"
        case 253: return "Stencil8"
        case 260: return "Depth32F_S8"
        default: return "Format \(format)"
        }
    }
}

struct TexturesView: View {
    @State private var textures: [TextureItem] = []
    @State private var selectedTexture: String?

    private let debugBridge = DebugBridge.shared()

    var body: some View {
        HSplitView {
            // Texture list
            List(selection: $selectedTexture) {
                ForEach(textures) { texture in
                    TextureListRow(texture: texture)
                        .tag(texture.name)
                }
            }
            .frame(minWidth: 250)

            // Texture preview
            if let selected = selectedTexture,
               let texture = debugBridge.getTexture(selected) {
                TexturePreviewView(name: selected, texture: texture)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a texture to preview")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        let dicts = debugBridge.allTextures() as? [[String: Any]] ?? []
        textures = dicts.map { TextureItem(from: $0) }
    }
}

struct TextureListRow: View {
    let texture: TextureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(texture.name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

            HStack {
                Text("\(texture.width)x\(texture.height)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(texture.formatName)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TexturePreviewView: View {
    let name: String
    let texture: MTLTexture

    @State private var mipLevel: Int = 0
    @State private var slice: Int = 0
    @State private var zoom: CGFloat = 1.0
    @State private var showChannelR = true
    @State private var showChannelG = true
    @State private var showChannelB = true
    @State private var showChannelA = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(name)
                    .font(.headline)

                Spacer()

                // Mip level picker
                if texture.mipmapLevelCount > 1 {
                    Picker("Mip", selection: $mipLevel) {
                        ForEach(0..<Int(texture.mipmapLevelCount), id: \.self) { level in
                            Text("Mip \(level)").tag(level)
                        }
                    }
                    .frame(width: 100)
                }

                // Slice picker for arrays
                if texture.arrayLength > 1 {
                    Picker("Slice", selection: $slice) {
                        ForEach(0..<Int(texture.arrayLength), id: \.self) { s in
                            Text("Slice \(s)").tag(s)
                        }
                    }
                    .frame(width: 100)
                }

                Divider().frame(height: 20)

                // Channel toggles
                Toggle("R", isOn: $showChannelR)
                Toggle("G", isOn: $showChannelG)
                Toggle("B", isOn: $showChannelB)
                Toggle("A", isOn: $showChannelA)

                Divider().frame(height: 20)

                // Zoom controls
                Button("-") { zoom = max(0.25, zoom - 0.25) }
                Text("\(Int(zoom * 100))%")
                    .frame(width: 50)
                Button("+") { zoom = min(4.0, zoom + 0.25) }
            }
            .padding()

            Divider()

            // Texture info
            HStack {
                Text("\(texture.width)x\(texture.height)")
                Text("Mips: \(texture.mipmapLevelCount)")
                if texture.arrayLength > 1 {
                    Text("Layers: \(texture.arrayLength)")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 4)

            // Preview
            ScrollView([.horizontal, .vertical]) {
                MetalTexturePreview(
                    texture: texture,
                    mipLevel: mipLevel,
                    slice: slice,
                    zoom: zoom
                )
                .frame(
                    width: CGFloat(max(1, Int(texture.width) >> mipLevel)) * zoom,
                    height: CGFloat(max(1, Int(texture.height) >> mipLevel)) * zoom
                )
            }
            .background(checkerboardPattern())
        }
    }

    private func checkerboardPattern() -> some View {
        Canvas { context, size in
            let squareSize: CGFloat = 10
            let rows = Int(size.height / squareSize) + 1
            let cols = Int(size.width / squareSize) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color(white: 0.2) : Color(white: 0.3))
                    )
                }
            }
        }
    }
}

struct MetalTexturePreview: NSViewRepresentable {
    let texture: MTLTexture
    let mipLevel: Int
    let slice: Int
    let zoom: CGFloat

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = texture.device
        view.delegate = context.coordinator
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.texture = texture
        context.coordinator.mipLevel = mipLevel
        context.coordinator.slice = slice
        view.setNeedsDisplay(view.bounds)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(texture: texture, mipLevel: mipLevel, slice: slice)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var texture: MTLTexture
        var mipLevel: Int
        var slice: Int

        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?

        init(texture: MTLTexture, mipLevel: Int, slice: Int) {
            self.texture = texture
            self.mipLevel = mipLevel
            self.slice = slice
            super.init()

            setupPipeline()
        }

        private func setupPipeline() {
            let device = texture.device
            commandQueue = device.makeCommandQueue()

            // Create simple blit shader inline
            let shaderSource = """
            #include <metal_stdlib>
            using namespace metal;

            struct VertexOut {
                float4 position [[position]];
                float2 texCoord;
            };

            vertex VertexOut vertexShader(uint vid [[vertex_id]]) {
                float2 positions[] = {
                    float2(-1, -1), float2(1, -1), float2(-1, 1),
                    float2(1, -1), float2(1, 1), float2(-1, 1)
                };
                float2 texCoords[] = {
                    float2(0, 1), float2(1, 1), float2(0, 0),
                    float2(1, 1), float2(1, 0), float2(0, 0)
                };

                VertexOut out;
                out.position = float4(positions[vid], 0, 1);
                out.texCoord = texCoords[vid];
                return out;
            }

            fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                          texture2d<float> tex [[texture(0)]]) {
                constexpr sampler s(filter::nearest);
                return tex.sample(s, in.texCoord);
            }
            """

            do {
                let library = try device.makeLibrary(source: shaderSource, options: nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
                descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                print("Failed to create pipeline: \(error)")
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
                  let pipeline = pipelineState else { return }

            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

#Preview {
    DebugView()
        .frame(width: 800, height: 600)
}
