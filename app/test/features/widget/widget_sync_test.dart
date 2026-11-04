import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_widget.dart';
import '../../helpers/test_app.dart';

final _today = DateTime(2026, 10, 15, 8);

Future<void> _seed(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  await repo.add(
    PaymentDraft(
      name: 'Подписка',
      categoryId: 2,
      amountKopecks: 19900,
      nextDueAt: DateTime(2026, 10, 20),
      remindDaysBefore: 1,
    ),
  );
}

void main() {
  final writer = FakeWidgetCacheWriter();
  final refresh = FakeWidgetRefresh();
  appTest(
    'при старте с данными пишет кэш и зовёт refresh',
    (tester, db) async {
      await tester.pumpAndSettle();
      expect(writer.writes, isNotEmpty);
      final data = writer.last!;
      expect(data.isEmpty, isFalse);
      expect(data.payments.first.name, 'Подписка');
      expect(data.payments.first.amountLabel, isNotNull);
      expect(refresh.refreshCalls, greaterThanOrEqualTo(1));
    },
    seed: _seed,
    today: _today,
    widgetCacheWriter: writer,
    widgetRefresh: refresh,
  );

  final writer2 = FakeWidgetCacheWriter();
  appTest(
    'новый платёж пересчитывает кэш',
    (tester, db) async {
      await tester.pumpAndSettle();
      final before = writer2.writes.length;
      await tester.runAsync(() async {
        await PaymentsRepository(db).add(
          PaymentDraft(
            name: 'Кредит',
            categoryId: 1,
            amountKopecks: 50000,
            nextDueAt: DateTime(2026, 10, 1),
            remindDaysBefore: 1,
          ),
        );
      });
      await tester.pumpAndSettle();
      expect(writer2.writes.length, greaterThan(before));
      // Просроченный «Кредит» идёт первым.
      expect(writer2.last!.payments.first.name, 'Кредит');
      expect(writer2.last!.payments.first.dueLabel, startsWith('просрочено'));
    },
    seed: _seed,
    today: _today,
    widgetCacheWriter: writer2,
  );

  final failing = FakeWidgetCacheWriter()..fail = true;
  appTest(
    'ошибка записи кэша не ломает приложение',
    (tester, db) async {
      await tester.pumpAndSettle();
      // Приложение живо, ошибка канала/кэша проглочена.
      expect(find.byType(NavigationBar), findsOneWidget);
    },
    seed: _seed,
    today: _today,
    widgetCacheWriter: failing,
  );
}
