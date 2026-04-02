import Foundation

/// Manages built-in file templates for the "New File" feature.
public enum FileTemplateManager {

    public struct Template: Identifiable {
        public let id: String          // e.g. "md"
        public let displayName: String // e.g. "Markdown"
        public let fileExtension: String
        public let icon: String        // SF Symbol name

        public init(id: String, displayName: String, fileExtension: String, icon: String) {
            self.id = id
            self.displayName = displayName
            self.fileExtension = fileExtension
            self.icon = icon
        }
    }

    public static let allTemplates: [Template] = [
        Template(id: "txt",   displayName: "Plain Text",  fileExtension: "txt",   icon: "doc.text"),
        Template(id: "md",    displayName: "Markdown",    fileExtension: "md",    icon: "doc.richtext"),
        Template(id: "swift", displayName: "Swift",       fileExtension: "swift", icon: "swift"),
        Template(id: "py",    displayName: "Python",      fileExtension: "py",    icon: "doc.plaintext"),
        Template(id: "sh",    displayName: "Shell",       fileExtension: "sh",    icon: "terminal"),
        Template(id: "json",  displayName: "JSON",        fileExtension: "json",  icon: "curlybraces"),
        Template(id: "xml",   displayName: "XML",         fileExtension: "xml",   icon: "chevron.left.forwardslash.chevron.right"),
        Template(id: "html",  displayName: "HTML",        fileExtension: "html",  icon: "globe"),
        Template(id: "css",   displayName: "CSS",         fileExtension: "css",   icon: "paintbrush"),
        Template(id: "docx",  displayName: "Word",        fileExtension: "docx",  icon: "doc.fill"),
        Template(id: "xlsx",  displayName: "Excel",       fileExtension: "xlsx",  icon: "tablecells"),
        Template(id: "pptx",  displayName: "PowerPoint",  fileExtension: "pptx",  icon: "rectangle.on.rectangle"),
    ]

    /// Creates a new file from a template in the given directory.
    /// Returns the URL of the created file.
    public static func createFile(
        template: Template,
        in directory: URL,
        fileName: String? = nil
    ) throws -> URL {
        let name = fileName ?? "Untitled"
        let destURL = uniqueURL(
            directory: directory,
            name: name,
            ext: template.fileExtension
        )

        let content = templateContent(for: template.id)
        try content.write(to: destURL, atomically: true, encoding: .utf8)
        return destURL
    }

    // MARK: - Private

    private static func uniqueURL(directory: URL, name: String, ext: String) -> URL {
        let base = directory.appendingPathComponent("\(name).\(ext)")
        if !FileManager.default.fileExists(atPath: base.path) { return base }

        var counter = 2
        while true {
            let candidate = directory.appendingPathComponent("\(name) \(counter).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
    }

    private static func templateContent(for id: String) -> String {
        switch id {
        case "md":
            return "# Untitled\n\n"
        case "html":
            return """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <title>Untitled</title>
            </head>
            <body>

            </body>
            </html>
            """
        case "py":
            return "#!/usr/bin/env python3\n\n"
        case "sh":
            return "#!/bin/bash\n\n"
        case "json":
            return "{\n\n}\n"
        case "xml":
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n\n</root>\n"
        case "swift":
            return "import Foundation\n\n"
        default:
            return ""
        }
    }
}
