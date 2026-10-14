import 'package:expense_tracker/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('нижняя навигация переключает вкладки', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ExpenseTrackerApp()));

    expect(find.text('Здесь будет список трат'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Подписки'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Здесь будут подписки и напоминания'), findsOneWidget);
  });
}
