import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/backup/data/backup_repository.dart';
import 'package:ezhemesyachno/features/backup/data/data_transfer_service.dart';
import 'package:ezhemesyachno/features/backup/data/file_gateway.dart';
import 'package:ezhemesyachno/features/backup/domain/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/backup_samples.dart';
import '../../helpers/fake_file_gateway.dart';

final fixedNow = DateTime(2026, 10, 15, 14, 30);

void main() {
  late AppDatabase db;
  late BackupRepository repo;
  late FakeFileGateway files;
  late DataTransferService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BackupRepository(db);
    files = FakeFileGateway();
    service = DataTransferService(repo, files, () => fixedNow);
    await repo.replaceAll(sampleData());
  });

  tearDown(() => db.close());

  String backupText() => encodeBackup(sampleData(), exportedAt: fixedNow);

  group('экспорт резервной копии', () {
    test('сохраняет файл с датой в имени', () async {
      final r = await service.exportBackup();
      expect(r.status, TransferStatus.saved);
      expect(files.saved.single.name, 'ezhemesyachno-backup-2026-10-15.json');
      expect(files.saved.single.mime, 'application/json');
    });

    test('в файле все данные и они читаются обратно', () async {
      await service.exportBackup();
      expectSameData(decodeBackup(files.lastSavedText!), sampleData());
    });

    test('отказ пользователя — статус «отменено», без ошибки', () async {
      files.saveAccepted = false;
      final r = await service.exportBackup();
      expect(r.status, TransferStatus.cancelled);
      expect(r.message, isNull);
    });

    test('ошибка записи — статус «ошибка» с пояснением', () async {
      files.saveError = Exception('нет места');
      final r = await service.exportBackup();
      expect(r.status, TransferStatus.failed);
      expect(r.message, contains('Не удалось сохранить файл'));
      expect(r.message, contains('нет места'));
    });
  });

  group('экспорт CSV', () {
    test('платежи: имя, тип, BOM, заголовок', () async {
      final r = await service.exportPaymentsCsv();
      expect(r.status, TransferStatus.saved);
      final f = files.saved.single;
      expect(f.name, 'ezhemesyachno-platezhi-2026-10-15.csv');
      expect(f.mime, 'text/csv');
      expect(f.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(files.lastSavedText, contains('Название;Категория'));
      expect(files.lastSavedText, contains('Электричество;ЖКХ;;да'));
    });

    test('история оплат', () async {
      final r = await service.exportHistoryCsv();
      expect(r.status, TransferStatus.saved);
      expect(files.saved.single.name, 'ezhemesyachno-oplaty-2026-10-15.csv');
      expect(files.lastSavedText, contains('Дата оплаты;Платёж'));
      expect(files.lastSavedText, contains('20.09.2026 18:30;Интернет'));
    });

    test('экспорт ничего не меняет в данных', () async {
      await service.exportPaymentsCsv();
      await service.exportHistoryCsv();
      await service.exportBackup();
      expectSameData(await repo.readAll(), sampleData());
    });
  });

  group('восстановление', () {
    test('заменяет данные и сообщает количество', () async {
      await repo.replaceAll(
        const BackupData(categories: [kHousing], payments: [], records: []),
      );
      files.pickText(backupText());

      final r = await service.restoreFromFile();

      expect(r.status, TransferStatus.restored);
      expect(r.payments, 4);
      expect(r.records, 2);
      expectSameData(await repo.readAll(), sampleData());
    });

    test(
      'полный круг: экспорт из одной базы, восстановление в другую',
      () async {
        await service.exportBackup();

        final other = AppDatabase(NativeDatabase.memory());
        addTearDown(other.close);
        final otherFiles = FakeFileGateway(
          pickResult: Uint8List.fromList(files.saved.single.bytes),
        );
        final otherService = DataTransferService(
          BackupRepository(other),
          otherFiles,
          () => fixedNow,
        );

        final r = await otherService.restoreFromFile();

        expect(r.status, TransferStatus.restored);
        expectSameData(await BackupRepository(other).readAll(), sampleData());
      },
    );

    test('просит у выбора файла ограничение размера', () async {
      await service.restoreFromFile();
      expect(files.lastMaxBytes, DataTransferService.maxBackupBytes);
    });

    test('отказ от выбора файла: данные не меняются', () async {
      files.pickResult = null;
      final r = await service.restoreFromFile();
      expect(r.status, TransferStatus.cancelled);
      expectSameData(await repo.readAll(), sampleData());
    });

    test('чужой файл: ошибка, данные не меняются', () async {
      files.pickText('это просто текст');
      final r = await service.restoreFromFile();
      expect(r.status, TransferStatus.failed);
      expect(r.message, contains('Это не файл резервной копии'));
      expectSameData(await repo.readAll(), sampleData());
    });

    test('файл новой версии: понятное сообщение, данные целы', () async {
      final json = jsonDecode(backupText()) as Map<String, Object?>;
      json['formatVersion'] = 99;
      files.pickText(jsonEncode(json));
      final r = await service.restoreFromFile();
      expect(r.status, TransferStatus.failed);
      expect(r.message, contains('более новой версией'));
      expectSameData(await repo.readAll(), sampleData());
    });

    test('файл с битой записью не применяется даже частично', () async {
      final json = jsonDecode(backupText()) as Map<String, Object?>;
      // Первые платежи в порядке, а третий ссылается на несуществующую категорию.
      ((json['payments'] as List)[2] as Map)['categoryId'] = 500;
      files.pickText(jsonEncode(json));

      final r = await service.restoreFromFile();

      expect(r.status, TransferStatus.failed);
      expect(r.message, contains('Платёж №3'));
      expectSameData(await repo.readAll(), sampleData());
    });

    test('испорченные байты (не UTF-8) дают ошибку, а не сбой', () async {
      files.pickResult = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x80, 0xC3]);
      final r = await service.restoreFromFile();
      expect(r.status, TransferStatus.failed);
      expectSameData(await repo.readAll(), sampleData());
    });

    test('слишком большой файл', () async {
      files.pickError = const FileTooLargeException();
      final r = await service.restoreFromFile();
      expect(r.status, TransferStatus.failed);
      expect(r.message, contains('слишком большой'));
    });

    test('ошибка открытия файла', () async {
      files.pickError = Exception('нет доступа');
      final r = await service.restoreFromFile();
      expect(r.status, TransferStatus.failed);
      expect(r.message, contains('Не удалось открыть файл'));
    });

    test('копия, пересохранённая в Блокноте (с BOM), читается', () async {
      await repo.replaceAll(
        const BackupData(categories: [kHousing], payments: [], records: []),
      );
      files.pickResult = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(backupText()),
      ]);

      final r = await service.restoreFromFile();

      expect(r.status, TransferStatus.restored);
      expectSameData(await repo.readAll(), sampleData());
    });
  });
}
