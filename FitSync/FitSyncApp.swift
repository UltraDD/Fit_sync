import SwiftUI

@main
struct FitSyncApp: App {
    @State private var workoutState = WorkoutState()
    @State private var homeVM: HomeViewModel?

    var body: some Scene {
        WindowGroup {
            WorkoutHomeView(
                workoutState: workoutState,
                homeVM: homeVM ?? HomeViewModel()
            )
            .preferredColorScheme(.dark)
            .onAppear {
                if homeVM == nil {
                    homeVM = HomeViewModel()
                }
                workoutState.loadDraft()
            }
        }
    }
}
