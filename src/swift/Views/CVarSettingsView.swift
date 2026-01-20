import SwiftUI
import simd

struct CVarItem: Identifiable {
    let id: String
    let key: String
    let displayName: String
    let type: CVarType
    let minFloat: Float
    let maxFloat: Float
    let minInt: Int32
    let maxInt: Int32
    let options: [String]

    init(from dict: [String: Any]) {
        self.key = dict["key"] as? String ?? UUID().uuidString
        self.id = self.key
        self.displayName = dict["displayName"] as? String ?? self.key
        let typeRaw = dict["type"] as? Int ?? 0
        self.type = CVarType(rawValue: typeRaw) ?? .float
        self.minFloat = dict["min"] as? Float ?? 0
        self.maxFloat = dict["max"] as? Float ?? 1
        self.minInt = dict["min"] as? Int32 ?? 0
        self.maxInt = dict["max"] as? Int32 ?? 100
        self.options = dict["options"] as? [String] ?? []
    }
}

struct CVarSettingsView: View {
    @State private var categories: [String] = []
    @State private var refreshTrigger = false

    private let registry = CVarRegistry.shared()

    var body: some View {
        Group {
            if categories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Settings Available")
                        .font(.headline)
                    Text("CVars will appear here once registered")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Button("Refresh") {
                        refreshData()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(categories, id: \.self) { category in
                        CVarCategorySection(category: category, registry: registry, refreshTrigger: $refreshTrigger)
                    }
                }
            }
        }
        .onAppear {
            refreshData()
        }
        .onChange(of: refreshTrigger) { _, _ in
            refreshData()
        }
    }

    private func refreshData() {
        let allCVars = registry.allCVars() as? [[String: Any]] ?? []
        let allCategories = registry.allCategories() as? [String] ?? []

        print("CVarSettingsView: Refreshing data")
        print("  Total CVars: \(allCVars.count)")
        print("  Categories: \(allCategories)")

        for cvar in allCVars {
            if let key = cvar["key"] as? String,
               let displayName = cvar["displayName"] as? String {
                print("    - \(key): \(displayName)")
            }
        }

        categories = allCategories
    }
}

struct CVarCategorySection: View {
    let category: String
    let registry: CVarRegistry
    @Binding var refreshTrigger: Bool

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            let cvars = (registry.cvars(forCategory: category) as? [[String: Any]] ?? [])
                .map { CVarItem(from: $0) }
            ForEach(cvars) { cvar in
                CVarRow(cvar: cvar, registry: registry, refreshTrigger: $refreshTrigger)
            }
        } label: {
            Text(category)
                .font(.headline)
        }
    }
}

struct CVarRow: View {
    let cvar: CVarItem
    let registry: CVarRegistry
    @Binding var refreshTrigger: Bool

    var body: some View {
        switch cvar.type {
        case .float:
            CVarFloatRow(cvar: cvar, registry: registry)
        case .int:
            CVarIntRow(cvar: cvar, registry: registry)
        case .bool:
            CVarBoolRow(cvar: cvar, registry: registry)
        case .enum:
            CVarEnumRow(cvar: cvar, registry: registry)
        case .color:
            CVarColorRow(cvar: cvar, registry: registry)
        case .vector3:
            CVarVector3Row(cvar: cvar, registry: registry)
        @unknown default:
            Text("Unknown type: \(cvar.displayName)")
        }
    }
}

struct CVarFloatRow: View {
    let cvar: CVarItem
    let registry: CVarRegistry

    @State private var value: Float = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(cvar.displayName)
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: cvar.minFloat...cvar.maxFloat)
                .onChange(of: value) { _, newValue in
                    registry.setFloat(cvar.key, value: newValue)
                }
        }
        .onAppear {
            value = registry.getFloat(cvar.key)
        }
    }
}

struct CVarIntRow: View {
    let cvar: CVarItem
    let registry: CVarRegistry

    @State private var value: Int32 = 0

    var body: some View {
        HStack {
            Text(cvar.displayName)
            Spacer()
            Stepper(value: $value, in: cvar.minInt...cvar.maxInt) {
                Text("\(value)")
                    .monospacedDigit()
            }
            .onChange(of: value) { _, newValue in
                registry.setInt(cvar.key, value: newValue)
            }
        }
        .onAppear {
            value = registry.getInt(cvar.key)
        }
    }
}

struct CVarBoolRow: View {
    let cvar: CVarItem
    let registry: CVarRegistry

    @State private var value: Bool = false

    var body: some View {
        Toggle(cvar.displayName, isOn: $value)
            .onChange(of: value) { _, newValue in
                registry.setBool(cvar.key, value: newValue)
            }
            .onAppear {
                value = registry.getBool(cvar.key)
            }
    }
}

struct CVarEnumRow: View {
    let cvar: CVarItem
    let registry: CVarRegistry

    @State private var value: Int32 = 0

    var body: some View {
        HStack {
            Text(cvar.displayName)
            Spacer()
            Picker("", selection: $value) {
                ForEach(0..<cvar.options.count, id: \.self) { index in
                    Text(cvar.options[index]).tag(Int32(index))
                }
            }
            .pickerStyle(.menu)
            .onChange(of: value) { _, newValue in
                registry.setEnum(cvar.key, value: newValue)
            }
        }
        .onAppear {
            value = registry.getEnum(cvar.key)
        }
    }
}

struct CVarColorRow: View {
    let cvar: CVarItem
    let registry: CVarRegistry

    @State private var color: Color = .white

    var body: some View {
        ColorPicker(cvar.displayName, selection: $color)
            .onChange(of: color) { _, newColor in
                let resolved = newColor.resolve(in: EnvironmentValues())
                let simdColor = simd_float4(
                    Float(resolved.red),
                    Float(resolved.green),
                    Float(resolved.blue),
                    Float(resolved.opacity)
                )
                registry.setColor(cvar.key, value: simdColor)
            }
            .onAppear {
                let simdColor = registry.getColor(cvar.key)
                color = Color(
                    red: Double(simdColor.x),
                    green: Double(simdColor.y),
                    blue: Double(simdColor.z),
                    opacity: Double(simdColor.w)
                )
            }
    }
}

struct CVarVector3Row: View {
    let cvar: CVarItem
    let registry: CVarRegistry

    @State private var x: Float = 0
    @State private var y: Float = 0
    @State private var z: Float = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cvar.displayName)
                .font(.headline)

            VStack(spacing: 4) {
                HStack {
                    Text("X:")
                        .frame(width: 20, alignment: .leading)
                        .foregroundColor(.secondary)
                    Slider(value: $x, in: cvar.minFloat...cvar.maxFloat)
                        .onChange(of: x) { _, _ in updateVector() }
                    Text(String(format: "%.2f", x))
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Y:")
                        .frame(width: 20, alignment: .leading)
                        .foregroundColor(.secondary)
                    Slider(value: $y, in: cvar.minFloat...cvar.maxFloat)
                        .onChange(of: y) { _, _ in updateVector() }
                    Text(String(format: "%.2f", y))
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Z:")
                        .frame(width: 20, alignment: .leading)
                        .foregroundColor(.secondary)
                    Slider(value: $z, in: cvar.minFloat...cvar.maxFloat)
                        .onChange(of: z) { _, _ in updateVector() }
                    Text(String(format: "%.2f", z))
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            let vec = registry.getVector3(cvar.key)
            x = vec.x
            y = vec.y
            z = vec.z
        }
    }

    private func updateVector() {
        registry.setVector3(cvar.key, value: simd_float3(x, y, z))
    }
}

#Preview {
    CVarSettingsView()
}
