import 'package:flutter/material.dart';

import '../models/tire_item.dart';
import '../widgets/dev_overlay.dart';

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
  late DateTime _installDate;

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
    _installDate = widget.tire.installDate;
  }

  @override
  void dispose() {
    _installOdometerController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _selectInstallDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _installDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select tire install date',
    );
    if (selected != null && mounted) setState(() => _installDate = selected);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      widget.tire.copyWith(
        installOdometer: int.parse(_installOdometerController.text.trim()),
        intervalKm: int.parse(_intervalController.text.trim()),
        installDate: _installDate,
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Edit ${widget.tire.code} Tire')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Current odometer: ${widget.currentOdometer} KM',
              style: const TextStyle(color: Color(0xFFBBCABF), fontSize: 12),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('tire-install-date-button'),
              onPressed: _selectInstallDate,
              icon: const Icon(Icons.calendar_today),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text('Install date: ${_formatDate(_installDate)}'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('tire-install-odometer-field'),
              controller: _installOdometerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Installation odometer',
                suffixText: 'KM',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final odometer = int.tryParse(value?.trim() ?? '');
                if (odometer == null || odometer < 0) {
                  return 'Enter a valid installation KM';
                }
                return odometer > widget.currentOdometer
                    ? 'Installation KM cannot exceed current KM'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('tire-interval-field'),
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tire lifespan interval',
                suffixText: 'KM',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final interval = int.tryParse(value?.trim() ?? '');
                return interval == null || interval <= 0
                    ? 'Enter an interval greater than 0 KM'
                    : null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              key: const Key('save-tire-button'),
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save tire'),
            ),
          ],
        ),
      ),
    ),
  );
}
