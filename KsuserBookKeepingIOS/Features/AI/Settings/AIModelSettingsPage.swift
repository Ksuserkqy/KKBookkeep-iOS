import SwiftUI

struct AIModelSettingsPage: View {
    @EnvironmentObject private var settingsStore: AIModelSettingsStore

    @State private var isEnabled = false
    @State private var endpoint = ""
    @State private var apiProtocol = AIModelProtocol.openAIResponses
    @State private var apiKey = ""
    @State private var selectedModel = ""
    @State private var fetchedModels: [AIModelOption] = []
    @State private var messageKey: String?
    @State private var isFetchingModels = false
    @State private var isSaving = false
    @State private var hasLoadedDraft = false

    private let modelListService = AIModelListService()

    var body: some View {
        Form {
            if let messageKey {
                Section {
                    Label {
                        Text(LocalizedStringKey(messageKey))
                    } icon: {
                        Image(systemName: isErrorMessage(messageKey) ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    }
                    .foregroundStyle(isErrorMessage(messageKey) ? .red : .green)
                }
            }

            Section {
                Toggle("ai.settings.enabled", isOn: $isEnabled)
                    .tint(.accentColor)

                Picker("ai.settings.protocol", selection: $apiProtocol) {
                    ForEach(AIModelProtocol.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }

                TextField("ai.settings.endpoint.placeholder", text: $endpoint)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("ai.settings.apiKey.placeholder", text: $apiKey)
                    .textContentType(.password)
            } header: {
                Text("ai.settings.section.connection")
            } footer: {
                Text("ai.settings.connection.footer")
            }

            Section {
                TextField("ai.settings.model.placeholder", text: $selectedModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        await fetchModels()
                    }
                } label: {
                    HStack {
                        Text("ai.settings.fetchModels")
                        Spacer()
                        if isFetchingModels {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                .disabled(isFetchingModels || endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !fetchedModels.isEmpty {
                    ForEach(fetchedModels) { model in
                        Button {
                            selectedModel = model.id
                        } label: {
                            HStack {
                                Text(model.id)
                                Spacer()
                                if selectedModel == model.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("ai.settings.section.model")
            } footer: {
                Text("ai.settings.model.footer")
            }
        }
        .navigationTitle(Text("ai.settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveSettings()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("common.save")
                    }
                }
                .disabled(isSaving)
            }
        }
        .task {
            loadDraftIfNeeded()
        }
    }

    private var draftConfiguration: AIModelConfiguration {
        AIModelConfiguration(
            isEnabled: isEnabled,
            endpoint: endpoint,
            apiProtocol: apiProtocol,
            selectedModel: selectedModel
        )
    }

    private func loadDraftIfNeeded() {
        guard !hasLoadedDraft else { return }
        hasLoadedDraft = true

        let draft = settingsStore.makeDraft()
        isEnabled = draft.configuration.isEnabled
        endpoint = draft.configuration.endpoint
        apiProtocol = draft.configuration.apiProtocol
        selectedModel = draft.configuration.selectedModel
        apiKey = draft.apiKey
    }

    private func saveSettings() {
        isSaving = true
        defer { isSaving = false }

        do {
            try settingsStore.save(
                AIModelSettingsDraft(
                    configuration: draftConfiguration,
                    apiKey: apiKey
                )
            )
            messageKey = "ai.settings.saved"
        } catch {
            messageKey = "ai.settings.error.saveFailed"
        }
    }

    private func fetchModels() async {
        isFetchingModels = true
        messageKey = nil
        defer { isFetchingModels = false }

        do {
            fetchedModels = try await modelListService.fetchModels(
                configuration: draftConfiguration,
                apiKey: apiKey
            )
            messageKey = "ai.settings.fetchModels.succeeded"
        } catch AIModelSettingsError.invalidEndpoint {
            fetchedModels = []
            messageKey = "ai.settings.error.invalidEndpoint"
        } catch AIModelSettingsError.emptyModelList {
            fetchedModels = []
            messageKey = "ai.settings.error.emptyModelList"
        } catch {
            fetchedModels = []
            messageKey = "ai.settings.error.fetchModelsFailed"
        }
    }

    private func isErrorMessage(_ key: String) -> Bool {
        key.contains(".error.")
    }
}
