import 'package:flutter/material.dart';

import '../models/service_item.dart';
import '../models/service_form_input.dart';
import '../models/service_history_entry.dart';
import '../l10n/app_localizations.dart';
import '../preferences/display_preferences.dart';
import 'history_screen.dart';
import '../theme/app_tokens.dart';
import '../widgets/current_odometer_label.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/date_input.dart';
import '../widgets/tracking_mode_selector.dart';
import '../widgets/gear_text_field.dart';
import '../widgets/time_preset_chip.dart';

class ServiceCompletionResult {
  const ServiceCompletionResult({
    required this.updatedService,
    required this.historyEntry,
  });

  final ServiceItem updatedService;
  final ServiceHistoryEntry historyEntry;
}

class EditServiceScreen extends StatefulWidget {
  const EditServiceScreen({
    super.key,
    required this.service,
    required this.currentOdometer,
    this.allowDelete = false,
    this.history = const [],
    this.openCompletionOnLaunch = false,
  });

  final ServiceItem service;
  final int currentOdometer;
  final bool allowDelete;
  final List<ServiceHistoryEntry> history;
  final bool openCompletionOnLaunch;

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _intervalController;
  late final TextEditingController _installKmController;
  late final TextEditingController _shelfLifeMonthsController;
  late DateTime _installDate;
  late ServiceTrackingMode _trackingMode;
  late String _iconKey;
  bool _showOptionalDetails = false;
  bool _showGuidance = true;
  bool _hasChanges = false;

  bool get _isCustomService => widget.service.isCustomService;

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/edit_service_screen.dart';
    _nameController = TextEditingController(text: widget.service.name);
    _noteController = TextEditingController(text: widget.service.note);
    _intervalController = TextEditingController(
      text: widget.service.intervalKm?.toString() ?? '',
    );
    _installKmController = TextEditingController(
      text:
          widget.service.serviceOdometer?.toString() ??
          widget.currentOdometer.toString(),
    );
    _shelfLifeMonthsController = TextEditingController(
      text: widget.service.shelfLifeMonths?.toString() ?? '',
    );
    _trackingMode = widget.service.tracksMileage && widget.service.tracksTime
        ? ServiceTrackingMode.mileageAndTime
        : widget.service.tracksTime
        ? ServiceTrackingMode.time
        : ServiceTrackingMode.mileage;
    _installDate = widget.service.installDate ?? DateTime.now();
    _iconKey = widget.service.iconKey;
    _showOptionalDetails = false;
    _loadGuidancePreference();
    if (widget.openCompletionOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCompletionForm();
      });
    }
  }

  Future<void> _loadGuidancePreference() async {
    final value = await DisplayPreferences.loadShowGuidance();
    if (mounted) setState(() => _showGuidance = value);
  }

  void _markChanged([String? _]) {
    setState(() => _hasChanges = true);
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
    _installKmController.dispose();
    _shelfLifeMonthsController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      widget.service.copyWith(
        name: _nameController.text.trim(),
        note: _noteController.text.trim(),
        iconKey: _iconKey,
        intervalKm: _tracksMileage
            ? int.parse(_intervalController.text.trim())
            : null,
        serviceOdometer: _tracksMileage
            ? int.parse(_installKmController.text.trim())
            : null,
        installDate: _tracksTime ? _installDate : null,
        shelfLifeMonths: _tracksTime
            ? int.parse(_shelfLifeMonthsController.text.trim())
            : null,
        units: widget.service.type == ServiceType.type02
            ? [
                for (final unit in widget.service.units)
                  ServiceUnit(
                    position: unit.position,
                    installOdometer: int.parse(
                      _installKmController.text.trim(),
                    ),
                  ),
              ]
            : const [],
      ),
    );
  }

  Future<void> _openCompletionForm() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.service.tracksMileage) {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      Navigator.pop(
        context,
        ServiceCompletionResult(
          updatedService: widget.service.copyWith(
            serviceOdometer: null,
            installDate: day,
            units: const [],
          ),
          historyEntry: ServiceHistoryEntry(
            id: _newCompletionEventId(),
            serviceId: widget.service.id,
            serviceName: widget.service.name,
            previousServiceOdometer: null,
            completedOdometer: null,
            newNote: widget.service.note,
            newIntervalKm: null,
            completedAt: day,
          ),
        ),
      );
      return;
    }
    final controller = TextEditingController(
      text: widget.service.tracksMileage
          ? widget.currentOdometer.toString()
          : '',
    );
    var completedAt = DateTime.now();
    String? error;
    final result = await showDialog<ServiceCompletionResult>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final minimum = widget.service.serviceOdometer ?? 0;
          final maximum = widget.currentOdometer;
          final numbers = MaterialLocalizations.of(context);
          final minimumLabel = numbers.formatDecimal(minimum);
          final maximumLabel = numbers.formatDecimal(maximum);
          return Material(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .72,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.markServiceServiced(widget.service.name),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (widget.service.tracksMileage)
                          TextField(
                            key: const Key('service-completion-km-field'),
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.completedKmLabel,
                              helperText: l10n.completionKmHelperText(
                                minimumLabel,
                                maximumLabel,
                              ),
                              errorText: error,
                            ),
                          ),
                        const SizedBox(height: 8),
                        DateInput(
                          value: completedAt,
                          onChanged: (value) =>
                              setSheetState(() => completedAt = value),
                          label: l10n.completedOn,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 15),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 15),
                          ),
                          fieldKey: const Key('service-completion-date-button'),
                          sheetKey: const Key('service-completion-date-sheet'),
                          wheelKey: const Key('service-completion-date-wheel'),
                          doneKey: const Key('service-completion-date-done'),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('service-completion-confirm-button'),
                          onPressed: () {
                            final completedOdometer =
                                widget.service.tracksMileage
                                ? int.tryParse(controller.text.trim())
                                : null;
                            if (widget.service.tracksMileage &&
                                (completedOdometer == null ||
                                    completedOdometer < minimum ||
                                    completedOdometer > maximum)) {
                              setSheetState(
                                () => error = l10n.enterCompletionKmRange(
                                  minimumLabel,
                                  maximumLabel,
                                ),
                              );
                              return;
                            }
                            final updatedService = widget.service.copyWith(
                              serviceOdometer: completedOdometer,
                              installDate: DateTime(
                                completedAt.year,
                                completedAt.month,
                                completedAt.day,
                              ),
                              units:
                                  widget.service.type == ServiceType.type02 &&
                                      completedOdometer != null
                                  ? [
                                      for (final unit in widget.service.units)
                                        ServiceUnit(
                                          position: unit.position,
                                          installOdometer: completedOdometer,
                                        ),
                                    ]
                                  : const [],
                            );
                            Navigator.pop(
                              sheetContext,
                              ServiceCompletionResult(
                                updatedService: updatedService,
                                historyEntry: ServiceHistoryEntry(
                                  id: _newCompletionEventId(),
                                  serviceId: widget.service.id,
                                  serviceName: widget.service.name,
                                  previousServiceOdometer:
                                      widget.service.serviceOdometer,
                                  completedOdometer: completedOdometer,
                                  newNote: widget.service.note,
                                  newIntervalKm: widget.service.intervalKm,
                                  completedAt: DateTime(
                                    completedAt.year,
                                    completedAt.month,
                                    completedAt.day,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text(l10n.confirmService),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result != null && mounted) Navigator.pop(context, result);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteServiceQuestion),
        content: Text(l10n.removeService(widget.service.name)),
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
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, ServiceEditResult.delete);
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          history: widget.history,
          serviceId: widget.service.id,
          serviceName: widget.service.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _confirmDiscard() || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.editServiceTitle),
          actions: [
            Semantics(
              button: true,
              label: l10n.viewHistory(widget.service.name),
              child: SizedBox(
                width: AppTokens.tapTargetSize,
                height: AppTokens.tapTargetSize,
                child: IconButton(
                  key: const Key('edit-service-history-button'),
                  onPressed: _openHistory,
                  tooltip: l10n.viewHistory(widget.service.name),
                  icon: const Icon(Icons.history_outlined),
                ),
              ),
            ),
            if (widget.allowDelete)
              IconButton(
                key: const Key('edit-service-delete-app-bar-button'),
                onPressed: _delete,
                tooltip: l10n.deleteService,
                color: colors.error,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CurrentOdometerLabel(odometer: widget.currentOdometer),
                const SizedBox(height: 0),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ServiceItem.iconForKey(_iconKey),
                            color: colors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.service.name,
                              style: AppTokens.sectionTitleStyle,
                            ),
                          ),
                          if (_isCustomService)
                            TextButton.icon(
                              key: const Key('edit-service-change-icon-button'),
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
                        key: const Key('service-name-field'),
                        controller: _nameController,
                        readOnly: !_isCustomService,
                        onChanged: _markChanged,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: l10n.serviceName,
                          border: const OutlineInputBorder(),
                        ),
                        validator: _requiredField(l10n.enterServiceName),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const Key('edit-service-optional-details-toggle'),
                        onPressed: () => setState(() {
                          _showOptionalDetails = !_showOptionalDetails;
                          _hasChanges = true;
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
                      if (_showOptionalDetails) ...[
                        const SizedBox(height: 8),
                        GearTextField(
                          key: const Key('service-note-field'),
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
                const SizedBox(height: 16),
                TrackingModeSelector(
                  value: _trackingMode,
                  mileageComplete: _mileageInputsComplete,
                  timeComplete: _timeInputsComplete,
                  onChanged: (value) => setState(() {
                    _trackingMode = value;
                    _hasChanges = true;
                  }),
                ),
                const SizedBox(height: 16),
                if (_tracksMileage)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_tracksMileage)
                          GearTextField(
                            key: const Key('service-install-km-field'),
                            controller: _installKmController,
                            onChanged: _markChanged,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.installKm,
                              suffixText: l10n.kilometersFieldSuffix,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) => switch (installKmProblem(
                              value ?? '',
                              currentOdometer: widget.currentOdometer,
                            )) {
                              null => null,
                              ServiceFieldProblem.odometerAheadOfCurrent =>
                                l10n.installKmCannotExceedCurrent,
                              _ => l10n.enterValidInstallKm,
                            },
                          ),
                        const SizedBox(height: 16),
                        GearTextField(
                          key: const Key('service-interval-field'),
                          controller: _intervalController,
                          onChanged: _markChanged,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.serviceInterval,
                            suffixText: l10n.kilometersFieldSuffix,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              positiveIntProblem(value ?? '') == null
                              ? null
                              : l10n.enterPositiveServiceInterval,
                        ),
                      ],
                    ),
                  ),
                if (_tracksMileage && _tracksTime) const SizedBox(height: 16),
                if (_tracksTime)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
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
                          fieldKey: const Key('service-install-date-button'),
                          sheetKey: const Key('service-install-date-sheet'),
                          wheelKey: const Key('service-install-date-wheel'),
                          cancelKey: const Key('service-install-date-cancel'),
                          doneKey: const Key('service-install-date-done'),
                        ),
                        const SizedBox(height: 16),
                        GearTextField(
                          key: const Key('service-shelf-life-months-field'),
                          controller: _shelfLifeMonthsController,
                          onChanged: _markChanged,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.repeatEvery,
                            suffixText: l10n.months,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              positiveIntProblem(value ?? '') == null
                              ? null
                              : l10n.enterPositiveShelfLife,
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
                  const SizedBox(height: 8),
                  Tooltip(
                    message: l10n.serviceConfigurationInstruction,
                    child: Text(
                      l10n.serviceConfigurationInstruction,
                      style: AppTokens.bodyStyle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Tooltip(
                    message: l10n.intervalEstimateNote,
                    child: Text(
                      l10n.intervalEstimateNote,
                      style: AppTokens.bodyStyle.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('save-service-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(l10n.saveChanges),
          ),
        ),
      ),
    );
  }

  String? Function(String?) _requiredField(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

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
}

enum ServiceEditResult { delete }

String _newCompletionEventId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  return 'service-$timestamp';
}
