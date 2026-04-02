import SwiftUI
import RightClickHeroKit

struct SettingsView: View {

    @State private var enabledFeatures: Set<ActionType> = SharedDefaults.enabledFeatures

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            MenuItemsSettingsView(enabledFeatures: $enabledFeatures)
        }
        .navigationTitle("RightClickHero")
        .frame(minWidth: 600, minHeight: 440)
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink("Menu Items", value: "menu")
            NavigationLink("Disk Analyzer", value: "disk")
            NavigationLink("Duplicates", value: "dupes")
            NavigationLink("About", value: "about")
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
