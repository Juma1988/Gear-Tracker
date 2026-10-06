import 'package:flutter/material.dart';

import '../models/service_item.dart';
import '../widgets/dev_overlay.dart';

class EditServiceScreen extends StatefulWidget {
  const EditServiceScreen({super.key, required this.service});

  final ServiceItem service;

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  static const _surfaceLow = Color(0xFF131B2E);
  static const _muted = Color(0xFFBBCABF);
  static const _primary = Color(0xFF4EDEA3);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _intervalController;
  late DateTime _installDate;

  @override
  void initState() {
    super.initState();
    DevOverlay.currentFilePath = 'lib/screens/edit_service_screen.dart';
    _nameController = TextEditingController(text: widget.service.name);
    _noteController = TextEditingController(text: widget.service.note);
    _intervalController = TextEditingController(
      text: widget.service.intervalKm.toString(),
    );
    _installDate = widget.service.installDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      widget.service.copyWith(
        name: _nameController.text.trim(),
        note: _noteController.text.trim(),
        intervalKm: int.parse(_intervalController.text.trim()),
        installDate: _installDate,
      ),
    );
  }

  Future<void> _selectInstallDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _installDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select install date',
    );
    if (selected != null && mounted) setState(() => _installDate = selected);
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Service')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(widget.service.icon, color: _primary, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Service details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('service-name-field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Service name',
                border: OutlineInputBorder(),
              ),
              validator: _requiredField('Enter a service name'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('service-install-date-button'),
              onPressed: _selectInstallDate,
              icon: const Icon(Icons.calendar_today),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text('Install date: ${_formatDate(_installDate)}'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('service-note-field'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'For example, 5W-40 SYN',
                border: OutlineInputBorder(),
              ),
              validator: _requiredField('Enter a note'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('service-interval-field'),
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Service interval',
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
            const SizedBox(height: 8),
            const Text(
              'This changes the service configuration. Use Update when the service has been replaced.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              key: const Key('save-service-button'),
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    ),
  );

  String? Function(String?) _requiredField(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;
}
