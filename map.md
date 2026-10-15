# Widget map

Production caller files exclude test-only usage. Private helpers are internal to
their containing widget and are not production-callable widgets.

## `lib/widgets/app_bar.dart`

- **Widget class:** `AppBar`
- **For:** Dashboard header with vehicle, settings, and add-service actions.
- **Used:** `lib/screens/dashboard_screen.dart`

## `lib/widgets/card_action_menu.dart`

- **Widget class:** `CardActionMenu` (with `CardActionMenuAction`)
- **For:** Compact overflow menu exposing per-card edit and delete commands.
- **Used:** `lib/screens/add_service_screen.dart`, `lib/screens/vehicle_selector_screen.dart`, `lib/widgets/service_health_card.dart`

## `lib/widgets/current_odometer_label.dart`

- **Widget class:** `CurrentOdometerLabel`
- **For:** Accessible current-odometer context on the service edit form.
- **Used:** `lib/screens/edit_service_screen.dart`

## `lib/widgets/date_input.dart`

- **Widget class:** `DateInput`
- **For:** Adaptive date field with a platform sheet picker.
- **Used:** `lib/screens/edit_service_screen.dart`, `lib/screens/service_form_screen.dart`, `lib/screens/edit_tire_screen.dart`

## `lib/widgets/dev_overlay.dart`

- **Widget class:** `DevOverlay`
- **For:** Debug-only restart and current-file-path developer controls.
- **Used:** `lib/main.dart`
- **Internal helpers:** `_DevOverlayState` is internal to `DevOverlay`.

## `lib/widgets/empty_history.dart`

- **Widget class:** `EmptyHistory`
- **For:** Accessible empty state for service history.
- **Used:** `lib/screens/history_screen.dart`

## `lib/widgets/history_entry_card.dart`

- **Widget class:** `HistoryEntryCard`
- **For:** Summary card for one completed service-history entry.
- **Used:** `lib/screens/history_screen.dart`

## `lib/widgets/odometer_card.dart`

- **Widget class:** `OdometerCard`
- **For:** Editable live odometer reading with save feedback.
- **Used:** `lib/screens/dashboard_screen.dart`
- **Internal helpers:** `_OdometerWheel` is internal to `OdometerCard`.

## `lib/widgets/service_health_card.dart`

- **Widget class:** `ServiceHealthCard`
- **For:** Interactive one-service or four-tire health summary.
- **Used:** `lib/screens/dashboard_screen.dart`
- **Internal helpers:** `_ServiceCard`, `_TireGridCard`, `_TireTile`,
  `_ServiceIcon`, `_StatusPill`, and `_UnitCode` are private to
   `ServiceHealthCard`.

## `lib/widgets/service_picker_card.dart`

- **Widget class:** `ServicePickerCard`
- **For:** Same-sized selectable service-type card for the add-service picker.
- **Used:** `lib/screens/add_service_screen.dart`
