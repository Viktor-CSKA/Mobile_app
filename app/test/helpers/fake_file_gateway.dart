import 'dart:convert';
import 'dart:typed_data';

import 'package:ezhemesyachno/features/backup/data/file_gateway.dart';

/// Подмена системных диалогов: запоминает сохранённые файлы, «выбирает»
/// заранее заданный файл.
class FakeFileGateway implements FileGateway {
  FakeFileGateway({this.pickResult, this.saveAccepted = true});

  /// Что вернёт выбор файла (null — пользователь отказался).
  Uint8List? pickResult;
  bool saveAccepted;

  /// Если задано, соответствующий вызов бросает эту ошибку.
  Object? saveError;
  Object? pickError;

  final List<({String name, Uint8List bytes, String mime})> saved = [];
  int pickCalls = 0;
  int? lastMaxBytes;

  void pickText(String text) =>
      pickResult = Uint8List.fromList(utf8.encode(text));

  String? get lastSavedText => saved.isEmpty
      ? null
      : utf8.decode(saved.last.bytes, allowMalformed: true);

  @override
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (saveError != null) throw saveError!;
    saved.add((name: fileName, bytes: bytes, mime: mimeType));
    return saveAccepted;
  }

  @override
  Future<Uint8List?> pickFile({required int maxBytes}) async {
    pickCalls++;
    lastMaxBytes = maxBytes;
    if (pickError != null) throw pickError!;
    return pickResult;
  }
}
