import Foundation

struct AIModelListService {
    func fetchModels(configuration: AIModelConfiguration, apiKey: String) async throws -> [AIModelOption] {
        let url = try modelListURL(for: configuration)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !apiKey.isEmpty {
            switch configuration.apiProtocol {
            case .openAIResponses, .openAICompatible:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .anthropic:
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)

        let modelIds = try Self.parseModelIds(from: data)
        guard !modelIds.isEmpty else {
            throw AIModelSettingsError.emptyModelList
        }

        return modelIds
            .map { AIModelOption(id: $0) }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    private func modelListURL(for configuration: AIModelConfiguration) throws -> URL {
        guard var components = URLComponents(string: configuration.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme != nil,
              components.host != nil
        else {
            throw AIModelSettingsError.invalidEndpoint
        }

        switch configuration.apiProtocol {
        case .openAIResponses, .openAICompatible:
            if !components.path.hasSuffix("/models") {
                components.path = normalizedPath(components.path, appending: "models")
            }
        case .anthropic:
            if components.path.hasSuffix("/v1/models") {
                break
            } else if components.path.hasSuffix("/v1") {
                components.path = normalizedPath(components.path, appending: "models")
            } else {
                components.path = normalizedPath(components.path, appending: "v1/models")
            }
        }

        guard let url = components.url else {
            throw AIModelSettingsError.invalidEndpoint
        }

        return url
    }

    private func normalizedPath(_ path: String, appending component: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.isEmpty {
            return "/\(component)"
        }

        return "/\(trimmedPath)/\(component)"
    }

    private static func parseModelIds(from data: Data) throws -> [String] {
        let object = try JSONSerialization.jsonObject(with: data)
        var ids = Set<String>()

        collectModelIds(from: object, into: &ids)
        return Array(ids)
    }

    private static func collectModelIds(from object: Any, into ids: inout Set<String>) {
        if let dictionary = object as? [String: Any] {
            if let id = dictionary["id"] as? String, !id.isEmpty {
                ids.insert(id)
            }

            if let name = dictionary["name"] as? String, !name.isEmpty {
                ids.insert(name)
            }

            for key in ["data", "models"] {
                if let nested = dictionary[key] {
                    collectModelIds(from: nested, into: &ids)
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                collectModelIds(from: item, into: &ids)
            }
        }
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIModelSettingsError.invalidEndpoint
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIModelSettingsError.invalidEndpoint
        }
    }
}
