import SwiftUI
import OffYetCore

@main
struct OffYetMainApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            StatusBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
