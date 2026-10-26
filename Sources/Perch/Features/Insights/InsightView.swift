import SwiftUI

struct InsightView: View {
    @StateObject private var viewModel: InsightViewModel
    @State private var showingSettings = false
    private let repository: MarketRepositoryProtocol
    @State private var confirmingClear = false

    init(repository: MarketRepositoryProtocol) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: InsightViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            welcome
                            ForEach(viewModel.turns) { turn in
                                message(turn)
                            }
                            if viewModel.isGenerating {
                                HStack { ProgressView(); Text(viewModel.status).font(.caption).foregroundStyle(.perchMuted) }
                            }
                            if let error = viewModel.errorMessage {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(error).font(.callout).foregroundStyle(.red)
                                    if viewModel.canRetry { Button("Retry last question") { viewModel.retry() } }
                                }
                                .perchCard()
                            }
                            Color.clear.frame(height: 1).id("latest")
                        }
                        .padding(20)
                    }
                    .onChange(of: viewModel.turns.last?.content) { _ in proxy.scrollTo("latest", anchor: .bottom) }
                }
                composer
            }
            .background(.perchBackground)
            .navigationTitle("Ask Perch")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button { confirmingClear = true } label: { Image(systemName: "trash") }
                            .accessibilityLabel("Clear conversation").disabled(viewModel.isGenerating)
                        Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Settings").disabled(viewModel.isGenerating)
                    }
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: { Task { await viewModel.refreshContext() } }) {
                PerchSettingsView(repository: repository)
            }
            .confirmationDialog("Delete this conversation from this device?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Delete conversation", role: .destructive) { viewModel.clear() }
            }
            .task { await viewModel.refreshContext() }
            .onDisappear { viewModel.stop() }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your portfolio, explained", systemImage: "sparkles").font(.headline).foregroundStyle(.perchAccent)
            Text("Ask about daily movement, diversification, or an illustrative sale. Perch calculates the numbers and uses sourced quotes to explain them.")
                .font(.subheadline).foregroundStyle(.perchMuted)
            Text("Sending shares your holdings, watchlist, and recent conversation with your configured backend and its AI provider. Chat history is saved on this device. Clear it with the trash button.")
                .font(.caption).foregroundStyle(.perchMuted)
            if !viewModel.isBackendConfigured {
                Text("Start by connecting your backend in Settings. Add your holdings in Portfolio, then return here to ask a question.")
                    .font(.subheadline).foregroundStyle(.perchText)
                Button("Connect backend") { showingSettings = true }
            } else if viewModel.holdingTickers.isEmpty {
                Text("Add your first holding in the Portfolio tab for personalized answers.")
                    .font(.subheadline).foregroundStyle(.perchMuted)
            }
            if viewModel.turns.isEmpty && viewModel.isBackendConfigured {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button(suggestion) { viewModel.send(suggestion) }
                        .font(.subheadline).multilineTextAlignment(.leading).disabled(viewModel.isGenerating)
                }
            }
        }
        .perchCard()
    }

    private func message(_ turn: ConversationTurn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(turn.role == "user" ? "You" : "Perch", systemImage: turn.role == "user" ? "person.crop.circle" : "sparkles")
                .font(.caption.weight(.bold)).foregroundStyle(.perchAccent)
            if let answer = turn.answer { Text(answer.title).font(.headline) }
            Text(turn.content.isEmpty ? "Checking portfolio data…" : turn.content)
                .font(.body).textSelection(.enabled)
            if !turn.isComplete { Text(viewModel.isGenerating ? "Draft · not yet validated" : "Unfinished response").font(.caption).foregroundStyle(.secondary) }
            if let answer = turn.answer {
                Text(answer.statusLabel).font(.caption.weight(.semibold)).foregroundStyle(.perchAccent)
                ForEach(answer.facts.filter { answer.factIDs.contains($0.id) }) { fact in
                    HStack(alignment: .top) {
                        Text(fact.label).foregroundStyle(.perchMuted)
                        Spacer()
                        Text(fact.display).monospacedDigit().bold()
                    }.font(.caption)
                }
                ForEach(Array(answer.sources.enumerated()), id: \.offset) { _, source in
                    Text("\(source.ticker) · \(source.source) · \(source.freshness) · \(source.asOf.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.perchMuted)
                }
                ForEach(answer.limitations, id: \.self) { Text($0).font(.caption).foregroundStyle(.perchMuted) }
                HStack {
                    Button { Task { await viewModel.rate(turn, rating: "helpful") } } label: { Label("Helpful", systemImage: "hand.thumbsup") }
                    Button { Task { await viewModel.rate(turn, rating: "unhelpful") } } label: { Label("Not helpful", systemImage: "hand.thumbsdown") }
                }
                .font(.caption).disabled(turn.rating != nil || viewModel.feedbackInFlight.contains(turn.id))
                if turn.rating != nil { Text("Feedback saved").font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .perchCard()
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask about your portfolio", text: $viewModel.input, axis: .vertical)
                .lineLimit(1...5).onSubmit { viewModel.send() }.disabled(viewModel.isGenerating || !viewModel.isBackendConfigured)
                .accessibilityLabel("Message to Ask Perch")
            if viewModel.isGenerating {
                Button("Stop") { viewModel.stop() }
            } else {
                Button { viewModel.send() } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                    .disabled(!viewModel.isBackendConfigured || viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.input.count > 1600)
                    .accessibilityLabel("Send message")
            }
        }
        .padding(16).background(.regularMaterial)
        .overlay(alignment: .topTrailing) {
            if viewModel.input.count > 1400 {
                Text("\(viewModel.input.count)/1600").font(.caption2)
                    .foregroundStyle(viewModel.input.count > 1600 ? Color.red : PerchPalette.muted)
                    .padding(.horizontal, 16).offset(y: -16)
            }
        }
    }
}
