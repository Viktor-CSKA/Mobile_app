import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Страховочная копия данных: приложение делает её само перед тем, как
/// заменить данные содержимым файла.
class SafetyCopy {
  const SafetyCopy({required this.savedAt, required this.text});

  final DateTime savedAt;

  /// Текст резервной копии (тот же формат, что у файла копии).
  final String text;
}

/// Хранилище единственной страховочной копии: новая заменяет прежнюю.
/// В тестах подменяется.
abstract class SafetyBackupStore {
  Future<void> save(String text, DateTime savedAt);

  /// Последняя копия или null, если её нет или она повреждена.
  Future<SafetyCopy?> load();
}

/// Хранит копию файлом в личной папке приложения (она не видна другим
/// приложениям и удаляется вместе с приложением).
class FileSafetyBackupStore implements SafetyBackupStore {
  FileSafetyBackupStore([Future<Directory> Function()? directory])
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'safety-backup.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<void> save(String text, DateTime savedAt) async {
    final file = await _file();
    // Сначала пишем во временный файл: сбой посреди записи не затрёт прежнюю
    // копию.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({'savedAt': savedAt.toUtc().toIso8601String(), 'text': text}),
      flush: true,
    );
    await temp.rename(file.path);
  }

  @override
  Future<SafetyCopy?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final map = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final savedAt = DateTime.parse(map['savedAt']! as String).toLocal();
      return SafetyCopy(savedAt: savedAt, text: map['text']! as String);
    } catch (_) {
      return null;
    }
  }
}
