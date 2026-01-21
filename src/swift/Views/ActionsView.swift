import SwiftUI

struct ActionItem: Identifiable {
    let id: String
    let key: String
    let displayName: String
    let category: String
    let shortcutHint: String?

    init(from dict: [String: Any]) {
        self.key = dict["key"] as? String ?? UUID().uuidString
        self.id = self.key
        self.displayName = dict["displayName"] as? String ?? self.key
        self.category = dict["category"] as? String ?? ""
        self.shortcutHint = dict["shortcutHint"] as? String
    }
}

struct ActionsView: View {
    @State private var categories: [String] = []

    private let actionsBridge = ActionsBridge.shared()

    var body: some View {
        List {
            ForEach(categories, id: \.self) { category in
                ActionsCategorySection(category: category, actionsBridge: actionsBridge)
            }
        }
        .onAppear {
            refreshCategories()
        }
    }

    private func refreshCategories() {
        categories = actionsBridge.allCategories()
    }
}

struct ActionsCategorySection: View {
    let category: String
    let actionsBridge: ActionsBridge

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            let actions = (actionsBridge.actions(forCategory: category) as? [[String: Any]] ?? [])
                .map { ActionItem(from: $0) }
            ForEach(actions) { action in
                ActionRow(action: action, actionsBridge: actionsBridge)
            }
        } label: {
            HStack {
                Image(systemName: categoryIcon(for: category))
                    .foregroundColor(.accentColor)
                Text(category)
                    .font(.headline)
            }
        }
    }

    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "rendering":
            return "paintbrush"
        case "debug":
            return "ladybug"
        case "camera":
            return "camera"
        case "capture":
            return "record.circle"
        case "shaders":
            return "chevron.left.forwardslash.chevron.right"
        case "scene":
            return "cube"
        default:
            return "gear"
        }
    }
}

struct ActionRow: View {
    let action: ActionItem
    let actionsBridge: ActionsBridge

    var body: some View {
        Button(action: {
            actionsBridge.triggerAction(action.key)
        }) {
            HStack {
                Text(action.displayName)
                    .foregroundColor(.primary)

                Spacer()

                if let shortcut = action.shortcutHint {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

// Compact toolbar version for quick access
struct ActionsToolbar: View {
    private let actionsBridge = ActionsBridge.shared()

    var body: some View {
        HStack(spacing: 8) {
            let allActions = (actionsBridge.allActions() as? [[String: Any]] ?? [])
                .map { ActionItem(from: $0) }

            ForEach(allActions.prefix(6)) { action in
                ActionToolbarButton(action: action, actionsBridge: actionsBridge)
            }

            if allActions.count > 6 {
                Menu {
                    ForEach(allActions.dropFirst(6)) { action in
                        Button(action.displayName) {
                            actionsBridge.triggerAction(action.key)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct ActionToolbarButton: View {
    let action: ActionItem
    let actionsBridge: ActionsBridge

    var body: some View {
        Button(action: {
            actionsBridge.triggerAction(action.key)
        }) {
            Text(action.displayName)
                .lineLimit(1)
        }
        .help(action.displayName)
    }
}
