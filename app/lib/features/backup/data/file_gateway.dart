import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Работа с файлами через системные диалоги. В тестах подменяется.
abstract class FileGateway {
  /// Предлагает пользователю сохранить файл. Возвращает false, если он
  /// отказался.
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Предлагает выбрать файл и возвращает его содержимое; null — отказ.
  /// Бросает [FileTooLargeException], если файл больше [maxBytes].
  Future<Uint8List?> pickFile({required int maxBytes});
}

class FileTooLargeException implements Exception {
  const FileTooLargeException();
}

/// Реализация на file_picker (системные диалоги Android).
class FilePickerGateway implements FileGateway {
  const FilePickerGateway();

  @override
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: 'Сохранить файл',
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> pickFile({required int maxBytes}) async {
    final file = await FilePicker.pickFile(dialogTitle: 'Выберите файл копии');
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > maxBytes) throw const FileTooLargeException();
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw const FileTooLargeException();
    return bytes;
  }
}
