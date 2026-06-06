import Foundation

struct ICloudDriveSyncStorage: SyncStorage {
    let rootURL: URL
    let fileManager: FileManager

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func listFiles(at path: String) async throws -> [String] {
        try listEntries(at: path)
            .filter { !$0.isDirectory }
            .map(\.name)
            .sorted()
    }

    func listDirectories(at path: String) async throws -> [String] {
        try listEntries(at: path)
            .filter { $0.isDirectory }
            .map(\.name)
            .filter { !$0.isEmpty }
            .sorted()
    }

    func readFile(at path: String) async throws -> Data {
        let fileURL = url(for: path)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw SyncStorageError.fileNotFound
        }

        try await startDownloadingIfNeeded(fileURL)
        return try Data(contentsOf: fileURL)
    }

    func writeFileAtomic(_ data: Data, to path: String) async throws {
        let destinationURL = url(for: path)
        try ensureParentDirectories(for: destinationURL)
        try cleanupTemporaryFiles(for: destinationURL)

        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")

        do {
            try data.write(to: temporaryURL, options: [.atomic, .completeFileProtection])
            try replaceItem(at: destinationURL, withItemAt: temporaryURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    func moveFile(from sourcePath: String, to destinationPath: String) async throws {
        let sourceURL = url(for: sourcePath)
        let destinationURL = url(for: destinationPath)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw SyncStorageError.fileNotFound
        }

        try ensureParentDirectories(for: destinationURL)
        try replaceItem(at: destinationURL, withItemAt: sourceURL)
    }

    func deleteFile(at path: String) async throws {
        let fileURL = url(for: path)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func listEntries(at path: String) throws -> [LocalSyncFileEntry] {
        let directoryURL = url(for: path)
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            throw SyncStorageError.fileNotFound
        }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey]
        return try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )
        .compactMap { entryURL in
            let resourceValues = try entryURL.resourceValues(forKeys: resourceKeys)
            guard let name = resourceValues.name, !name.isEmpty else { return nil }
            return LocalSyncFileEntry(name: name, isDirectory: resourceValues.isDirectory == true)
        }
    }

    private func url(for path: String) -> URL {
        normalizedPath(path)
            .split(separator: "/")
            .reduce(rootURL) { partialURL, component in
                partialURL.appendingPathComponent(String(component))
            }
    }

    private func normalizedPath(_ path: String) -> String {
        let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalized == "KKBookKeep" {
            return ""
        }

        if normalized.hasPrefix("KKBookKeep/") {
            return String(normalized.dropFirst("KKBookKeep/".count))
        }

        return normalized
    }

    private func ensureParentDirectories(for fileURL: URL) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func cleanupTemporaryFiles(for destinationURL: URL) throws {
        let directoryURL = destinationURL.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }

        let fileName = destinationURL.lastPathComponent
        let entries = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.nameKey],
            options: [.skipsHiddenFiles]
        )

        for entry in entries {
            let entryName = entry.lastPathComponent
            if entryName.hasPrefix("\(fileName)."), entryName.hasSuffix(".tmp") {
                try? fileManager.removeItem(at: entry)
            }
        }
    }

    private func replaceItem(at destinationURL: URL, withItemAt sourceURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    private func startDownloadingIfNeeded(_ fileURL: URL) async throws {
        var resourceValues = try fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if resourceValues.ubiquitousItemDownloadingStatus == .notDownloaded {
            try fileManager.startDownloadingUbiquitousItem(at: fileURL)
        }

        for _ in 0..<20 {
            resourceValues = try fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if resourceValues.ubiquitousItemDownloadingStatus != .notDownloaded {
                return
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
}

private struct LocalSyncFileEntry {
    var name: String
    var isDirectory: Bool
}
