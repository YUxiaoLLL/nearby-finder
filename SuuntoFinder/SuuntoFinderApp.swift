import SwiftUI

@main
struct SuuntoFinderApp: App {
    @AppStorage(AppLanguage.preferenceKey) private var languageRaw = AppLanguage.selected.rawValue
    @StateObject private var finder = FinderModel()
    @Environment(\.scenePhase) private var scenePhase
    init() {
        // Explicit developer launch option for on-device language verification.
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--app-language"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1),
           let language = AppLanguage(rawValue: ProcessInfo.processInfo.arguments[index + 1]) {
            AppLanguage.selected = language
        }
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("--location-audit") && !ProcessInfo.processInfo.arguments.contains("--normal-ui") {
                    LocationAuditMap(controller: finder.lastPlace).onAppear { finder.start() }
                } else { ContentView(model: finder) }
            }
                .environment(\.locale, (AppLanguage(rawValue: languageRaw) ?? AppLanguage.selected).locale)
                .id(languageRaw)
                .background(SystemLocationMapProbe(controller: finder.lastPlace)
                    .allowsHitTesting(false))
                .onAppear {
                    if !ProcessInfo.processInfo.arguments.contains("--location-audit") {
                        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("locationAudit.") {
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                    }
                    if ProcessInfo.processInfo.arguments.contains("--normal-ui") && !finder.running { finder.start() }
                }
                .onChange(of: scenePhase) { phase in finder.setForeground(phase == .active) }
        }
    }
}
