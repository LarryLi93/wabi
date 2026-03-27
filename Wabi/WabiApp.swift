import SwiftUI
import SwiftData

@main
struct WabiApp: App {
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var authManager = AuthSessionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(localizationManager)
                .environment(\.locale, localizationManager.locale)
        }
        .modelContainer(for: Note.self)
    }
}
