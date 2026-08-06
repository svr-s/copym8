import SwiftUI
import KeyboardShortcuts

struct TestView: View {
    var body: some View {
        KeyboardShortcuts.Recorder("Test", name: .toggleApp) { shortcut in
            print(shortcut)
        }
    }
}
