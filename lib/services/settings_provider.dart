import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys
const String _kLanguage = 'settings_language';
const String _kTheme = 'settings_theme';
const String _kStartup = 'settings_startup';
const String _kHardwareDecode = 'settings_hw_decode';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final String language; // 'en', 'ar', 'ku'
  final String theme; // 'amber', 'red', 'blue', 'green'
  final String startupScreen; // 'live', 'movies', 'series', 'dashboard'
  final bool hardwareDecoding;

  SettingsState({
    this.language = 'en',
    this.theme = 'amber',
    this.startupScreen = 'live',
    this.hardwareDecoding = true,
  });

  SettingsState copyWith({
    String? language,
    String? theme,
    String? startupScreen,
    bool? hardwareDecoding,
  }) {
    return SettingsState(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      startupScreen: startupScreen ?? this.startupScreen,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      language: prefs.getString(_kLanguage) ?? 'en',
      theme: prefs.getString(_kTheme) ?? 'amber',
      startupScreen: prefs.getString(_kStartup) ?? 'live',
      hardwareDecoding: prefs.getBool(_kHardwareDecode) ?? true,
    );
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> setStartupScreen(String screen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartup, screen);
    state = state.copyWith(startupScreen: screen);
  }

  Future<void> setHardwareDecoding(bool hw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHardwareDecode, hw);
    state = state.copyWith(hardwareDecoding: hw);
  }
}
