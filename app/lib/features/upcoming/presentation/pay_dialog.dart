import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../payments/domain/payment_draft.dart';

/// Спрашивает фактически оплаченную сумму. Возвращает сумму либо пропуск
/// периода. Отмена (null из диалога) превращается в пустой результат.
/// Поле заполнено обычной суммой платежа; для платежа с переменной суммой пусто.
Future<PayDialogResult> showPayDialog(
  BuildContext context,
  PaymentWithCategory item,
) async {
  final result = await showDialog<PayDialogResult>(
    context: context,
    builder: (_) => _PayDialog(item: item),
  );
  return result ?? const PayDialogResult();
}

class PayDialogResult {
  const PayDialogResult({this.amount, this.skip = false});

  /// Оплачиваемая сумма в копейках; null без [skip] — отмена.
  final int? amount;

  /// true — пользователь выбрал «Пропустить период».
  final bool skip;
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
    Navigator.of(context)
        .pop(PayDialogResult(amount: parseRubles(_amount.text)));
  }

  void _skip() {
    Navigator.of(context).pop(const PayDialogResult(skip: true));
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
        TextButton(onPressed: _skip, child: const Text('Пропустить')),
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
