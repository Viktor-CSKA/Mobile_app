import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_planner.dart';

/// Хранение настроек напоминаний в SharedPreferences.
class ReminderSettingsStore {
  ReminderSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _enabledKey = 'reminders_enabled';
  static const _minutesKey = 'reminders_minutes_of_day';

  ReminderSettings load() {
    const defaults = ReminderSettings();
    final minutes = _prefs.getInt(_minutesKey);
    return ReminderSettings(
      enabled: _prefs.getBool(_enabledKey) ?? defaults.enabled,
      // Испорченное значение не должно ломать запуск.
      minutesOfDay: (minutes != null && minutes >= 0 && minutes < 24 * 60)
          ? minutes
          : defaults.minutesOfDay,
    );
  }

  Future<void> save(ReminderSettings settings) async {
    await _prefs.setBool(_enabledKey, settings.enabled);
    await _prefs.setInt(_minutesKey, settings.minutesOfDay);
  }
}
