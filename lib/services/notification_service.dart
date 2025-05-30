import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return; // ⛔ Jangan init ulang kalau sudah

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notificationsPlugin.initialize(settings);
    tz.initializeTimeZones();

    // Minta izin Android 13+
    final status = await Permission.notification.request();
    if (status.isGranted) {
      print('✅ Izin notifikasi diberikan');
    } else {
      print('❌ Izin notifikasi ditolak');
    }

    _initialized = true; // ✅ Set sudah siap
  }

  static Future<void> scheduleDailyReminder({
    int hour = 20,
    int minute = 0,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      0,
      'Catatan Harian',
      'Sudah menulis catatan hari ini?',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminder',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> cancelAll() async {
    try {
      // Inisialisasi ulang jika perlu (opsional tapi aman)
      if (!_initialized) {
        await init(); // kamu bisa tambahkan flag _initialized jika mau
      }
      await _notificationsPlugin.cancelAll();
      print('✅ Notifikasi dibatalkan');
    } catch (e) {
      print('❌ Gagal membatalkan notifikasi: $e');
    }
  }

  static Future<void> showChallengeCompleted() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'challenge_channel',
        'Tantangan',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _notificationsPlugin.show(
      1, // ID notifikasi
      'Tantangan Selesai 🎉',
      'Kamu telah menulis jurnal selama 3 hari berturut-turut!',
      details,
    );
  }
}
