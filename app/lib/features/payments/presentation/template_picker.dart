import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../data/user_templates_providers.dart';
import '../domain/payment_templates.dart';
import 'payment_labels.dart';

/// Открывает список всех шаблонов с поиском; возвращает выбранный или null.
/// Сверху — шаблоны, которые пользователь запомнил сам.
Future<PaymentTemplate?> showTemplatePicker(BuildContext context) {
  return showModalBottomSheet<PaymentTemplate>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _TemplatePicker(),
  );
}

class _TemplatePicker extends ConsumerStatefulWidget {
  const _TemplatePicker();

  @override
  ConsumerState<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends ConsumerState<_TemplatePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = searchIn(ref.watch(userTemplatesProvider), _query);
    final found = searchTemplates(_query);

    final children = <Widget>[];

    if (mine.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Мои шаблоны', style: theme.textTheme.titleSmall),
        ),
      );
      for (final t in mine) {
        children.add(
          ListTile(
            title: Text(t.name),
            subtitle: Text(_hint(t)),
            onTap: () => Navigator.of(context).pop(t),
            trailing: IconButton(
              tooltip: 'Удалить шаблон «${t.name}»',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(userTemplatesProvider.notifier).remove(t.name),
            ),
          ),
        );
      }
    }

    // Готовые шаблоны по категориям, порядок каталога сохраняется.
    String? current;
    for (final t in found) {
      if (t.categoryName != current) {
        current = t.categoryName;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(t.categoryName, style: theme.textTheme.titleSmall),
          ),
        );
      }
      children.add(
        ListTile(
          title: Text(t.name),
          subtitle: Text(_hint(t)),
          onTap: () => Navigator.of(context).pop(t),
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск: например, «ипотека»',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: children.isEmpty
                ? const Center(child: Text('Ничего не найдено'))
                : ListView(children: children),
          ),
        ],
      ),
    );
  }

  String _hint(PaymentTemplate t) {
    final amount = t.amountKopecks;
    final parts = [
      periodLabel(t.periodMonths),
      if (t.variableAmount) 'сумма меняется',
      if (!t.variableAmount && amount != null) formatKopecks(amount),
    ];
    return parts.join(' · ');
  }
}
