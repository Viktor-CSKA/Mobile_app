import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/widget_data.dart';

/// Пишет кэш виджета, который читает нативный `AppWidgetProvider`.
abstract class WidgetCacheWriter {
  Future<void> write(WidgetData data);
}

/// Кладёт JSON в `widget_data.json` в папке приложения.
///
/// На Android это `getFilesDir()`, откуда виджет читает тем же путём
/// (`context.filesDir`), поэтому нативной стороне не нужен платформенный канал.
class FileWidgetCacheWriter implements WidgetCacheWriter {
  const FileWidgetCacheWriter();

  static const String fileName = 'widget_data.json';

  @override
  Future<void> write(WidgetData data) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(
      jsonEncode(data.toJson()),
      encoding: utf8,
      flush: true,
    );
  }
}
