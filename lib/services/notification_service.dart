import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import package notifikasi lokal
import 'package:timezone/data/latest.dart' as tz; // Import data timezone terbaru
import 'package:timezone/timezone.dart' as tz; // Import fungsi timezone
import 'package:permission_handler/permission_handler.dart'; // Import untuk meminta izin notifikasi

// Kelas service untuk mengatur notifikasi lokal aplikasi
class NotificationService {
  // Singleton instance dari plugin notifikasi
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Flag untuk memastikan inisialisasi hanya dilakukan sekali
  static bool _initialized = false;

  // Fungsi inisialisasi notifikasi dan timezone
  static Future<void> init() async {
    if (_initialized) return; // Jika sudah diinisialisasi, keluar

    // Pengaturan inisialisasi untuk Android (ikon launcher)
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    // Inisialisasi plugin notifikasi dengan pengaturan di atas
    await _notificationsPlugin.initialize(settings);

    // Inisialisasi data timezone
    tz.initializeTimeZones();

    // Meminta izin notifikasi (khusus Android 13+)
    final status = await Permission.notification.request();
    if (status.isGranted) {
      print('✅ Izin notifikasi diberikan');
    } else {
      print('❌ Izin notifikasi ditolak');
    }

    _initialized = true; // Set flag sudah diinisialisasi
  }

  // Fungsi untuk menjadwalkan notifikasi harian pada jam & menit tertentu
  static Future<void> scheduleDailyReminder({
    int hour = 20, // Default jam 20 (8 malam)
    int minute = 0, // Default menit 0
  }) async {
    await _notificationsPlugin.zonedSchedule(
      0, // ID notifikasi
      'Catatan Harian', // Judul notifikasi
      'Sudah menulis catatan hari ini?', // Isi pesan notifikasi
      _nextInstanceOfTime(hour, minute), // Waktu penjadwalan berikutnya
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel', // Channel ID
          'Daily Reminder', // Nama channel
          importance: Importance.max, // Tingkat kepentingan tinggi
          priority: Priority.high, // Prioritas tinggi
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Mode penjadwalan agar tetap berjalan walau idle
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime, // Interpretasi waktu absolut
      matchDateTimeComponents: DateTimeComponents.time, // Hanya jam & menit yang dicocokkan (harian)
    );
  }

  // Fungsi untuk mendapatkan waktu berikutnya sesuai jam & menit yang diinginkan
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local); // Waktu saat ini di zona lokal
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // Jika waktu yang dijadwalkan sudah lewat hari ini, jadwalkan untuk besok
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Fungsi untuk membatalkan semua notifikasi yang terjadwal/aktif
  static Future<void> cancelAll() async {
    try {
      // Pastikan sudah diinisialisasi sebelum membatalkan notifikasi
      if (!_initialized) {
        await init(); // Inisialisasi jika belum
      }
      await _notificationsPlugin.cancelAll(); // Batalkan semua notifikasi
      print('✅ Notifikasi dibatalkan');
    } catch (e) {
      print('❌ Gagal membatalkan notifikasi: $e'); // Tampilkan error jika gagal
    }
  }

  // Fungsi untuk menampilkan notifikasi ketika tantangan selesai (misal: menulis jurnal 3 hari berturut-turut)
  static Future<void> showChallengeCompleted() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'challenge_channel', // Channel ID khusus tantangan
        'Tantangan', // Nama channel
        importance: Importance.high, // Tingkat kepentingan tinggi
        priority: Priority.high, // Prioritas tinggi
      ),
    );

    await _notificationsPlugin.show(
      1, // ID notifikasi
      'Tantangan Selesai 🎉', // Judul notifikasi
      'Kamu telah menulis jurnal selama 3 hari berturut-turut!', // Isi pesan notifikasi
      details, // Detail pengaturan notifikasi
    );
  }
}
