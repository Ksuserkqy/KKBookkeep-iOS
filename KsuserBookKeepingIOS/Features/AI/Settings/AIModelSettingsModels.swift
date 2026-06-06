import Foundation
import SwiftUI

enum AIModelProtocol: String, CaseIterable, Codable, Identifiable {
    case openAIResponses
    case openAICompatible
    case anthropic

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .openAIResponses:
            return "ai.settings.protocol.openAIResponses"
        case .openAICompatible:
            return "ai.settings.protocol.openAICompatible"
        case .anthropic:
            return "ai.settings.protocol.anthropic"
        }
    }
}

struct AIModelConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var endpoint: String
    var apiProtocol: AIModelProtocol
    var selectedModel: String

    static let defaultValue = AIModelConfiguration(
        isEnabled: false,
        endpoint: "",
        apiProtocol: .openAIResponses,
        selectedModel: ""
    )

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case endpoint
        case apiProtocol
        case selectedModel
    }

    init(
        isEnabled: Bool,
        endpoint: String,
        apiProtocol: AIModelProtocol,
        selectedModel: String
    ) {
        self.isEnabled = isEnabled
        self.endpoint = endpoint
        self.apiProtocol = apiProtocol
        self.selectedModel = selectedModel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        selectedModel = try container.decode(String.self, forKey: .selectedModel)

        let rawProtocol = try container.decode(String.self, forKey: .apiProtocol)
        apiProtocol = AIModelProtocol(rawValue: rawProtocol) ?? .openAIResponses
    }
}

struct AIModelSettingsDraft: Equatable {
    var configuration: AIModelConfiguration
    var apiKey: String
}

struct AIModelOption: Identifiable, Equatable {
    let id: String
}
