import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../../reminders/data/reminder_providers.dart';
import '../data/payments_providers.dart';
import '../data/user_templates_providers.dart';
import '../domain/payment_draft.dart';
import '../domain/payment_schedule.dart';
import '../domain/payment_templates.dart';
import 'payment_history.dart';
import 'payment_labels.dart';
import 'template_picker.dart';

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
  final _amountFocus = FocusNode();

  int? _categoryId;
  bool _variableAmount = false;
  int _periodMonths = 1;
  int _remindDays = 1;
  DateTime _nextDue = dateOnly(DateTime.now());
  DateTime? _endsAt;
  bool _loading = false;
  bool _saving = false;

  /// false — платёж в архиве (выплачен или убран вручную).
  bool _isActive = true;

  /// У платежа из архива закончился срок: после «Сохранить» он вернётся в
  /// список с новыми датами.
  bool _reactivate = false;

  bool get _isEdit => widget.paymentId != null;

  @override
  void initState() {
    super.initState();
    _nextDue = dateOnly(ref.read(todayProvider));
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
      _isActive = payment.isActive;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  /// Заполняет форму шаблоном. Сумму не трогаем, кроме переменной (её
  /// очищаем); для платежа с постоянной суммой переводим фокус на «Сумма».
  void _applyTemplate(PaymentTemplate t, List<Category> categories) {
    final categoryId = categoryIdFor(t, [
      for (final c in categories) (id: c.id, name: c.name),
    ]);
    final due = suggestedDue(t, ref.read(todayProvider));
    setState(() {
      _name.text = t.name;
      if (categoryId != null) _categoryId = categoryId;
      _periodMonths = t.periodMonths;
      _remindDays = t.remindDaysBefore;
      _variableAmount = t.variableAmount;
      if (t.variableAmount) _amount.clear();
      // У шаблона пользователя есть своя сумма; у готовых её нет.
      if (!t.variableAmount && t.amountKopecks != null) {
        _amount.text = _kopecksToInput(t.amountKopecks!);
      }
      if (due != null) _nextDue = due;
    });
    if (!t.variableAmount && t.amountKopecks == null) {
      // Поле суммы могло только что появиться (если было «сумма меняется»),
      // поэтому фокус просим после перестроения.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
  }

  /// Запоминает заполненную форму как шаблон: потом платёж создаётся одним
  /// нажатием. Дата в шаблон не входит, кроме дня месяца.
  Future<void> _saveAsTemplate(List<Category> categories) async {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) return;
    final category = categories.where((c) => c.id == categoryId).firstOrNull;
    if (category == null) return;

    final name = _name.text.trim();
    await ref
        .read(userTemplatesProvider.notifier)
        .add(
          PaymentTemplate(
            name,
            category.name,
            periodMonths: _periodMonths,
            variableAmount: _variableAmount,
            amountKopecks: _variableAmount ? null : parseRubles(_amount.text),
            remindDaysBefore: _remindDays,
            dayOfMonth: _nextDue.day,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Шаблон «$name» сохранён: его можно выбрать в новом платеже',
          ),
        ),
      );
  }

  Future<void> _pickTemplate(List<Category> categories) async {
    final t = await showTemplatePicker(context);
    if (t != null && mounted) _applyTemplate(t, categories);
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
      await repo.update(widget.paymentId!, draft, reactivate: _reactivate);
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

  /// Убирает платёж в архив: история остаётся, из «Ближайших», календаря и
  /// напоминаний он пропадает.
  Future<void> _archive() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(paymentsRepositoryProvider).archive(widget.paymentId!);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Платёж убран в архив: он внизу списка платежей'),
        ),
      );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _unarchive() async {
    final messenger = ScaffoldMessenger.of(context);
    final back = await ref
        .read(paymentsRepositoryProvider)
        .unarchive(widget.paymentId!, today: ref.read(todayProvider));
    if (!mounted) return;
    if (back) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Платёж вернулся в список')),
        );
      Navigator.of(context).pop(true);
    } else {
      setState(() => _reactivate = true);
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
    final myTemplates = ref.watch(userTemplatesProvider);
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
          if (!_loading)
            IconButton(
              tooltip: 'Запомнить как шаблон',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: () => _saveAsTemplate(categories),
            ),
          if (_isEdit && _isActive && !_loading)
            IconButton(
              tooltip: 'В архив',
              icon: const Icon(Icons.archive_outlined),
              onPressed: _archive,
            ),
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
                    if (_isEdit && !_isActive) ...[
                      _ArchiveBanner(
                        reactivate: _reactivate,
                        onRestore: _unarchive,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!_isEdit) ...[
                      Text(
                        'Быстрый выбор',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      // Одна прокручиваемая строка вместо нескольких: форма
                      // остаётся короткой. «Все шаблоны» стоит первым.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.list, size: 18),
                              label: const Text('Все шаблоны'),
                              onPressed: () => _pickTemplate(categories),
                            ),
                            for (final t in myTemplates.take(5)) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                avatar: const Icon(Icons.bookmark, size: 18),
                                label: Text(t.name),
                                onPressed: () => _applyTemplate(t, categories),
                              ),
                            ],
                            for (final t in popularTemplates) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                label: Text(t.name),
                                onPressed: () => _applyTemplate(t, categories),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                        focusNode: _amountFocus,
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
                    if (_isEdit) PaymentHistory(paymentId: widget.paymentId!),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
      // Кнопка закреплена внизу: форма длинная, и её не нужно искать прокруткой.
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ),
    );
  }
}

/// Плашка наверху формы платежа из архива.
class _ArchiveBanner extends StatelessWidget {
  const _ArchiveBanner({required this.reactivate, required this.onRestore});

  final bool reactivate;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reactivate
                  ? 'Срок платежа закончился. Измените даты и нажмите '
                        '«Сохранить»: платёж вернётся в список.'
                  : 'Платёж в архиве: его нет в «Ближайших», календаре и '
                        'напоминаниях. История оплат сохранена.',
            ),
            if (!reactivate) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRestore,
                child: const Text('Вернуть из архива'),
              ),
            ],
          ],
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
