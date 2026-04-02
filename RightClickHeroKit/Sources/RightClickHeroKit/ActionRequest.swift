import Foundation

// MARK: - Action Types

public enum ActionType: String, Codable, CaseIterable {
    case newFile
    case cutMark
    case paste
    case copyPath
    case convertImage
    case airDrop
    case hideFile
    case showFile
    case permanentDelete
    case compress
    case compressEncrypted
    case moveToFolder
    case copyToFolder
    case openWith
    case uninstallApp
    case analyzeSpace
    case findDuplicates
    case screenshot
    case screenRecordStart
    case screenRecordStop
}

// MARK: - Image Conversion Target

public enum ImageFormat: String, Codable {
    case jpeg
    case png
    case webp
    case heic
}

// MARK: - Request / Response

public struct ActionRequest: Codable {
    /// The operation to perform.
    public let type: ActionType

    /// Security-scoped bookmark data (base64-encoded) for each selected file.
    public let bookmarks: [Data]

    /// Optional destination directory bookmark (for move/copy/newFile).
    public let destinationBookmark: Data?

    /// Flexible key-value parameters (e.g. "format": "png", "template": "md").
    public let parameters: [String: String]

    public init(
        type: ActionType,
        bookmarks: [Data] = [],
        destinationBookmark: Data? = nil,
        parameters: [String: String] = [:]
    ) {
        self.type = type
        self.bookmarks = bookmarks
        self.destinationBookmark = destinationBookmark
        self.parameters = parameters
    }
}

public struct ActionResult: Codable {
    public let success: Bool
    public let message: String?

    /// Returned URLs (e.g. converted file paths) as bookmark data.
    public let resultBookmarks: [Data]

    public init(success: Bool, message: String? = nil, resultBookmarks: [Data] = []) {
        self.success = success
        self.message = message
        self.resultBookmarks = resultBookmarks
    }

    public static func ok(_ message: String? = nil, bookmarks: [Data] = []) -> ActionResult {
        ActionResult(success: true, message: message, resultBookmarks: bookmarks)
    }

    public static func failure(_ message: String) -> ActionResult {
        ActionResult(success: false, message: message)
    }
}

// MARK: - Codable helpers for XPC transport

public extension ActionRequest {
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
    static func decoded(from data: Data) throws -> ActionRequest {
        try JSONDecoder().decode(ActionRequest.self, from: data)
    }
}

public extension ActionResult {
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
    static func decoded(from data: Data) throws -> ActionResult {
        try JSONDecoder().decode(ActionResult.self, from: data)
    }
}
