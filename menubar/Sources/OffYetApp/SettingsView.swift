import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    let onBack: () -> Void

    var body: some View {
        Text("设置")
    }
}
