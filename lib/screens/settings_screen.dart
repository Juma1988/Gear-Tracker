import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/garage_backup.dart';
import '../data/garage_repository.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/vehicle_profile.dart';
import '../preferences/display_preferences.dart';
import '../reminders/reminder_preferences.dart';
import '../theme/app_tokens.dart';
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

  Future<void> _openLanguageDialog() async {
    final appState = GearTrackerApp.of(context);
    if (appState == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        final currentLanguage = appState.locale?.languageCode ?? 'en';
        return AlertDialog(
          key: const Key('language-dialog'),
          title: Text(l10n.chooseLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.languageSettingsHint),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('language-option-english'),
                title: Text(l10n.languageEnglish),
                trailing: currentLanguage == 'en'
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () {
                  appState.setLocale(const Locale('en'));
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                key: const Key('language-option-arabic'),
                title: Text(l10n.languageArabic),
                trailing: currentLanguage == 'ar'
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () {
                  appState.setLocale(const Locale('ar'));
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        );
      },
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
      padding: const EdgeInsetsDirectional.only(start: 10, end: 10, bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [sectionLabel(label), const SizedBox(height: 8), ...children],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                ServicePickerCard(
                  key: const Key('settings-language-card'),
                  title: l10n.language,
                  subtitle: l10n.locale.languageCode == 'ar'
                      ? l10n.languageArabic
                      : l10n.languageEnglish,
                  icon: Icons.language,
                  compact: true,
                  onTap: _openLanguageDialog,
                ),
                if (appState?.locale?.languageCode == 'ar') ...[
                  const SizedBox(height: 12),
                  _SettingsSwitchTile(
                    key: const Key('settings-egyptian-dialect-card'),
                    title: l10n.egyptianDialect,
                    subtitle: l10n.languageArabic,
                    icon: Icons.record_voice_over_outlined,
                    value: appState?.isEgyptianArabic ?? false,
                    switchKey: const Key('settings-egyptian-dialect-switch'),
                    onChanged: (value) => appState?.setEgyptianDialect(value),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              settingsGroup(l10n.backupRestoreSection, [
                _BackupActionsCard(
                  key: const Key('settings-backup-card'),
                  title: l10n.backupAndRestore,
                  subtitle: l10n.backupPrivacySummary,
                  icon: Icons.save_alt_outlined,
                  onCopy: _copyBackup,
                  onRestore: _restoreBackup,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.switchKey,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final Key switchKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
      child: SwitchListTile(
        key: switchKey,
        contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 4),
        secondary: Icon(icon, color: colors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _BackupActionsCard extends StatelessWidget {
  const _BackupActionsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onCopy,
    required this.onRestore,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onCopy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.tertiary.withValues(alpha: .35)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.tertiary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppTokens.cardTitleStyle)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.backupActionHint,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('settings-backup-copy'),
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.copyBackup),
              ),
              FilledButton.tonalIcon(
                key: const Key('settings-backup-restore'),
                onPressed: onRestore,
                icon: const Icon(Icons.restore_outlined),
                label: Text(l10n.restoreBackup),
              ),
            ],
          ),
        ],
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
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _value.enabled ? 1 : .55,
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('reminders-repeat-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.repeatUntilComplete),
                    value: _value.repeatUntilComplete,
                    onChanged: _value.enabled
                        ? (value) => setState(
                            () => _value = _value.copyWith(
                              repeatUntilComplete: value,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('reminders-weekday-selector'),
                    initialValue: _value.weekday,
                    decoration: InputDecoration(labelText: l10n.day),
                    items: [
                      for (
                        var day = DateTime.monday;
                        day <= DateTime.sunday;
                        day++
                      )
                        DropdownMenuItem(
                          value: day,
                          child: Text(l10n.weekdayName(day)),
                        ),
                    ],
                    onChanged: _value.enabled
                        ? (day) => setState(
                            () => _value = _value.copyWith(weekday: day),
                          )
                        : null,
                  ),
                  ListTile(
                    key: const Key('reminders-time-picker'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.time),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimeOfDay(context, _value.hour, _value.minute),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: _value.enabled ? _pickTime : null,
                  ),
                ],
              ),
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
