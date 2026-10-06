<div align="center">
  <img src="tool/icon_master.png" alt="Gear Tracker mint gear mark" width="96" height="96">
  <h1>Gear Tracker</h1>
  <p><strong>Know what your vehicle needs—before it needs it.</strong></p>
  <p>A focused vehicle-care dashboard. Your mileage, service intervals, and tire health—in one clear view.</p>
  <p><a href="#what-works-today">Features</a> · <a href="#run-locally">Run locally</a> · <a href="#roadmap">Roadmap</a></p>
</div>

---

## Less guesswork. A clearer next service.

Maintenance is easier to plan when you can see how much of an interval is left. Gear Tracker turns a manually entered odometer reading into a visual maintenance overview: health bars drain as kilometers accumulate, status labels highlight approaching service intervals, and each tire has its own record.

Built with Flutter, the interface pairs deep navy surfaces with mint accents and a tactile, six-wheel odometer. The working core is local: no account or backend is required.

> **Work in progress.** The dashboard and editors are implemented; several navigation destinations and actions are placeholders. This is a development project, not a production-ready maintenance record or diagnostic tool.

## What works today

| Capability | Current implementation |
| --- | --- |
| **A hands-on odometer** | Six directly scrollable digit wheels, with carry/borrow between digits and debounced auto-save. Maintenance cards recalculate from the saved KM reading. |
| **Mileage-based service health** | Remaining kilometers, health bars, and status labels calculated from the installation reading and configured interval. The initial service is Engine Oil. |
| **Four-position tire tracking** | Individual FL, FR, BL, and BR mileage-health indicators in one card, with a header reflecting the worst tire status. |
| **Editable service details** | Double-tap a service card and choose **Edit** to change its name, note, installation date, and interval. Service installation KM is not editable yet. |
| **Editable tire records** | Double-tap an individual tire to change its installation date, installation KM, and lifespan interval. |
| **On-device storage** | Odometer, service configuration, and tire records are serialized as a JSON snapshot through `shared_preferences`. No cloud sync is implemented. |

### Reading the dashboard

Health bars start full and drain toward empty. The used percentage is calculated from distance since installation divided by the configured interval, clamped to 0–100% and rounded to a whole percentage for status selection.

| Rounded interval used | Status |
| --- | --- |
| Below 50% | Excellent |
| 50–74% | Good |
| 75–89% | Warning |
| 90–99% | Replace soon |
| 100% | Replace now |

These are **mileage-based estimates**, not measured component condition. Installation dates are recorded but do not currently drive warnings. Use manufacturer guidance and physical inspections when deciding what maintenance is needed.

## Try the current flow

1. Open the dashboard. A fresh installation starts with **74,850 KM**, an Engine Oil entry, and four tire records from [`lib/data/data.dart`](lib/data/data.dart)—starter data, not readings from your vehicle.
2. Scroll an odometer digit. After editing settles, the dashboard waits two seconds before saving the staged reading and refreshing maintenance values.
3. Double-tap **Engine Oil → Edit** to adjust its details, or double-tap a tire position to edit that tire.

**Current limits:** History and Services tabs are placeholder screens. **Update** only displays a message; it does not record a replacement. The header `+` and vehicle selector also display coming-soon messages. There is no add/delete-service flow, backup import/export, multi-vehicle management, or localization yet; the UI is English and uses kilometers.

Local storage is not a backup. History is not maintained by the dashboard, and storage recovery/schema migration still need hardening. Avoid using this development build as your only maintenance record. Odometer interaction and save-feedback behavior also remain under investigation.

## Run locally

### Prerequisites

- Flutter with Dart **3.13.4 or a compatible newer 3.x SDK** (`pubspec.yaml` requires `^3.13.4`). The checks below used **Flutter 3.47.5 / Dart 3.13.4**.
- For Android: the Flutter Android toolchain, Android SDK Platform **37** (the configured compile SDK), and a compatible JDK supporting Java 17.
- For iOS: macOS, Xcode, and the platform tooling required by Flutter and its plugins. iOS has not been verified in this documentation pass.

```sh
git clone https://github.com/Juma1988/Gear-Tracker.git
cd Gear-Tracker
flutter doctor
flutter pub get
flutter devices
flutter run -d <device-id>
```

Replace `<device-id>` with an Android device/emulator or, on macOS, an iOS target listed by `flutter devices`. If you already have the source locally, start from `flutter doctor` in the project root.

### Platform status

| Platform | Evidence and limitations |
| --- | --- |
| Android | Project configuration is present. An earlier developer checkpoint recorded a debug APK build and launch on a Samsung SM S908E. No device launch or build was repeated for this README. |
| iOS | Project configuration and app assets are present. No iOS build or runtime verification is claimed. |
| Web / desktop | No platform runner directories are included; support is not claimed. |

Android release configuration currently uses debug signing. It is not ready for store distribution.

## Under the hood

- **UI:** Flutter, Dart, Material 3, and reusable service-health cards.
- **State:** Local widget state with staged/saved odometer values and editor results returned through Navigator.
- **Rules:** Service and tire models calculate mileage health, remaining distance, and status.
- **Persistence:** `GarageRepository` stores the active JSON snapshot using `shared_preferences`.
- **Checks:** `flutter_test` and `flutter_lints`.

`path_provider`, `share_plus`, `file_picker`, and `receive_sharing_intent` are also declared dependencies. Their presence does **not** mean backup or sharing flows are implemented.

```text
lib/
  data/       Starter records and local snapshot repository
  models/     Service, tire, odometer, and history data types
  screens/    Dashboard, editors, and placeholder destinations
  widgets/    Odometer wheels, health cards, and navigation
test/         Focused model and widget tests
tool/         App-icon generator and existing brand asset
android/      Android runner
ios/          iOS runner
```

### Developer verification

```sh
flutter analyze
flutter test
```

Executed on **2026-10-06** with Flutter 3.47.5 / Dart 3.13.4:

- `flutter analyze`: **no issues found**.
- `flutter test`: **21 tests passed**.

The suite covers dashboard rendering, placeholder navigation, mileage calculations, odometer digit behavior, health-card states, and editor results. These are focused developer checks—not independent QA, end-to-end persistence verification, or a guarantee of platform readiness.

## Roadmap

Planned work, not available functionality or a release schedule:

- [ ] Harden odometer/save feedback, persistence failure handling, and schema migration.
- [ ] Record replacements through **Update**, preserve immutable history, and build the History view.
- [ ] Add service creation/deletion, presets, and editable service installation KM.
- [ ] Generalize four-position cards beyond tires.
- [ ] Add optional duration markers while retaining mileage-driven health and status.
- [ ] Export/import versioned `*.geartracker-backup.json` files and support Android open-with.
- [ ] Complete independent QA and platform/release verification.

---

**Feedback:** Found a problem? [Open an issue](https://github.com/Juma1988/Gear-Tracker/issues) with the device, reproduction steps, and expected behavior. Redact personal vehicle data, local paths, and credentials from attachments.

**License:** [Eclipse Public License 2.0](LICENSE), preserved from the existing repository.
