import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/service_item.dart';
import '../theme/app_tokens.dart';
import '../widgets/card_action_menu.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/gear_text_field.dart';
import '../widgets/service_picker_card.dart';
import 'service_form_screen.dart';

/// High-level section a [ServicePreset] belongs to in the picker.
enum ServicePresetCategory { engine, fluids, brakesAndTires, electrical, other }

class ServicePreset {
  const ServicePreset({
    required this.name,
    required this.iconKey,
    required this.icon,
    required this.category,
  });

  final String name;
  final String iconKey;
  final IconData icon;
  final ServicePresetCategory category;
}

const servicePresets = <ServicePreset>[
  ServicePreset(
    name: 'Engine oil',
    iconKey: 'oil',
    icon: Icons.oil_barrel,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Oil filter',
    iconKey: 'oil_filter',
    icon: Icons.oil_barrel,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Air filter',
    iconKey: 'air_filter',
    icon: Icons.air,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Cabin filter',
    iconKey: 'cabin_filter',
    icon: Icons.air_outlined,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Brake pads',
    iconKey: 'brake_pads',
    icon: Icons.car_repair,
    category: ServicePresetCategory.brakesAndTires,
  ),
  ServicePreset(
    name: 'Brake fluid',
    iconKey: 'brake_fluid',
    icon: Icons.opacity,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Tire rotation and alignment',
    iconKey: 'tires',
    icon: Icons.tire_repair,
    category: ServicePresetCategory.brakesAndTires,
  ),
  ServicePreset(
    name: 'Battery',
    iconKey: 'battery',
    icon: Icons.battery_full,
    category: ServicePresetCategory.electrical,
  ),
  ServicePreset(
    name: 'Spark plugs',
    iconKey: 'spark_plugs',
    icon: Icons.bolt,
    category: ServicePresetCategory.engine,
  ),
  ServicePreset(
    name: 'Coolant',
    iconKey: 'coolant',
    icon: Icons.water_drop,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Transmission fluid',
    iconKey: 'transmission_fluid',
    icon: Icons.settings,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Power steering fluid',
    iconKey: 'power_steering',
    icon: Icons.water_drop_outlined,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'Timing belt / chain inspection',
    iconKey: 'timing_belt',
    icon: Icons.timer_outlined,
    category: ServicePresetCategory.engine,
  ),
  ServicePreset(
    name: 'Drive belts',
    iconKey: 'drive_belts',
    icon: Icons.sync_alt,
    category: ServicePresetCategory.engine,
  ),
  ServicePreset(
    name: 'Wiper blades',
    iconKey: 'wipers',
    icon: Icons.visibility,
    category: ServicePresetCategory.other,
  ),
  ServicePreset(
    name: 'Suspension / shocks inspection',
    iconKey: 'suspension',
    icon: Icons.height,
    category: ServicePresetCategory.other,
  ),
  ServicePreset(
    name: 'Fuel filter',
    iconKey: 'fuel_filter',
    icon: Icons.local_gas_station,
    category: ServicePresetCategory.fluids,
  ),
  ServicePreset(
    name: 'AC service',
    iconKey: 'ac',
    icon: Icons.ac_unit,
    category: ServicePresetCategory.electrical,
  ),
];

const tireHealthPreset = ServicePreset(
  name: 'Tire health',
  iconKey: 'tire_health',
  icon: Icons.tire_repair,
  category: ServicePresetCategory.brakesAndTires,
);

final servicePickerPresets = <ServicePreset>[
  ...servicePresets,
  tireHealthPreset,
];

const customServiceIconLibrary = <ServicePreset>[
  ServicePreset(
    name: 'General maintenance',
    iconKey: 'maintenance',
    icon: Icons.build_outlined,
    category: ServicePresetCategory.other,
  ),
  ...servicePresets,
];

final servicePresetNames = servicePresets
    .map((preset) => preset.name)
    .toList(growable: false);

/// Display order of the picker's preset sections.
const servicePresetCategoryOrder = <ServicePresetCategory>[
  ServicePresetCategory.fluids,
  ServicePresetCategory.brakesAndTires,
  ServicePresetCategory.engine,
  ServicePresetCategory.electrical,
  ServicePresetCategory.other,
];

String servicePresetCategoryLabel(
  AppLocalizations l10n,
  ServicePresetCategory category,
) => switch (category) {
  ServicePresetCategory.engine => l10n.presetGroupEngine,
  ServicePresetCategory.fluids => l10n.presetGroupFluids,
  ServicePresetCategory.brakesAndTires => l10n.presetGroupBrakesAndTires,
  ServicePresetCategory.electrical => l10n.presetGroupElectrical,
  ServicePresetCategory.other => l10n.presetGroupOther,
};

String servicePresetDisplayName(AppLocalizations l10n, ServicePreset preset) =>
    l10n.servicePresetName(preset.iconKey, preset.name);

/// Case-insensitive, whitespace-trimmed preset search.
///
/// Pure so the matching rule can be tested without rendering the picker.
List<ServicePreset> filterServicePresets(
  String query, [
  AppLocalizations? l10n,
]) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return servicePickerPresets;
  return servicePickerPresets
      .where((preset) {
        final name = l10n == null
            ? preset.name
            : servicePresetDisplayName(l10n, preset);
        return name.toLowerCase().contains(normalized) ||
            preset.name.toLowerCase().contains(normalized);
      })
      .toList(growable: false);
}

/// Returned by [AddServiceScreen] when the user chooses to start tracking the
/// vehicle's four tire positions.
class TireHealthAdded {
  const TireHealthAdded();
}

/// Returned when the user removes the vehicle's tire tracking.
class TireHealthRemoved {
  const TireHealthRemoved();
}

/// Returned when the user removes an already-added service.
class ServiceRemoved {
  const ServiceRemoved(this.serviceId);
  final String serviceId;
}

/// Lets the user select a default service or start a custom service.
class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({
    super.key,
    this.currentOdometer = 0,
    this.existingServices = const [],
    this.hasTires = false,
    this.recordingService,
    this.openCustomServiceDirectly = false,
  });

  final int currentOdometer;
  final List<ServiceItem> existingServices;

  /// Whether the active vehicle already tracks tire health.
  final bool hasTires;
  final ServiceItem? recordingService;
  final bool openCustomServiceDirectly;

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/add_service_screen.dart';
    if (widget.openCustomServiceDirectly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCustomService();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchExpanded = true);
  }

  Future<void> _openForm({
    String? presetName,
    required String iconKey,
    required IconData icon,
    ServiceType serviceType = ServiceType.type01,
    ServiceItem? recordingService,
  }) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
          currentOdometer: widget.currentOdometer,
          initialServiceName: presetName,
          initialIconKey: iconKey,
          initialIcon: icon,
          serviceType: serviceType,
          existingServiceNames: widget.existingServices.map(
            (service) => service.name,
          ),
          recordingService: recordingService,
          returnToDashboardOnBack: widget.openCustomServiceDirectly,
        ),
      ),
    );
    if (!mounted || result == null) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _openCustomService() async {
    final selectedIcon = await Navigator.of(context).push<ServicePreset>(
      MaterialPageRoute(
        builder: (_) => _CustomServiceIconPicker(
          returnToDashboardOnBack: widget.openCustomServiceDirectly,
        ),
      ),
    );
    if (!mounted || selectedIcon == null) return;
    await _openForm(iconKey: selectedIcon.iconKey, icon: selectedIcon.icon);
  }

  /// Finds the already-added service that matches a preset, if any.
  ServiceItem? _addedServiceFor(ServicePreset preset) {
    for (final service in widget.existingServices) {
      if (service.iconKey == preset.iconKey ||
          (preset.iconKey == 'oil' && service.id == 'engine-oil')) {
        return service;
      }
    }
    return null;
  }

  Future<void> _confirmRemove({
    required String title,
    required String message,
    required Object result,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            key: const Key('confirm-remove-service-button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(dialogContext).delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _removeAddedService(ServiceItem addedService) {
    final l10n = AppLocalizations.of(context);
    _confirmRemove(
      title: l10n.deleteServiceWithName(addedService.name),
      message: l10n.serviceDataLostMessage,
      result: ServiceRemoved(addedService.id),
    );
  }

  Widget _presetCard(AppLocalizations l10n, ServicePreset preset) {
    if (preset.iconKey == tireHealthPreset.iconKey) {
      return _tireHealthCard(l10n);
    }
    final addedService = _addedServiceFor(preset);
    final isRecordingTarget =
        widget.recordingService != null &&
        addedService != null &&
        widget.recordingService!.id == addedService.id;
    return ServicePickerCard(
      key: Key('service-preset-${preset.iconKey}'),
      title: servicePresetDisplayName(l10n, preset),
      subtitle: l10n.servicePresetDescription(preset.iconKey),
      icon: preset.icon,
      isSelected: addedService != null,
      onTap: isRecordingTarget
          ? () => _openForm(
              presetName: addedService.name,
              iconKey: addedService.iconKey,
              icon: addedService.icon,
              serviceType: addedService.type,
              recordingService: addedService,
            )
          : addedService == null
          ? () => _openForm(
              presetName: servicePresetDisplayName(l10n, preset),
              iconKey: preset.iconKey,
              icon: preset.icon,
            )
          : null,
      onLongPress: addedService == null || isRecordingTarget
          ? null
          : () => _removeAddedService(addedService),
      trailing: addedService == null || isRecordingTarget
          ? null
          : CardActionMenu(
              key: Key('service-preset-menu-${preset.iconKey}'),
              tooltip: l10n.serviceMenuTooltip,
              actions: [
                CardActionMenuAction(
                  value: 'remove',
                  icon: Icons.delete_outline,
                  label: l10n.removeAction,
                  isDestructive: true,
                  onSelected: () => _removeAddedService(addedService),
                ),
              ],
            ),
    );
  }

  Widget _tireHealthCard(AppLocalizations l10n) {
    return ServicePickerCard(
      key: const Key('tire-health-service-card'),
      title: l10n.tireHealthService,
      subtitle:
          '${l10n.tireHealthDescription} · ${widget.hasTires ? l10n.tireHealthTrackedSubtitle : l10n.tireHealthAddSubtitle}',
      icon: Icons.tire_repair,
      isSelected: widget.hasTires,
      onTap: () => Navigator.of(context).pop(const TireHealthAdded()),
      onLongPress: widget.hasTires
          ? () => _confirmRemove(
              title: l10n.deleteTireHealthQuestion,
              message: l10n.tireHealthDataLostMessage,
              result: const TireHealthRemoved(),
            )
          : null,
      trailing: widget.hasTires
          ? CardActionMenu(
              key: const Key('tire-health-service-menu'),
              tooltip: l10n.serviceMenuTooltip,
              actions: [
                CardActionMenuAction(
                  value: 'remove',
                  icon: Icons.delete_outline,
                  label: l10n.removeAction,
                  isDestructive: true,
                  onSelected: () => _confirmRemove(
                    title: l10n.deleteTireHealthQuestion,
                    message: l10n.tireHealthDataLostMessage,
                    result: const TireHealthRemoved(),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  /// Builds the searchable preset list, grouped into labeled sections.
  ///
  /// Empty sections are hidden so a search narrows the list without leaving
  /// orphaned headings behind.
  List<Widget> _presetSections(AppLocalizations l10n) {
    final matches = filterServicePresets(_query, l10n);
    if (matches.isEmpty) {
      return [
        Padding(
          key: const Key('no-service-presets-message'),
          padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceLg),
          child: Text(
            l10n.noServicesMatch,
            style: AppTokens.bodyStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    for (final category in servicePresetCategoryOrder) {
      final categoryPresets = matches
          .where((preset) => preset.category == category)
          .toList();
      if (categoryPresets.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
          child: Semantics(
            key: Key('service-preset-group-${category.name}'),
            header: true,
            container: true,
            child: Text(
              servicePresetCategoryLabel(l10n, category),
              style: AppTokens.bodyStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: AppTokens.fontWeightSemiBold,
                letterSpacing: AppTokens.letterSpacingCaps,
              ),
            ),
          ),
        ),
      );
      for (final preset in categoryPresets) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
            child: _presetCard(l10n, preset),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              alignment: AlignmentDirectional.centerStart,
              child: child,
            ),
          ),
          child: _searchExpanded
              ? GearTextField(
                  key: const ValueKey('service-preset-search-field'),
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.searchServicesHint,
                    isDense: true,
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      tooltip: l10n.cancel,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _searchExpanded = false;
                        });
                      },
                    ),
                  ),
                )
              : Text(
                  widget.recordingService == null
                      ? l10n.addServiceTitle
                      : l10n.recordServiceTitle,
                ),
        ),
        actions: [
          if (!_searchExpanded)
            IconButton(
              key: const ValueKey('service-preset-search-button'),
              tooltip: l10n.searchServicesHint,
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ServicePickerCard(
              key: const Key('start-custom-service-button'),
              title: l10n.customService,
              subtitle: l10n.customServiceDescription,
              icon: Icons.build_outlined,
              onTap: widget.recordingService == null
                  ? _openCustomService
                  : () => _openForm(
                      presetName: widget.recordingService!.name,
                      iconKey: widget.recordingService!.iconKey,
                      icon: widget.recordingService!.icon,
                      serviceType: widget.recordingService!.type,
                      recordingService: widget.recordingService,
                    ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 4),
            ..._presetSections(l10n),
          ],
        ),
      ),
    );
  }
}

class _CustomServiceIconPicker extends StatelessWidget {
  const _CustomServiceIconPicker({this.returnToDashboardOnBack = false});

  final bool returnToDashboardOnBack;

  void _handleBack(BuildContext context) {
    if (returnToDashboardOnBack) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<Object>(
      canPop: !returnToDashboardOnBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && returnToDashboardOnBack) _handleBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chooseIcon),
          leading: returnToDashboardOnBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _handleBack(context),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Text(
                  l10n.chooseIconInstruction,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  key: const Key('custom-service-icon-auto'),
                  onPressed: () => Navigator.of(context).pop(
                    const ServicePreset(
                      name: 'General maintenance',
                      iconKey: 'maintenance',
                      icon: Icons.build_outlined,
                      category: ServicePresetCategory.other,
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(l10n.useAutomaticIcon),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 600 ? 4 : 3;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: .9,
                      ),
                      itemCount: customServiceIconLibrary.length,
                      itemBuilder: (context, index) {
                        final icon = customServiceIconLibrary[index];
                        return _CustomServiceIconTile(
                          icon: icon,
                          displayName: l10n.servicePresetName(
                            icon.iconKey,
                            icon.name,
                          ),
                          onTap: () => Navigator.of(context).pop(icon),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomServiceIconTile extends StatelessWidget {
  const _CustomServiceIconTile({
    required this.icon,
    required this.displayName,
    required this.onTap,
  });

  final ServicePreset icon;
  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: displayName,
      hint: AppLocalizations.of(context).useIconHint,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: .45)),
            ),
            child: InkWell(
              key: Key('custom-service-icon-${icon.iconKey}'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              focusColor: color.withValues(alpha: .18),
              hoverColor: color.withValues(alpha: .08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon.icon, color: color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
