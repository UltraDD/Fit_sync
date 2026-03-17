import SwiftUI
import HealthKit

@main
struct FitSyncApp: App {
    @State private var workoutState = WorkoutState()
    @State private var syncVM = SyncViewModel()
    @State private var homeVM: HomeViewModel?

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("训练", systemImage: "dumbbell") {
                    if let homeVM {
                        WorkoutHomeView(workoutState: workoutState, homeVM: homeVM)
                    }
                }
                Tab("健康", systemImage: "heart.text.square") {
                    HealthSyncView(syncVM: syncVM)
                }
                Tab("设置", systemImage: "gearshape") {
                    SettingsView()
                }
            }
            .onAppear {
                if homeVM == nil {
                    homeVM = HomeViewModel(syncViewModel: syncVM)
                }
                workoutState.loadDraft()
                requestHealthKit()
            }
        }
    }

    private func requestHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        Task {
            try? await HealthKitService().requestAuthorization()
        }
    }
}
