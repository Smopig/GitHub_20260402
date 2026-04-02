import SwiftUI
import RightClickHeroKit

/// Disk space analyzer — shows top-level directory sizes as a bar chart.
struct DiskAnalyzerView: View {

    @State private var entries: [DiskEntry] = []
    @State private var isScanning = false
    @State private var rootURL: URL?
    @State private var totalSize: Int64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Disk Analyzer")
                    .font(.title2.bold())
                Spacer()
                Button("Choose Folder…") { chooseFolder() }
                if isScanning {
                    ProgressView().scaleEffect(0.7)
                }
            }

            if let root = rootURL {
                Text(root.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if entries.isEmpty && !isScanning {
                ContentUnavailableView(
                    "No Folder Selected",
                    systemImage: "internaldrive",
                    description: Text("Choose a folder to analyze its disk usage.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(entries.prefix(50)) { entry in
                            DiskEntryRow(entry: entry, total: totalSize)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .navigationTitle("Disk Analyzer")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Analyze"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        rootURL = url
        scan(url: url)
    }

    private func scan(url: URL) {
        isScanning = true
        entries = []
        Task {
            let scanner = DiskScanner()
            let result = try? await scanner.topLevel(root: url, limit: 50)
            await MainActor.run {
                entries = result ?? []
                totalSize = entries.reduce(0) { $0 + $1.size }
                isScanning = false
            }
        }
    }
}

// MARK: - Row

private struct DiskEntryRow: View {
    let entry: DiskEntry
    let total: Int64

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(entry.size) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                Text(entry.url.lastPathComponent)
                    .lineLimit(1)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", fraction * 100))
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: geo.size.width * fraction, height: 6)
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DiskAnalyzerView()
        .frame(width: 520, height: 500)
}
