//
//  CoreDataManager.swift
//  FFCoreData
//
//  Created by Florian Friedrich on 10/06/15.
//  Copyright © 2015 Florian Friedrich. All rights reserved.
//

import Foundation
import CoreData

private class CoreDataManager {
    private lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = self.configuration.bundle.URLForResource(self.configuration.modelName, withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    
    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.configuration.storeURL
        do {
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options)
        } catch {
            do {
                try self.clearDataStore()
            } catch {
                print("Failed to delete data store")
            }
            do {
                try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
            }
            catch {
                fatalError("Could not add persistent store with error: \(error)")
            }
        }
        return coordinator
        }()

    private lazy var backgroundSavingContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        let ctx = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        ctx.persistentStoreCoordinator = coordinator
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()
    
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let parentContext = self.backgroundSavingContext
        let ctx = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        ctx.parentContext = parentContext
        return ctx
    }()
    
    private let configuration: CoreDataStack.Configuration
    
    init(configuration: CoreDataStack.Configuration) {
        self.configuration = configuration
    }
    
    private func createTemporaryMainContext() -> NSManagedObjectContext {
        return createTemporaryContextWithConcurrencyType(.MainQueueConcurrencyType)
    }
    
    private func createTemporaryBackgroundContext() -> NSManagedObjectContext {
        return createTemporaryContextWithConcurrencyType(.PrivateQueueConcurrencyType)
    }
    
    private func createTemporaryContextWithConcurrencyType(type: NSManagedObjectContextConcurrencyType) -> NSManagedObjectContext {
        let parentContext = managedObjectContext
        let tempCtx = NSManagedObjectContext(concurrencyType: type)
        tempCtx.parentContext = parentContext
        tempCtx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        tempCtx.undoManager = nil
        return tempCtx
    }
    
    private func clearDataStore() throws {
        try NSFileManager.defaultManager().removeItemAtURL(configuration.storeURL)
    }
    
    private func saveContext(ctx: NSManagedObjectContext) {
        if !ctx.hasChanges { return }
        do {
            try ctx.save()
            switch ctx {
            case managedObjectContext:
                print("Main NSManagedObjectContext saved successfully!")
            case backgroundSavingContext:
                print("Background NSManagedObjectContext saved successfully!")
            default:
                print("NSManagedObjectContext \(ctx) saved successfully!")
            }
        } catch {
            print("Unresolved error while saving NSManagedObjectContext \(error)")
        }
        if let parentContext = ctx.parentContext {
            parentContext.performBlock { self.saveContext(parentContext) }
        }
    }
}

public struct CoreDataStack {
    public struct Configuration {
        private static let InfoDictionarySQLiteNameKey = "FFCDDataManagerSQLiteName"
        private static let InfoDictionaryModelNameKey = "FFCDDataManagerModelName"
        private static let LegacyConfiguration: Configuration = {
            let bundle = NSBundle.mainBundle()
            var modelName: String? = nil
            var sqliteName: String? = nil
            if let infoDict = bundle.infoDictionary {
                modelName = infoDict[Configuration.InfoDictionaryModelNameKey] as? String
                sqliteName = infoDict[Configuration.InfoDictionarySQLiteNameKey] as? String
            }
            return Configuration(bundle: bundle, modelName: modelName, sqliteName: sqliteName)
        }()
        
        public let bundle: NSBundle
        public let modelName: String
        public let sqliteName: String
        
        private let storeURL: NSURL
        private let applicationDataDirectory: NSURL = {
            let fileManager = NSFileManager.defaultManager()
            let dataFolderURL: NSURL
            #if os(iOS)
            dataFolderURL = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last!
            #elseif os(OSX)
            let url = fileManager.URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask).last!
            dataFolderURL = url.URLByAppendingPathComponent(NSApp.identifier)
            var isDir = false
            let exists = fileManager.fileExistsAtPath(dataFolderURL.path!, isDirectory: &isDir)
            if !exists || (exists && !isDir) {
                do {
                    try fileManager.createDirectoryAtURL(dataFolderURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Could not create application support folder: \(error)")
                }
            }
            #endif
            return dataFolderURL
        }()
        
        private static let InfoDictionaryTargetDisplayNameKey = "CFBundleDisplayName"
        private static let InfoDictionaryTargetNameKey = String(kCFBundleNameKey)
        private static let DefaultTargetName = "UNKNOWN_TARGET_NAME"
        public init(bundle: NSBundle, modelName: String? = nil, sqliteName: String? = nil) {
            func targetName(bundle: NSBundle) -> String {
                let infoDict = bundle.infoDictionary!
                let name = infoDict[Configuration.InfoDictionaryTargetDisplayNameKey] ?? infoDict[Configuration.InfoDictionaryTargetNameKey]
                return (name as? String) ?? Configuration.DefaultTargetName
            }
            self.bundle = bundle
            self.modelName = modelName ?? targetName(bundle)
            self.sqliteName = sqliteName ?? targetName(bundle)
            self.storeURL = applicationDataDirectory.URLByAppendingPathComponent(self.sqliteName + ".sqlite")
        }
    }
    
    public static  var configuration = Configuration.LegacyConfiguration
    private static let Manager = CoreDataManager(configuration: CoreDataStack.configuration)
    
    public static let MainContext: NSManagedObjectContext = CoreDataStack.Manager.managedObjectContext
    
    public static func saveMainContext() { CoreDataStack.saveContext(CoreDataStack.MainContext) }
    
    public static func saveContext(context: NSManagedObjectContext) {
        context.performBlockAndWait { CoreDataStack.Manager.saveContext(context) }
    }
    
    public static func createTemporaryMainContext() -> NSManagedObjectContext {
        return CoreDataStack.Manager.createTemporaryMainContext()
    }
    
    public static func createTemporaryBackgroundContext() -> NSManagedObjectContext {
        return CoreDataStack.Manager.createTemporaryBackgroundContext()
    }
    
    public static func clearDataStore() throws { try CoreDataStack.Manager.clearDataStore() }
}
