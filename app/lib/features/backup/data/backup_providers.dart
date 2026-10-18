import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/database/database_provider.dart';
import 'backup_repository.dart';
import 'data_transfer_service.dart';
import 'file_gateway.dart';
import 'safety_backup_store.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(ref.watch(appDatabaseProvider)),
);

final fileGatewayProvider = Provider<FileGateway>(
  (ref) => const FilePickerGateway(),
);

final safetyBackupStoreProvider = Provider<SafetyBackupStore>(
  (ref) => FileSafetyBackupStore(),
);

final dataTransferServiceProvider = Provider<DataTransferService>((ref) {
  return DataTransferService(
    ref.watch(backupRepositoryProvider),
    ref.watch(fileGatewayProvider),
    ref.watch(safetyBackupStoreProvider),
    () => ref.read(nowProvider),
  );
});

/// Что лежит в страховочной копии (null — копии нет). Обновляется после
/// каждого восстановления через `ref.invalidate`.
final safetyInfoProvider = FutureProvider.autoDispose<SafetyInfo?>(
  (ref) => ref.watch(dataTransferServiceProvider).safetyCopyInfo(),
);
