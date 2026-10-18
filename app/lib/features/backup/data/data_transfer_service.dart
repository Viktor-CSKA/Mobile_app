import 'dart:convert';
import 'dart:typed_data';

import '../domain/backup_codec.dart';
import '../domain/csv_export.dart';
import 'backup_repository.dart';
import 'file_gateway.dart';
import 'safety_backup_store.dart';

enum TransferStatus { saved, restored, cancelled, failed }

/// Итог операции для показа пользователю.
class TransferResult {
  const TransferResult(
    this.status, {
    this.message,
    this.payments = 0,
    this.records = 0,
  });

  final TransferStatus status;

  /// Понятное пользователю пояснение (для ошибок).
  final String? message;

  /// Сколько платежей и оплат записано (для восстановления).
  final int payments;
  final int records;
}

/// Описание страховочной копии для экрана настроек.
class SafetyInfo {
  const SafetyInfo({
    required this.savedAt,
    required this.payments,
    required this.records,
  });

  final DateTime savedAt;
  final int payments;
  final int records;
}

/// Экспорт данных в файлы и восстановление из резервной копии.
class DataTransferService {
  DataTransferService(this._repo, this._files, this._safety, this._now);

  final BackupRepository _repo;
  final FileGateway _files;
  final SafetyBackupStore _safety;
  final DateTime Function() _now;

  /// Верхний предел размера файла копии.
  static const maxBackupBytes = 20 * 1000 * 1000;

  Future<TransferResult> exportBackup() async {
    final data = await _repo.readAll();
    final text = encodeBackup(data, exportedAt: _now());
    return _save(
      'ezhemesyachno-backup-${_stamp()}.json',
      Uint8List.fromList(utf8.encode(text)),
      'application/json',
    );
  }

  Future<TransferResult> exportPaymentsCsv() async {
    final data = await _repo.readAll();
    return _save(
      'ezhemesyachno-platezhi-${_stamp()}.csv',
      csvBytes(paymentsCsv(data)),
      'text/csv',
    );
  }

  Future<TransferResult> exportHistoryCsv() async {
    final data = await _repo.readAll();
    return _save(
      'ezhemesyachno-oplaty-${_stamp()}.csv',
      csvBytes(historyCsv(data)),
      'text/csv',
    );
  }

  /// Спрашивает файл, проверяет его и заменяет им все данные.
  /// Если файл не подходит, данные приложения не меняются.
  Future<TransferResult> restoreFromFile() async {
    final Uint8List? bytes;
    try {
      bytes = await _files.pickFile(maxBytes: maxBackupBytes);
    } on FileTooLargeException {
      return const TransferResult(
        TransferStatus.failed,
        message: 'Файл слишком большой для резервной копии',
      );
    } catch (e) {
      return TransferResult(
        TransferStatus.failed,
        message: 'Не удалось открыть файл: $e',
      );
    }
    if (bytes == null) return const TransferResult(TransferStatus.cancelled);

    final BackupData data;
    try {
      // allowMalformed: испорченные байты дадут ошибку формата, а не сбой.
      data = decodeBackup(utf8.decode(bytes, allowMalformed: true));
    } on BackupFormatException catch (e) {
      return TransferResult(TransferStatus.failed, message: e.message);
    }

    return _replaceWith(data);
  }

  /// Что лежит в страховочной копии; null, если копии нет.
  Future<SafetyInfo?> safetyCopyInfo() async {
    final copy = await _safety.load();
    if (copy == null) return null;
    try {
      final data = decodeBackup(copy.text);
      return SafetyInfo(
        savedAt: copy.savedAt,
        payments: data.payments.length,
        records: data.records.length,
      );
    } on BackupFormatException {
      return null;
    }
  }

  /// Возвращает данные из страховочной копии. Нынешние данные при этом тоже
  /// становятся страховочной копией, поэтому действие можно отменить так же.
  Future<TransferResult> restoreSafetyCopy() async {
    final copy = await _safety.load();
    final BackupData data;
    try {
      if (copy == null) throw const BackupFormatException('Копии нет');
      data = decodeBackup(copy.text);
    } on BackupFormatException {
      return const TransferResult(
        TransferStatus.failed,
        message: 'Страховочной копии нет или она повреждена',
      );
    }
    return _replaceWith(data);
  }

  /// Сохраняет страховочную копию текущих данных и заменяет их на [data].
  /// Если копию сохранить не удалось, данные не трогаем: замена необратима.
  /// Пустые данные копировать не нужно, чтобы не затереть более раннюю копию.
  Future<TransferResult> _replaceWith(BackupData data) async {
    try {
      final current = await _repo.readAll();
      final hasData = current.payments.isNotEmpty || current.records.isNotEmpty;
      if (hasData) {
        final now = _now();
        await _safety.save(encodeBackup(current, exportedAt: now), now);
      }
    } catch (e) {
      return TransferResult(
        TransferStatus.failed,
        message:
            'Не удалось сохранить страховочную копию, данные не тронуты: $e',
      );
    }

    try {
      await _repo.replaceAll(data);
    } catch (e) {
      return TransferResult(
        TransferStatus.failed,
        message: 'Не удалось записать данные, прежние сохранены: $e',
      );
    }
    return TransferResult(
      TransferStatus.restored,
      payments: data.payments.length,
      records: data.records.length,
    );
  }

  Future<TransferResult> _save(
    String name,
    Uint8List bytes,
    String mime,
  ) async {
    try {
      final ok = await _files.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: mime,
      );
      return TransferResult(
        ok ? TransferStatus.saved : TransferStatus.cancelled,
      );
    } catch (e) {
      return TransferResult(
        TransferStatus.failed,
        message: 'Не удалось сохранить файл: $e',
      );
    }
  }

  String _stamp() {
    final d = _now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
