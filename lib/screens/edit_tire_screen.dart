import 'package:flutter/material.dart';

import '../models/tire_item.dart';
import '../l10n/app_localizations.dart';
import '../preferences/display_preferences.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/gear_text_field.dart';
import '../widgets/date_input.dart';

class EditTireScreen extends StatefulWidget {
  const EditTireScreen({
    super.key,
    required this.tire,
    required this.currentOdometer,
  });

  final TireItem tire;
  final int currentOdometer;

  @override
  State<EditTireScreen> createState() => _EditTireScreenState();
}

class _EditTireScreenState extends State<EditTireScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _installOdometerController;
  late final TextEditingController _intervalController;
  late final TextEditingController _shelfLifeController;
  late DateTime _installDate;
  bool _hasChanges = false;
  bool _showGuidance = true;

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/edit_tire_screen.dart';
    _installOdometerController = TextEditingController(
      text: widget.tire.installOdometer.toString(),
    );
    _intervalController = TextEditingController(
      text: widget.tire.intervalKm.toString(),
    );
    _shelfLifeController = TextEditingController(
      text: (widget.tire.shelfLifeMonths ?? 60).toString(),
    );
    _installDate = widget.tire.installDate;
    _loadGuidancePreference();
  }

  Future<void> _loadGuidancePreference() async {
    final value = await DisplayPreferences.loadShowGuidance();
    if (mounted) setState(() => _showGuidance = value);
  }

  @override
  void dispose() {
    _installOdometerController.dispose();
    _intervalController.dispose();
    _shelfLifeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      widget.tire.copyWith(
        installOdometer: int.parse(_installOdometerController.text.trim()),
        intervalKm: int.parse(_intervalController.text.trim()),
        installDate: _installDate,
        shelfLifeMonths: int.parse(_shelfLifeController.text.trim()),
      ),
    );
  }

  void _markChanged([String? _]) => setState(() => _hasChanges = true);

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

  String _readingValue(
    TextEditingController controller,
    MaterialLocalizations localizations,
  ) {
    final raw = controller.text.trim();
    final value = int.tryParse(raw);
    return value == null ? raw : localizations.formatDecimal(value);
  }

  Widget _reading(String text) => Semantics(
    container: true,
    label: text,
    child: ExcludeSemantics(
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final odometer = material.formatDecimal(widget.currentOdometer);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || await _confirmDiscard() == false || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.editTireTitle(widget.tire.code))),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _reading(l10n.currentOdometer(odometer)),
                      _reading(
                        l10n.installDate(
                          material.formatMediumDate(_installDate),
                        ),
                      ),
                      _reading(
                        '${l10n.installationOdometer}: '
                        '${_readingValue(_installOdometerController, material)} '
                        '${l10n.kilometers}',
                      ),
                      _reading(
                        '${l10n.tireLifespanInterval}: '
                        '${_readingValue(_intervalController, material)} '
                        '${l10n.kilometers}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                        key: const Key('tire-install-odometer-field'),
                        controller: _installOdometerController,
                        keyboardType: TextInputType.number,
                        onChanged: _markChanged,
                        decoration: InputDecoration(
                          labelText: l10n.installationOdometer,
                          suffixText: l10n.kilometersFieldSuffix,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final odometer = int.tryParse(value?.trim() ?? '');
                          if (odometer == null || odometer < 0) {
                            return l10n.enterValidInstallationDistance;
                          }
                          return odometer > widget.currentOdometer
                              ? l10n.installationDistanceCannotExceedCurrent
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GearTextField(
                        key: const Key('tire-interval-field'),
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        onChanged: _markChanged,
                        decoration: InputDecoration(
                          labelText: l10n.tireLifespanInterval,
                          suffixText: l10n.kilometersFieldSuffix,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final interval = int.tryParse(value?.trim() ?? '');
                          return interval == null || interval <= 0
                              ? l10n.enterPositiveTireInterval
                              : null;
                        },
                      ),
                      if (_showGuidance) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.intervalEstimateNote,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GearTextField(
                        key: const Key('tire-shelf-life-field'),
                        controller: _shelfLifeController,
                        keyboardType: TextInputType.number,
                        onChanged: _markChanged,
                        decoration: InputDecoration(
                          labelText: l10n.tireAgeDuration,
                          suffixText: l10n.months,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final months = int.tryParse(value?.trim() ?? '');
                          return months == null || months <= 0
                              ? l10n.enterPositiveDuration
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const Key('save-tire-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(l10n.saveTire),
          ),
        ),
      ),
    );
  }
}
