import 'package:ezhemesyachno/features/widget/data/widget_cache_writer.dart';
import 'package:ezhemesyachno/features/widget/data/widget_refresh.dart';
import 'package:ezhemesyachno/features/widget/domain/widget_data.dart';

/// Записывает кэш в память: никакого реального файла и плагина path_provider.
class FakeWidgetCacheWriter implements WidgetCacheWriter {
  final List<WidgetData> writes = [];

  /// Если true, `write` бросает исключение (проверка устойчивости).
  bool fail = false;

  @override
  Future<void> write(WidgetData data) async {
    if (fail) throw StateError('cache write failed');
    writes.add(data);
  }

  WidgetData? get last => writes.isEmpty ? null : writes.last;
}

/// Считает вызовы refresh без платформенного канала.
class FakeWidgetRefresh implements WidgetRefresh {
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }
}
