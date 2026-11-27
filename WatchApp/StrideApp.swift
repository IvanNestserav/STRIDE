import SwiftUI
@main struct StrideApp: App {
    @StateObject private var workout = WorkoutManager()
    var body: some Scene { WindowGroup { ContentView().environmentObject(workout) } }
}
