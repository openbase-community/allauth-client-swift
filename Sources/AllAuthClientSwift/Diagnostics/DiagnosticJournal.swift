import Foundation

/// Optional bounded diagnostic persistence. Writes run off the caller's thread.
/// If persistence fails, AuthDiagnostics' in-memory buffer remains available.
public final class DiagnosticJournal: @unchecked Sendable {
    private let queue = DispatchQueue(label: "openbase.diagnostic-journal")
    private let url: URL
    private let maximumBytes: Int
    private var failure: String?

    public init(url: URL, maximumBytes: Int = 16 * 1024 * 1024) {
        precondition(maximumBytes > 0)
        self.url = url
        self.maximumBytes = maximumBytes
    }

    public func append(_ data: Data) {
        queue.async { [self] in
            guard failure == nil else { return }
            do {
                guard data.count + 1 <= maximumBytes else {
                    throw CocoaError(.fileWriteOutOfSpace)
                }
                let manager = FileManager.default
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let size = manager.fileExists(atPath: url.path)
                    ? (try manager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
                    : 0
                if size + data.count + 1 > maximumBytes {
                    let previous = url.appendingPathExtension("previous")
                    if manager.fileExists(atPath: previous.path) { try manager.removeItem(at: previous) }
                    try manager.moveItem(at: url, to: previous)
                }
                if !manager.fileExists(atPath: url.path) {
                    try Data().write(to: url)
                }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data + Data([10]))
            } catch {
                // Stop persistence after failure; the normal memory buffer is the fallback.
                failure = "\(type(of: error)): \((error as NSError).code)"
            }
        }
    }

    /// Wait for queued writes and return a failure that collectors must report.
    public func flush() -> String? { queue.sync { failure } }
}
