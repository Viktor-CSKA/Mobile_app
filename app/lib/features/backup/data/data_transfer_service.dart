import 'dart:convert';
import 'dart:typed_data';

import '../domain/backup_codec.dart';
import '../domain/csv_export.dart';
import 'backup_repository.dart';
import 'file_gateway.dart';

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

/// Экспорт данных в файлы и восстановление из резервной копии.
class DataTransferService {
  DataTransferService(this._repo, this._files, this._now);

  final BackupRepository _repo;
  final FileGateway _files;
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
