import SwiftUI

@main
struct MacFixApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .frame(minWidth: 660, minHeight: 540)
        }
    }
}
