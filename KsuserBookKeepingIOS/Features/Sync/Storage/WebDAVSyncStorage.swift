import Foundation

struct WebDAVSyncStorage: SyncStorage {
    let serverURL: String
    let authentication: WebDAVAuthentication
    let username: String
    let secret: String

    func listFiles(at path: String) async throws -> [String] {
        try await listEntries(at: path)
            .filter { !$0.isDirectory }
            .map(\.name)
            .sorted()
    }

    func listDirectories(at path: String) async throws -> [String] {
        try await listEntries(at: path)
            .filter { $0.isDirectory }
            .map(\.name)
            .filter { !$0.isEmpty }
            .sorted()
    }

    func readFile(at path: String) async throws -> Data {
        let request = try makeRequest(method: "GET", path: path)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, allowedStatusCodes: [200])
        return data
    }

    func writeFileAtomic(_ data: Data, to path: String) async throws {
        try await ensureParentDirectories(for: path)
        try await cleanupTemporaryFiles(for: path)

        let temporaryPath = "\(path).\(UUID().uuidString).tmp"
        var putRequest = try makeRequest(method: "PUT", path: temporaryPath)
        putRequest.httpBody = data

        do {
            let (_, putResponse) = try await URLSession.shared.data(for: putRequest)
            try validate(response: putResponse, allowedStatusCodes: [200, 201, 204])

            do {
                try await moveFile(from: temporaryPath, to: path)
            } catch {
                try await putFile(data, to: path)
                try? await deleteFile(at: temporaryPath)
            }
        } catch {
            try? await deleteFile(at: temporaryPath)
            throw error
        }
    }

    func moveFile(from sourcePath: String, to destinationPath: String) async throws {
        var request = try makeRequest(method: "MOVE", path: sourcePath)
        request.setValue(try url(for: destinationPath).absoluteString, forHTTPHeaderField: "Destination")
        request.setValue("T", forHTTPHeaderField: "Overwrite")

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, allowedStatusCodes: [200, 201, 204])
    }

    func deleteFile(at path: String) async throws {
        let request = try makeRequest(method: "DELETE", path: path)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, allowedStatusCodes: [200, 202, 204, 404])
    }

    private func listEntries(at path: String) async throws -> [WebDAVEntry] {
        var request = try makeRequest(method: "PROPFIND", path: path)
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.httpBody = Data("""
        <?xml version="1.0" encoding="utf-8" ?>
        <D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/></D:prop></D:propfind>
        """.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, allowedStatusCodes: [207])

        return WebDAVHrefParser.parse(data: data)
            .compactMap { href in
                let trimmedHref = href.trimmingCharacters(in: .whitespacesAndNewlines)
                let isDirectory = trimmedHref.hasSuffix("/")
                guard let name = WebDAVEntry.name(from: trimmedHref) else { return nil }
                guard name != WebDAVEntry.name(from: try? url(for: path).absoluteString) else { return nil }
                return WebDAVEntry(name: name, isDirectory: isDirectory)
            }
    }

    private func ensureParentDirectories(for path: String) async throws {
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 1 else { return }

        var currentPath = ""
        for component in components.dropLast() {
            currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
            var request = try makeRequest(method: "MKCOL", path: currentPath)
            request.httpBody = Data()

            let (_, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, allowedStatusCodes: [200, 201, 204, 405])
        }
    }

    private func putFile(_ data: Data, to path: String) async throws {
        var request = try makeRequest(method: "PUT", path: path)
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, allowedStatusCodes: [200, 201, 204])
    }

    private func cleanupTemporaryFiles(for path: String) async throws {
        let components = path.split(separator: "/").map(String.init)
        guard let fileName = components.last else { return }

        let directory = components.dropLast().joined(separator: "/")
        let files = (try? await listFiles(at: directory)) ?? []
        let temporaryFileNames = files.filter { file in
            file.hasPrefix("\(fileName).") && file.hasSuffix(".tmp")
        }

        for temporaryFileName in temporaryFileNames {
            let temporaryPath = directory.isEmpty ? temporaryFileName : "\(directory)/\(temporaryFileName)"
            try? await deleteFile(at: temporaryPath)
        }
    }

    private func makeRequest(method: String, path: String) throws -> URLRequest {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        switch authentication {
        case .password:
            guard !username.isEmpty, !secret.isEmpty else {
                throw SyncStorageError.webDAVNotConfigured
            }

            let credential = Data("\(username):\(secret)".utf8).base64EncodedString()
            request.setValue("Basic \(credential)", forHTTPHeaderField: "Authorization")
        case .token:
            guard !secret.isEmpty else {
                throw SyncStorageError.webDAVNotConfigured
            }

            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func url(for path: String) throws -> URL {
        guard var baseURL = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SyncStorageError.invalidURL
        }

        if !baseURL.path.hasSuffix("/") {
            baseURL.appendPathComponent("")
        }

        return path
            .split(separator: "/")
            .reduce(baseURL) { partialURL, component in
                partialURL.appendingPathComponent(String(component))
            }
    }

    private func validate(response: URLResponse, allowedStatusCodes: Set<Int>) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncStorageError.invalidURL
        }

        guard allowedStatusCodes.contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw SyncStorageError.fileNotFound
            }

            throw SyncStorageError.unexpectedHTTPStatus(httpResponse.statusCode)
        }
    }
}
