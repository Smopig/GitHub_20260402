import SwiftUI
import RightClickHeroKit

/// Finds and displays duplicate files in a chosen directory.
struct DuplicateFinderView: View {

    @State private var groups: [DuplicateDetector.DuplicateGroup] = []
    @State private var isScanning = false
    @State private var scanProgress: (Int, Int) = (0, 0)
    @State private var selectedForDeletion: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Duplicate Files")
                    .font(.title2.bold())
                Spacer()
                if !selectedForDeletion.isEmpty {
                    Button("Delete Selected (\(selectedForDeletion.count))") {
                        deleteSelected()
                    }
                    .foregroundStyle(.red)
                }
                Button("Choose Folder…") { chooseFolder() }
                if isScanning {
                    ProgressView(
                        value: Double(scanProgress.0),
                        total: max(1, Double(scanProgress.1))
                    )
                    .frame(width: 80)
                }
            }

            if groups.isEmpty && !isScanning {
                ContentUnavailableView(
                    "No Duplicates Found",
                    systemImage: "doc.on.doc",
                    description: Text("Choose a folder to scan for duplicate files.")
                )
            } else {
                let totalWasted = groups.reduce(0) { $0 + $1.wastedBytes }
                Text("Wasted space: \(ByteCountFormatter.string(fromByteCount: totalWasted, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(groups) { group in
                    Section {
                        ForEach(group.files, id: \.self) { url in
                            HStack {
                                Image(systemName: selectedForDeletion.contains(url)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedForDeletion.contains(url) ? .red : .secondary)
                                    .onTapGesture { toggleSelection(url) }
                                Text(url.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                        }
                    } header: {
                        Text("\(group.files.count) copies · \(ByteCountFormatter.string(fromByteCount: group.wastedBytes, countStyle: .file)) wasted")
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Duplicates")
    }

    // MARK: - Actions

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Scan"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        scan(url: url)
    }

    private func scan(url: URL) {
        isScanning = true
        groups = []
        scanProgress = (0, 0)
        Task {
            let detector = DuplicateDetector()
            let result = try? await detector.findDuplicates(in: url) { done, total in
                Task { @MainActor in scanProgress = (done, total) }
            }
            await MainActor.run {
                groups = result ?? []
                isScanning = false
            }
        }
    }

    private func toggleSelection(_ url: URL) {
        if selectedForDeletion.contains(url) {
            selectedForDeletion.remove(url)
        } else {
            selectedForDeletion.insert(url)
        }
    }

    private func deleteSelected() {
        for url in selectedForDeletion {
            try? FileManager.default.removeItem(at: url)
        }
        groups = groups.compactMap { group in
            let remaining = group.files.filter { !selectedForDeletion.contains($0) }
            guard remaining.count > 1 else { return nil }
            return DuplicateDetector.DuplicateGroup(hash: group.hash, files: remaining)
        }
        selectedForDeletion = []
    }
}

#Preview {
    DuplicateFinderView()
        .frame(width: 520, height: 500)
}
