import '../data/garage_repository.dart';
import '../models/service_history_entry.dart';
import '../models/fuel_entry.dart';
import '../models/fuel_calculations.dart';
import '../models/fuel_preferences.dart';
import '../models/service_item.dart';
import '../models/tire_item.dart';
import '../models/vehicle_profile.dart';

enum DashboardLoadState { loading, ready, empty, error }

enum DashboardSaveState { unsaved, saving, saved, failed }

/// Owns the dashboard's garage boundary while leaving presentation and
/// navigation in [DashboardScreen].
class DashboardController {
  DashboardController({GarageRepository? repository})
    : repository = repository ?? GarageRepository();

  final GarageRepository repository;
  bool _fuelWritePending = false;

  Future<bool> saveFuel(FuelEntry entry, {required int usualGrade}) async {
    if (_fuelWritePending || vehicle?.id != entry.vehicleId) return false;
    try {
      entry.validate();
      if (entry.fullTank == null ||
          !FuelCalculations.fitsOdometerOrder(entry, fuelEntries)) {
        return false;
      }
      final next = [...fuelEntries.where((e) => e.id != entry.id), entry];
      final prices = {...vehicle!.fuelPreferences.prices};
      // The most recently saved input is the next-entry suggestion, even
      // when the user is adding a backdated fill or correcting an old one.
      prices[entry.grade] = entry.recordedPrice ?? entry.pricePerLiter;
      return await _persistFuel(
        next,
        FuelPreferences(
          usualGrade: usualGrade,
          prices: Map.unmodifiable(prices),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFuel(String vehicleId, String id) async {
    if (_fuelWritePending || vehicle?.id != vehicleId) return false;
    return _persistFuel(
      FuelCalculations.withoutEntry(fuelEntries, vehicleId, id),
      vehicle!.fuelPreferences,
    );
  }

  Future<bool> _persistFuel(
    List<FuelEntry> entries,
    FuelPreferences preferences,
  ) async {
    final current = vehicle;
    final garage = collection;
    if (current == null || garage == null) return false;
    _fuelWritePending = true;
    final revision = repository.revision;
    try {
      final updated = current.copyWith(
        fuelPreferences: preferences,
        garage: GarageSnapshot(
          odometer: current.garage.odometer,
          services: services,
          tires: tires,
          history: history,
          fuelEntries: List.unmodifiable(entries),
          lastUpdatedAt: DateTime.now().toUtc(),
        ),
      );
      return await saveCollection(
        garage.copyWith(
          vehicles: [
            for (final v in garage.vehicles) v.id == updated.id ? updated : v,
          ],
        ),
        expectedRevision: revision,
      );
    } finally {
      _fuelWritePending = false;
    }
  }

  GarageCollection? collection;
  VehicleProfile? vehicle;
  List<ServiceItem> services = const [];
  List<TireItem> tires = const [];
  List<ServiceHistoryEntry> history = const [];
  List<FuelEntry> fuelEntries = const [];
  String savedOdometer = '000000';
  String displayedOdometer = '000000';
  String stagedOdometer = '000000';
  DashboardLoadState loadState = DashboardLoadState.loading;
  DashboardSaveState saveState = DashboardSaveState.saved;

  Future<void> load() async {
    loadState = DashboardLoadState.loading;
    try {
      final result = await repository.loadCollectionResult();
      if (result case GarageFailure()) {
        loadState = DashboardLoadState.error;
        return;
      }
      var loaded = (result as GarageSuccess<GarageCollection>).value;
      if (loaded.isEmpty) {
        collection = loaded;
        vehicle = null;
        loadState = DashboardLoadState.empty;
        return;
      }
      final activeVehicle = loaded.launchVehicle;
      if (activeVehicle.id != loaded.selectedVehicleId) {
        loaded = loaded.copyWith(selectedVehicleId: activeVehicle.id);
        // Refreshing the active vehicle is best effort at startup.
        try {
          await repository.saveCollectionResult(loaded);
        } catch (_) {}
      }
      collection = loaded;
      _selectLoadedVehicle(activeVehicle);
      loadState = DashboardLoadState.ready;
    } catch (_) {
      loadState = DashboardLoadState.error;
    }
  }

  Future<bool> saveCollection(
    GarageCollection next, {
    int? expectedRevision,
  }) async {
    saveState = DashboardSaveState.saving;
    final result = await repository.saveCollectionResult(
      next,
      expectedRevision: expectedRevision,
    );
    if (result case GarageFailure()) {
      saveState = DashboardSaveState.failed;
      return false;
    }
    collection = next;
    if (next.isEmpty) {
      vehicle = null;
      services = const [];
      tires = const [];
      history = const [];
      fuelEntries = const [];
    } else {
      _selectLoadedVehicle(next.selectedVehicle);
    }
    saveState = DashboardSaveState.saved;
    return true;
  }

  Future<bool> persistGarage({
    List<ServiceItem>? nextServices,
    List<TireItem>? nextTires,
    List<ServiceHistoryEntry>? nextHistory,
    List<FuelEntry>? nextFuelEntries,
    String? odometer,
  }) async {
    final currentCollection = collection;
    final currentVehicle = vehicle;
    if (currentCollection == null || currentVehicle == null) return false;
    final updatedVehicle = currentVehicle.copyWith(
      garage: GarageSnapshot(
        odometer: int.parse(odometer ?? savedOdometer),
        services: nextServices ?? services,
        tires: nextTires ?? tires,
        history: nextHistory ?? history,
        fuelEntries: nextFuelEntries ?? fuelEntries,
        lastUpdatedAt: DateTime.now().toUtc(),
      ),
    );
    final updatedCollection = currentCollection.copyWith(
      vehicles: currentCollection.vehicles
          .map((item) => item.id == updatedVehicle.id ? updatedVehicle : item)
          .toList(growable: false),
    );
    return saveCollection(updatedCollection);
  }

  Future<bool> updateOdometer(String value) async {
    savedOdometer = value;
    displayedOdometer = value;
    stagedOdometer = value;
    return persistGarage();
  }

  void stageOdometer(String value) {
    stagedOdometer = value;
    saveState = DashboardSaveState.unsaved;
  }

  void selectVehicle(VehicleProfile selected, GarageCollection next) {
    collection = next;
    _selectLoadedVehicle(selected);
  }

  void _selectLoadedVehicle(VehicleProfile selected) {
    vehicle = selected;
    final snapshot = selected.garage;
    savedOdometer = snapshot.odometer.toString().padLeft(6, '0');
    displayedOdometer = savedOdometer;
    stagedOdometer = savedOdometer;
    services = snapshot.services;
    tires = snapshot.tires;
    history = snapshot.history;
    fuelEntries = snapshot.fuelEntries;
  }
}
