//
//  GiftlyApp.swift
//  Giftly
//
//  App entry point. Wires the SwiftData model container (with CloudKit),
//  the AppSession (role state), entitlements, and the FM prewarm.
//
//  CloudKit: syncs to the parent's private database in
//  iCloud.com.aramirez.Giftly. Needs the iCloud (CloudKit) capability with
//  that container and Background Modes > Remote notifications. Debug builds
//  push the schema to the Development environment once (CloudSchema); deploy
//  it to Production in the CloudKit Console before TestFlight.
//  Kid wishes are stored in the SAME store here for v1 simplicity; if you
//  want the stricter "kid data never leaves device" posture, give the kid
//  store its OWN non-synced ModelConfiguration — noted in the README.
//

import SwiftUI
import SwiftData

@main
struct GiftlyApp: App {

    @State private var session = AppSession()

    // Shared model container, synced to the parent's private iCloud database.
    let container: ModelContainer = GiftlyApp.makeContainer()

    static let cloudContainerID = "iCloud.com.aramirez.Giftly"

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Person.self, Occasion.self, Wish.self, ProductMatch.self])
        #if DEBUG
        CloudSchema.initializeIfNeeded(schema: schema, containerID: cloudContainerID)
        #endif
        let synced = ModelConfiguration(schema: schema,
                                        isStoredInMemoryOnly: false,
                                        cloudKitDatabase: .private(cloudContainerID))
        do {
            return try ModelContainer(for: schema, configurations: [synced])
        } catch {
            // Never crash a tester over iCloud: fall back to the same store
            // on this phone only. Sync picks up once the problem is fixed.
            print("CloudKit container failed, using local store: \(error)")
            let local = ModelConfiguration(schema: schema,
                                           isStoredInMemoryOnly: false,
                                           cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [local])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(GiftlyTheme.cranberry)
                .environment(session)
                .environment(Entitlements.shared)
                .environment(GiftIntelligence.shared)
                .onAppear {
                    if session.role == .parent { GiftIntelligence.shared.prewarm() }
                }
                .task { await Entitlements.shared.unlockForBetaIfNeeded() }
        }
        .modelContainer(container)
    }
}
