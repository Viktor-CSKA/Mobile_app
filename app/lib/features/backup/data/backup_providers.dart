import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/database/database_provider.dart';
import 'backup_repository.dart';
import 'data_transfer_service.dart';
import 'file_gateway.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(ref.watch(appDatabaseProvider)),
);

final fileGatewayProvider = Provider<FileGateway>(
  (ref) => const FilePickerGateway(),
);

final dataTransferServiceProvider = Provider<DataTransferService>((ref) {
  return DataTransferService(
    ref.watch(backupRepositoryProvider),
    ref.watch(fileGatewayProvider),
    () => ref.read(nowProvider),
  );
});
