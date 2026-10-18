import 'package:ezhemesyachno/features/backup/data/safety_backup_store.dart';

/// Подмена хранилища страховочной копии: держит копию в памяти.
class FakeSafetyBackupStore implements SafetyBackupStore {
  SafetyCopy? copy;

  /// Если задано, сохранение бросает эту ошибку.
  Object? saveError;
  int saveCalls = 0;

  @override
  Future<void> save(String text, DateTime savedAt) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    copy = SafetyCopy(savedAt: savedAt, text: text);
  }

  @override
  Future<SafetyCopy?> load() async => copy;
}
