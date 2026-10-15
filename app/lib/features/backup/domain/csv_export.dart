import 'dart:convert';
import 'dart:typed_data';

import '../../payments/presentation/payment_labels.dart';
import 'backup_codec.dart';

/// Экранирует одно поле CSV (разделитель — точка с запятой, как ждёт Excel
/// в русской локали).
///
/// Текст, начинающийся с `=`, `+`, `-`, `@`, получает впереди апостроф: иначе
/// Excel примет его за формулу («CSV-инъекция»).
String csvField(String value) {
  var v = value;
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
  final needsQuotes =
      v.contains(';') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r');
  if (!needsQuotes) return v;
  return '"${v.replaceAll('"', '""')}"';
}

/// Склеивает строки таблицы в текст CSV (строки разделены `\r\n`).
String buildCsv(List<List<String>> rows) =>
    rows.map((r) => r.map(csvField).join(';')).join('\r\n');

/// Байты CSV в UTF-8 с BOM, чтобы Excel правильно открыл кириллицу.
Uint8List csvBytes(String csv) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);

/// Сумма в рублях с запятой: `69000` → `690,00`.
String csvAmount(int kopecks) {
  final rubles = kopecks ~/ 100;
  final cents = (kopecks % 100).toString().padLeft(2, '0');
  return '$rubles,$cents';
}

String _csvDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

String _csvDateTime(DateTime d) =>
    '${_csvDate(d)} '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// Таблица платежей.
String paymentsCsv(BackupData data) {
  final categories = {for (final c in data.categories) c.id: c.name};
  final rows = <List<String>>[
    [
      'Название',
      'Категория',
      'Сумма, ₽',
      'Сумма меняется',
      'Периодичность',
      'Ближайший платёж',
      'Дата окончания',
      'Напоминать за, дн.',
      'Заметка',
      'Статус',
    ],
    for (final p in data.payments)
      [
        p.name,
        categories[p.categoryId] ?? '',
        p.amountKopecks == null ? '' : csvAmount(p.amountKopecks!),
        p.amountKopecks == null ? 'да' : 'нет',
        periodLabel(p.periodMonths),
        _csvDate(p.nextDueAt),
        p.endsAt == null ? '' : _csvDate(p.endsAt!),
        '${p.remindDaysBefore}',
        p.note,
        p.isActive ? 'Активен' : 'Завершён',
      ],
  ];
  return buildCsv(rows);
}

/// Таблица оплат (история), по возрастанию даты.
String historyCsv(BackupData data) {
  final categories = {for (final c in data.categories) c.id: c.name};
  final payments = {for (final p in data.payments) p.id: p};
  final records = [...data.records]
    ..sort((a, b) {
      final c = a.paidAt.compareTo(b.paidAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final rows = <List<String>>[
    ['Дата оплаты', 'Платёж', 'Категория', 'Сумма, ₽'],
    for (final r in records)
      [
        _csvDateTime(r.paidAt),
        payments[r.paymentId]?.name ?? '',
        categories[payments[r.paymentId]?.categoryId] ?? '',
        csvAmount(r.amountKopecks),
      ],
  ];
  return buildCsv(rows);
}
