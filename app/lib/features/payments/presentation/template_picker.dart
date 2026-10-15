import 'package:flutter/material.dart';

import '../domain/payment_templates.dart';
import 'payment_labels.dart';

/// Открывает список всех шаблонов с поиском; возвращает выбранный или null.
Future<PaymentTemplate?> showTemplatePicker(BuildContext context) {
  return showModalBottomSheet<PaymentTemplate>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _TemplatePicker(),
  );
}

class _TemplatePicker extends StatefulWidget {
  const _TemplatePicker();

  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final found = searchTemplates(_query);

    // Группы по категориям, порядок каталога сохраняется.
    final children = <Widget>[];
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
            child: found.isEmpty
                ? const Center(child: Text('Ничего не найдено'))
                : ListView(children: children),
          ),
        ],
      ),
    );
  }

  String _hint(PaymentTemplate t) {
    final parts = [
      periodLabel(t.periodMonths),
      if (t.variableAmount) 'сумма меняется',
    ];
    return parts.join(' · ');
  }
}
