//
//  CloudSchema.swift
//  Giftly
//
//  Debug only. Pushes the SwiftData model's record types to the CloudKit
//  Development environment so they can be deployed to Production in the
//  CloudKit Console (TestFlight and App Store builds use Production).
//  Opt in: add the launch argument -initCloudKitSchema to the Run scheme
//  (Product > Scheme > Edit Scheme > Run > Arguments). It blocks launch for
//  up to 30 seconds while it talks to iCloud, so it never runs otherwise.
//  Runs once per schema version; bump `version` after changing a @Model.
//

#if DEBUG
import CoreData
import SwiftData

enum CloudSchema {
    static let version = "2"   // 2: Person.favoriteCharacters, Person.devices
    private static let doneKey = "giftly_cloudkit_schema_version"

    static func initializeIfNeeded(schema: Schema, containerID: String) {
        guard ProcessInfo.processInfo.arguments.contains("-initCloudKitSchema") else { return }
        guard UserDefaults.standard.string(forKey: doneKey) != version else {
            print("CloudKit schema already initialized (version \(version)). Bump CloudSchema.version to run again.")
            return
        }
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: schema) else { return }
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .private(containerID))
        do {
            try autoreleasepool {
                let description = NSPersistentStoreDescription(url: config.url)
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
                description.shouldAddStoreAsynchronously = false
                let container = NSPersistentCloudKitContainer(name: "Giftly", managedObjectModel: model)
                container.persistentStoreDescriptions = [description]
                var loadError: Error?
                container.loadPersistentStores { _, error in loadError = error }
                if let loadError { throw loadError }
                // Always detach the temporary store, success or failure, so it
                // never mirrors alongside the app's real container.
                defer {
                    for store in container.persistentStoreCoordinator.persistentStores {
                        try? container.persistentStoreCoordinator.remove(store)
                    }
                }
                try container.initializeCloudKitSchema()
            }
            UserDefaults.standard.set(version, forKey: doneKey)
            print("CloudKit schema initialized (version \(version))")
        } catch {
            // Usually: not signed in to iCloud on this device, or the
            // container isn't set up yet. Try again next launch.
            print("CloudKit schema init skipped: \(error)")
        }
    }
}
#endif
