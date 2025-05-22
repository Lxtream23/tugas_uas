import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugas_uas/services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _diaryReminder = false;
  bool _pinToNotification = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _diaryReminder = prefs.getBool('notif_harian') ?? false;
      _pinToNotification = prefs.getBool('pin_notif') ?? false;
      _reminderTime = TimeOfDay(
        hour: prefs.getInt('notif_hour') ?? 20,
        minute: prefs.getInt('notif_minute') ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pemberitahuan')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Pengingat Tidak Bekerja?'),
            subtitle: const Text('Ketuk untuk menemukan solusi'),
            onTap: () {
              // Tampilkan dialog solusi
              showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('Solusi'),
                      content: const Text(
                        'Pastikan izin notifikasi aktif di pengaturan sistem.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tutup'),
                        ),
                      ],
                    ),
              );
            },
            trailing: const Icon(Icons.info_outline),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Sematkan Pengingat ke Bilah Pemberitahuan'),
            value: _pinToNotification,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              setState(() => _pinToNotification = value);
              prefs.setBool('pin_notif', value);
            },
          ),
          SwitchListTile(
            title: const Text('Pengingat Diary'),
            subtitle: const Text(
              'Nyalakan pengingat untuk menghindari lupa menulis buku harian',
            ),
            value: _diaryReminder,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              setState(() => _diaryReminder = value);
              prefs.setBool('notif_harian', value);

              if (value) {
                await NotificationService.scheduleDailyReminder(
                  hour: _reminderTime.hour,
                  minute: _reminderTime.minute,
                );
                // ✅ Tampilkan SnackBar ketika aktif
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: const [
                        Icon(Icons.notifications_active, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(child: Text('Notifikasi diaktifkan')),
                      ],
                    ),
                    backgroundColor: Colors.green[600],
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } else {
                // ❌ Tampilkan SnackBar ketika nonaktif
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: const [
                        Icon(Icons.notifications_off, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(child: Text('Notifikasi dimatikan')),
                      ],
                    ),
                    backgroundColor: Colors.red[600],
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
          ),

          ListTile(
            title: const Text('Waktu Pengingat'),
            subtitle: Text('${_reminderTime.format(context)}'),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _reminderTime,
              );
              if (picked != null) {
                final prefs = await SharedPreferences.getInstance();
                setState(() => _reminderTime = picked);
                prefs.setInt('notif_hour', picked.hour);
                prefs.setInt('notif_minute', picked.minute);

                if (_diaryReminder) {
                  await NotificationService.scheduleDailyReminder(
                    hour: picked.hour,
                    minute: picked.minute,
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('Fase Pengingat'),
            subtitle: const Text('Otomatis'), // placeholder
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur belum tersedia')),
              );
            },
          ),
        ],
      ),
    );
  }
}
