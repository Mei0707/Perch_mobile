# Perch – AI-Powered Finance Tracker

Perch is a modern iOS finance tracking app built with Swift and SwiftUI. It helps users understand their spending, track budgets, view financial trends, and receive AI-powered insights from their transaction history.

The goal of Perch is to demonstrate strong iOS engineering fundamentals, including SwiftUI, MVVM architecture, networking, async programming, caching, local persistence, accessibility, and LLM-powered product features.

---

## Overview

Perch allows users to connect or import financial transaction data, categorize expenses, monitor budgets, and generate personalized spending summaries. The app is designed with a clean, warm, lightweight interface focused on clarity and daily usability.

Core product goals:

- Help users quickly understand where their money goes
- Provide simple financial dashboards without overwhelming users
- Support offline access to recent transactions and insights
- Use AI to explain spending patterns in natural language
- Deliver a smooth and accessible iOS experience

---

## Key Features

### Financial Dashboard

- Monthly spending overview
- Income vs. expense summary
- Category-based spending breakdown
- Recent transaction list
- Budget progress cards
- Lightweight trend indicators

### Transaction Management

- View transaction history
- Search and filter transactions by category, date, or merchant
- Add, edit, and delete manual transactions
- Automatic category assignment using simple rules

### AI-Powered Insights

- LLM-generated monthly spending summaries
- Personalized budget suggestions
- Anomaly detection for unusual spending behavior
- Natural-language explanations such as:
  - “Your dining spending increased by 22% this month.”
  - “You spent more than usual on subscriptions.”
  - “You are on track to stay within your grocery budget.”

### Offline-First Experience

- Recent transactions stored locally using Core Data
- Cached dashboard data for fast app launch
- Offline access to previous financial summaries
- Background sync when network becomes available

### Accessibility

- Dynamic Type support
- VoiceOver-friendly labels
- High-contrast readable UI
- Clear semantic structure for charts, cards, and buttons

---

## Tech Stack

### iOS

- Swift
- SwiftUI
- MVVM Architecture
- Xcode
- Combine / Observation
- Async/Await

### Networking

- URLSession
- REST APIs
- JSON decoding with Codable
- Retry and error handling
- Background data synchronization

### Local Storage & Caching

- Core Data
- UserDefaults for lightweight preferences
- In-memory cache for dashboard data
- Disk-backed persistence for offline access

### AI

- LLM API integration
- Prompt engineering
- Spending summary generation
- Anomaly explanation
- Personalized recommendation generation

---

## Architecture

Perch follows an MVVM-based architecture with clear separation between UI, business logic, networking, persistence, and AI services.

```text
Perch
├── App
│   └── PerchApp.swift
├── Features
│   ├── Dashboard
│   │   ├── DashboardView.swift
│   │   ├── DashboardViewModel.swift
│   │   └── DashboardModels.swift
│   ├── Transactions
│   │   ├── TransactionListView.swift
│   │   ├── TransactionDetailView.swift
│   │   ├── TransactionViewModel.swift
│   │   └── TransactionModels.swift
│   ├── Budgets
│   │   ├── BudgetView.swift
│   │   ├── BudgetViewModel.swift
│   │   └── BudgetModels.swift
│   └── Insights
│       ├── InsightView.swift
│       ├── InsightViewModel.swift
│       └── InsightModels.swift
├── Core
│   ├── Networking
│   │   ├── APIClient.swift
│   │   ├── Endpoint.swift
│   │   └── NetworkError.swift
│   ├── Persistence
│   │   ├── CoreDataManager.swift
│   │   ├── TransactionEntity.swift
│   │   └── CacheManager.swift
│   ├── AI
│   │   ├── AIInsightService.swift
│   │   ├── PromptBuilder.swift
│   │   └── InsightResponseParser.swift
│   └── Utilities
│       ├── DateFormatter+Extensions.swift
│       ├── CurrencyFormatter.swift
│       └── CategoryMapper.swift
└── Resources
    ├── Assets.xcassets
    └── MockData.json
```

---

## System Design

### Data Flow

```text
SwiftUI View
   ↓
ViewModel
   ↓
Repository Layer
   ↓
API Client / Core Data / AI Service
   ↓
Remote API + Local Cache
```

The ViewModel is responsible for preparing UI state. The repository layer decides whether to load data from the network, local cache, or both. This keeps the UI simple and makes the app easier to test.

---

## Core Components

### 1. Dashboard Module

The dashboard provides a high-level financial snapshot.

Responsibilities:

- Fetch monthly transaction summaries
- Calculate category totals
- Display budget progress
- Load cached dashboard data immediately
- Refresh data asynchronously in the background

Example dashboard state:

```swift
struct DashboardState {
    let totalSpending: Decimal
    let totalIncome: Decimal
    let topCategories: [CategorySummary]
    let recentTransactions: [Transaction]
    let monthlyInsight: String?
    let isLoading: Bool
}
```

---

### 2. Networking Layer

The networking layer uses `URLSession` and `async/await` to fetch remote data.

Responsibilities:

- Centralized request building
- JSON decoding
- Error handling
- Retry support
- Authentication token attachment
- Network status-aware sync

Example:

```swift
final class APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try endpoint.makeURLRequest()
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

---

### 3. Persistence Layer

Perch uses Core Data to support offline access and faster app launch.

Responsibilities:

- Store recent transactions
- Cache monthly summaries
- Persist user budget settings
- Support offline reads
- Sync local changes when online

Example entities:

- TransactionEntity
- BudgetEntity
- InsightEntity
- CategoryEntity

---

### 4. Caching Strategy

Perch uses a layered caching strategy:

```text
Memory Cache → Core Data Cache → Remote API
```

Caching goals:

- Show dashboard data instantly on app launch
- Reduce duplicate network calls
- Keep recent transactions available offline
- Refresh stale data in the background

Cache invalidation strategy:

- Dashboard summary: refresh every app launch or after 15 minutes
- Transactions: refresh on pull-to-refresh or background sync
- AI insights: regenerate only when new monthly data changes significantly

---

### 5. AI Insight Service

The AI service converts financial activity into readable insights.

Responsibilities:

- Build structured prompts from transaction summaries
- Call an LLM API securely through a backend proxy
- Parse and validate AI responses
- Cache generated insights locally
- Provide fallback rule-based insights if AI is unavailable

Example AI prompt input:

```json
{
  "month": "April 2026",
  "totalSpending": 2140.50,
  "topCategories": [
    { "name": "Dining", "amount": 420.20 },
    { "name": "Groceries", "amount": 360.10 },
    { "name": "Subscriptions", "amount": 89.99 }
  ],
  "previousMonthSpending": 1890.00
}
```

Example AI output:

```json
{
  "summary": "Your spending increased this month, mostly due to dining and subscriptions.",
  "recommendations": [
    "Review recurring subscriptions.",
    "Set a weekly dining budget.",
    "Track grocery spending against your monthly goal."
  ],
  "riskLevel": "medium"
}
```

---

## API Design

Example REST endpoints:

```text
GET    /transactions
POST   /transactions
PUT    /transactions/{id}
DELETE /transactions/{id}
GET    /summary/monthly
GET    /budgets
POST   /budgets
POST   /insights/generate
```

Example transaction response:

```json
{
  "id": "txn_123",
  "merchant": "Trader Joe's",
  "amount": 54.32,
  "category": "Groceries",
  "date": "2026-04-20T10:30:00Z"
}
```

---

## Async Programming

Perch uses Swift concurrency to keep the UI responsive.

Examples:

- Fetch dashboard data with `async/await`
- Run sync operations in background tasks
- Avoid blocking the main thread during Core Data writes
- Cancel stale requests when users leave a screen

Example:

```swift
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var state: DashboardState

    func loadDashboard() async {
        state = state.loading()
        do {
            let dashboard = try await dashboardRepository.fetchDashboard()
            state = DashboardState.loaded(from: dashboard)
        } catch {
            state = state.failed(error)
        }
    }
}
```

---

## Error Handling

Perch handles common failure cases gracefully:

- No internet connection
- API timeout
- Invalid server response
- AI service unavailable
- Local storage failure
- Empty transaction data

User-facing behavior:

- Show cached data when possible
- Display clear retry options
- Use fallback insights when AI is unavailable
- Avoid crashing on partial failures

---

## Accessibility Design

Accessibility support includes:

- VoiceOver labels for dashboard cards
- Dynamic Type support for all text
- Descriptive chart summaries
- Sufficient color contrast
- Large tappable buttons
- Reduced motion support where applicable

Example:

```swift
Text("Monthly spending: $2,140")
    .accessibilityLabel("Monthly spending is two thousand one hundred forty dollars")
```

---

## Testing Strategy

### Unit Tests

- ViewModel state transitions
- API response decoding
- Category mapping logic
- Budget calculations
- AI response parsing
- Cache expiration logic

### UI Tests

- Dashboard loads successfully
- User can add a transaction
- User can filter transaction history
- Offline mode displays cached data
- Accessibility labels are present

### Mocking

- Mock APIClient for network tests
- Mock Core Data store for persistence tests
- Mock AIInsightService for deterministic AI tests

---

## Security & Privacy

Since Perch handles financial data, privacy is a key design consideration.

Security practices:

- Do not store API keys in the iOS client
- Route LLM requests through a backend proxy
- Avoid sending raw sensitive transaction data when possible
- Use summarized financial data for AI prompts
- Store only necessary data locally
- Support local data deletion


---

## Future Improvements

- Plaid API integration for real bank transaction import
- GraphQL support for flexible dashboard queries
- WidgetKit home screen widgets
- Apple Watch companion app
- Push notifications for budget alerts
- On-device ML for transaction categorization
- More advanced anomaly detection
- Multi-currency support

