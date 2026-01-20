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
        List {
            ForEach(categories, id: \.self) { category in
                CVarCategorySection(category: category, registry: registry, refreshTrigger: $refreshTrigger)
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
        categories = registry.allCategories() as? [String] ?? []
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

#Preview {
    CVarSettingsView()
}
