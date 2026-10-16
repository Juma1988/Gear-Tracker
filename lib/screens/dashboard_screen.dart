import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart' hide AppBar;
import 'package:app/widgets/odometer_card.dart';

import '../data/garage_repository.dart';
import '../controllers/dashboard_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/service_item.dart';
import '../models/service_history_entry.dart';
import '../models/tire_item.dart';
import '../models/vehicle_profile.dart';
import '../preferences/display_preferences.dart';
import '../reminders/reminder_notification_service.dart';
import '../reminders/reminder_preferences.dart';
import '../widgets/app_bar.dart';
import '../widgets/dev_overlay.dart';

import '../widgets/service_health_card.dart';
import '../widgets/service_card_content.dart';
import 'add_service_screen.dart';
import 'add_vehicle_screen.dart';
import 'edit_service_screen.dart';
import 'edit_tire_screen.dart';
import 'tire_health_wizard_screen.dart';
import 'settings_screen.dart';
import 'vehicle_selector_screen.dart';

export '../controllers/dashboard_controller.dart'
    show DashboardLoadState, DashboardSaveState;

const bool showServiceDemo = bool.fromEnvironment(
  'SHOW_SERVICE_DEMO',
  defaultValue: false,
);

final _demoServices = <ServiceItem>[
  ServiceItem(
    id: 'demo-engine-oil',
    name: 'Engine Oil',
    note: 'Full synthetic 5W-30',
    serviceOdometer: 64850,
    intervalKm: 10000,
    iconKey: 'oil',
    installDate: DateTime(2026, 4, 1),
  ),
  ServiceItem(
    id: 'demo-brake-pads',
    name: 'Brake Pads',
    note: 'Front axle inspection',
    serviceOdometer: 52000,
    intervalKm: 30000,
    iconKey: 'brake_pads',
    installDate: DateTime(2025, 8, 14),
  ),
  ServiceItem(
    id: 'demo-air-filter',
    name: 'Air Filter',
    note: 'Inspect filter and intake housing',
    serviceOdometer: 68000,
    intervalKm: 20000,
    iconKey: 'air_filter',
    installDate: DateTime(2026, 3, 1),
  ),
  ServiceItem(
    id: 'demo-battery',
    name: 'Battery Inspection',
    note: 'Check terminals and charge level',
    installDate: DateTime(2025, 1, 1),
    shelfLifeMonths: 36,
    iconKey: 'battery',
  ),
  ServiceItem(
    id: 'demo-timing-belt',
    name: 'Timing Belt',
    note: 'Replace by distance or date',
    serviceOdometer: 40000,
    intervalKm: 60000,
    installDate: DateTime(2025, 1, 10),
    shelfLifeMonths: 24,
    iconKey: 'timing_belt',
  ),
  ServiceItem(
    id: 'demo-oil-filter',
    name: 'Oil Filter',
    note: 'Replace with engine oil service',
    serviceOdometer: 70000,
    intervalKm: 10000,
    iconKey: 'oil_filter',
    installDate: DateTime(2026, 5, 15),
  ),
  ServiceItem(
    id: 'demo-cabin-filter',
    name: 'Cabin Filter',
    note: 'Replace for clean cabin air',
    serviceOdometer: 60000,
    intervalKm: 15000,
    iconKey: 'cabin_filter',
    installDate: DateTime(2025, 12, 5),
  ),
  ServiceItem(
    id: 'demo-brake-fluid',
    name: 'Brake Fluid',
    note: 'Flush and inspect moisture level',
    installDate: DateTime(2025, 12, 10),
    shelfLifeMonths: 12,
    iconKey: 'brake_fluid',
  ),
  ServiceItem(
    id: 'demo-tire-rotation',
    name: 'Tire Rotation',
    note: 'Rotate and check alignment',
    serviceOdometer: 65000,
    intervalKm: 12000,
    iconKey: 'tires',
    installDate: DateTime(2026, 1, 20),
  ),
  ServiceItem(
    id: 'demo-spark-plugs',
    name: 'Spark Plugs',
    note: 'Inspect gap and ignition performance',
    serviceOdometer: 45000,
    intervalKm: 40000,
    iconKey: 'spark_plugs',
    installDate: DateTime(2025, 6, 10),
  ),
  ServiceItem(
    id: 'demo-coolant',
    name: 'Coolant',
    note: 'Check level, color, and freeze protection',
    serviceOdometer: 50000,
    intervalKm: 40000,
    iconKey: 'coolant',
    installDate: DateTime(2025, 7, 1),
  ),
  ServiceItem(
    id: 'demo-transmission-fluid',
    name: 'Transmission Fluid',
    note: 'Inspect level and shift quality',
    serviceOdometer: 30000,
    intervalKm: 60000,
    iconKey: 'transmission_fluid',
    installDate: DateTime(2024, 10, 12),
  ),
  ServiceItem(
    id: 'demo-power-steering',
    name: 'Power Steering Fluid',
    note: 'Inspect fluid level and leaks',
    serviceOdometer: 35000,
    intervalKm: 50000,
    iconKey: 'power_steering',
    installDate: DateTime(2025, 2, 3),
  ),
  ServiceItem(
    id: 'demo-drive-belts',
    name: 'Drive Belts',
    note: 'Inspect tension, cracks, and wear',
    serviceOdometer: 40000,
    intervalKm: 50000,
    iconKey: 'drive_belts',
    installDate: DateTime(2025, 5, 18),
  ),
  ServiceItem(
    id: 'demo-wipers',
    name: 'Wiper Blades',
    note: 'Replace when streaking or chattering',
    serviceOdometer: 65000,
    intervalKm: 15000,
    iconKey: 'wipers',
    installDate: DateTime(2026, 2, 8),
  ),
  ServiceItem(
    id: 'demo-suspension',
    name: 'Suspension Inspection',
    note: 'Check shocks, mounts, and bushings',
    serviceOdometer: 25000,
    intervalKm: 60000,
    iconKey: 'suspension',
    installDate: DateTime(2024, 12, 12),
  ),
  ServiceItem(
    id: 'demo-fuel-filter',
    name: 'Fuel Filter',
    note: 'Replace and inspect fuel lines',
    serviceOdometer: 30000,
    intervalKm: 50000,
    iconKey: 'fuel_filter',
    installDate: DateTime(2025, 4, 9),
  ),
  ServiceItem(
    id: 'demo-ac-service',
    name: 'AC Service',
    note: 'Check cooling performance and refrigerant',
    installDate: DateTime(2025, 10, 30),
    shelfLifeMonths: 12,
    iconKey: 'ac',
  ),
  ServiceItem(
    id: 'demo-coolant-change-now',
    name: 'Coolant Change Now',
    note: 'Time limit reached',
    installDate: DateTime(2025, 10, 1),
    shelfLifeMonths: 12,
    iconKey: 'coolant',
  ),
  ServiceItem(
    id: 'demo-general-maintenance',
    name: 'General Maintenance',
    note: 'Seasonal inspection and fluid checks',
    serviceOdometer: 65000,
    intervalKm: 15000,
    iconKey: 'maintenance',
    installDate: DateTime(2026, 2, 1),
  ),
];

final _demoHistory = <ServiceHistoryEntry>[
  ServiceHistoryEntry(
    id: 'demo-engine-oil-history-1',
    serviceId: 'demo-engine-oil',
    serviceName: 'Engine Oil',
    previousServiceOdometer: 34850,
    completedOdometer: 44850,
    newNote: 'Full synthetic 5W-30 and oil filter replaced.',
    newIntervalKm: 10000,
    completedAt: DateTime(2024, 8, 18),
  ),
  ServiceHistoryEntry(
    id: 'demo-engine-oil-history-2',
    serviceId: 'demo-engine-oil',
    serviceName: 'Engine Oil',
    previousServiceOdometer: 44850,
    completedOdometer: 54850,
    newNote: 'Oil level and filter checked during routine service.',
    newIntervalKm: 10000,
    completedAt: DateTime(2025, 4, 12),
  ),
  ServiceHistoryEntry(
    id: 'demo-engine-oil-history-3',
    serviceId: 'demo-engine-oil',
    serviceName: 'Engine Oil',
    previousServiceOdometer: 54850,
    completedOdometer: 64850,
    newNote: 'Full synthetic oil change completed at the scheduled interval.',
    newIntervalKm: 10000,
    completedAt: DateTime(2026, 4, 1),
  ),
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.repository,
    this.odometerSaveDebounce = const Duration(seconds: 1),
    this.onSaveStateChanged,
  });

  final GarageRepository? repository;
  final Duration odometerSaveDebounce;
  final ValueChanged<DashboardSaveState>? onSaveStateChanged;

  @visibleForTesting
  static const Key saveStatusKey = Key('dashboard-save-status');

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  String _savedOdometer = '000000';
  String _displayedOdometer = '000000';
  String _stagedOdometer = '000000';
  int _odometerSaveRevision = 0;
  Timer? _odometerSaveTimer;
  late final GarageRepository _repository;
  late final DashboardController _controller;
  late final ReminderNotificationService _reminderService;
  String? _pendingReminderVehicleId;
  String? _pendingReminderServiceId;
  GarageCollection? _garageCollection;
  VehicleProfile? _vehicle;
  List<ServiceItem> _services = const [];
  List<ServiceItem> _demoServicesVisible = List.of(_demoServices);
  List<TireItem> _tires = const [];
  List<ServiceHistoryEntry> _history = const [];
  DashboardLoadState _loadState = DashboardLoadState.loading;
  DashboardSaveState _saveState = DashboardSaveState.saved;
  bool _compactTireHealth = false;

  void _setSaveState(DashboardSaveState state) {
    if (!mounted) return;
    setState(() => _saveState = state);
    widget.onSaveStateChanged?.call(state);
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  List<ServiceItem> get _servicesForDisplay =>
      showServiceDemo ? _demoServicesVisible : _services;

  List<ServiceHistoryEntry> get _historyForDisplay =>
      showServiceDemo ? _demoHistory : _history;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? GarageRepository();
    _controller = DashboardController(repository: _repository);
    _reminderService = ReminderNotificationService(
      onNotificationResponse: _handleReminderResponse,
    );
    DevOverlay.currentFilePath = 'lib/screens/dashboard_screen.dart';
    _loadGarage();
    _loadDisplayPreferences();
  }

  Future<void> _loadDisplayPreferences() async {
    final value = await DisplayPreferences.loadCompactTireHealth();
    if (mounted) setState(() => _compactTireHealth = value);
  }

  Future<void> _loadGarage() async {
    await _controller.load();
    if (!mounted) return;
    setState(() {
      _garageCollection = _controller.collection;
      _vehicle = _controller.vehicle;
      _savedOdometer = _controller.savedOdometer;
      _displayedOdometer = _controller.displayedOdometer;
      _stagedOdometer = _controller.stagedOdometer;
      _services = _controller.services;
      _tires = _controller.tires;
      _history = _controller.history;
      _loadState = _controller.loadState;
    });
    if (_loadState == DashboardLoadState.ready) {
      unawaited(_syncReminders());
      _openPendingReminderService();
    }
  }

  void _handleReminderResponse(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final vehicleId = decoded['vehicleId'];
      final serviceId = decoded['serviceId'];
      if (vehicleId is! String || serviceId is! String) return;
      final collection = _garageCollection;
      if (collection == null || !mounted) {
        _pendingReminderVehicleId = vehicleId;
        _pendingReminderServiceId = serviceId;
        return;
      }
      final vehicleIndex = collection.vehicles.indexWhere(
        (item) => item.id == vehicleId,
      );
      final vehicle = vehicleIndex == -1
          ? null
          : collection.vehicles[vehicleIndex];
      if (vehicle == null) return;
      _pendingReminderVehicleId = vehicleId;
      _pendingReminderServiceId = serviceId;
      _openPendingReminderService();
    } catch (_) {
      // Malformed external payloads must not affect normal app navigation.
    }
  }

  /// Test seam: delivers a reminder payload exactly as the notification
  /// service would, without requiring a device-backed plugin.
  @visibleForTesting
  void deliverReminderResponseForTesting(String payload) =>
      _handleReminderResponse(payload);

  void _openPendingReminderService() {
    final vehicleId = _pendingReminderVehicleId;
    final serviceId = _pendingReminderServiceId;
    final vehicle = _vehicle;
    if (serviceId == null || vehicle == null || !mounted) return;
    if (vehicleId != null && vehicle.id != vehicleId) {
      final collection = _garageCollection;
      final targetExists =
          collection?.vehicles.any((item) => item.id == vehicleId) ?? false;
      if (!targetExists) {
        _pendingReminderVehicleId = null;
        _pendingReminderServiceId = null;
        return;
      }
      if (collection != null) {
        unawaited(
          _applyVehicleSelection(collection, VehicleSelected(vehicleId)),
        );
      }
      return;
    }
    final serviceIndex = vehicle.garage.services.indexWhere(
      (item) => item.id == serviceId,
    );
    final service = serviceIndex == -1
        ? null
        : vehicle.garage.services[serviceIndex];
    if (service == null) {
      _pendingReminderVehicleId = null;
      _pendingReminderServiceId = null;
      return;
    }
    _pendingReminderVehicleId = null;
    _pendingReminderServiceId = null;
    _editServiceDirect(service);
  }

  Future<void> _syncReminders({
    List<ServiceItem>? services,
    int? odometer,
    bool forceReschedule = false,
  }) async {
    final vehicle = _vehicle;
    if (vehicle == null) return;
    try {
      final preferences = await const ReminderPreferencesRepository().load();
      final reminderResult = await _reminderService.syncResult(
        preferences: preferences,
        targets: ReminderNotificationService.dueTargets(
          vehicleId: vehicle.id,
          vehicleName: vehicle.name,
          services: services ?? _services,
          currentOdometer: odometer ?? int.parse(_savedOdometer),
        ),
        forceReschedule: forceReschedule,
      );
      if (reminderResult case ReminderFailure(:final kind)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kind == ReminderFailureKind.permission
                  ? _l10n.remindersPermissionDenied
                  : _l10n.remindersSyncFailed,
            ),
          ),
        );
      }
    } catch (_) {
      // Reminder delivery is optional and must not prevent garage use.
    }
  }

  /// Persists the currently displayed vehicle state into its profile.
  Future<bool> _persistGarage({
    List<ServiceItem>? services,
    List<TireItem>? tires,
    List<ServiceHistoryEntry>? history,
    String? odometer,
  }) async {
    _setSaveState(DashboardSaveState.saving);
    final ok = await _controller.persistGarage(
      nextServices: services,
      nextTires: tires,
      nextHistory: history,
      odometer: odometer,
    );
    if (ok) {
      if (mounted) {
        setState(() {
          _garageCollection = _controller.collection;
          _vehicle = _controller.vehicle;
          _services = _controller.services;
          _tires = _controller.tires;
          _history = _controller.history;
        });
      }
      unawaited(
        _syncReminders(services: services ?? _services, forceReschedule: true),
      );
      _setSaveState(DashboardSaveState.saved);
      return true;
    }
    _setSaveState(DashboardSaveState.failed);
    return false;
  }

  Future<void> _persistCurrentGarage({String? odometer}) async {
    final ok = await _persistGarage(odometer: odometer ?? _savedOdometer);
    if (!ok && mounted) _showSaveFailure(onRetry: _persistCurrentGarage);
  }

  void _showSaveFailure({Future<void> Function()? onRetry}) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.changesSaveFailed),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () => unawaited(onRetry?.call() ?? _persistGarage()),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _saveOdometer() {
    final odometer = _stagedOdometer;
    setState(() {
      _savedOdometer = odometer;
      _displayedOdometer = odometer;
      _odometerSaveRevision++;
    });
    unawaited(_persistCurrentGarage(odometer: odometer));
  }

  void _stageOdometer(String value) {
    setState(() => _stagedOdometer = value);
    _setSaveState(DashboardSaveState.unsaved);
    _odometerSaveTimer?.cancel();
    _odometerSaveTimer = Timer(widget.odometerSaveDebounce, () {
      if (mounted && _stagedOdometer != _savedOdometer) {
        _saveOdometer();
      }
    });
  }

  @override
  void dispose() {
    _odometerSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final servicesForDisplay = _servicesForDisplay;
    final usingDemoServices = showServiceDemo;
    return Scaffold(
      body: SafeArea(
        child: _loadState == DashboardLoadState.ready
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: AppBar(
                      vehicleName: _vehicle?.name ?? '2022 Golf GTI',
                      onSettings: _openSettings,
                      onVehicle: _openVehicleSelector,
                      onAdd: _addService,
                      status: _mostUrgentStatus(
                        int.parse(_displayedOdometer),
                        now: DateTime.now(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        OdometerCard(
                          odometer: _stagedOdometer,
                          onChanged: _stageOdometer,
                          saveRevision: _odometerSaveRevision,
                          isDirty: _stagedOdometer != _savedOdometer,
                          status: _mostUrgentStatus(
                            int.parse(_displayedOdometer),
                            now: DateTime.now(),
                          ),
                          lastUpdatedAt: _vehicle?.garage.lastUpdatedAt,
                          saveStatus: switch (_saveState) {
                            DashboardSaveState.unsaved => l10n.unsavedChanges,
                            DashboardSaveState.saving => l10n.saving,
                            DashboardSaveState.saved => l10n.saved,
                            DashboardSaveState.failed => l10n.saveFailed,
                          },
                          saveStatusKey: DashboardScreen.saveStatusKey,
                        ),
                        if (_tires.isEmpty && servicesForDisplay.isEmpty) ...[
                          const SizedBox(height: 12),
                          _EmptyVehicleRecordMessage(
                            title: l10n.emptyVehicleRecordsTitle,
                            message: l10n.emptyVehicleRecordsMessage,
                            actionLabel: l10n.addService,
                            onAdd: _addService,
                            semanticKey: const Key('empty-vehicle-records'),
                          ),
                        ] else if (_tires.isEmpty) ...[
                          const SizedBox(height: 12),
                          _EmptyVehicleRecordMessage(
                            title: l10n.tireHealth,
                            message: l10n.tireHealthGuideMessage,
                            actionLabel: l10n.addTireHealth,
                            onAdd: _addTireHealth,
                            semanticKey: const Key('empty-tire-health'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        for (final card in DashboardHealthCard.ordered(
                          services: servicesForDisplay,
                          tires: _tires,
                          currentOdometer: int.parse(_displayedOdometer),
                          now: DateTime.now(),
                        )) ...[
                          switch (card) {
                            DashboardServiceHealthCard(:final service) =>
                              ServiceHealthCard.service(
                                service: service,
                                currentOdometer: int.parse(_displayedOdometer),
                                onEditService: usingDemoServices
                                    ? () => _showServiceActionsDialog(
                                        service,
                                        demo: true,
                                      )
                                    : () => _showServiceActionsDialog(service),
                                onDeleteService: usingDemoServices
                                    ? () {}
                                    : () => _deleteService(service),
                              ),
                            DashboardTireHealthCard() =>
                              ServiceHealthCard.tireGrid(
                                tires: _tires,
                                currentOdometer: int.parse(_displayedOdometer),
                                onEditTire: _editTire,
                                compact: _compactTireHealth,
                                hideAtNarrowLargeText: true,
                              ),
                          },
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: switch (_loadState) {
                      DashboardLoadState.loading => Center(
                        child: Semantics(
                          label: l10n.loadingGarage,
                          child: const CircularProgressIndicator(),
                        ),
                      ),
                      DashboardLoadState.error => _DashboardStateMessage(
                        title: l10n.garageLoadFailed,
                        actionLabel: l10n.retry,
                        onPressed: _loadGarage,
                      ),
                      DashboardLoadState.empty => _DashboardStateMessage(
                        title: l10n.emptyGarageTitle,
                        message: l10n.emptyGarageMessage,
                        semanticLabel:
                            '${l10n.emptyGarageTitle}. ${l10n.emptyGarageMessage}',
                        actionLabel: l10n.addVehicle,
                        onPressed: _addVehicle,
                      ),
                      DashboardLoadState.ready => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _addVehicle() async {
    final result = await Navigator.of(context).push<VehicleProfile>(
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );
    if (result == null || !mounted) return;
    final collection =
        _garageCollection ??
        const GarageCollection(
          vehicles: [],
          selectedVehicleId: '',
          defaultVehicleId: GarageCollection.lastUsedVehicleId,
        );
    final updated = collection.copyWith(
      vehicles: [...collection.vehicles, result],
      selectedVehicleId: result.id,
    );
    try {
      if (!await _controller.saveCollection(updated)) {
        if (mounted) _showSaveFailure();
        return;
      }
      if (mounted) await _loadGarage();
    } catch (_) {
      if (mounted) _showSaveFailure(onRetry: _addVehicle);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          vehicles: _garageCollection?.vehicles ?? const [],
          defaultVehicleId: _garageCollection?.defaultVehicleId,
          repository: _repository,
          onGarageRestored: _reloadGarageAfterRestore,
          onDefaultVehicleChanged: _setDefaultVehicle,
          onReminderPreferencesChanged: (_) =>
              _syncReminders(forceReschedule: true),
          onCompactTireHealthChanged: (value) =>
              setState(() => _compactTireHealth = value),
        ),
      ),
    );
  }

  /// After a restore the in-memory garage is stale, and reminders may belong to
  /// a vehicle that no longer exists, so both are rebuilt from storage.
  Future<void> _reloadGarageAfterRestore() async {
    await _loadGarage();
    if (mounted) await _syncReminders(forceReschedule: true);
  }

  Future<void> _setDefaultVehicle(String vehicleId) async {
    final collection = _garageCollection;
    if (collection == null) return;
    final vehicle = collection.vehicles.firstWhere(
      (item) => item.id == vehicleId,
      orElse: () => collection.selectedVehicle,
    );
    final updated = collection.copyWith(
      defaultVehicleId: vehicleId,
      selectedVehicleId: vehicle.id,
    );
    if (!await _controller.saveCollection(updated)) {
      if (mounted) _showSaveFailure();
      return;
    }
    if (!mounted) return;
    final snapshot = vehicle.garage;
    setState(() {
      _garageCollection = updated;
      _vehicle = vehicle;
      _savedOdometer = snapshot.odometer.toString().padLeft(6, '0');
      _displayedOdometer = _savedOdometer;
      _stagedOdometer = _savedOdometer;
      _services = snapshot.services;
      _tires = snapshot.tires;
      _history = snapshot.history;
    });
    unawaited(_syncReminders(forceReschedule: true));
  }

  Future<void> _openVehicleSelector() async {
    final collection = _garageCollection;
    if (collection == null) return;
    final result = await Navigator.of(context).push<VehicleSelectionResult>(
      MaterialPageRoute(
        builder: (_) => VehicleSelectorScreen(
          vehicles: collection.vehicles,
          selectedVehicleId: collection.selectedVehicleId,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _applyVehicleSelection(collection, result);
  }

  Future<void> _applyVehicleSelection(
    GarageCollection collection,
    VehicleSelectionResult result,
  ) async {
    final vehicles = [...collection.vehicles];
    final String selectedId;
    switch (result) {
      case VehicleSelected(:final vehicleId):
        selectedId = vehicleId;
      case VehicleCreated(:final vehicle):
        vehicles.add(vehicle);
        selectedId = vehicle.id;
      case VehicleUpdated(:final vehicle):
        final index = vehicles.indexWhere((item) => item.id == vehicle.id);
        if (index == -1) {
          vehicles.add(vehicle);
        } else {
          vehicles[index] = vehicle;
        }
        selectedId = collection.selectedVehicleId;
    }
    final updated = collection.copyWith(
      vehicles: vehicles,
      selectedVehicleId: selectedId,
      defaultVehicleId: collection.defaultVehicleId,
    );
    try {
      if (!await _controller.saveCollection(updated)) {
        if (mounted) _showSaveFailure();
        return;
      }
    } catch (_) {
      if (mounted) _showSaveFailure();
      return;
    }
    if (!mounted) return;
    final vehicle = updated.selectedVehicle;
    setState(() {
      _garageCollection = updated;
      _vehicle = vehicle;
      _savedOdometer = vehicle.garage.odometer.toString().padLeft(6, '0');
      _displayedOdometer = _savedOdometer;
      _stagedOdometer = _savedOdometer;
      _services = vehicle.garage.services;
      _tires = vehicle.garage.tires;
      _history = vehicle.garage.history;
    });
    unawaited(_syncReminders(forceReschedule: true));
    _openPendingReminderService();
  }

  ServiceStatus _mostUrgentStatus(int currentOdometer, {DateTime? now}) {
    final statuses = [
      for (final service in _servicesForDisplay)
        service.statusAt(currentOdometer, now: now),
      for (final tire in _tires) tire.metricsAt(currentOdometer).status,
    ];
    return statuses.fold(
      ServiceStatus.excellent,
      (mostUrgent, status) =>
          status.index > mostUrgent.index ? status : mostUrgent,
    );
  }

  Future<void> _addService() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => AddServiceScreen(
          currentOdometer: int.parse(_savedOdometer),
          existingServices: _services,
          hasTires: _tires.isNotEmpty,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result is TireHealthAdded) {
      await _addTireHealth();
      return;
    }
    if (result is TireHealthRemoved) {
      await _removeTireHealth();
      return;
    }
    if (result is ServiceRemoved) {
      ServiceItem? service;
      for (final item in _services) {
        if (item.id == result.serviceId) {
          service = item;
          break;
        }
      }
      if (service != null) {
        await _deleteService(service, confirmed: true);
      }
      return;
    }
    if (result is ServiceItem) {
      await _saveNewService(result);
    }
  }

  Future<void> _addTireHealth() async {
    if (_tires.isNotEmpty) return;
    final tires = await Navigator.of(context).push<List<TireItem>>(
      MaterialPageRoute(
        builder: (_) =>
            TireHealthWizardScreen(currentOdometer: int.parse(_savedOdometer)),
      ),
    );
    if (!mounted ||
        tires == null ||
        tires.length != TireItem.positionIds.length) {
      return;
    }
    final ok = await _persistGarage(tires: tires);
    if (!mounted) return;
    if (!ok) {
      _showSaveFailure(onRetry: _addTireHealth);
      return;
    }
    _showMessage(_l10n.tireHealthAdded);
  }

  Future<void> _removeTireHealth() async {
    if (_tires.isEmpty) return;
    final ok = await _persistGarage(tires: const []);
    if (!mounted) return;
    if (!ok) {
      _showSaveFailure(onRetry: _removeTireHealth);
      return;
    }
    _showMessage(_l10n.tireHealthRemoved);
  }

  Future<void> _saveNewService(ServiceItem newService) async {
    final updatedServices = [..._services, newService];
    final ok = await _persistGarage(services: updatedServices);
    if (!mounted) return;
    if (!ok) {
      _showSaveFailure(onRetry: () => _saveNewService(newService));
      return;
    }
    _showMessage(_l10n.serviceSaved(newService.name));
  }

  Widget _serviceDialogInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _showServiceActionsDialog(
    ServiceItem service, {
    bool demo = false,
  }) async {
    final l10n = _l10n;
    final odometer = int.parse(_displayedOdometer);
    final metrics = service.metricsAt(odometer);
    final status = service.statusAt(odometer);
    final serviceHistory = _historyForDisplay
        .where((entry) => entry.serviceId == service.id)
        .toList(growable: false);
    final lastServiced = serviceHistory.isEmpty
        ? null
        : serviceHistory.reduce(
            (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
          );
    final tracking = service.tracksMileage && service.tracksTime
        ? l10n.trackingBothSummary
        : service.tracksTime
        ? l10n.trackingTimeSummary
        : l10n.trackingMileageSummary;
    final materialL10n = MaterialLocalizations.of(context);
    final statusColor = switch (status) {
      ServiceStatus.replaceNow => Theme.of(context).colorScheme.error,
      ServiceStatus.warning ||
      ServiceStatus.replaceSoon => Theme.of(context).colorScheme.tertiary,
      ServiceStatus.good ||
      ServiceStatus.excellent => Theme.of(context).colorScheme.primary,
    };
    final statusIcon = switch (status) {
      ServiceStatus.replaceNow => Icons.error_outline,
      ServiceStatus.warning ||
      ServiceStatus.replaceSoon => Icons.warning_amber_outlined,
      ServiceStatus.good ||
      ServiceStatus.excellent => Icons.check_circle_outline,
    };
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(service.name),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .58,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.serviceCardActionsMessage(service.name)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: .65),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.status(serviceHealthStatusKey(status)),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                metrics == null
                                    ? l10n.timeBased
                                    : '${metrics.remainingPercent}% ${l10n.left}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _serviceDialogInfoRow(
                    context,
                    icon: Icons.route_outlined,
                    label: l10n.trackingSummaryLabel,
                    value: tracking,
                  ),
                  const SizedBox(height: 8),
                  _serviceDialogInfoRow(
                    context,
                    icon: Icons.history,
                    label: l10n.lastServicedLabel,
                    value: lastServiced == null
                        ? l10n.noServiceHistoryShort
                        : materialL10n.formatMediumDate(
                            lastServiced.completedAt,
                          ),
                  ),
                  if (service.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _serviceDialogInfoRow(
                      context,
                      icon: Icons.notes_outlined,
                      label: l10n.note,
                      value: service.note,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'edit'),
            child: Text(l10n.editServiceHint),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'service'),
            icon: const Icon(Icons.task_alt),
            label: Text(l10n.serviceActionMarkServiced),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (demo) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => EditServiceScreen(
            service: service,
            currentOdometer: int.parse(_displayedOdometer),
            allowDelete: true,
            history: _historyForDisplay,
            openCompletionOnLaunch: action == 'service',
          ),
        ),
      );
      if (!mounted || result == null) return;
      if (result == ServiceEditResult.delete) {
        setState(() {
          _demoServicesVisible = _demoServicesVisible
              .where((item) => item.id != service.id)
              .toList(growable: false);
        });
      } else if (result is ServiceItem) {
        setState(() {
          _demoServicesVisible = _demoServicesVisible
              .map((item) => item.id == result.id ? result : item)
              .toList(growable: false);
        });
      }
      return;
    }
    await _editServiceDirect(service, openCompletion: action == 'service');
  }

  Future<void> _editServiceDirect(
    ServiceItem service, {
    bool openCompletion = false,
  }) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => EditServiceScreen(
          service: service,
          currentOdometer: int.parse(_stagedOdometer),
          allowDelete: service.id != 'engine-oil',
            history: _historyForDisplay,
          openCompletionOnLaunch: openCompletion,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == ServiceEditResult.delete) {
      await _deleteService(service, confirmed: true);
      return;
    }
    if (result is ServiceCompletionResult) {
      await _saveServiceCompletion(result);
      return;
    }
    final updatedService = result as ServiceItem;
    await _saveServiceConfiguration(updatedService);
  }

  Future<void> _saveServiceConfiguration(ServiceItem updatedService) async {
    final updatedServices = _services
        .map((item) => item.id == updatedService.id ? updatedService : item)
        .toList(growable: false);
    final ok = await _persistGarage(services: updatedServices);
    if (!mounted) return;
    if (!ok) {
      _showSaveFailure(
        onRetry: () => _saveServiceConfiguration(updatedService),
      );
      return;
    }
    _showMessage(_l10n.serviceSaved(updatedService.name));
  }

  Future<void> _saveServiceCompletion(
    ServiceCompletionResult completion,
  ) async {
    final updatedServices = _services
        .map(
          (item) => item.id == completion.updatedService.id
              ? completion.updatedService
              : item,
        )
        .toList(growable: false);
    final updatedHistory = [
      ..._history.where((entry) => entry.id != completion.historyEntry.id),
      completion.historyEntry,
    ];
    final ok = await _persistGarage(
      services: updatedServices,
      history: updatedHistory,
    );
    if (!mounted) return;
    if (!ok) {
      _showSaveFailure(onRetry: () => _saveServiceCompletion(completion));
      return;
    }
    _showMessage(_l10n.serviceMarkedServiced(completion.updatedService.name));
  }

  Future<void> _deleteService(
    ServiceItem service, {
    bool confirmed = false,
  }) async {
    // Capture the associated history up front so the undo window can restore
    // every removed entry at its prior position.
    final removedHistory = <({int index, ServiceHistoryEntry entry})>[
      for (var index = 0; index < _history.length; index++)
        if (_history[index].serviceId == service.id)
          (index: index, entry: _history[index]),
    ];
    if (!confirmed) {
      final l10n = AppLocalizations.of(context);
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.deleteServiceQuestion),
              content: Text(
                removedHistory.isEmpty
                    ? l10n.removeServiceFromVehicle(service.name)
                    : l10n.removeServiceAndHistoryFromVehicle(service.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.delete),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!mounted || confirmed != true) return;
    final removedIndex = _services.indexWhere((item) => item.id == service.id);
    if (removedIndex == -1) return;
    final updatedServices = _services
        .where((item) => item.id != service.id)
        .toList();
    // Deleting a service must delete its completion history with it, or the
    // persisted snapshot would reference a service that no longer exists and
    // the garage could never be loaded again.
    final updatedHistory = _history
        .where((entry) => entry.serviceId != service.id)
        .toList();
    final ok = await _persistGarage(
      services: updatedServices,
      history: updatedHistory,
    );
    if (!mounted) return;
    if (!ok) {
      _showSaveFailure(onRetry: () => _deleteService(service, confirmed: true));
      return;
    }
    _showDeletedServiceUndo(service, removedIndex, removedHistory);
  }

  /// Offers a short undo window after a deletion.
  ///
  /// The repository remains the source of truth: undo re-inserts the service
  /// and its history at their previous positions and persists it, so the
  /// restored state survives navigation and relaunch. Once the snack bar
  /// elapses, the deletion stands.
  void _showDeletedServiceUndo(
    ServiceItem service,
    int index,
    List<({int index, ServiceHistoryEntry entry})> removedHistory,
  ) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.serviceDeleted(service.name)),
          // SnackBars with an action default to persist, which would keep the
          // undo affordance on screen forever; the window is a hard 5 seconds.
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.undoAction,
            onPressed: () => unawaited(
              _restoreDeletedService(service, index, removedHistory),
            ),
          ),
        ),
      );
  }

  Future<void> _restoreDeletedService(
    ServiceItem service,
    int index,
    List<({int index, ServiceHistoryEntry entry})> removedHistory,
  ) async {
    if (!mounted) return;
    if (_services.any((item) => item.id == service.id)) return;
    final restoredServices = [..._services];
    final insertAt = index < 0 ? 0 : min(index, restoredServices.length);
    restoredServices.insert(insertAt, service);
    // Re-insert history in ascending original-index order so entries land at
    // their prior positions and keep the list chronological.
    final restoredHistory = [..._history];
    for (final removed in removedHistory) {
      final historyAt = min(removed.index, restoredHistory.length);
      restoredHistory.insert(historyAt, removed.entry);
    }
    final ok = await _persistGarage(
      services: restoredServices,
      history: restoredHistory,
    );
    if (!mounted) return;
    if (!ok) {
      _showSaveFailure(
        onRetry: () => _restoreDeletedService(service, index, removedHistory),
      );
      return;
    }
    _showMessage(_l10n.serviceRestored(service.name));
  }

  Future<void> _editTire(TireItem tire) async {
    final updatedTire = await Navigator.of(context).push<TireItem>(
      MaterialPageRoute(
        builder: (_) => EditTireScreen(
          tire: tire,
          currentOdometer: int.parse(_savedOdometer),
        ),
      ),
    );
    if (!mounted || updatedTire == null) return;
    final updatedTires = _tires
        .map((item) => item.id == updatedTire.id ? updatedTire : item)
        .toList(growable: false);
    await _saveTireUpdate(updatedTires, updatedTire);
  }

  Future<void> _saveTireUpdate(
    List<TireItem> updatedTires,
    TireItem updatedTire,
  ) async {
    final ok = await _persistGarage(tires: updatedTires);
    if (!mounted) return;
    if (!ok) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tireSaveFailed),
          action: SnackBarAction(
            label: l10n.retry,
            onPressed: () =>
                unawaited(_saveTireUpdate(updatedTires, updatedTire)),
          ),
        ),
      );
      return;
    }
    _showMessage(AppLocalizations.of(context).tireSaved(updatedTire.code));
  }
}

class _DashboardStateMessage extends StatelessWidget {
  const _DashboardStateMessage({
    required this.title,
    required this.actionLabel,
    required this.onPressed,
    this.message,
    this.semanticLabel,
  });

  final String title;
  final String? message;
  final String? semanticLabel;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            key: semanticLabel == null
                ? null
                : const Key('empty-garage-message'),
            container: true,
            label: semanticLabel,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

class _EmptyVehicleRecordMessage extends StatelessWidget {
  const _EmptyVehicleRecordMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAdd,
    required this.semanticKey,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAdd;
  final Key semanticKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      key: semanticKey,
      label: '$title. $message',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension DashboardServiceOrdering on List<ServiceItem> {
  /// Returns display-only urgency order: lowest remaining health-bar value first,
  /// followed by name and id for deterministic ties.
  List<ServiceItem> sortedByHealth(int currentOdometer, {DateTime? now}) {
    final services = List<ServiceItem>.of(this);
    services.sort(
      (a, b) => ServiceUrgencyPolicy.compare(
        a,
        b,
        currentOdometer: currentOdometer,
        now: now,
      ),
    );
    return services;
  }
}

sealed class DashboardHealthCard {
  const DashboardHealthCard({required this.health, required this.status});

  final double health;
  final ServiceStatus status;

  static List<DashboardHealthCard> ordered({
    required List<ServiceItem> services,
    required List<TireItem> tires,
    required int currentOdometer,
    DateTime? now,
  }) {
    final cards = <DashboardHealthCard>[
      for (final service in services)
        DashboardServiceHealthCard(
          service: service,
          health: service.metricsAt(currentOdometer)?.health ?? 1,
          status: service.statusAt(currentOdometer, now: now),
        ),
      if (tires.isNotEmpty)
        DashboardTireHealthCard(
          health: tires
              .map((tire) => tire.metricsAt(currentOdometer).health)
              .reduce(min),
          status: tires
              .map((tire) => tire.metricsAt(currentOdometer).status)
              .reduce((a, b) => b.index > a.index ? b : a),
        ),
    ];
    cards.sort((a, b) {
      final aDeferred =
          a is DashboardServiceHealthCard &&
          ServiceUrgencyPolicy.isTimeOnlyBelowPromotion(a.service, now: now);
      final bDeferred =
          b is DashboardServiceHealthCard &&
          ServiceUrgencyPolicy.isTimeOnlyBelowPromotion(b.service, now: now);
      if (aDeferred != bDeferred) return aDeferred ? 1 : -1;
      final statusComparison = ServiceUrgencyPolicy.urgencyRank(b.status)
          .compareTo(ServiceUrgencyPolicy.urgencyRank(a.status));
      if (statusComparison != 0) return statusComparison;
      final healthComparison = a.health.compareTo(b.health);
      if (healthComparison != 0) return healthComparison;
      return a.compareTieBreak(b);
    });
    return cards;
  }

  int compareTieBreak(DashboardHealthCard other);
}

final class DashboardServiceHealthCard extends DashboardHealthCard {
  const DashboardServiceHealthCard({
    required this.service,
    required super.health,
    required super.status,
  });

  final ServiceItem service;

  @override
  int compareTieBreak(DashboardHealthCard other) {
    if (other case DashboardServiceHealthCard(:final service)) {
      final nameComparison = this.service.name.compareTo(service.name);
      return nameComparison != 0
          ? nameComparison
          : this.service.id.compareTo(service.id);
    }
    return -1;
  }
}

final class DashboardTireHealthCard extends DashboardHealthCard {
  const DashboardTireHealthCard({required super.health, required super.status});

  @override
  int compareTieBreak(DashboardHealthCard other) =>
      other is DashboardTireHealthCard ? 0 : 1;
}
