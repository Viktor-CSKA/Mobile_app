import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../../reminders/data/reminder_providers.dart';
import '../data/payments_providers.dart';
import '../domain/payment_draft.dart';
import '../domain/payment_schedule.dart';
import 'payment_labels.dart';

/// Экран добавления (когда [paymentId] == null) или редактирования платежа.
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, this.paymentId});

  final int? paymentId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  int? _categoryId;
  bool _variableAmount = false;
  int _periodMonths = 1;
  int _remindDays = 1;
  DateTime _nextDue = dateOnly(DateTime.now());
  DateTime? _endsAt;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.paymentId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final payment = await ref
        .read(paymentsRepositoryProvider)
        .getById(widget.paymentId!);
    if (!mounted) return;
    if (payment == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _name.text = payment.name;
      _note.text = payment.note;
      _categoryId = payment.categoryId;
      _variableAmount = payment.amountKopecks == null;
      if (payment.amountKopecks != null) {
        _amount.text = _kopecksToInput(payment.amountKopecks!);
      }
      _periodMonths = payment.periodMonths;
      _remindDays = payment.remindDaysBefore;
      _nextDue = dateOnly(payment.nextDueAt);
      _endsAt = payment.endsAt == null ? null : dateOnly(payment.endsAt!);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) return;

    final end = _endsAt;
    if (end != null && end.isBefore(_nextDue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дата окончания раньше ближайшего платежа'),
        ),
      );
      return;
    }

    final draft = PaymentDraft(
      name: _name.text,
      categoryId: categoryId,
      amountKopecks: _variableAmount ? null : parseRubles(_amount.text),
      periodMonths: _periodMonths,
      nextDueAt: _nextDue,
      remindDaysBefore: _remindDays,
      endsAt: end,
      note: _note.text,
    );

    setState(() => _saving = true);
    final repo = ref.read(paymentsRepositoryProvider);
    if (_isEdit) {
      await repo.update(widget.paymentId!, draft);
    } else {
      await repo.add(draft);
      await _askNotificationPermission();
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// После первого платежа просим разрешение на уведомления: в этот момент
  /// понятно, зачем оно нужно. Отказ или сбой не мешают сохранению.
  Future<void> _askNotificationPermission() async {
    if (!ref.read(reminderSettingsProvider).enabled) return;
    try {
      await ref
          .read(notificationSchedulerProvider)
          .requestNotificationPermission();
    } catch (e) {
      debugPrint('Не удалось запросить разрешение на уведомления: $e');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить платёж?'),
        content: const Text('Вместе с платежом удалится история оплат.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(paymentsRepositoryProvider).delete(widget.paymentId!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final selectedCategory =
        _categoryId ?? (categories.isEmpty ? null : categories.first.id);
    if (_categoryId == null && selectedCategory != null && !_isEdit) {
      // Категория по умолчанию — первая; запоминаем без лишней перерисовки.
      _categoryId = selectedCategory;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Платёж' : 'Новый платёж'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Например, Интернет',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Введите название'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey('category-$selectedCategory'),
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Категория',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? 'Выберите категорию' : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Сумма меняется'),
                      subtitle: const Text(
                        'Например, ЖКХ: сумму вводите при оплате',
                      ),
                      value: _variableAmount,
                      onChanged: (v) => setState(() => _variableAmount = v),
                    ),
                    if (!_variableAmount)
                      TextFormField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Сумма',
                          suffixText: '₽',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => parseRubles(v ?? '') == null
                            ? 'Введите сумму'
                            : null,
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _periodMonths,
                      decoration: const InputDecoration(
                        labelText: 'Как часто',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final e in periodOptions.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _periodMonths = v ?? 1),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: const Text('Ближайший платёж'),
                      subtitle: Text(formatDateFull(_nextDue)),
                      onTap: () async {
                        final picked = await _pickDate(_nextDue);
                        if (picked != null) {
                          setState(() => _nextDue = dateOnly(picked));
                        }
                      },
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: _remindDays,
                      decoration: const InputDecoration(
                        labelText: 'Напомнить',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final e in remindOptions.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _remindDays = v ?? 1),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Есть дата окончания'),
                      subtitle: const Text('Кредит или рассрочка'),
                      value: _endsAt != null,
                      onChanged: (v) =>
                          setState(() => _endsAt = v ? _nextDue : null),
                    ),
                    if (_endsAt != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_busy),
                        title: const Text('Последний платёж'),
                        subtitle: Text(formatDateFull(_endsAt!)),
                        onTap: () async {
                          final picked = await _pickDate(
                            _endsAt!,
                            first: _nextDue,
                          );
                          if (picked != null) {
                            setState(() => _endsAt = dateOnly(picked));
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Заметка',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

String _kopecksToInput(int kopecks) {
  final rubles = kopecks ~/ 100;
  final cents = kopecks % 100;
  return cents == 0 ? '$rubles' : '$rubles,${cents.toString().padLeft(2, '0')}';
}
