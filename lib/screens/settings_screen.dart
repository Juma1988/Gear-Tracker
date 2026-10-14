import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/garage_backup.dart';
import '../data/garage_repository.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/vehicle_profile.dart';
import '../preferences/display_preferences.dart';
import '../reminders/reminder_preferences.dart';
import '../widgets/dev_overlay.dart';
import '../widgets/service_picker_card.dart';

/// Thin seam over the platform clipboard so the backup flows stay testable.
abstract interface class GarageClipboard {
  Future<String?> read();
  Future<void> write(String text);
}

class SystemGarageClipboard implements GarageClipboard {
  const SystemGarageClipboard();

  @override
  Future<String?> read() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  @override
  Future<void> write(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.vehicles = const [],
    this.defaultVehicleId,
    this.onDefaultVehicleChanged,
    this.reminderPreferencesRepository = const ReminderPreferencesRepository(),
    this.onReminderPreferencesChanged,
    this.onCompactTireHealthChanged,
    this.repository,
    this.onGarageRestored,
    this.clipboard = const SystemGarageClipboard(),
  });

  final List<VehicleProfile> vehicles;
  final String? defaultVehicleId;
  final ValueChanged<String>? onDefaultVehicleChanged;
  final ReminderPreferencesRepository reminderPreferencesRepository;
  final Future<void> Function(ReminderPreferences)?
  onReminderPreferencesChanged;
  final ValueChanged<bool>? onCompactTireHealthChanged;

  /// Repository used by the backup and restore actions. Defaults to the real
  /// device-backed repository.
  final GarageRepository? repository;

  /// Invoked after a successful restore so the host can reload its garage.
  final Future<void> Function()? onGarageRestored;

  final GarageClipboard clipboard;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _defaultVehicleId;
  ReminderPreferences _reminderPreferences = const ReminderPreferences();
  bool _compactTireHealth = false;
  bool _showGuidance = true;
  late final GarageRepository _repository;

  @override
  void initState() {
    super.initState();
    _defaultVehicleId = widget.defaultVehicleId;
    _repository = widget.repository ?? GarageRepository();
    _loadReminderPreferences();
    _loadCompactTireHealth();
    _loadShowGuidance();
  }

  Future<void> _loadCompactTireHealth() async {
    final value = await DisplayPreferences.loadCompactTireHealth();
    if (mounted) setState(() => _compactTireHealth = value);
  }

  Future<void> _toggleCompactTireHealth() async {
    final value = !_compactTireHealth;
    setState(() => _compactTireHealth = value);
    await DisplayPreferences.saveCompactTireHealth(value);
    widget.onCompactTireHealthChanged?.call(value);
  }

  Future<void> _loadShowGuidance() async {
    final value = await DisplayPreferences.loadShowGuidance();
    if (mounted) setState(() => _showGuidance = value);
  }

  Future<void> _toggleShowGuidance() async {
    final value = !_showGuidance;
    setState(() => _showGuidance = value);
    await DisplayPreferences.saveShowGuidance(value);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openBackupDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('backup-dialog'),
        title: Text(AppLocalizations.of(dialogContext).backupAndRestore),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(dialogContext).localStorageTitle),
              const SizedBox(height: 4),
              Text(AppLocalizations.of(dialogContext).localStorageGuidance),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(dialogContext).backupGuidance),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('backup-dialog-copy'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _copyBackup();
            },
            child: Text(AppLocalizations.of(dialogContext).copyBackup),
          ),
          TextButton(
            key: const Key('backup-dialog-restore'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _restoreBackup();
            },
            child: Text(AppLocalizations.of(dialogContext).restoreBackup),
          ),
          FilledButton(
            key: const Key('backup-dialog-close'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(dialogContext).closeAction),
          ),
        ],
      ),
    );
  }

  Future<void> _copyBackup() async {
    final l10n = AppLocalizations.of(context);
    try {
      final backup = await _repository.exportBackup();
      await widget.clipboard.write(backup);
      if (!mounted) return;
      _showMessage(l10n.backupCopied);
    } catch (_) {
      if (!mounted) return;
      _showMessage(l10n.backupFailed);
    }
  }

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context);
    final String? text;
    try {
      text = await widget.clipboard.read();
    } catch (_) {
      if (mounted) _showMessage(l10n.restoreFailed);
      return;
    }
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      _showMessage(l10n.clipboardEmptyBackup);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('restore-confirm-dialog'),
        title: Text(AppLocalizations.of(dialogContext).restoreConfirmTitle),
        content: Text(AppLocalizations.of(dialogContext).restoreConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            key: const Key('restore-confirm-action'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AppLocalizations.of(dialogContext).restoreConfirmAction,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.importBackup(text);
    } on GarageBackupException catch (error) {
      if (mounted) _showMessage(_backupErrorMessage(l10n, error.failure));
      return;
    } catch (_) {
      if (mounted) _showMessage(l10n.restoreFailed);
      return;
    }
    if (!mounted) return;
    _showMessage(l10n.restoreComplete);
    await widget.onGarageRestored?.call();
  }

  /// Maps a rejection to localized recovery copy. Raw parser messages are
  /// deliberately never shown to the user.
  String _backupErrorMessage(
    AppLocalizations l10n,
    GarageBackupFailure failure,
  ) => switch (failure) {
    GarageBackupFailure.empty => l10n.clipboardEmptyBackup,
    GarageBackupFailure.unsupportedVersion => l10n.unsupportedBackupVersion,
    GarageBackupFailure.malformed ||
    GarageBackupFailure.wrongFormat ||
    GarageBackupFailure.invalidData => l10n.restoreFailed,
  };

  Future<void> _loadReminderPreferences() async {
    final value = await widget.reminderPreferencesRepository.load();
    if (mounted) setState(() => _reminderPreferences = value);
  }

  String get _reminderSubtitle {
    final l10n = AppLocalizations.of(context);
    if (!_reminderPreferences.enabled) return l10n.off;
    return l10n.reminderScheduleSummary(
      l10n.weekdayName(_reminderPreferences.weekday),
      _formatTimeOfDay(
        context,
        _reminderPreferences.hour,
        _reminderPreferences.minute,
      ),
    );
  }

  Future<void> _editReminders() async {
    final value = await showDialog<ReminderPreferences>(
      context: context,
      builder: (_) => ReminderSettingsDialog(initial: _reminderPreferences),
    );
    if (value == null) return;
    try {
      await widget.reminderPreferencesRepository.save(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).remindersSaveFailed),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _reminderPreferences = value);
    await widget.onReminderPreferencesChanged?.call(value);
  }

  VehicleProfile? get _defaultVehicle {
    final id = _defaultVehicleId;
    if (id == null || id == GarageCollection.lastUsedVehicleId) return null;
    for (final vehicle in widget.vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  Future<void> _pickDefaultVehicle() async {
    if (widget.vehicles.isEmpty) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(AppLocalizations.of(dialogContext).defaultVehicle),
        children: [
          SimpleDialogOption(
            key: const Key('default-vehicle-option-last-used'),
            onPressed: () => Navigator.pop(
              dialogContext,
              GarageCollection.lastUsedVehicleId,
            ),
            child: Row(
              children: [
                Icon(
                  _defaultVehicleId == GarageCollection.lastUsedVehicleId
                      ? Icons.check_circle
                      : Icons.history,
                  color: _defaultVehicleId == GarageCollection.lastUsedVehicleId
                      ? Theme.of(dialogContext).colorScheme.primary
                      : Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(dialogContext).lastUsedVehicle,
                  ),
                ),
              ],
            ),
          ),
          for (final vehicle in widget.vehicles)
            SimpleDialogOption(
              key: Key('default-vehicle-option-${vehicle.id}'),
              onPressed: () => Navigator.pop(dialogContext, vehicle.id),
              child: Row(
                children: [
                  Icon(
                    vehicle.id == _defaultVehicleId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: vehicle.id == _defaultVehicleId
                        ? Theme.of(dialogContext).colorScheme.primary
                        : Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(vehicle.name)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == _defaultVehicleId) return;
    final selectedName = selected == GarageCollection.lastUsedVehicleId
        ? AppLocalizations.of(context).lastUsedVehicle
        : widget.vehicles.firstWhere((vehicle) => vehicle.id == selected).name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          key: const Key('default-vehicle-confirm-dialog'),
          title: Text(dialogL10n.defaultVehicleChangeTitle(selectedName)),
          content: Text(dialogL10n.defaultVehicleChangeMessage(selectedName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogL10n.cancel),
            ),
            FilledButton(
              key: const Key('default-vehicle-confirm-action'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogL10n.changeDefaultVehicle),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _defaultVehicleId = selected);
    widget.onDefaultVehicleChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    DevOverlay.currentFilePath = 'lib/screens/settings_screen.dart';
    final appState = GearTrackerApp.of(context);
    final usesTelemetryTheme = appState?.usesTelemetryTheme ?? false;
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    Widget sectionLabel(String label) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: colors.primary, fontWeight: FontWeight.w700),
      ),
    );

    Widget settingsGroup(String label, List<Widget> children) => Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsetsDirectional.only(start: 10, end: 10, bottom: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [sectionLabel(label), ...children],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              settingsGroup(l10n.appearanceSection, [
                ServicePickerCard(
                  key: const Key('settings-theme-card'),
                  title: l10n.theme,
                  subtitle: usesTelemetryTheme
                      ? l10n.themeTelemetry
                      : l10n.themeClassic,
                  icon: usesTelemetryTheme
                      ? Icons.analytics_outlined
                      : Icons.palette_outlined,
                  compact: true,
                  onTap: () => appState?.toggleTheme(),
                ),
                const SizedBox(height: 4),
                ServicePickerCard(
                  key: const Key('settings-compact-tire-health-card'),
                  title: l10n.compactTireHealthCard,
                  subtitle: _compactTireHealth
                      ? l10n.compactTireHealthCardOn
                      : l10n.compactTireHealthCardOff,
                  icon: Icons.view_compact_outlined,
                  trailing: Switch(
                    key: const Key('settings-compact-tire-health-switch'),
                    value: _compactTireHealth,
                    onChanged: (_) => _toggleCompactTireHealth(),
                  ),
                  compact: true,
                  onTap: _toggleCompactTireHealth,
                ),
                const SizedBox(height: 4),
                ServicePickerCard(
                  key: const Key('settings-show-guidance-card'),
                  title: l10n.showGuidance,
                  subtitle: _showGuidance
                      ? l10n.showGuidanceOn
                      : l10n.showGuidanceOff,
                  icon: Icons.lightbulb_outline,
                  trailing: Switch(
                    key: const Key('settings-show-guidance-switch'),
                    value: _showGuidance,
                    onChanged: (_) => _toggleShowGuidance(),
                  ),
                  compact: true,
                  onTap: _toggleShowGuidance,
                ),
                ServicePickerCard(
                  key: const Key('settings-language-card'),
                  title: l10n.language,
                  subtitle: l10n.locale.languageCode == 'ar'
                      ? l10n.languageArabic
                      : l10n.languageEnglish,
                  icon: Icons.language,
                  compact: true,
                  onTap: () => appState?.toggleLocale(),
                ),
              ]),
              const SizedBox(height: 2),
              settingsGroup(l10n.garageSection, [
                ServicePickerCard(
                  key: const Key('settings-default-vehicle-card'),
                  title: l10n.defaultVehicle,
                  subtitle:
                      _defaultVehicleId == GarageCollection.lastUsedVehicleId
                      ? l10n.lastUsedVehicle
                      : _defaultVehicle?.name ?? l10n.notSet,
                  icon: Icons.directions_car_filled,
                  compact: true,
                  onTap: _pickDefaultVehicle,
                ),
              ]),
              const SizedBox(height: 2),
              settingsGroup(l10n.notificationsSection, [
                ServicePickerCard(
                  key: const Key('settings-reminders-card'),
                  title: l10n.reminders,
                  subtitle: _reminderSubtitle,
                  icon: Icons.notifications_active_outlined,
                  compact: true,
                  onTap: _editReminders,
                ),
              ]),
              const SizedBox(height: 2),
              settingsGroup(l10n.backupRestoreSection, [
                ServicePickerCard(
                  key: const Key('settings-backup-card'),
                  title: l10n.backupAndRestore,
                  subtitle: l10n.backupGuidance,
                  icon: Icons.save_alt_outlined,
                  accentColor: colors.tertiary,
                  compact: true,
                  onTap: _openBackupDialog,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderSettingsDialog extends StatefulWidget {
  const ReminderSettingsDialog({super.key, required this.initial});

  final ReminderPreferences initial;

  @override
  State<ReminderSettingsDialog> createState() => _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends State<ReminderSettingsDialog> {
  late ReminderPreferences _value = widget.initial;

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _value.hour, minute: _value.minute),
    );
    if (time != null) {
      setState(
        () => _value = _value.copyWith(hour: time.hour, minute: time.minute),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.maintenanceReminders),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              key: const Key('reminders-enabled-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enableReminders),
              value: _value.enabled,
              onChanged: (value) =>
                  setState(() => _value = _value.copyWith(enabled: value)),
            ),
            SwitchListTile(
              key: const Key('reminders-repeat-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.repeatUntilComplete),
              value: _value.repeatUntilComplete,
              onChanged: _value.enabled
                  ? (value) => setState(
                      () =>
                          _value = _value.copyWith(repeatUntilComplete: value),
                    )
                  : null,
            ),
            DropdownButtonFormField<int>(
              key: const Key('reminders-weekday-selector'),
              initialValue: _value.weekday,
              decoration: InputDecoration(labelText: l10n.day),
              items: [
                for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                  DropdownMenuItem(
                    value: day,
                    child: Text(l10n.weekdayName(day)),
                  ),
              ],
              onChanged: _value.enabled
                  ? (day) =>
                        setState(() => _value = _value.copyWith(weekday: day))
                  : null,
            ),
            ListTile(
              key: const Key('reminders-time-picker'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.time),
              trailing: Text(
                _formatTimeOfDay(context, _value.hour, _value.minute),
              ),
              onTap: _value.enabled ? _pickTime : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _value),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

/// Formats a reminder time through [MaterialLocalizations] so the AM/PM marker
/// and any locale-specific separators stay consistent with the platform.
String _formatTimeOfDay(BuildContext context, int hour, int minute) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
