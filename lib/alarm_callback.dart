// Import package Flutter untuk menggunakan WidgetsFlutterBinding.
// WidgetsFlutterBinding diperlukan untuk menginisialisasi binding Flutter pada background isolate.
import 'package:flutter/widgets.dart';

// Import BackupService dari folder services.
// BackupService berisi fungsi untuk melakukan proses backup data.
import 'services/backup_service.dart';

// Anotasi pragma untuk menandai fungsi ini sebagai entry-point VM.
// Ini penting agar fungsi ini bisa dipanggil dari luar aplikasi utama (misal oleh alarm manager di background).
@pragma('vm:entry-point')

// Fungsi callback yang akan dijalankan ketika alarm berbunyi (misal oleh background task scheduler).
// Fungsi ini bersifat async karena ada proses asynchronous di dalamnya.
void alarmBackupCallback() async {
  // Inisialisasi binding Flutter pada background isolate.
  // Ini wajib dipanggil sebelum menggunakan fitur/fungsi Flutter di background.
  WidgetsFlutterBinding.ensureInitialized();

  // Memanggil fungsi backgroundBackup dari BackupService.
  // Fungsi ini menjalankan proses backup data secara background.
  await BackupService.backgroundBackup();
}
