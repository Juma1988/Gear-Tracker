import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'gear_text_field.dart';
import '../theme/app_tokens.dart';

/// An outlined date field that opens a wheel-based date picker.
class DateInput extends StatefulWidget {
  const DateInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.firstDate,
    this.lastDate,
    this.fieldKey,
    this.sheetKey,
    this.wheelKey,
    this.cancelKey,
    this.doneKey,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Key? fieldKey;
  final Key? sheetKey;
  final Key? wheelKey;
  final Key? cancelKey;
  final Key? doneKey;

  @override
  State<DateInput> createState() => _DateInputState();
}

class _DateInputState extends State<DateInput> {
  String get _formattedDate =>
      MaterialLocalizations.of(context).formatMediumDate(widget.value);

  Future<void> _open() async {
    final minimumDate = _dateOnly(widget.firstDate ?? DateTime(2000));
    final requestedMaximum = _dateOnly(widget.lastDate ?? DateTime.now());
    final maximumDate = requestedMaximum.isBefore(minimumDate)
        ? minimumDate
        : requestedMaximum;
    final initialDate = _clampDate(widget.value, minimumDate, maximumDate);

    // Desktop and web users generally have a keyboard and pointer. Material's
    // calendar dialog is a better fit there, while the wheel remains compact
    // and touch-friendly on mobile platforms.
    if (kIsWeb ||
        switch (defaultTargetPlatform) {
          TargetPlatform.linux ||
          TargetPlatform.macOS ||
          TargetPlatform.windows => true,
          _ => false,
        }) {
      final selected = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: minimumDate,
        lastDate: maximumDate,
        helpText: widget.label,
      );
      if (selected != null) widget.onChanged(_dateOnly(selected));
      return;
    }

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DateInputSheet(
        initialDate: initialDate,
        firstDate: minimumDate,
        lastDate: maximumDate,
        label: widget.label,
        sheetKey: widget.sheetKey,
        wheelKey: widget.wheelKey,
        cancelKey: widget.cancelKey,
        doneKey: widget.doneKey,
      ),
    );
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: widget.fieldKey,
      child: GearTextField(
        key: ValueKey(
          '${Localizations.localeOf(context)}:${widget.value.year}-${widget.value.month}-${widget.value.day}',
        ),
        initialValue: _formattedDate,
        readOnly: true,
        showCursor: false,
        onTap: _open,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _DateInputSheet extends StatefulWidget {
  const _DateInputSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.label,
    this.sheetKey,
    this.wheelKey,
    this.cancelKey,
    this.doneKey,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String label;
  final Key? sheetKey;
  final Key? wheelKey;
  final Key? cancelKey;
  final Key? doneKey;

  @override
  State<_DateInputSheet> createState() => _DateInputSheetState();
}

class _DateInputSheetState extends State<_DateInputSheet> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;
    final sheetHeight = (mediaQuery.textScaler.scale(360))
        .clamp(360.0, availableHeight);
    final wheelHeight = (sheetHeight - mediaQuery.textScaler.scale(118)).clamp(
      120.0,
      216.0,
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight),
        child: Container(
          key: widget.sheetKey,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTokens.radiusLg),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        key: widget.cancelKey,
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppLocalizations.of(context).cancel),
                      ),
                      Expanded(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: AppTokens.fontWeightBold,
                          ),
                        ),
                      ),
                      FilledButton(
                        key: widget.doneKey,
                        onPressed: () => Navigator.pop(context, _selectedDate),
                        child: Text(AppLocalizations.of(context).done),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: wheelHeight,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        primaryColor: scheme.primary,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: scheme.onSurface),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        key: widget.wheelKey,
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _selectedDate,
                        minimumDate: widget.firstDate,
                        maximumDate: widget.lastDate,
                        onDateTimeChanged: (value) {
                          setState(() => _selectedDate = _dateOnly(value));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _clampDate(DateTime value, DateTime minimum, DateTime maximum) {
  final date = _dateOnly(value);
  if (date.isBefore(minimum)) return minimum;
  if (date.isAfter(maximum)) return maximum;
  return date;
}
