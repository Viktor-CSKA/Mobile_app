import 'package:flutter/services.dart';

/// Сообщает нативной стороне, что кэш виджета обновился и нужно перерисовать.
abstract class WidgetRefresh {
  Future<void> refresh();
}

/// Метод `update` на канале `app.ezhemesyachno/widget` обновляет все виджеты.
class MethodChannelWidgetRefresh implements WidgetRefresh {
  const MethodChannelWidgetRefresh();

  static const MethodChannel _channel = MethodChannel(
    'app.ezhemesyachno/widget',
  );

  @override
  Future<void> refresh() async {
    try {
      await _channel.invokeMethod<void>('update');
    } on MissingPluginException {
      // Не Android (например, тесты) — виджета нет, пропускаем молча.
    } on PlatformException {
      // Канал не ответил — не мешаем работе приложения.
    }
  }
}
