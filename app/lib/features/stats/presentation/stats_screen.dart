import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../../../core/format/plural_ru.dart';
import '../data/stats_providers.dart';
import '../domain/year_stats.dart';

/// Статистика оплат за год: итог, по месяцам и по категориям.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late int _year = ref.read(todayProvider).year;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(yearStatsProvider(_year));

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Предыдущий год',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _year--),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Следующий год',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _year++),
              ),
            ],
          ),
          Expanded(
            child: stats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Не удалось посчитать статистику: $e')),
              data: (s) => s.isEmpty ? _Empty(year: _year) : _Content(s),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'За $year год оплат пока нет.\n'
          'Статистика строится по отметкам «Оплачено».',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content(this.stats);

  final YearStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = stats.paymentsCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Оплачено за ${stats.year} год'),
                const SizedBox(height: 4),
                Text(
                  formatKopecks(stats.totalKopecks),
                  key: const Key('stats-total'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$count ${pluralRu(count, 'оплата', 'оплаты', 'оплат')}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const _Title('По месяцам'),
        for (var m = 1; m <= 12; m++)
          _BarRow(
            label: monthNameRu(m),
            value: stats.byMonthKopecks[m - 1],
            max: stats.maxMonthKopecks,
          ),
        const _Title('По категориям'),
        for (final c in stats.byCategory)
          _BarRow(
            label: c.category.name,
            value: c.kopecks,
            max: stats.byCategory.first.kopecks,
            color: Color(c.category.colorValue),
            share: stats.totalKopecks == 0
                ? null
                : (c.kopecks * 100 / stats.totalKopecks).round(),
          ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Строка со столбиком: подпись, сумма (и доля), длина по отношению к [max].
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    this.color,
    this.share,
  });

  final String label;
  final int value;
  final int max;
  final Color? color;

  /// Доля от итога в процентах (для категорий).
  final int? share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = max <= 0 ? 0.0 : value / max;
    final amount = value == 0
        ? '—'
        : share == null
        ? formatKopecks(value)
        : '${formatKopecks(value)} · $share%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (color != null) ...[
                CircleAvatar(radius: 5, backgroundColor: color),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(label)),
              Text(amount, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: color,
          ),
        ],
      ),
    );
  }
}
