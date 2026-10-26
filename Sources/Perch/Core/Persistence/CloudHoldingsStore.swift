import CloudKit
import Foundation

// Explicit upload/download of a single private snapshot. No credentials or chat are synced.
// Requires the app's signed iCloud entitlement; see docs/RELEASE.md.
struct CloudHoldingsStore {
    private let container = CKContainer.default()
    private let recordID = CKRecord.ID(recordName: "perch-holdings-v1")

    private func database() async throws -> CKDatabase {
        guard try await container.accountStatus() == .available else { throw CloudError.accountUnavailable }
        return container.privateCloudDatabase
    }

    func download() async throws -> [Holding] {
        let db = try await database()
        let record = try await db.record(for: recordID)
        guard let data = record["holdings"] as? Data else { throw HoldingsError.invalid }
        let holdings = try JSONDecoder().decode([Holding].self, from: data)
        try HoldingsStore.validate(holdings)
        return holdings
    }

    func upload(_ holdings: [Holding]) async throws {
        try HoldingsStore.validate(holdings)
        let db = try await database()
        let record: CKRecord
        do { record = try await db.record(for: recordID) }
        catch let error as CKError where error.code == .unknownItem { record = CKRecord(recordType: "PortfolioSnapshot", recordID: recordID) }
        record["holdings"] = try JSONEncoder().encode(holdings) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        // Default save policy is ifServerRecordUnchanged: a concurrent writer yields a conflict.
        _ = try await db.save(record)
    }
}

enum CloudError: LocalizedError {
    case accountUnavailable
    var errorDescription: String? { "Sign in to iCloud and use a signed Perch build with CloudKit enabled." }
}
