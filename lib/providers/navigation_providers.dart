import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final activeCalculatorProvider = AsyncNotifierProvider<ActiveCalculatorNotifier, String>(ActiveCalculatorNotifier.new);
final appThemeModeProvider = AsyncNotifierProvider<AppThemeModeNotifier, ThemeMode>(AppThemeModeNotifier.new);
final appZoomProvider = AsyncNotifierProvider<AppZoomNotifier, double>(AppZoomNotifier.new);

const String _boxName = 'app_settings';
const String _lastCalculatorKey = 'last_calculator';
const String _themeModeKey = 'theme_mode';
const String _zoomKey = 'app_zoom';

Future<Box<String>> _openSettingsBox() async {
  if (Hive.isBoxOpen(_boxName)) {
    return Hive.box<String>(_boxName);
  }
  return Hive.openBox<String>(_boxName);
}

class ActiveCalculatorNotifier extends AsyncNotifier<String> {
  static const String defaultCalculator = 'manage';

  @override
  Future<String> build() async {
    final Box<String> box = await _openSettingsBox();
    return box.get(_lastCalculatorKey, defaultValue: defaultCalculator) ?? defaultCalculator;
  }

  Future<void> setActiveCalculator(String calculatorId) async {
    state = AsyncData(calculatorId);
    // 'settings' and 'manage' are ephemeral – skip persistence so the
    // app returns to the last real calculator on restart.
    if (calculatorId == 'settings' || calculatorId == 'manage') return;
    final Box<String> box = await _openSettingsBox();
    await box.put(_lastCalculatorKey, calculatorId);
  }
}

class AppThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final Box<String> box = await _openSettingsBox();
    final String value = box.get(_themeModeKey, defaultValue: 'system') ?? 'system';
    return _decodeThemeMode(value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final Box<String> box = await _openSettingsBox();
    await box.put(_themeModeKey, _encodeThemeMode(mode));
  }

  ThemeMode _decodeThemeMode(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

class AppZoomNotifier extends AsyncNotifier<double> {
  static const double minZoom = 0.8;
  static const double maxZoom = 1.4;

  @override
  Future<double> build() async {
    final Box<String> box = await _openSettingsBox();
    final String raw = box.get(_zoomKey, defaultValue: '1.0') ?? '1.0';
    final double value = double.tryParse(raw) ?? 1.0;
    return value.clamp(minZoom, maxZoom);
  }

  Future<void> setZoom(double zoom) async {
    final double normalized = zoom.clamp(minZoom, maxZoom);
    state = AsyncData(normalized);
    final Box<String> box = await _openSettingsBox();
    await box.put(_zoomKey, normalized.toStringAsFixed(2));
  }
}
