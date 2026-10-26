import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reminders/data/reminder_providers.dart';
import '../domain/payment_templates.dart';
import '../domain/user_templates.dart';

/// Шаблоны, которые пользователь запомнил сам («Запомнить как шаблон» в форме
/// платежа). Хранятся на устройстве, новые идут первыми.
class UserTemplatesNotifier extends Notifier<List<PaymentTemplate>> {
  static const key = 'user_templates';

  @override
  List<PaymentTemplate> build() =>
      decodeUserTemplates(ref.watch(sharedPreferencesProvider).getString(key));

  Future<void> add(PaymentTemplate template) =>
      _save(withTemplate(state, template));

  Future<void> remove(String name) => _save(withoutTemplate(state, name));

  Future<void> _save(List<PaymentTemplate> next) async {
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(key, encodeUserTemplates(next));
  }
}

final userTemplatesProvider =
    NotifierProvider<UserTemplatesNotifier, List<PaymentTemplate>>(
      UserTemplatesNotifier.new,
    );
