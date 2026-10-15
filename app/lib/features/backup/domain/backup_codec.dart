import 'dart:convert';

import '../../../core/database/app_database.dart';

/// Все данные приложения, которые попадают в резервную копию.
class BackupData {
  const BackupData({
    required this.categories,
    required this.payments,
    required this.records,
  });

  final List<Category> categories;
  final List<Payment> payments;
  final List<PaymentRecord> records;
}

/// Файл не является корректной резервной копией. [message] можно показать
/// пользователю.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

const backupAppId = 'ezhemesyachno';

/// Версия формата файла (не путать с версией схемы базы).
const backupFormatVersion = 1;

const _maxItems = 100000;
const _maxFileChars = 50 * 1000 * 1000;

/// Превращает данные в текст резервной копии (JSON с отступами).
String encodeBackup(BackupData data, {required DateTime exportedAt}) {
  final map = <String, Object?>{
    'app': backupAppId,
    'formatVersion': backupFormatVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'categories': [
      for (final c in data.categories)
        {'id': c.id, 'name': c.name, 'colorValue': c.colorValue},
    ],
    'payments': [
      for (final p in data.payments)
        {
          'id': p.id,
          'name': p.name,
          'categoryId': p.categoryId,
          'amountKopecks': p.amountKopecks,
          'periodMonths': p.periodMonths,
          'nextDueAt': _dateToString(p.nextDueAt),
          'anchorDay': p.anchorDay,
          'remindDaysBefore': p.remindDaysBefore,
          'endsAt': p.endsAt == null ? null : _dateToString(p.endsAt!),
          'note': p.note,
          'isActive': p.isActive,
        },
    ],
    'records': [
      for (final r in data.records)
        {
          'id': r.id,
          'paymentId': r.paymentId,
          'amountKopecks': r.amountKopecks,
          'paidAt': r.paidAt.toUtc().toIso8601String(),
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Разбирает и полностью проверяет текст резервной копии.
///
/// Ничего не записывает в базу: при любой проблеме бросает
/// [BackupFormatException], а данные приложения остаются нетронутыми.
BackupData decodeBackup(String text) {
  if (text.length > _maxFileChars) {
    throw const BackupFormatException('Файл слишком большой');
  }
  // Редакторы Windows (Блокнот) добавляют в начало файла метку порядка байт.
  final body = text.startsWith('﻿') ? text.substring(1) : text;
  final Object? root;
  try {
    root = jsonDecode(body);
  } on FormatException {
    throw const BackupFormatException(
      'Это не файл резервной копии «Ежемесячно»',
    );
  }
  if (root is! Map<String, Object?>) {
    throw const BackupFormatException(
      'Это не файл резервной копии «Ежемесячно»',
    );
  }
  if (root['app'] != backupAppId) {
    throw const BackupFormatException(
      'Это не файл резервной копии «Ежемесячно»',
    );
  }
  final version = root['formatVersion'];
  if (version is! int || version < 1) {
    throw const BackupFormatException('Не удалось определить версию файла');
  }
  if (version > backupFormatVersion) {
    throw const BackupFormatException(
      'Файл создан более новой версией приложения. Обновите «Ежемесячно»',
    );
  }

  final categories = _decodeCategories(_list(root, 'categories'));
  final categoryIds = {for (final c in categories) c.id};
  final payments = _decodePayments(_list(root, 'payments'), categoryIds);
  final paymentIds = {for (final p in payments) p.id};
  final records = _decodeRecords(_list(root, 'records'), paymentIds);

  return BackupData(
    categories: categories,
    payments: payments,
    records: records,
  );
}

List<Object?> _list(Map<String, Object?> root, String key) {
  final v = root[key];
  if (v is! List<Object?>) {
    throw BackupFormatException('В файле нет раздела «$key»');
  }
  if (v.length > _maxItems) {
    throw BackupFormatException('Слишком много записей в разделе «$key»');
  }
  return v;
}

List<Category> _decodeCategories(List<Object?> raw) {
  final seen = <int>{};
  final result = <Category>[];
  for (var i = 0; i < raw.length; i++) {
    final m = _map(raw[i], 'Категория №${i + 1}');
    final id = _id(m, 'Категория №${i + 1}', seen);
    final name = _string(m, 'name', 1, 50, 'Категория №${i + 1}');
    final color = m['colorValue'];
    if (color is! int || color < 0 || color > 0xFFFFFFFF) {
      throw BackupFormatException('Категория №${i + 1}: некорректный цвет');
    }
    result.add(Category(id: id, name: name, colorValue: color));
  }
  return result;
}

List<Payment> _decodePayments(List<Object?> raw, Set<int> categoryIds) {
  final seen = <int>{};
  final result = <Payment>[];
  for (var i = 0; i < raw.length; i++) {
    final where = 'Платёж №${i + 1}';
    final m = _map(raw[i], where);
    final id = _id(m, where, seen);
    final name = _string(m, 'name', 1, 80, where);
    final categoryId = m['categoryId'];
    if (categoryId is! int || !categoryIds.contains(categoryId)) {
      throw BackupFormatException('$where: неизвестная категория');
    }
    final amount = m['amountKopecks'];
    if (amount != null && (amount is! int || amount < 0)) {
      throw BackupFormatException('$where: некорректная сумма');
    }
    final period = m['periodMonths'];
    if (period is! int || period < 1 || period > 120) {
      throw BackupFormatException('$where: некорректный период');
    }
    final due = _date(m['nextDueAt'], '$where: некорректная дата платежа');
    final anchor = m['anchorDay'];
    if (anchor is! int || anchor < 1 || anchor > 31) {
      throw BackupFormatException('$where: некорректный день месяца');
    }
    final remind = m['remindDaysBefore'];
    if (remind is! int || remind < 0 || remind > 365) {
      throw BackupFormatException('$where: некорректное напоминание');
    }
    final endsRaw = m['endsAt'];
    final ends = endsRaw == null
        ? null
        : _date(endsRaw, '$where: некорректная дата окончания');
    final note = m['note'] ?? '';
    if (note is! String || note.length > 2000) {
      throw BackupFormatException('$where: некорректная заметка');
    }
    final active = m['isActive'];
    if (active is! bool) {
      throw BackupFormatException('$where: не указано, активен ли платёж');
    }
    result.add(
      Payment(
        id: id,
        name: name,
        categoryId: categoryId,
        amountKopecks: amount as int?,
        periodMonths: period,
        nextDueAt: due,
        anchorDay: anchor,
        remindDaysBefore: remind,
        endsAt: ends,
        note: note,
        isActive: active,
      ),
    );
  }
  return result;
}

List<PaymentRecord> _decodeRecords(List<Object?> raw, Set<int> paymentIds) {
  final seen = <int>{};
  final result = <PaymentRecord>[];
  for (var i = 0; i < raw.length; i++) {
    final where = 'Оплата №${i + 1}';
    final m = _map(raw[i], where);
    final id = _id(m, where, seen);
    final paymentId = m['paymentId'];
    if (paymentId is! int || !paymentIds.contains(paymentId)) {
      throw BackupFormatException('$where: неизвестный платёж');
    }
    final amount = m['amountKopecks'];
    if (amount is! int || amount < 0) {
      throw BackupFormatException('$where: некорректная сумма');
    }
    final paidRaw = m['paidAt'];
    final paid = paidRaw is String ? DateTime.tryParse(paidRaw) : null;
    if (paid == null) {
      throw BackupFormatException('$where: некорректная дата оплаты');
    }
    result.add(
      PaymentRecord(
        id: id,
        paymentId: paymentId,
        amountKopecks: amount,
        paidAt: paid.isUtc ? paid.toLocal() : paid,
      ),
    );
  }
  return result;
}

Map<String, Object?> _map(Object? v, String where) {
  if (v is! Map<String, Object?>) {
    throw BackupFormatException('$where: неверная запись');
  }
  return v;
}

int _id(Map<String, Object?> m, String where, Set<int> seen) {
  final id = m['id'];
  if (id is! int || id < 1) {
    throw BackupFormatException('$where: некорректный номер');
  }
  if (!seen.add(id)) {
    throw BackupFormatException('$where: повторяющийся номер');
  }
  return id;
}

String _string(
  Map<String, Object?> m,
  String key,
  int min,
  int max,
  String where,
) {
  final v = m[key];
  if (v is! String || v.trim().length < min || v.length > max) {
    throw BackupFormatException('$where: некорректное название');
  }
  return v;
}

String _dateToString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime _date(Object? v, String error) {
  if (v is! String) throw BackupFormatException(error);
  final m = _dateRe.firstMatch(v);
  if (m == null) throw BackupFormatException(error);
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  // DateTime «чинит» несуществующие даты (30 февраля), поэтому сверяем.
  if (date.year != y || date.month != mo || date.day != d) {
    throw BackupFormatException(error);
  }
  return date;
}
