import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/vehicle_profile.dart';
import 'odometer_card.dart';

class DailyOdometerDialog extends StatefulWidget {
  const DailyOdometerDialog({
    super.key,
    required this.vehicles,
    required this.initialVehicleId,
    required this.onSave,
  });
  final List<VehicleProfile> vehicles;
  final String initialVehicleId;
  final Future<bool> Function(String vehicleId, String value) onSave;
  @override
  State<DailyOdometerDialog> createState() => _DailyOdometerDialogState();
}

class _DailyOdometerDialogState extends State<DailyOdometerDialog> {
  late String _vehicleId = widget.initialVehicleId;
  VehicleProfile get _vehicle =>
      widget.vehicles.firstWhere((vehicle) => vehicle.id == _vehicleId);
  String get _savedValue => _vehicle.garage.odometer.toString().padLeft(6, '0');
  late String _value = _savedValue;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    final reading = int.tryParse(_value);
    if (reading == null ||
        reading < _vehicle.garage.odometer ||
        reading > 999999) {
      setState(() => _error = l.dailyOdometerRangeError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(_vehicleId, _value);
    } catch (_) {}
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = l.changesSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        key: const Key('daily-odometer-dialog'),
        insetPadding: const EdgeInsets.all(16),
        title: Text(l.dailyOdometerTitle),
        scrollable: true,
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('daily-odometer-vehicle'),
                initialValue: _vehicleId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.selectVehicle),
                items: [
                  for (final vehicle in widget.vehicles)
                    DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(
                        vehicle.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (id) {
                        if (id == null || id == _vehicleId) return;
                        setState(() {
                          _vehicleId = id;
                          _value = _savedValue;
                          _error = null;
                        });
                      },
              ),
              const SizedBox(height: 12),
              Text(l.dailyOdometerHint),
              const SizedBox(height: 16),
              AbsorbPointer(
                absorbing: _saving,
                child: KeyedSubtree(
                  key: ValueKey(_vehicleId),
                  child: OdometerCard(
                    key: const Key('daily-odometer-card'),
                    odometer: _value,
                    onChanged: (value) => setState(() => _value = value),
                    saveRevision: 0,
                    lastUpdatedAt: _vehicle.garage.lastUpdatedAt,
                    isDirty: _value != _savedValue,
                    saveStatus: _saving
                        ? l.saving
                        : _value == _savedValue
                        ? l.saved
                        : l.unsavedChanges,
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      key: const Key('daily-odometer-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('daily-odometer-skip'),
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l.notNow),
          ),
          FilledButton(
            key: const Key('daily-odometer-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l.saving : l.saveAction),
          ),
        ],
      ),
    );
  }
}
