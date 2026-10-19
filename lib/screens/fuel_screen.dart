import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/fuel_localizations.dart';
import '../models/fuel_entry.dart';
import '../models/fuel_calculations.dart';
import '../models/vehicle_profile.dart';
import '../widgets/dev_overlay.dart';
import '../preferences/fuel_display_preferences.dart';

class FuelScreen extends StatefulWidget {
  const FuelScreen({
    this.consumptionUnit = FuelConsumptionUnit.kmPerLiter,
    super.key,
    required this.vehicle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onVehicle,
    required this.onSettings,
    required this.onRetry,
    required this.onAddVehicle,
    this.loading = false,
    this.loadError = false,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });
  final VehicleProfile? vehicle;
  final VoidCallback onAdd;
  final ValueChanged<FuelEntry> onEdit;
  final Future<bool> Function(FuelEntry) onDelete;
  final VoidCallback onVehicle;
  final VoidCallback onSettings;
  final VoidCallback onRetry;
  final VoidCallback onAddVehicle;
  final bool loading;
  final FuelConsumptionUnit consumptionUnit;
  final bool loadError;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  @override
  State<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends State<FuelScreen> {
  bool _deleting = false;
  AppLocalizations get l => AppLocalizations.of(context);
  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/fuel_screen.dart';
  }

  String _date(FuelEntry e) {
    final date = e.date.toLocal();
    final n = MaterialLocalizations.of(context);
    return '${n.formatMediumDate(date)} · ${n.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  String _status(FuelEntry e) => l.fuel(
    e.fullTank == null
        ? 'unknown'
        : e.fullTank!
        ? 'full'
        : 'partial',
  );

  Future<void> _details(FuelEntry entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.fuel('view'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(widget.vehicle!.name),
              Text(_date(entry)),
              Text(
                '${entry.odometer} ${l.kilometers} · ${entry.grade} · ${_status(entry)}',
              ),
              Text(
                '${entry.liters.toStringAsFixed(3)} ${l.fuel('litersUnit')} · ${entry.cost.toStringAsFixed(2)} ${l.fuel('egp')}',
              ),
              Text(
                '${l.fuel('effective')}: ${entry.pricePerLiter.toStringAsFixed(6)}',
              ),
              if (entry.recordedPrice != null)
                Text('${l.fuel('price')}: ${entry.recordedPrice}'),
              if (entry.note.isNotEmpty) Text(entry.note),
              if (entry.breaksConsumption) Text(l.fuel('gap')),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('fuel-edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.pop(sheet, 'edit'),
                label: Text(l.edit),
              ),
              TextButton.icon(
                key: const Key('fuel-delete'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => Navigator.pop(sheet, 'delete'),
                label: Text(l.fuel('deleteAction')),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') widget.onEdit(entry);
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l.fuel('delete')),
          content: Text(l.fuel('deleteBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const Key('fuel-confirm-delete'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.fuel('deleteAction')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || _deleting) return;
      setState(() => _deleting = true);
      var success = false;
      try {
        success = await widget.onDelete(entry);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _deleting = false);
      if (!success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.fuel('deletedError'))));
      }
    }
  }

  Widget _summary(String title, String value, {String? detail, Key? key}) =>
      Card(
        key: key,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              if (detail != null) Text(detail),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final entries = vehicle == null
        ? <FuelEntry>[]
        : FuelCalculations.ordered(
            vehicle.garage.fuelEntries,
            vehicle.id,
          ).reversed.toList();
    final intervals = vehicle == null
        ? <FuelInterval>[]
        : FuelCalculations.intervals(entries, vehicle.id);
    final latest = intervals.isEmpty ? null : intervals.last;
    final total = entries.fold(0.0, (sum, e) => sum + e.cost);
    return Scaffold(
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.fuelTab,
                      key: const Key('fuel-page-title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onSettings,
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: l.settingsTitle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.loading
                  ? Center(
                      child: Semantics(
                        label: l.loadingGarage,
                        child: const CircularProgressIndicator(),
                      ),
                    )
                  : widget.loadError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.garageLoadFailed),
                          TextButton(
                            onPressed: widget.onRetry,
                            child: Text(l.retry),
                          ),
                        ],
                      ),
                    )
                  : vehicle == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.noVehiclesYet),
                          FilledButton(
                            onPressed: widget.onAddVehicle,
                            child: Text(l.addVehicle),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 56),
                      children: [
                        Card(
                          child: ListTile(
                            key: const Key('fuel-vehicle'),
                            leading: const Icon(Icons.directions_car_outlined),
                            title: Text(vehicle.name),
                            subtitle: Text(
                              '${l.fuel('usualGrade')}: ${vehicle.fuelPreferences.usualGrade}',
                            ),
                            trailing: const Icon(Icons.expand_more),
                            onTap: widget.onVehicle,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('fuel-add'),
                          onPressed: widget.onAdd,
                          icon: const Icon(Icons.add),
                          label: Text(l.fuel('add')),
                        ),
                        if (entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(l.noFuelEntries),
                          ),
                        const SizedBox(height: 12),
                        _summary(
                          l.fuel('latest'),
                          entries.isEmpty
                              ? l.fuel('none')
                              : _date(entries.first),
                          detail: entries.isEmpty
                              ? null
                              : '${entries.first.liters.toStringAsFixed(3)} ${l.fuel('litersUnit')} · ${entries.first.cost.toStringAsFixed(2)} ${l.fuel('egp')}',
                        ),
                        _summary(
                          l.fuel('spending'),
                          '${total.toStringAsFixed(2)} ${l.fuel('egp')}',
                          key: const Key('fuel-total-spending'),
                        ),
                        _summary(
                          l.fuel('economy'),
                          latest == null
                              ? '—'
                              : '${widget.consumptionUnit.fromKmPerLiter(latest.kmPerLiter).toStringAsFixed(2)} ${l.fuel(widget.consumptionUnit.labelKey)}',
                          detail: latest == null
                              ? l.fuel('needsFull')
                              : _date(
                                  entries.firstWhere(
                                    (e) => e.id == latest.endId,
                                  ),
                                ),
                          key: const Key('fuel-consumption'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.fuel('history'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final entry in entries)
                          Card(
                            key: Key('fuel-record-${entry.id}'),
                            child: ListTile(
                              enabled: !_deleting,
                              isThreeLine: true,
                              onTap: () => _details(entry),
                              title: Text(
                                '${entry.cost.toStringAsFixed(2)} ${l.fuel('egp')} · ${entry.liters.toStringAsFixed(3)} ${l.fuel('litersUnit')}',
                              ),
                              subtitle: Text(
                                '${_date(entry)}\n${entry.odometer} ${l.kilometers} · ${entry.grade} · ${_status(entry)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
