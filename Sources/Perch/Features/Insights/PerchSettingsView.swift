import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct HoldingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var holdings: [Holding]
    init(holdings: [Holding]) { self.holdings = holdings }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw HoldingsError.invalid }
        holdings = try JSONDecoder().decode([Holding].self, from: data)
        try HoldingsStore.validate(holdings)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(holdings))
    }
}

struct PerchSettingsView: View {
    let repository: MarketRepositoryProtocol
    @Environment(\.dismiss) private var dismiss
    @State private var backendURL = AppSettings.baseURL?.absoluteString ?? ""
    @State private var token = AppSettings.backendToken ?? ""
    @State private var message: String?
    @State private var exporting = false
    @State private var importing = false
    @State private var document = HoldingsDocument(holdings: [])
    @State private var pendingHoldings: [Holding]?
    @State private var busy = false
    @State private var remindersEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Market data & AI") {
                    TextField("Backend URL (HTTPS)", text: $backendURL).disableAutocorrection(true)
                    SecureField("Personal backend token", text: $token)
                    Text("Use localhost for the simulator or your HTTPS backend on a device. Saving enables quote requests and automatic portfolio explanations. Provider API keys belong only on the server. An empty URL enables labeled demo prices.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Save connection") {
                        do { try AppSettings.saveBackend(url: backendURL, token: token); message = "Connection saved. Refresh the dashboard or ask a question." }
                        catch { message = error.localizedDescription }
                    }
                }
                Section("Holdings backup") {
                    Button("Export holdings as JSON") { run { document = HoldingsDocument(holdings: try await repository.loadHoldings()); exporting = true } }
                    Button("Import holdings…") { importing = true }
                    Text("Holdings are stored durably on this device. Imports replace the local portfolio after you review them. Quotes and chat are not included.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Private iCloud snapshot") {
                    if Bundle.main.object(forInfoDictionaryKey: "PerchCloudSyncEnabled") as? Bool == true {
                        Button("Upload holdings to iCloud") { run { let holdings = try await repository.loadHoldings(); try await CloudHoldingsStore().upload(holdings); message = "Private iCloud snapshot updated." } }
                        Button("Download iCloud holdings…") { run { pendingHoldings = try await CloudHoldingsStore().download() } }
                        Text("Manual sync of holdings only. Upload replaces the private cloud snapshot. Download shows a preview before replacing this device's holdings. Concurrent changes report a conflict; retry after reviewing your data.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Available in signed builds configured with the Perch iCloud container. Local export and import work without iCloud.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Portfolio reminder") {
                    Toggle("Daily reminder at 4:15 PM local time", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { enabled in run { try await setReminder(enabled) } }
                    Text("A local reminder to review your portfolio. It does not monitor live prices or send trading alerts.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("Ask Perch sends holdings, watchlist symbols, and recent chat to your backend and AI provider. Server analytics store latency, data coverage, tool names, and helpfulness ratings. They do not store holdings, prompts, or chat. Responses API storage is disabled. Provider retention policies still apply.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message { Section { Text(message).font(.callout) } }
                if busy { ProgressView() }
            }
            .disabled(busy)
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Perch-holdings") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 65_536 else { throw HoldingsError.invalid }
                    let holdings = try JSONDecoder().decode([Holding].self, from: Data(contentsOf: url))
                    try HoldingsStore.validate(holdings)
                    pendingHoldings = holdings
                } catch { message = error.localizedDescription }
            }
            .sheet(isPresented: Binding(get: { pendingHoldings != nil }, set: { if !$0 { pendingHoldings = nil } })) {
                NavigationStack {
                    List {
                        Text("This replaces all local holdings with the following \(pendingHoldings?.count ?? 0) positions.")
                        ForEach(pendingHoldings ?? []) { holding in
                            LabeledContent(holding.ticker, value: "\(holding.shares) shares")
                        }
                        Button("Replace local holdings", role: .destructive) {
                            let holdings = pendingHoldings ?? []
                            run { try await repository.replaceHoldings(holdings); pendingHoldings = nil; message = "Holdings restored." }
                        }.disabled(busy)
                    }
                    .navigationTitle("Review holdings")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { pendingHoldings = nil } } }
                }
            }
            .task {
                let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                remindersEnabled = pending.contains { $0.identifier == "perch.daily-review" }
            }
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        busy = true
        Task {
            defer { busy = false }
            do { try await operation() } catch { message = error.localizedDescription }
        }
    }

    private func setReminder(_ enabled: Bool) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["perch.daily-review"])
        guard enabled else { return }
        guard try await center.requestAuthorization(options: [.alert, .sound]) else {
            remindersEnabled = false
            message = "Enable notifications for Perch in system settings to use reminders."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Time to check in with Perch"
        content.body = "Review your holdings and ask about portfolio movement."
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 16, minute: 15), repeats: true)
        try await center.add(UNNotificationRequest(identifier: "perch.daily-review", content: content, trigger: trigger))
    }
}
