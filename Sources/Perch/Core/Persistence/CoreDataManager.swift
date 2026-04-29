import CoreData
import Foundation

final class CoreDataManager {
    static let shared = CoreDataManager()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = NSManagedObjectModel()
        let stock = NSEntityDescription()
        stock.name = "StockEntity"
        stock.managedObjectClassName = "NSManagedObject"
        stock.properties = [
            Self.attribute("ticker", .stringAttributeType),
            Self.attribute("name", .stringAttributeType),
            Self.attribute("exchange", .stringAttributeType),
            Self.attribute("sector", .stringAttributeType),
            Self.attribute("price", .decimalAttributeType),
            Self.attribute("change", .decimalAttributeType),
            Self.attribute("changePercent", .doubleAttributeType),
            Self.attribute("updatedAt", .dateAttributeType)
        ]
        model.entities = [stock]

        container = NSPersistentContainer(name: "Perch", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data store failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = false
        return attribute
    }
}
