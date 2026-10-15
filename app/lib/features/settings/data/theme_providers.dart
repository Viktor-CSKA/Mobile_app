import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../reminders/data/reminder_providers.dart';

/// Тема приложения как строка для хранения.
String themeModeToString(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

/// Читает сохранённую строку; неизвестное значение — «как в системе».
ThemeMode themeModeFromString(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class ThemeModeStore {
  ThemeModeStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'theme_mode';

  ThemeMode load() => themeModeFromString(_prefs.getString(_key));

  Future<void> save(ThemeMode mode) =>
      _prefs.setString(_key, themeModeToString(mode));
}

final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => ThemeModeStore(ref.watch(sharedPreferencesProvider)),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(themeModeStoreProvider).load();

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(themeModeStoreProvider).save(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
