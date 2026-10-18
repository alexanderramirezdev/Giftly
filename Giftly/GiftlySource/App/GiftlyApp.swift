//
//  GiftlyApp.swift
//  Giftly
//
//  App entry point. Wires the SwiftData model container (with CloudKit),
//  the AppSession (role state), entitlements, and the FM prewarm.
//
//  CloudKit note: the ModelConfiguration below uses the default automatic
//  CloudKit sync. For that to work you must, in the real Xcode project:
//    • add the iCloud capability with CloudKit + a container
//    • add the "Background Modes → Remote notifications" capability
//    • make sure every @Model obeys the CloudKit rules (see Models.swift)
//  Kid wishes are stored in the SAME store here for v1 simplicity; if you
//  want the stricter "kid data never leaves device" posture, give the kid
//  store its OWN non-synced ModelConfiguration — noted in the README.
//

import SwiftUI
import SwiftData

@main
struct GiftlyApp: App {

    @State private var session = AppSession()

    // Shared model container with CloudKit sync.
    let container: ModelContainer = {
        let schema = Schema([Person.self, Occasion.self, Wish.self, ProductMatch.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic           // flip to .none to disable sync while testing
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A CloudKit misconfiguration is the #1 launch crash here. Fail
            // loudly in dev; in production you'd fall back to a local store.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Workshop.brass)
                .environment(session)
                .environment(Entitlements.shared)
                .environment(GiftIntelligence.shared)
                .onAppear {
                    if session.role == .parent { GiftIntelligence.shared.prewarm() }
                }
        }
        .modelContainer(container)
    }
}
