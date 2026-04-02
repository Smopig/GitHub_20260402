import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Converts image files between JPEG, PNG, WEBP, and HEIC formats.
public enum ImageConverter {

    public enum ConversionError: LocalizedError {
        case loadFailed(URL)
        case destinationCreationFailed
        case finalizationFailed
        case unsupportedFormat(ImageFormat)

        public var errorDescription: String? {
            switch self {
            case .loadFailed(let url): return "Cannot load image at \(url.lastPathComponent)"
            case .destinationCreationFailed: return "Cannot create image destination"
            case .finalizationFailed: return "Failed to write image"
            case .unsupportedFormat(let f): return "Unsupported format: \(f.rawValue)"
            }
        }
    }

    /// Converts an image file to the target format.
    /// Returns the URL of the newly created file.
    public static func convert(
        source: URL,
        to format: ImageFormat,
        quality: Double = 0.85
    ) throws -> URL {
        guard let cgImage = loadCGImage(from: source) else {
            throw ConversionError.loadFailed(source)
        }

        let outputURL = outputURL(for: source, format: format)
        let utType = utType(for: format)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.destinationCreationFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.finalizationFailed
        }

        return outputURL
    }

    /// Batch conversion using Swift concurrency.
    public static func convertBatch(
        sources: [URL],
        to format: ImageFormat,
        quality: Double = 0.85
    ) async throws -> [URL] {
        try await withThrowingTaskGroup(of: URL.self) { group in
            for url in sources {
                group.addTask {
                    try convert(source: url, to: format, quality: quality)
                }
            }
            var results: [URL] = []
            for try await url in group {
                results.append(url)
            }
            return results
        }
    }

    // MARK: - Private helpers

    private static func loadCGImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func outputURL(for source: URL, format: ImageFormat) -> URL {
        let ext: String
        switch format {
        case .jpeg: ext = "jpg"
        case .png:  ext = "png"
        case .webp: ext = "webp"
        case .heic: ext = "heic"
        }
        return source.deletingPathExtension().appendingPathExtension(ext)
    }

    private static func utType(for format: ImageFormat) -> UTType {
        switch format {
        case .jpeg: return .jpeg
        case .png:  return .png
        case .webp: return .webP
        case .heic: return .heic
        }
    }
}
