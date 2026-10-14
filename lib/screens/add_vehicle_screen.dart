import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/vehicle_profile.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/gear_text_field.dart';

/// Collects the minimum details for a vehicle profile.
///
/// Used both for creating a clean profile and for editing an existing one.
class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key, this.initial});

  final VehicleProfile? initial;

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _odometerController = TextEditingController();

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/add_vehicle_screen.dart';
    final initial = widget.initial;
    if (initial != null) {
      _yearController.text = initial.year.toString();
      _makeController.text = initial.make ?? '';
      _modelController.text = initial.model;
      _odometerController.text = _formatOdometer(initial.garage.odometer);
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final year = int.parse(_yearController.text.trim());
    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    final odometer = int.parse(_odometerController.text.replaceAll(' ', ''));
    final initial = widget.initial;
    final vehicle = initial == null
        ? VehicleProfile.clean(
            year: year,
            make: make,
            model: model,
            odometer: odometer,
          )
        : initial
              .copyWith(
                year: year,
                make: make.isEmpty ? null : make,
                model: model,
              )
              .withOdometer(odometer);
    Navigator.of(context).pop(vehicle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numbers = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editVehicle : l10n.addVehicle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isEditing ? l10n.editVehicle : l10n.addVehicle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: _Field(
                            controller: _yearController,
                            label: l10n.year,
                            hint: l10n.yearHint,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (value) {
                              final year = int.tryParse(value?.trim() ?? '');
                              if (year == null) return l10n.enterModelYear;
                              if (year < 1900 || year > 2100) {
                                return l10n.enterYearBetween;
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _Field(
                            controller: _modelController,
                            label: l10n.model,
                            hint: l10n.modelHint,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? l10n.enterModel
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _makeController,
                      label: l10n.makeOptional,
                      hint: l10n.makeHint,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Icon(
                        Icons.speed_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        controller: _odometerController,
                        label: l10n.currentOdometerField,
                        hint: l10n.odometerHint,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _submit,
                        inputFormatters: [_OdometerFormatter()],
                        validator: (value) {
                          final odometer = int.tryParse(
                            (value ?? '').replaceAll(' ', ''),
                          );
                          if (odometer == null) {
                            return l10n.enterCurrentOdometer;
                          }
                          if (odometer < 0 || odometer > 999999) {
                            return l10n.enterOdometerRange(
                              numbers.formatDecimal(0),
                              numbers.formatDecimal(999999),
                            );
                          }
                          return null;
                        },
                      ),
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
        child: FilledButton(
          key: const Key('add-vehicle-submit'),
          onPressed: _submit,
          child: Text(_isEditing ? l10n.saveAction : l10n.addVehicle),
        ),
      ),
    );
  }
}

String _formatOdometer(int value) {
  final digits = value.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, end);
    groups.insert(0, digits.substring(start, end));
  }
  return groups.join(' ');
}

class _OdometerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 6) return oldValue;
    final text = digits.isEmpty ? '' : _formatOdometer(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GearTextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator,
      onFieldSubmitted: (_) => onSubmitted?.call(),
    );
  }
}
