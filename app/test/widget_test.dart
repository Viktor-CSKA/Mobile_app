import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  appTest('нижняя навигация переключает вкладки', (tester, db) async {
    // Первая вкладка — «Ближайшие», платежей ещё нет.
    expect(find.textContaining('Платежей пока нет'), findsOneWidget);

    await openTab(tester, 'Календарь');
    expect(find.byKey(const Key('calendar-grid')), findsOneWidget);

    await openTab(tester, 'Платежи');
    expect(find.text('Добавить платёж'), findsOneWidget);

    await openTab(tester, 'Настройки');
    expect(find.text('Сохранить резервную копию'), findsOneWidget);
  });
}
