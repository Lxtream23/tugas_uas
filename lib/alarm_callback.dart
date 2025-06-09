import 'package:flutter/widgets.dart';
import 'services/backup_service.dart';

@pragma('vm:entry-point')
void alarmBackupCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackupService.backgroundBackup();
}
