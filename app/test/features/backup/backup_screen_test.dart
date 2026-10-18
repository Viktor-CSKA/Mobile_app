import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/backup/data/backup_repository.dart';
import 'package:ezhemesyachno/features/backup/domain/backup_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/backup_samples.dart';
import '../../helpers/fake_file_gateway.dart';
import '../../helpers/fake_scheduler.dart';
import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

Future<void> seedSample(AppDatabase db) =>
    BackupRepository(db).replaceAll(sampleData());

/// Копия с одним платежом «Кинопоиск» для проверки восстановления.
String otherBackup() => encodeBackup(
  BackupData(
    categories: const [kSubs],
    payments: [
      Payment(
        id: 1,
        name: 'Кинопоиск',
        categoryId: 2,
        amountKopecks: 29900,
        periodMonths: 1,
        nextDueAt: DateTime(2026, 11, 3),
        anchorDay: 3,
        remindDaysBefore: 1,
        endsAt: null,
        note: '',
        isActive: true,
      ),
    ],
    records: const [],
  ),
  exportedAt: DateTime.utc(2026, 10, 1),
);

Future<void> openSettings(WidgetTester tester) => openTab(tester, 'Настройки');

void main() {
  group('сохранение', () {
    final f1 = FakeFileGateway();
    appTest(
      'резервная копия сохраняется файлом',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Сохранить резервную копию'));
        await tester.pumpAndSettle();

        expect(f1.saved.single.name, 'ezhemesyachno-backup-2026-10-15.json');
        expect(find.text('Резервная копия сохранена'), findsOneWidget);
        expectSameData(decodeBackup(f1.lastSavedText!), sampleData());
      },
      today: today,
      seed: seedSample,
      files: f1,
    );

    final f2 = FakeFileGateway();
    appTest(
      'экспорт платежей в CSV',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Экспорт платежей (CSV)'));
        await tester.pumpAndSettle();

        expect(f2.saved.single.name, 'ezhemesyachno-platezhi-2026-10-15.csv');
        expect(f2.lastSavedText, contains('Интернет;Подписки;690,00'));
        expect(find.text('Таблица платежей сохранена'), findsOneWidget);
      },
      today: today,
      seed: seedSample,
      files: f2,
    );

    final f3 = FakeFileGateway();
    appTest(
      'экспорт истории оплат в CSV',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Экспорт истории оплат (CSV)'));
        await tester.pumpAndSettle();

        expect(f3.saved.single.name, 'ezhemesyachno-oplaty-2026-10-15.csv');
        expect(find.text('История оплат сохранена'), findsOneWidget);
      },
      today: today,
      seed: seedSample,
      files: f3,
    );

    final f4 = FakeFileGateway(saveAccepted: false);
    appTest(
      'отказ в диалоге сохранения не показывает сообщений',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Сохранить резервную копию'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
      },
      today: today,
      seed: seedSample,
      files: f4,
    );

    final f5 = FakeFileGateway();
    f5.saveError = Exception('нет места');
    appTest(
      'ошибка сохранения показывается пользователю',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Сохранить резервную копию'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Не удалось сохранить файл'),
          findsOneWidget,
        );
      },
      today: today,
      seed: seedSample,
      files: f5,
    );

    final f6 = FakeFileGateway();
    appTest(
      'экспорт пустого приложения тоже работает',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Экспорт платежей (CSV)'));
        await tester.pumpAndSettle();

        expect(f6.saved.length, 1);
        expect(find.text('Таблица платежей сохранена'), findsOneWidget);
      },
      today: today,
      files: f6,
    );
  });

  group('восстановление', () {
    final g1 = FakeFileGateway();
    appTest(
      'перед выбором файла просит подтверждение, «Отмена» ничего не делает',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Восстановить из копии'));
        await tester.pumpAndSettle();

        expect(find.text('Восстановить из копии?'), findsOneWidget);
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();

        expect(g1.pickCalls, 0);
        expectSameData(await BackupRepository(db).readAll(), sampleData());
      },
      today: today,
      seed: seedSample,
      files: g1,
    );

    final g2 = FakeFileGateway();
    final s2 = FakeNotificationScheduler();
    g2.pickText(otherBackup());
    appTest(
      'подтверждение заменяет данные и пересчитывает напоминания',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Восстановить из копии'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Выбрать файл'));
        await tester.pumpAndSettle();

        expect(g2.pickCalls, 1);
        expect(find.text('Восстановлено: 1 платёж, 0 оплат'), findsOneWidget);

        final data = await BackupRepository(db).readAll();
        expect(data.payments.single.name, 'Кинопоиск');

        await openTab(tester, 'Платежи');
        expect(find.text('Кинопоиск'), findsOneWidget);
        expect(find.text('Интернет'), findsNothing);
        // Напоминания переписаны под восстановленные платежи.
        expect(s2.lastPlan.map((e) => e.title).toSet(), {'Кинопоиск'});
      },
      today: today,
      seed: seedSample,
      files: g2,
      scheduler: s2,
    );

    final g3 = FakeFileGateway();
    g3.pickText('это не копия');
    appTest(
      'неподходящий файл: сообщение, данные не тронуты',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Восстановить из копии'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Выбрать файл'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Файл не подошёл'), findsOneWidget);
        expect(
          find.textContaining('Это не файл резервной копии'),
          findsOneWidget,
        );
        expectSameData(await BackupRepository(db).readAll(), sampleData());
      },
      today: today,
      seed: seedSample,
      files: g3,
    );

    final g4 = FakeFileGateway(); // выбор файла отменён
    appTest(
      'отказ при выборе файла: без сообщений, данные целы',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Восстановить из копии'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Выбрать файл'));
        await tester.pumpAndSettle();

        expect(g4.pickCalls, 1);
        expect(find.byType(SnackBar), findsNothing);
        expectSameData(await BackupRepository(db).readAll(), sampleData());
      },
      today: today,
      seed: seedSample,
      files: g4,
    );

    final g5 = FakeFileGateway();
    g5.pickText(
      encodeBackup(sampleData(), exportedAt: DateTime.utc(2026, 10, 1)),
    );
    appTest(
      'копия с историей: показывается число платежей и оплат',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Восстановить из копии'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Выбрать файл'));
        await tester.pumpAndSettle();

        expect(find.text('Восстановлено: 4 платежа, 2 оплаты'), findsOneWidget);
      },
      today: today,
      files: g5,
    );
  });

  group('страховочная копия', () {
    appTest(
      'пока восстановлений не было, пункта возврата нет',
      (tester, db) async {
        await openSettings(tester);
        expect(find.text('Вернуть данные до восстановления'), findsNothing);
      },
      today: today,
      seed: seedSample,
    );

    final h2 = FakeFileGateway();
    h2.pickText(otherBackup());
    appTest(
      'после восстановления данные можно вернуть из копии',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Восстановить из копии'));
        await tester.pumpAndSettle();
        expect(find.textContaining('само сохранит копию'), findsOneWidget);
        await tester.tap(find.text('Выбрать файл'));
        await tester.pumpAndSettle();

        // Появился пункт с описанием копии: время и число платежей.
        expect(find.text('Вернуть данные до восстановления'), findsOneWidget);
        expect(find.text('Копия от 15 окт, 08:00: 4 платежа'), findsOneWidget);
        expect(
          (await BackupRepository(db).readAll()).payments.single.name,
          'Кинопоиск',
        );

        await tester.tap(find.text('Вернуть данные до восстановления'));
        await tester.pumpAndSettle();
        expect(find.text('Вернуть прежние данные?'), findsOneWidget);
        await tester.tap(find.text('Вернуть'));
        await tester.pumpAndSettle();

        expect(find.text('Возвращено: 4 платежа, 2 оплаты'), findsOneWidget);
        expectSameData(await BackupRepository(db).readAll(), sampleData());
      },
      today: today,
      seed: seedSample,
      files: h2,
    );

    final h3 = FakeFileGateway();
    h3.pickText(otherBackup());
    appTest(
      '«Отмена» в диалоге возврата данных не меняет',
      (tester, db) async {
        await openSettings(tester);
        await tester.tap(find.text('Восстановить из копии'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Выбрать файл'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Вернуть данные до восстановления'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();

        expect(
          (await BackupRepository(db).readAll()).payments.single.name,
          'Кинопоиск',
        );
      },
      today: today,
      seed: seedSample,
      files: h3,
    );
  });
}
