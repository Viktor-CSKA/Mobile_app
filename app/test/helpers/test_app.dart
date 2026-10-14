import 'package:drift/native.dart';
import 'package:ezhemesyachno/app.dart';
import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Виджет-тест приложения с базой в памяти (вместо файла на устройстве).
///
/// После теста дерево виджетов снимается и время прокручивается: Drift при
/// закрытии подписок ставит нулевой таймер, а Flutter не терпит висящих таймеров.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body,
) {
  testWidgets(description, (tester) async {
    // Высокий экран, чтобы вся форма помещалась без прокрутки.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
        child: const EzhemesyachnoApp(),
      ),
    );
    await tester.pump();

    await body(tester, db);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
