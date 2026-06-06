import Combine
import Foundation

@MainActor
final class AIModelSettingsStore: ObservableObject {
    @Published private(set) var configuration: AIModelConfiguration

    private let defaults: UserDefaults
    private let credentialStore = AIModelCredentialStore()

    private enum DefaultsKey {
        static let configuration = "ai.model.configuration"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: DefaultsKey.configuration),
            let stored = try? Self.decoder.decode(AIModelConfiguration.self, from: data)
        {
            self.configuration = stored
        } else {
            self.configuration = .defaultValue
        }
    }

    func makeDraft() -> AIModelSettingsDraft {
        AIModelSettingsDraft(
            configuration: configuration,
            apiKey: credentialStore.readAPIKey()
        )
    }

    func save(_ draft: AIModelSettingsDraft) throws {
        let oldAPIKey = credentialStore.readAPIKey()

        do {
            try credentialStore.saveAPIKey(draft.apiKey)
        } catch {
            try? credentialStore.saveAPIKey(oldAPIKey)
            throw error
        }

        let normalizedConfiguration = AIModelConfiguration(
            isEnabled: draft.configuration.isEnabled,
            endpoint: draft.configuration.endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiProtocol: draft.configuration.apiProtocol,
            selectedModel: draft.configuration.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let data = try Self.encoder.encode(normalizedConfiguration)
        defaults.set(data, forKey: DefaultsKey.configuration)
        configuration = normalizedConfiguration
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}
