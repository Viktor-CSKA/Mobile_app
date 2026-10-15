import 'package:ezhemesyachno/features/settings/data/theme_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

ThemeMode currentMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  group('преобразование темы', () {
    test('в строку и обратно', () {
      for (final m in ThemeMode.values) {
        expect(themeModeFromString(themeModeToString(m)), m);
      }
    });

    test('строки хранения', () {
      expect(themeModeToString(ThemeMode.light), 'light');
      expect(themeModeToString(ThemeMode.dark), 'dark');
      expect(themeModeToString(ThemeMode.system), 'system');
    });

    test('неизвестное и пустое значение — как в системе', () {
      expect(themeModeFromString(null), ThemeMode.system);
      expect(themeModeFromString(''), ThemeMode.system);
      expect(themeModeFromString('neon'), ThemeMode.system);
    });
  });

  group('ThemeModeStore', () {
    Future<SharedPreferences> prefs([Map<String, Object> v = const {}]) {
      SharedPreferences.setMockInitialValues(v);
      return SharedPreferences.getInstance();
    }

    test('по умолчанию — как в системе', () async {
      expect(ThemeModeStore(await prefs()).load(), ThemeMode.system);
    });

    test('сохраняет и читает', () async {
      final p = await prefs();
      await ThemeModeStore(p).save(ThemeMode.dark);
      expect(ThemeModeStore(p).load(), ThemeMode.dark);
      await ThemeModeStore(p).save(ThemeMode.light);
      expect(ThemeModeStore(p).load(), ThemeMode.light);
    });

    test('читает ранее записанное значение', () async {
      final p = await prefs({'theme_mode': 'dark'});
      expect(ThemeModeStore(p).load(), ThemeMode.dark);
    });

    test('испорченное значение не ломает запуск', () async {
      final p = await prefs({'theme_mode': 'что-то'});
      expect(ThemeModeStore(p).load(), ThemeMode.system);
    });
  });

  group('экран настроек', () {
    appTest('по умолчанию тема как в системе', (tester, db) async {
      expect(currentMode(tester), ThemeMode.system);
      await openTab(tester, 'Настройки');
      expect(find.text('Оформление'), findsOneWidget);
      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.selected, {ThemeMode.system});
    });

    appTest('выбор «Тёмная» сразу меняет тему приложения', (tester, db) async {
      await openTab(tester, 'Настройки');
      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();

      expect(currentMode(tester), ThemeMode.dark);
      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.selected, {ThemeMode.dark});
    });

    appTest('можно вернуться на «Светлая» и «Система»', (tester, db) async {
      await openTab(tester, 'Настройки');
      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      expect(currentMode(tester), ThemeMode.light);

      await tester.tap(find.text('Система'));
      await tester.pumpAndSettle();
      expect(currentMode(tester), ThemeMode.system);
    });

    appTest('сохранённый выбор действует с запуска', (tester, db) async {
      expect(currentMode(tester), ThemeMode.dark);
      await openTab(tester, 'Настройки');
      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.selected, {ThemeMode.dark});
    }, prefs: {'theme_mode': 'dark'});

    appTest('выбор записывается в настройки устройства', (tester, db) async {
      await openTab(tester, 'Настройки');
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();

      final stored = await tester.runAsync(() async {
        final p = await SharedPreferences.getInstance();
        return p.getString('theme_mode');
      });
      expect(stored, 'light');
    });
  });
}
