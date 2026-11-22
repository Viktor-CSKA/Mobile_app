import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Кольцо прогресса «оплачено из месячного бюджета».
///
/// Показывает долю [paidKopecks] от общего размера месяца [totalKopecks]
/// (оплаченное + оставшееся). В центре — сумма, которую ещё предстоит
/// заплатить; подпись под ней поясняет, от какой суммы считается доля.
class MonthProgressRing extends StatelessWidget {
  const MonthProgressRing({
    super.key,
    required this.paidKopecks,
    required this.totalKopecks,
    this.size = 92,
    this.strokeWidth = 9,
  }) : assert(totalKopecks >= 0, 'общий размер месяца не бывает отрицательным');

  /// Уже оплачено в этом месяце.
  final int paidKopecks;

  /// Весь месячный бюджет: оплаченное + оставшееся к оплате.
  final int totalKopecks;

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = math.max(0, totalKopecks - paidKopecks);
    final progress = totalKopecks == 0
        ? 0.0
        : (paidKopecks / totalKopecks).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                remaining == 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.tertiary,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Точная оставшаяся сумма стоит рядом в заголовке карточки,
              // поэтому в центре кольца дублировать её не нужно.
              Text(
                remaining == 0 ? 'всё оплачено' : 'осталось',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
