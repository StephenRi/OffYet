import SwiftUI
import OffYetCore

struct PanelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Text("OffYet").padding(20).frame(width: 360)
    }
}
