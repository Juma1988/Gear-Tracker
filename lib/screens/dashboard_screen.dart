import 'dart:async';

import 'package:flutter/material.dart' hide AppBar;
import 'package:app/widgets/odometer_card.dart';

import '../data/data.dart';
import '../data/garage_repository.dart';
import '../models/service_item.dart';
import '../models/tire_item.dart';
import '../widgets/app_bar.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/gear_bottom_navigation.dart';

import '../widgets/service_health_card_01.dart';
import '../widgets/service_health_card_02.dart';
import 'history_screen.dart';
import 'edit_service_screen.dart';
import 'edit_tire_screen.dart';
import 'services_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navigationIndex = 0;
  String _savedOdometer = initialOdometer;
  String _stagedOdometer = initialOdometer;
  int _odometerSaveRevision = 0;
  Timer? _odometerSaveTimer;
  final _repository = GarageRepository();
  List<ServiceItem> _services = List.of(initialServices);
  List<TireItem> _tires = List.of(initialTires);

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/dashboard_screen.dart';
    _loadGarage();
  }

  Future<void> _loadGarage() async {
    final snapshot = await _repository.load();
    if (!mounted || snapshot == null) return;
    setState(() {
      _savedOdometer = snapshot.odometer.toString().padLeft(6, '0');
      _stagedOdometer = _savedOdometer;
      _services = snapshot.services;
      _tires = snapshot.tires;
    });
  }

  Future<void> _persistGarage() => _repository.save(
    GarageSnapshot(
      odometer: int.parse(_savedOdometer),
      services: _services,
      tires: _tires,
      history: const [],
    ),
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _saveOdometer() {
    setState(() {
      _savedOdometer = _stagedOdometer;
      _odometerSaveRevision++;
    });
    _persistGarage();
  }

  void _stageOdometer(String value) {
    setState(() => _stagedOdometer = value);
    _odometerSaveTimer?.cancel();
    _odometerSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _stagedOdometer != _savedOdometer) _saveOdometer();
    });
  }

  @override
  void dispose() {
    _odometerSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (_navigationIndex) {
      0 => SafeArea(
        child: Column(
          children: [
            AppBar(
              onSettings: () => _showMessage('Settings coming soon'),
              onVehicle: () => _showMessage('Vehicle selector coming soon'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  OdometerCard(
                    odometer: _stagedOdometer,
                    onChanged: _stageOdometer,
                    saveRevision: _odometerSaveRevision,
                    isDirty: _stagedOdometer != _savedOdometer,
                  ),
                  const SizedBox(height: 12),
                  for (final service in _services) ...[
                    ServiceHealthCardType01(
                      service: service,
                      currentOdometer: int.parse(_savedOdometer),
                      onDoubleTap: () => _showServiceActions(service),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ServiceHealthCardType02(
                    title: 'Tire Health',
                    icon: Icons.tire_repair,
                    units: _tires,
                    currentOdometer: int.parse(_savedOdometer),
                    onEditUnit: _editTire,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      1 => const HistoryScreen(),
      _ => const ServicesScreen(),
    },
    bottomNavigationBar: GearBottomNavigation(
      selectedIndex: _navigationIndex,
      onDestinationSelected: (index) =>
          setState(() => _navigationIndex = index),
    ),
  );

  void _showServiceActions(ServiceItem service) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(service.name),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _editService(service);
          },
          child: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _showMessage('Update selected');
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );

  Future<void> _editService(ServiceItem service) async {
    final updatedService = await Navigator.of(context).push<ServiceItem>(
      MaterialPageRoute(builder: (_) => EditServiceScreen(service: service)),
    );
    if (!mounted || updatedService == null) return;
    setState(() {
      _services = _services
          .map((item) => item.id == updatedService.id ? updatedService : item)
          .toList();
    });
    await _persistGarage();
    if (mounted) _showMessage('${updatedService.name} saved');
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
    setState(() {
      _tires = _tires
          .map((item) => item.id == updatedTire.id ? updatedTire : item)
          .toList();
    });
    await _persistGarage();
    if (mounted) _showMessage('${updatedTire.code} tire saved');
  }
}
