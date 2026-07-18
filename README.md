# FitSync

FitSync is a native iOS workout logger built with SwiftUI. It focuses on a stable in-session experience and optional integrations for HealthKit, Live Activities, and GitHub-based data sync.

## Features

- Record strength and cardio workouts, including sets, weight, reps, RPE, warm-up, cooldown, and notes.
- Save in-progress workouts locally and review workout history.
- Optionally read and write supported HealthKit metrics after permission is granted.
- Show workout timers through WidgetKit and Live Activities.
- Optionally sync structured workout plans and results through the GitHub Contents API.
- Store access tokens in the iOS Keychain rather than in the repository.

## Requirements

- Xcode with the iOS 26.2 SDK or newer.
- An iPhone or simulator supported by that SDK.
- A personal Apple development team selected locally when running on a physical device.

HealthKit and Live Activity behavior should be verified on a physical device. The simulator only covers part of the app flow.

## Getting Started

1. Clone the repository.
2. Open `FitSync.xcodeproj` in Xcode.
3. Select your own development team for the `FitSync` and `FitSyncWidget` targets when device signing is required.
4. Choose the `FitSync` scheme and run the app.

GitHub sync is optional. Configure a repository and token in the app settings; never commit access tokens or exported personal data.

## Project Structure

| Path | Purpose |
|---|---|
| `FitSync/` | Main SwiftUI app, models, services, view models, and views |
| `FitSyncWidget/` | WidgetKit and Live Activity extension |
| `FitSync.xcodeproj/` | Xcode project configuration |
| `REVIEW_LOG.md` | Historical engineering review notes |

## Privacy

FitSync can process workout and health information on the device. Review the permissions and destination repository before enabling sync. Keep any repository that stores personal workout or health records private.

This source repository does not include personal workout records, HealthKit exports, credentials, or access tokens.

## License

FitSync is released under the [MIT License](LICENSE).
