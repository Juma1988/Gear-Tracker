import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/fuel_localizations.dart';
import '../models/fuel_entry.dart';
import '../models/fuel_calculations.dart';
import '../models/vehicle_profile.dart';
import '../widgets/date_input.dart';
import '../widgets/dev_overlay.dart';

class FuelFormScreen extends StatefulWidget {
  const FuelFormScreen({
    super.key,
    required this.vehicle,
    required this.onSave,
    this.initial,
  });
  final VehicleProfile vehicle;
  final FuelEntry? initial;
  final Future<bool> Function(FuelEntry entry, int usualGrade) onSave;
  @override
  State<FuelFormScreen> createState() => _FuelFormScreenState();
}

class _FuelFormScreenState extends State<FuelFormScreen> {
  final _form = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _price = TextEditingController();
  final _amount = TextEditingController();
  final _liters = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  late String _id;
  late int _grade;
  bool _byAmount = true;
  bool _full = true;
  bool _usual = false;
  bool _saving = false;
  String? _error;
  AppLocalizations get l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/fuel_form_screen.dart';
    final initial = widget.initial;
    _id =
        initial?.id ??
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    _date = initial?.date.toLocal() ?? DateTime.now();
    _grade = initial?.grade ?? widget.vehicle.fuelPreferences.usualGrade;
    _full = initial?.fullTank ?? true;
    var odo = widget.vehicle.garage.odometer;
    for (final e in widget.vehicle.garage.fuelEntries) {
      odo = max(odo, e.odometer);
    }
    _odometer.text = '${initial?.odometer ?? odo}';
    final price =
        initial?.recordedPrice ??
        (initial == null
            ? widget.vehicle.fuelPreferences.prices[_grade]
            : initial.pricePerLiter);
    _price.text = price == null ? '' : '$price';
    _amount.text = initial == null ? '' : '${initial.cost}';
    _liters.text = initial == null ? '' : '${initial.liters}';
    _note.text = initial?.note ?? '';
  }

  @override
  void dispose() {
    for (final c in [_odometer, _price, _amount, _liters, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    final price = FuelInput.decimal(_price.text);
    final source = FuelInput.decimal(_byAmount ? _amount.text : _liters.text);
    final target = _byAmount ? _liters : _amount;
    if (price == null || source == null) {
      target.text = '';
      return;
    }
    final result = _byAmount
        ? FuelInput.litersFromAmount(source, price)
        : FuelInput.amountFromLiters(source, price);
    target.text = result == null || !result.isFinite
        ? ''
        : result.toStringAsFixed(_byAmount ? 3 : 2);
  }

  String? _positive(String? text) {
    final value = FuelInput.decimal(text ?? '');
    return value != null && value > 0 && value <= 1e9
        ? null
        : l.fuel('positive');
  }

  Future<void> _save() async {
    if (_saving) return;
    final odo = FuelInput.decimal(_odometer.text);
    String? inputError;
    if (odo == null || odo < 0 || odo > 999999 || odo % 1 != 0) {
      inputError = l.fuel('odometerError');
    }
    for (final (controller, label) in [
      (_price, l.fuel('price')),
      (_amount, l.fuel('amount')),
      (_liters, l.fuel('liters')),
    ]) {
      if (_positive(controller.text) != null) {
        inputError ??= '$label: ${l.fuel('positive')}';
      }
    }
    if (inputError != null) {
      setState(() => _error = inputError);
      _form.currentState!.validate();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(inputError)));
      return;
    }
    if (!_form.currentState!.validate()) return;
    final entry = FuelEntry(
      id: _id,
      vehicleId: widget.vehicle.id,
      date: _date.toUtc(),
      odometer: FuelInput.decimal(_odometer.text)!.toInt(),
      liters: FuelInput.decimal(_liters.text)!,
      cost: FuelInput.decimal(_amount.text)!,
      grade: _grade,
      fullTank: _full,
      note: _note.text.trim(),
      recordedPrice: FuelInput.decimal(_price.text),
      breaksConsumption: widget.initial?.breaksConsumption ?? false,
    );
    if (_date.isAfter(DateTime.now())) {
      setState(() => _error = l.fuel('future'));
      return;
    }
    if (!FuelCalculations.fitsOdometerOrder(
      entry,
      widget.vehicle.garage.fuelEntries,
    )) {
      setState(() => _error = l.fuel('orderError'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var success = false;
    try {
      success = await widget.onSave(
        entry,
        _usual ? _grade : widget.vehicle.fuelPreferences.usualGrade,
      );
    } catch (_) {}
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = l.fuel('saveError');
      });
    }
  }

  Widget _number(
    TextEditingController controller,
    String name,
    String label, {
    required VoidCallback changed,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: Key('fuel-$name'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: _positive,
      onChanged: (_) => setState(changed),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final liters = FuelInput.decimal(_liters.text);
    final amount = FuelInput.decimal(_amount.text);
    final effective =
        liters != null && liters > 0 && amount != null && amount > 0
        ? amount / liters
        : null;
    final numbers = MaterialLocalizations.of(context);
    final dateLabel = numbers.formatMediumDate(_date);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.fuel(widget.initial == null ? 'add' : 'edit')),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const Key('fuel-save'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? l.saving : l.saveAction),
            ),
          ),
        ),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.directions_car_outlined),
                        title: Text(widget.vehicle.name),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('fuel-odometer'),
                      controller: _odometer,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.currentOdometerField,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (text) {
                        final value = FuelInput.decimal(text ?? '');
                        return value != null &&
                                value >= 0 &&
                                value <= 999999 &&
                                value % 1 == 0
                            ? null
                            : l.fuel('odometerError');
                      },
                    ),
                    const SizedBox(height: 16),
                    DateInput(
                      value: _date,
                      label: l.fuel('date'),
                      firstDate: DateTime(1900),
                      onChanged: (day) => setState(
                        () => _date = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          _date.hour,
                          _date.minute,
                        ),
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      key: const Key('fuel-grade'),
                      initialValue: _grade,
                      decoration: InputDecoration(labelText: l.fuel('grade')),
                      items: [
                        for (final grade in [92, 95])
                          DropdownMenuItem(value: grade, child: Text('$grade')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _grade = value;
                          _price.text =
                              widget.vehicle.fuelPreferences.prices[value]
                                  ?.toString() ??
                              '';
                          _calculate();
                        });
                      },
                    ),
                    CheckboxListTile(
                      key: const Key('fuel-usual'),
                      contentPadding: EdgeInsets.zero,
                      value: _usual,
                      title: Text(l.fuel('usual')),
                      onChanged: (v) => setState(() => _usual = v ?? false),
                    ),
                    const SizedBox(height: 16),
                    _number(
                      _price,
                      'price',
                      l.fuel('price'),
                      changed: () {
                        _calculate();
                      },
                    ),
                    _number(
                      _amount,
                      'amount',
                      l.fuel('amount'),
                      changed: () {
                        _byAmount = true;
                        _calculate();
                      },
                    ),
                    _number(
                      _liters,
                      'liters',
                      l.fuel('liters'),
                      changed: () {
                        _byAmount = false;
                        _calculate();
                      },
                    ),
                    Text(
                      l.fuel('receipt'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SwitchListTile(
                      key: const Key('fuel-full'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.fuel('fullQuestion')),
                      value: _full,
                      onChanged: (v) => setState(() => _full = v),
                    ),
                    TextFormField(
                      key: const Key('fuel-note'),
                      controller: _note,
                      maxLength: 1000,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: l.fuel('note')),
                    ),
                    Card(
                      key: const Key('fuel-review'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.fuel('review'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(widget.vehicle.name),
                            Text(dateLabel),
                            Text(
                              '${_odometer.text} ${l.kilometers} · $_grade · ${l.fuel(_full ? 'full' : 'partial')}',
                            ),
                            Text(
                              '${_liters.text} ${l.fuel('liters')} · ${_amount.text} ${l.fuel('egp')}',
                            ),
                            Text(
                              '${l.fuel('effective')}: ${effective?.toStringAsFixed(6) ?? '—'}',
                              key: const Key('fuel-effective-price'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            key: const Key('fuel-form-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
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
