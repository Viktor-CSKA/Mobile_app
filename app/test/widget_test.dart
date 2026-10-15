import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  appTest('нижняя навигация переключает вкладки', (tester, db) async {
    expect(find.textContaining('Платежей пока нет'), findsOneWidget);

    await openTab(tester, 'Календарь');

    expect(find.text('Здесь будет календарь платежей'), findsOneWidget);
  });
}
