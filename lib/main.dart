import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/dev_overlay.dart';

void main() =>
    runApp(const RestartWidget(child: SplashScreen(child: GearTrackerApp())));

const bool isDebug = kDebugMode;

class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

class GearTrackerApp extends StatefulWidget {
  const GearTrackerApp({super.key});

  static GearTrackerAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<GearTrackerAppState>();

  @override
  State<GearTrackerApp> createState() => GearTrackerAppState();
}

class GearTrackerAppState extends State<GearTrackerApp> {
  static const _themePreferenceKey = 'usesTelemetryTheme';
  static const _localePreferenceKey = 'appLocale';
  bool _usesTelemetryTheme = false;
  Locale? _locale;

  bool get usesTelemetryTheme => _usesTelemetryTheme;
  Locale? get locale => _locale;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadLocalePreference();
  }

  Future<void> _loadLocalePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final languageCode = preferences.getString(_localePreferenceKey);
    if (!mounted || languageCode == null) return;
    if (languageCode == 'en') {
      setState(() => _locale = const Locale('en'));
    } else if (languageCode == 'ar-EG') {
      setState(() => _locale = const Locale('ar', 'EG'));
    } else if (languageCode == 'ar') {
      setState(() => _locale = const Locale('ar'));
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'en' && locale.languageCode != 'ar') return;
    if (locale.languageCode == 'ar' &&
        locale.countryCode != null &&
        locale.countryCode != 'EG') {
      return;
    }
    setState(() => _locale = locale);
    final preferences = await SharedPreferences.getInstance();
    final value = locale.languageCode == 'ar' && locale.countryCode == 'EG'
        ? 'ar-EG'
        : locale.languageCode;
    await preferences.setString(_localePreferenceKey, value);
  }

  Future<void> toggleLocale() => setLocale(
    (_locale?.languageCode ?? 'en') == 'ar'
        ? const Locale('en')
        : const Locale('ar'),
  );

  bool get isEgyptianArabic =>
      _locale?.languageCode == 'ar' && _locale?.countryCode == 'EG';

  Future<void> setEgyptianDialect(bool enabled) async {
    if (_locale?.languageCode != 'ar') return;
    await setLocale(enabled ? const Locale('ar', 'EG') : const Locale('ar'));
  }

  Future<void> _loadThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final usesTelemetryTheme =
        preferences.getBool(_themePreferenceKey) ?? false;
    if (mounted) setState(() => _usesTelemetryTheme = usesTelemetryTheme);
  }

  Future<void> toggleTheme() async {
    final usesTelemetryTheme = !_usesTelemetryTheme;
    setState(() => _usesTelemetryTheme = usesTelemetryTheme);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_themePreferenceKey, usesTelemetryTheme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gear Tracker',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _usesTelemetryTheme ? AppTheme.telemetry() : AppTheme.classic(),
      home: const DevOverlay(child: DashboardScreen()),
    );
  }
}
