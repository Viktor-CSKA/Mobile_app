import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../payments/domain/payment_draft.dart';

/// Спрашивает фактически оплаченную сумму. Возвращает копейки или null (отмена).
///
/// Поле заполнено обычной суммой платежа; для платежа с переменной суммой пусто.
Future<int?> showPayDialog(BuildContext context, PaymentWithCategory item) {
  return showDialog<int>(
    context: context,
    builder: (_) => _PayDialog(item: item),
  );
}

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.item});

  final PaymentWithCategory item;

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    final known = widget.item.payment.amountKopecks;
    _amount = TextEditingController(text: known == null ? '' : _toInput(known));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(parseRubles(_amount.text));
  }

  @override
  Widget build(BuildContext context) {
    final variable = widget.item.payment.amountKopecks == null;
    return AlertDialog(
      title: Text('Оплачено: ${widget.item.payment.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              variable
                  ? 'Введите, сколько вы заплатили.'
                  : 'Сумма из платежа. Измените, если заплатили иначе.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Сумма',
                suffixText: '₽',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  parseRubles(v ?? '') == null ? 'Введите сумму' : null,
              onFieldSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Оплачено')),
      ],
    );
  }
}

String _toInput(int kopecks) {
  final rubles = kopecks ~/ 100;
  final cents = kopecks % 100;
  return cents == 0 ? '$rubles' : '$rubles,${cents.toString().padLeft(2, '0')}';
}
