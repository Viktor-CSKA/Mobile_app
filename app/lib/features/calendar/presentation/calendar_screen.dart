import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../../payments/data/payments_providers.dart';
import '../../payments/domain/payment_schedule.dart';
import '../../payments/presentation/payment_form_screen.dart';
import '../../stats/presentation/stats_screen.dart';
import '../../upcoming/presentation/upcoming_labels.dart';
import '../data/calendar_providers.dart';
import '../domain/month_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    _month = DateTime(today.year, today.month);
    _selected = today;
  }

  void _goTo(DateTime month) {
    final today = ref.read(todayProvider);
    final first = DateTime(month.year, month.month);
    setState(() {
      _month = first;
      _selected = (today.year == first.year && today.month == first.month)
          ? today
          : first;
    });
  }

  void _openPayment(int paymentId) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => PaymentFormScreen(paymentId: paymentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final active = ref.watch(activePaymentsProvider);
    final paid = ref.watch(paidInMonthProvider(_month));

    final error = active.error ?? paid.error;
    final scheduled = active.value;
    final paidList = paid.value;

    Widget body;
    if (error != null) {
      body = Center(child: Text('Не удалось загрузить календарь: $error'));
    } else if (scheduled == null || paidList == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final calendar = MonthCalendar.build(
        month: _month,
        today: today,
        scheduled: scheduled,
        paid: paidList,
      );
      body = Column(
        children: [
          _MonthHeader(
            month: _month,
            onPrevious: () => _goTo(shiftMonth(_month, -1)),
            onNext: () => _goTo(shiftMonth(_month, 1)),
            onToday: () => _goTo(today),
          ),
          const _WeekdayRow(),
          _MonthGrid(
            calendar: calendar,
            today: today,
            selected: _selected,
            onSelect: (d) => setState(() => _selected = d),
          ),
          _TotalsRow(calendar: calendar),
          const Divider(height: 1),
          Expanded(
            child: _DayEntries(
              day: _selected,
              today: today,
              entries: calendar.entriesOn(_selected),
              onOpen: _openPayment,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь'),
        actions: [
          IconButton(
            tooltip: 'Статистика за год',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Предыдущий месяц',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              formatMonthYear(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(onPressed: onToday, child: const Text('Сегодня')),
          IconButton(
            tooltip: 'Следующий месяц',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final d in weekdaysShortRu)
            Expanded(
              child: Center(child: Text(d, style: style)),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.calendar,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final MonthCalendar calendar;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final month = calendar.month;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.count(
        key: const Key('calendar-grid'),
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.15,
        children: [
          for (var i = 0; i < calendar.leadingBlanks; i++) const SizedBox(),
          for (var d = 1; d <= calendar.daysCount; d++)
            _DayCell(
              day: DateTime(month.year, month.month, d),
              entries: calendar.entriesOn(DateTime(month.year, month.month, d)),
              isToday: dateOnly(today) == DateTime(month.year, month.month, d),
              isSelected:
                  dateOnly(selected) == DateTime(month.year, month.month, d),
              onTap: onSelect,
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entries,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final List<CalendarEntry> entries;
  final bool isToday;
  final bool isSelected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onTap(day),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final e in entries.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (e.overdue ? scheme.error : Color(e.colorValue))
                                  .withValues(alpha: e.paid ? 0.35 : 1),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.calendar});

  final MonthCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final t = calendar.totals;
    final parts = <String>[
      'Запланировано: ${formatKopecks(t.plannedKopecks)}',
      if (t.variableCount > 0) '+${t.variableCount} с переменной суммой',
      'Оплачено: ${formatKopecks(t.paidKopecks)}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        parts.join(' · '),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _DayEntries extends StatelessWidget {
  const _DayEntries({
    required this.day,
    required this.today,
    required this.entries,
    required this.onOpen,
  });

  final DateTime day;
  final DateTime today;
  final List<CalendarEntry> entries;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = dateOnly(day) == dateOnly(today);
    final title = isToday
        ? '${formatDateFull(day)} · сегодня'
        : formatDateFull(day);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('В этот день платежей нет'),
          ),
        for (final e in entries)
          ListTile(
            // Оплаченную запись тоже можно открыть: в форме платежа есть
            // история оплат.
            onTap: () => onOpen(e.paymentId),
            leading: CircleAvatar(
              backgroundColor: Color(e.colorValue),
              child: Icon(
                e.paid ? Icons.check : Icons.schedule,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(e.name),
            subtitle: Text(
              e.paid
                  ? 'Оплачено · ${e.categoryName}'
                  : '${dueLabel(daysBetween(today, e.date))} · ${e.categoryName}',
              style: e.overdue
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
            trailing: Text(
              e.amountKopecks == null
                  ? 'сумма меняется'
                  : formatKopecks(e.amountKopecks!),
              style: theme.textTheme.titleSmall,
            ),
          ),
      ],
    );
  }
}
