//
//  CoreDataStack.swift
//
//  Lightweight, reusable Core Data utilities for programmatic models.
//  Use this stack to define your own entities and repositories without .xcdatamodel files.
//

import Foundation
import CoreData

public final class CoreDataStack {
    public let container: NSPersistentContainer

    public init(name: String, model: NSManagedObjectModel, inMemory: Bool = false) {
        container = NSPersistentContainer(name: name, managedObjectModel: model)
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error {
                #if DEBUG
                print("CoreDataStack: load error -> \(error)")
                #endif
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    public var viewContext: NSManagedObjectContext { container.viewContext }
    public func newBackgroundContext() -> NSManagedObjectContext { container.newBackgroundContext() }

    public func save(_ context: NSManagedObjectContext? = nil) {
        let ctx = context ?? container.viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() } catch {
            #if DEBUG
            print("CoreDataStack: save error -> \(error)")
            #endif
        }
    }
}

public enum CoreDataModelBuilder {
    public static func model(entities: [NSEntityDescription]) -> NSManagedObjectModel {
        let m = NSManagedObjectModel()
        m.entities = entities
        return m
    }

    public static func entity(name: String,
                              managedObjectClass: AnyClass,
                              attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = name
        e.managedObjectClassName = NSStringFromClass(managedObjectClass)
        e.properties = attributes
        return e
    }

    public static func attribute(name: String,
                                 type: NSAttributeType,
                                 isOptional: Bool = false,
                                 isIndexed: Bool = false) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = isOptional
        a.isIndexed = isIndexed
        return a
    }
}

