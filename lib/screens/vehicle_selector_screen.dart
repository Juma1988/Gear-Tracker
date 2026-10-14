import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/vehicle_profile.dart';
import '../widgets/card_action_menu.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/service_picker_card.dart';
import 'add_vehicle_screen.dart';

/// Outcome of the vehicle selector: either an existing vehicle was chosen or a
/// new clean profile should be created.
sealed class VehicleSelectionResult {
  const VehicleSelectionResult();
}

final class VehicleSelected extends VehicleSelectionResult {
  const VehicleSelected(this.vehicleId);
  final String vehicleId;
}

final class VehicleCreated extends VehicleSelectionResult {
  const VehicleCreated(this.vehicle);
  final VehicleProfile vehicle;
}

final class VehicleUpdated extends VehicleSelectionResult {
  const VehicleUpdated(this.vehicle);
  final VehicleProfile vehicle;
}

class VehicleSelectorScreen extends StatelessWidget {
  const VehicleSelectorScreen({
    super.key,
    required this.vehicles,
    required this.selectedVehicleId,
  });

  final List<VehicleProfile> vehicles;
  final String selectedVehicleId;

  Future<void> _addVehicle(BuildContext context) async {
    final created = await Navigator.of(context).push<VehicleProfile>(
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );
    if (!context.mounted || created == null) return;
    Navigator.of(context).pop(VehicleCreated(created));
  }

  Future<void> _editVehicle(
    BuildContext context,
    VehicleProfile vehicle,
  ) async {
    final updated = await Navigator.of(context).push<VehicleProfile>(
      MaterialPageRoute(builder: (_) => AddVehicleScreen(initial: vehicle)),
    );
    if (!context.mounted || updated == null) return;
    Navigator.of(context).pop(VehicleUpdated(updated));
  }

  @override
  Widget build(BuildContext context) {
    DevOverlay.currentFilePath = 'lib/screens/vehicle_selector_screen.dart';
    final l10n = AppLocalizations.of(context);
    final numbers = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.yourVehicles)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (vehicles.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 44,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noVehiclesYet,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.createCleanProfile,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (vehicles.isEmpty) const SizedBox(height: 16),
            for (final vehicle in vehicles) ...[
              ServicePickerCard(
                key: Key('vehicle-card-${vehicle.id}'),
                title: vehicle.name,
                subtitle:
                    '${numbers.formatDecimal(vehicle.garage.odometer)} ${l10n.kilometers}',
                icon: Icons.directions_car_filled,
                isSelected: vehicle.id == selectedVehicleId,
                onTap: () =>
                    Navigator.of(context).pop(VehicleSelected(vehicle.id)),
                onLongPress: () => _editVehicle(context, vehicle),
                trailing: CardActionMenu(
                  key: Key('vehicle-menu-${vehicle.id}'),
                  tooltip: l10n.vehicleMenuTooltip,
                  actions: [
                    CardActionMenuAction(
                      value: 'edit',
                      icon: Icons.edit_outlined,
                      label: l10n.editVehicle,
                      onSelected: () => _editVehicle(context, vehicle),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            ServicePickerCard(
              key: const Key('add-vehicle-card'),
              title: l10n.addVehicle,
              subtitle: l10n.createCleanProfile,
              icon: Icons.add,
              onTap: () => _addVehicle(context),
            ),
          ],
        ),
      ),
    );
  }
}
