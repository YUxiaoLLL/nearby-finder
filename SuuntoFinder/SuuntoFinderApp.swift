import SwiftUI

@main
struct SuuntoFinderApp: App {
    @StateObject private var finder = FinderModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ContentView(model: finder)
                .onChange(of: scenePhase) { phase in finder.setForeground(phase == .active) }
        }
    }
}
