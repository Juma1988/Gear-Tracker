import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/tire_item.dart';
import '../widgets/date_input.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/gear_text_field.dart';
import '../widgets/time_preset_chip.dart';

class TireHealthWizardScreen extends StatefulWidget {
  const TireHealthWizardScreen({super.key, required this.currentOdometer});

  final int currentOdometer;

  @override
  State<TireHealthWizardScreen> createState() => _TireHealthWizardScreenState();
}

class _TireHealthWizardScreenState extends State<TireHealthWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _installOdometerController;
  late final TextEditingController _intervalController;
  late final TextEditingController _shelfLifeController;
  late DateTime _installDate;
  var _step = 0;
  final _tires = <TireItem>[];

  String get _positionId => TireItem.positionIds[_step];

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/tire_health_wizard_screen.dart';
    _installOdometerController = TextEditingController(
      text: widget.currentOdometer.toString(),
    );
    _intervalController = TextEditingController();
    _shelfLifeController = TextEditingController();
    _installDate = DateTime.now();
  }

  @override
  void dispose() {
    _installOdometerController.dispose();
    _intervalController.dispose();
    _shelfLifeController.dispose();
    super.dispose();
  }

  void _prefillFrom(TireItem tire) {
    _installOdometerController.text = tire.installOdometer.toString();
    _intervalController.text = tire.intervalKm.toString();
    _shelfLifeController.text = (tire.shelfLifeMonths ?? 60).toString();
    _installDate = tire.installDate;
  }

  void _setShelfLifePreset(int months) {
    setState(() => _shelfLifeController.text = months.toString());
  }

  Widget _groupLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  IconData get _positionIcon => Icons.directions_car_filled;

  Future<void> _next() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tire = TireItem(
      id: _positionId,
      code: switch (_positionId) {
        'front-left' => 'FL',
        'front-right' => 'FR',
        'back-left' => 'BL',
        _ => 'BR',
      },
      installOdometer: int.parse(_installOdometerController.text.trim()),
      intervalKm: int.parse(_intervalController.text.trim()),
      installDate: _installDate,
      shelfLifeMonths: int.parse(_shelfLifeController.text.trim()),
    );
    _tires.add(tire);
    if (_step == TireItem.positionIds.length - 1) {
      Navigator.pop(context, List<TireItem>.unmodifiable(_tires));
      return;
    }
    setState(() {
      _step++;
      _prefillFrom(tire);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final position = l10n.tirePosition(_positionId);
    final progress = (_step + 1) / TireItem.positionIds.length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tireHealthSetupTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.tireHealthStep(_step + 1, TireItem.positionIds.length),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Row(
                    key: ValueKey(_positionId),
                    children: [
                      Icon(
                        _positionIcon,
                        color: colors.onSurfaceVariant,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          position,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_step + 1}/${TireItem.positionIds.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _step == 0
                    ? l10n.tireHealthFirstTireHint
                    : l10n.tireHealthCopyPreviousHint,
                style: TextStyle(color: colors.onSurfaceVariant),
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
                    _groupLabel(context, l10n.trackingModeMileage),
                    GearTextField(
                      key: const Key('wizard-install-odometer-field'),
                      controller: _installOdometerController,
                      keyboardType: TextInputType.number,
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
                    const SizedBox(height: 16),
                    GearTextField(
                      key: const Key('wizard-interval-field'),
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
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
                    _groupLabel(context, l10n.trackingModeTime),
                    DateInput(
                      value: _installDate,
                      onChanged: (value) =>
                          setState(() => _installDate = value),
                      label: l10n.installedOn,
                      fieldKey: const Key('wizard-install-date-button'),
                      sheetKey: const Key('wizard-install-date-sheet'),
                      wheelKey: const Key('wizard-install-date-wheel'),
                      cancelKey: const Key('wizard-install-date-cancel'),
                      doneKey: const Key('wizard-install-date-done'),
                    ),
                    const SizedBox(height: 16),
                    GearTextField(
                      key: const Key('wizard-shelf-life-field'),
                      controller: _shelfLifeController,
                      keyboardType: TextInputType.number,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TimePresetChip(
                            key: const Key('wizard-one-year-preset'),
                            label: l10n.timePresetOneYear,
                            onPressed: () => _setShelfLifePreset(12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TimePresetChip(
                            key: const Key('wizard-two-year-preset'),
                            label: l10n.timePresetTwoYears,
                            onPressed: () => _setShelfLifePreset(24),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TimePresetChip(
                            key: const Key('wizard-three-year-preset'),
                            label: l10n.timePresetThreeYears,
                            onPressed: () => _setShelfLifePreset(36),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TimePresetChip(
                            key: const Key('wizard-five-year-preset'),
                            label: l10n.timePresetFiveYears,
                            onPressed: () => _setShelfLifePreset(60),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          key: const Key('tire-wizard-next-button'),
          onPressed: _next,
          child: Text(
            _step == TireItem.positionIds.length - 1
                ? l10n.finish
                : l10n.nextAction,
          ),
        ),
      ),
    );
  }
}
