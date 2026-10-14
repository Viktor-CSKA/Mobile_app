import 'package:ezhemesyachno/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('нижняя навигация переключает вкладки', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EzhemesyachnoApp()));

    expect(find.text('Здесь будут ближайшие платежи'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Календарь'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Здесь будет календарь платежей'), findsOneWidget);
  });
}
