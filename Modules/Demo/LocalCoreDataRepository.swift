//
//  LocalCoreDataRepository.swift
//

import Foundation
import CoreData
import SwiftUI

@objc(LocalDemoItem)
final class LocalDemoItem: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var contact: String
    @NSManaged var createdAt: Date
}

// Build a programmatic model via reusable CoreDataStack helpers.
private extension LocalCoreDataRepository {
    nonisolated static func makeModel() -> NSManagedObjectModel {
        let id = CoreDataModelBuilder.attribute(name: "id", type: .UUIDAttributeType, isOptional: false, isIndexed: true)
        let name = CoreDataModelBuilder.attribute(name: "name", type: .stringAttributeType)
        let contact = CoreDataModelBuilder.attribute(name: "contact", type: .stringAttributeType)
        let createdAt = CoreDataModelBuilder.attribute(name: "createdAt", type: .dateAttributeType)
        let entity = CoreDataModelBuilder.entity(name: "LocalDemoItem", managedObjectClass: LocalDemoItem.self, attributes: [id, name, contact, createdAt])
        return CoreDataModelBuilder.model(entities: [entity])
    }
}

/// Reusable example repository that demonstrates CRUD with CoreDataStack.
/// Replace the `LocalDemoItem` entity with your own to adapt for other use cases.
@MainActor
final class LocalCoreDataRepository: ObservableObject {
    struct Item: Identifiable, Equatable { let id: UUID; var name: String; var contact: String; var createdAt: Date }

    @Published private(set) var items: [Item] = []
    private let stack: CoreDataStack
    private var context: NSManagedObjectContext { stack.viewContext }

    init(stack: CoreDataStack = CoreDataStack(name: "LocalDemo", model: LocalCoreDataRepository.makeModel())) {
        self.stack = stack
        refresh()
    }

    func add(name: String, contact: String) {
        let obj = LocalDemoItem(context: context)
        obj.id = UUID()
        obj.name = name
        obj.contact = contact
        obj.createdAt = Date()
        stack.save(context)
        refresh()
    }

    func delete(at offsets: IndexSet) {
        let current = items
        for index in offsets {
            let id = current[index].id
            if let obj = fetchObject(id: id) {
                context.delete(obj)
            }
        }
        stack.save(context)
        refresh()
    }

    private func refresh() {
        let request = NSFetchRequest<LocalDemoItem>(entityName: "LocalDemoItem")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let result = try context.fetch(request)
            self.items = result.map { Item(id: $0.id, name: $0.name, contact: $0.contact, createdAt: $0.createdAt) }
        } catch {
            self.items = []
        }
    }

    private func fetchObject(id: UUID) -> LocalDemoItem? {
        let request = NSFetchRequest<LocalDemoItem>(entityName: "LocalDemoItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

}
