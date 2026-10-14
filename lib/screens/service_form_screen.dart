import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_localizations.dart';
import '../models/service_form_input.dart';
import '../models/service_item.dart';
import '../preferences/display_preferences.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/date_input.dart';
import '../widgets/tracking_mode_selector.dart';
import '../widgets/gear_text_field.dart';
import '../widgets/time_preset_chip.dart';

/// Collects editable details for a blank or preset-named service.
class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({
    super.key,
    required this.currentOdometer,
    this.initialServiceName,
    this.initialIconKey,
    this.initialIcon,
    this.serviceType = ServiceType.type01,
    this.existingServiceNames = const [],
  });

  final int currentOdometer;
  final String? initialServiceName;
  final String? initialIconKey;
  final IconData? initialIcon;
  final ServiceType serviceType;
  final Iterable<String> existingServiceNames;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _noteController = TextEditingController();
  final _intervalController = TextEditingController();
  final _shelfLifeMonthsController = TextEditingController();
  late final TextEditingController _installKmController;
  late DateTime _installDate;
  late String _iconKey;
  ServiceTrackingMode _trackingMode = ServiceTrackingMode.mileage;
  bool _showOptionalDetails = false;
  bool _showGuidance = true;
  bool _hasChanges = false;
  final _mileageGroupKey = GlobalKey();
  final _timeGroupKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/service_form_screen.dart';
    _nameController = TextEditingController(text: widget.initialServiceName);
    _installDate = DateTime.now();
    _iconKey = widget.initialIconKey ?? 'maintenance';
    _installKmController = TextEditingController(
      text: widget.currentOdometer.toString(),
    );
    _loadGuidancePreference();
  }

  Future<void> _loadGuidancePreference() async {
    final value = await DisplayPreferences.loadShowGuidance();
    if (mounted) setState(() => _showGuidance = value);
  }

  void _markChanged([String? _]) {
    setState(() => _hasChanges = true);
  }

  void _selectTrackingMode(ServiceTrackingMode value) {
    setState(() {
      _trackingMode = value;
      _hasChanges = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = value == ServiceTrackingMode.time
          ? _timeGroupKey
          : _mileageGroupKey;
      Scrollable.ensureVisible(
        target.currentContext!,
        alignment: 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.discardChangesQuestion),
            content: Text(l10n.discardChangesMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.discard),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _changeIcon() async {
    const iconKeys = [
      'oil',
      'brake_pads',
      'air_filter',
      'battery',
      'coolant',
      'tires',
      'maintenance',
    ];
    final selectedKey = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final key in iconKeys)
              ListTile(
                leading: Icon(ServiceItem.iconForKey(key)),
                title: Text(
                  AppLocalizations.of(sheetContext).serviceIconLabel(key),
                ),
                onTap: () => Navigator.pop(sheetContext, key),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selectedKey == null) return;
    setState(() {
      _iconKey = selectedKey;
      _hasChanges = true;
    });
  }

  void _setTimePreset(int months) {
    setState(() {
      _shelfLifeMonthsController.text = months.toString();
      _hasChanges = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _intervalController.dispose();
    _shelfLifeMonthsController.dispose();
    _installKmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    if (_isDuplicateName(_nameController.text)) {
      final addAnyway = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.addDuplicateServiceQuestion),
          content: Text(l10n.duplicateServiceMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.addAnyway),
            ),
          ],
        ),
      );
      if (addAnyway != true || !mounted) return;
    }
    Navigator.of(context)
        .pop(_input.toItem(id: _newServiceId(), iconKey: _iconKey));
  }

  /// Raw form state handed to the pure [ServiceFormInput] rules.
  ServiceFormInput get _input => ServiceFormInput(
    name: _nameController.text,
    note: _noteController.text,
    installKm: _installKmController.text,
    intervalKm: _intervalController.text,
    shelfLifeMonths: _shelfLifeMonthsController.text,
    trackingMode: _trackingMode,
    installDate: _installDate,
    currentOdometer: widget.currentOdometer,
  );

  bool _isDuplicateName(String candidate) {
    final normalizedCandidate = _normalizeName(candidate);
    return widget.existingServiceNames.any(
      (name) => _normalizeName(name) == normalizedCandidate,
    );
  }

  String _normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  String _newServiceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _confirmDiscard() || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.addService)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              key: const Key('service-form-scroll-view'),
              primary: false,
              scrollCacheExtent: ScrollCacheExtent.pixels(1000),
              padding: const EdgeInsets.all(16),
              children: [
                _FormSection(
                  title: l10n.serviceDetails,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  ServiceItem.iconForKey(_iconKey),
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.selectedServiceIcon,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  key: const Key(
                                    'service-form-change-icon-button',
                                  ),
                                  onPressed: _changeIcon,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    l10n.changeIcon,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GearTextField(
                              key: const Key('add-service-name-field'),
                              controller: _nameController,
                              onChanged: _markChanged,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: l10n.serviceName,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? l10n.enterServiceName
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              key: const Key(
                                'service-form-optional-details-toggle',
                              ),
                              onPressed: () => setState(() {
                                _markChanged();
                                _showOptionalDetails = !_showOptionalDetails;
                              }),
                              icon: Icon(
                                _showOptionalDetails
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: Text(
                                _showOptionalDetails
                                    ? l10n.hideDetails
                                    : l10n.addNote,
                              ),
                            ),
                            if (_showOptionalDetails ||
                                _noteController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              GearTextField(
                                key: const Key('add-service-note-field'),
                                controller: _noteController,
                                onChanged: _markChanged,
                                decoration: InputDecoration(
                                  labelText: l10n.note,
                                  hintText: l10n.serviceNoteHint,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: l10n.schedule,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TrackingModeSelector(
                        key: const Key('tracking-mode-selector'),
                        value: _trackingMode,
                        mileageComplete: _mileageInputsComplete,
                        timeComplete: _timeInputsComplete,
                        onChanged: _selectTrackingMode,
                      ),
                      const SizedBox(height: 12),
                      if (_tracksMileage)
                        Container(
                          key: _mileageGroupKey,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_tracksMileage)
                                _InstallKmField(
                                  fieldKey: const Key(
                                    'add-service-install-km-field',
                                  ),
                                  controller: _installKmController,
                                  currentOdometer: widget.currentOdometer,
                                  label: l10n.installKm,
                                  kilometersLabel: l10n.kilometersFieldSuffix,
                                  onChanged: _markChanged,
                                ),
                              const SizedBox(height: 16),
                              GearTextField(
                                key: const Key('add-service-interval-field'),
                                controller: _intervalController,
                                onChanged: _markChanged,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.serviceInterval,
                                  suffixText: l10n.kilometersFieldSuffix,
                                  border: const OutlineInputBorder(),
                                ),
                                validator: _validateMileageInterval,
                              ),
                            ],
                          ),
                        ),
                      if (_tracksMileage && _tracksTime)
                        const SizedBox(height: 16),
                      if (_tracksTime)
                        Container(
                          key: _timeGroupKey,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DateInput(
                                value: _installDate,
                                onChanged: (value) => setState(() {
                                  _installDate = value;
                                  _hasChanges = true;
                                }),
                                label: l10n.installedOn,
                                fieldKey: const Key(
                                  'service-install-date-button',
                                ),
                                sheetKey: const Key(
                                  'service-install-date-sheet',
                                ),
                                wheelKey: const Key(
                                  'service-install-date-wheel',
                                ),
                                cancelKey: const Key(
                                  'service-install-date-cancel',
                                ),
                                doneKey: const Key('service-install-date-done'),
                              ),
                              const SizedBox(height: 16),
                              GearTextField(
                                key: const Key(
                                  'add-service-shelf-life-months-field',
                                ),
                                controller: _shelfLifeMonthsController,
                                onChanged: _markChanged,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.repeatEvery,
                                  suffixText: l10n.months,
                                  border: const OutlineInputBorder(),
                                ),
                                validator: _validateShelfLife,
                              ),
                              if (_tracksTime) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TimePresetChip(
                                        label: l10n.timePresetOneYear,
                                        onPressed: () => _setTimePreset(12),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: TimePresetChip(
                                        label: l10n.timePresetTwoYears,
                                        onPressed: () => _setTimePreset(24),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: TimePresetChip(
                                        label: l10n.timePresetThreeYears,
                                        onPressed: () => _setTimePreset(36),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: TimePresetChip(
                                        label: l10n.timePresetFiveYears,
                                        onPressed: () => _setTimePreset(60),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (_showGuidance) ...[
                        const SizedBox(height: 12),
                        Tooltip(
                          message: l10n.intervalEstimateNote,
                          child: Text(
                            l10n.intervalEstimateNote,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: l10n.review,
                  child: _ServicePreview(
                    name: _nameController.text.trim(),
                    icon:
                        widget.initialIcon ?? ServiceItem.iconForKey(_iconKey),
                    tracksMileage: _tracksMileage,
                    tracksTime: _tracksTime,
                    installKm: _installKmController.text.trim(),
                    intervalKm: _intervalController.text.trim(),
                    shelfLifeMonths: _shelfLifeMonthsController.text.trim(),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('service-form-sticky-save-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.addService),
          ),
        ),
      ),
    );
  }

  bool get _tracksMileage =>
      _trackingMode == ServiceTrackingMode.mileage ||
      _trackingMode == ServiceTrackingMode.mileageAndTime;

  bool get _tracksTime =>
      _trackingMode == ServiceTrackingMode.time ||
      _trackingMode == ServiceTrackingMode.mileageAndTime;

  bool get _mileageInputsComplete =>
      installKmProblem(
            _installKmController.text,
            currentOdometer: widget.currentOdometer,
          ) ==
          null &&
      positiveIntProblem(_intervalController.text) == null;

  bool get _timeInputsComplete =>
      positiveIntProblem(_shelfLifeMonthsController.text) == null;

  /// Interval copy is intentionally uniform: a blank field and a
  /// non-positive value both read "enter an interval greater than 0".
  String? _validateMileageInterval(String? value) =>
      _input.problemWithIntervalKm() == null
      ? null
      : AppLocalizations.of(context).enterPositiveServiceInterval;

  /// Shelf life keeps its distinct copy: a blank or non-positive month count
  /// both read as "enter a positive shelf life".
  String? _validateShelfLife(String? value) =>
      _input.problemWithShelfLifeMonths() == null
      ? null
      : AppLocalizations.of(context).enterPositiveShelfLife;
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(color: Colors.transparent, child: child),
      ),
    ],
  );
}

class _InstallKmField extends StatelessWidget {
  const _InstallKmField({
    required this.fieldKey,
    required this.controller,
    required this.currentOdometer,
    required this.label,
    required this.kilometersLabel,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final int currentOdometer;
  final String label;
  final String kilometersLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => GearTextField(
    key: fieldKey,
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      suffixText: kilometersLabel,
      border: const OutlineInputBorder(),
    ),
    validator: (value) => switch (installKmProblem(
      value ?? '',
      currentOdometer: currentOdometer,
    )) {
      null => null,
      ServiceFieldProblem.odometerAheadOfCurrent => AppLocalizations.of(
        context,
      ).installKmCannotExceedCurrent,
      _ => AppLocalizations.of(context).enterValidInstallKm,
    },
  );
}

class _ServicePreview extends StatelessWidget {
  const _ServicePreview({
    required this.name,
    required this.icon,
    required this.tracksMileage,
    required this.tracksTime,
    required this.installKm,
    required this.intervalKm,
    required this.shelfLifeMonths,
  });

  final String name;
  final IconData icon;
  final bool tracksMileage;
  final bool tracksTime;
  final String installKm;
  final String intervalKm;
  final String shelfLifeMonths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.primary;
    final title = name.isEmpty ? l10n.serviceName : name;
    return Semantics(
      container: true,
      label: l10n.servicePreview,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('custom-service-preview'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tracksMileage)
                _SummaryLine(
                  label: l10n.previewInstalled,
                  value: installKm.isEmpty
                      ? l10n.previewEnterInstallKm
                      : l10n.previewValueKm(installKm),
                ),
              if (tracksMileage)
                _SummaryLine(
                  label: l10n.previewMileage,
                  value: intervalKm.isEmpty
                      ? l10n.previewEnterInterval
                      : l10n.previewValueKm(intervalKm),
                ),
              if (tracksTime)
                _SummaryLine(
                  label: l10n.trackingModeTime,
                  value: shelfLifeMonths.isEmpty
                      ? l10n.previewEnterShelfLife
                      : l10n.previewValueMonths(shelfLifeMonths),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      '$label · $value',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
    ),
  );
}
