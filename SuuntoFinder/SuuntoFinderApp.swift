import SwiftUI

@main
struct SuuntoFinderApp: App {
    @StateObject private var finder = FinderModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("--location-audit") && !ProcessInfo.processInfo.arguments.contains("--normal-ui") {
                    LocationAuditMap(controller: finder.lastPlace).onAppear { finder.start() }
                } else { ContentView(model: finder) }
            }
                .background(SystemLocationMapProbe(controller: finder.lastPlace)
                    .allowsHitTesting(false))
                .onAppear {
                    if !ProcessInfo.processInfo.arguments.contains("--location-audit") {
                        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("locationAudit.") {
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                    }
                    if ProcessInfo.processInfo.arguments.contains("--normal-ui") { finder.start() }
                }
                .onChange(of: scenePhase) { phase in finder.setForeground(phase == .active) }
        }
    }
}
