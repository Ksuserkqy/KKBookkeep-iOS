import Foundation

protocol SyncStorage {
    func listFiles(at path: String) async throws -> [String]
    func listDirectories(at path: String) async throws -> [String]
    func readFile(at path: String) async throws -> Data
    func writeFileAtomic(_ data: Data, to path: String) async throws
    func moveFile(from sourcePath: String, to destinationPath: String) async throws
    func deleteFile(at path: String) async throws
}

enum SyncStorageError: Error {
    case invalidURL
    case fileNotFound
    case providerUnavailable
    case webDAVNotConfigured
    case unexpectedHTTPStatus(Int)
}
