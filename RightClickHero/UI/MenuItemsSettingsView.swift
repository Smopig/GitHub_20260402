import SwiftUI
import RightClickHeroKit

/// Settings panel for toggling which features appear in the right-click menu.
struct MenuItemsSettingsView: View {

    @Binding var enabledFeatures: Set<ActionType>

    private struct FeatureRow: Identifiable {
        let id: ActionType
        let title: String
        let subtitle: String
        let icon: String
    }

    private let rows: [FeatureRow] = [
        FeatureRow(id: .newFile,         title: "New File",          subtitle: "Create a new file with template",          icon: "doc.badge.plus"),
        FeatureRow(id: .cutMark,         title: "Cut",               subtitle: "Mark files for moving",                    icon: "scissors"),
        FeatureRow(id: .paste,           title: "Paste",             subtitle: "Complete cut operation",                   icon: "doc.on.clipboard"),
        FeatureRow(id: .copyPath,        title: "Copy Path",         subtitle: "Copy the full file path",                  icon: "link"),
        FeatureRow(id: .convertImage,    title: "Convert Image",     subtitle: "Convert between JPG, PNG, WebP, HEIC",     icon: "photo"),
        FeatureRow(id: .airDrop,         title: "AirDrop",           subtitle: "Share via AirDrop",                        icon: "antenna.radiowaves.left.and.right"),
        FeatureRow(id: .hideFile,        title: "Hide / Show File",  subtitle: "Toggle hidden attribute",                  icon: "eye.slash"),
        FeatureRow(id: .permanentDelete, title: "Delete Permanently",subtitle: "Delete without Trash",                     icon: "trash.slash"),
        FeatureRow(id: .compress,        title: "Compress",          subtitle: "Create ZIP archive",                       icon: "archivebox"),
        FeatureRow(id: .moveToFolder,    title: "Move to Folder",    subtitle: "Move files to another location",           icon: "folder"),
        FeatureRow(id: .copyToFolder,    title: "Copy to Folder",    subtitle: "Copy files to another location",           icon: "folder.badge.plus"),
        FeatureRow(id: .openWith,        title: "Open With",         subtitle: "Choose which app to open with",            icon: "app.badge"),
    ]

    var body: some View {
        List {
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    Image(systemName: row.icon)
                        .frame(width: 24)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .fontWeight(.medium)
                        Text(row.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { enabledFeatures.contains(row.id) },
                        set: { on in
                            if on { enabledFeatures.insert(row.id) }
                            else  { enabledFeatures.remove(row.id) }
                            SharedDefaults.enabledFeatures = enabledFeatures
                        }
                    ))
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Menu Items")
    }
}

#Preview {
    MenuItemsSettingsView(enabledFeatures: .constant(Set(ActionType.allCases)))
        .frame(width: 420, height: 500)
}
