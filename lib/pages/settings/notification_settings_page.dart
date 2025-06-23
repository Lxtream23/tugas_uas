import 'package:flutter/material.dart'; // Import library Flutter untuk UI
import 'package:shared_preferences/shared_preferences.dart'; // Untuk menyimpan preferensi secara lokal
import 'package:tugas_uas/services/notification_service.dart'; // Service untuk mengatur notifikasi
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom snackbar
import 'package:another_flushbar/flushbar.dart'; // Library pihak ketiga untuk menampilkan flushbar/snackbar

// Widget utama halaman pengaturan notifikasi
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

// State dari NotificationSettingsPage, menyimpan status dan logika
class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Variabel untuk menyimpan status pengingat diary
  bool _diaryReminder = false;
  // Variabel untuk menyimpan status pin notifikasi ke bilah pemberitahuan
  bool _pinToNotification = false;
  // Variabel untuk menyimpan waktu pengingat
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPrefs(); // Memuat preferensi dari penyimpanan lokal saat inisialisasi
    _loadPinStatus(); // Memuat status pin notifikasi
  }

  // Fungsi untuk memuat preferensi dari SharedPreferences
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Ambil status pengingat harian, pin notifikasi, dan waktu pengingat
      _diaryReminder = prefs.getBool('notif_harian') ?? false;
      _pinToNotification = prefs.getBool('pin_notif') ?? false;
      _reminderTime = TimeOfDay(
        hour: prefs.getInt('notif_hour') ?? 20,
        minute: prefs.getInt('notif_minute') ?? 0,
      );
      // Debug print untuk memastikan nilai yang diambil
      debugPrint(
        '>> prefs.getBool(notif_harian): ${prefs.getBool('notif_harian')}',
      );
      debugPrint('>> prefs.getBool(pin_notif): ${prefs.getBool('pin_notif')}');
    });
  }

  // Fungsi untuk memuat status pin notifikasi dan menampilkan snackbar status awal
  Future<void> _loadPinStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinToNotification = prefs.getBool('pin_notif') ?? false;
    });

    // Menampilkan snackbar status pin setelah frame selesai dirender
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomSnackBar(
        context,
        _pinToNotification
            ? 'Pengingat saat ini disematkan'
            : 'Pengingat tidak disematkan',
        type: SnackBarType.success,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold sebagai kerangka utama halaman
    return Scaffold(
      appBar: AppBar(title: const Text('Pemberitahuan')), // Judul halaman
      body: ListView(
        children: [
          // ListTile untuk solusi jika notifikasi tidak bekerja
          ListTile(
            title: const Text('Pengingat Tidak Bekerja?'),
            subtitle: const Text('Ketuk untuk menemukan solusi'),
            onTap: () {
              // Tampilkan dialog solusi ketika diklik
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
            trailing: const Icon(Icons.info_outline), // Icon info di kanan
          ),
          const Divider(), // Garis pemisah

          // SwitchListTile untuk mengaktifkan/menonaktifkan pin notifikasi
          SwitchListTile(
            title: const Text('Sematkan Pengingat ke Bilah Pemberitahuan'),
            value: _pinToNotification,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              setState(() => _pinToNotification = value); // Update state
              prefs.setBool('pin_notif', value); // Simpan ke preferensi
              if (value) {
                // Tampilkan snackbar jika diaktifkan
                showCustomSnackBar(
                  context,
                  'Pengingat disematkan ke bilah pemberitahuan',
                  type: SnackBarType.success,
                  duration: const Duration(seconds: 2),
                  showAtTop: true,
                );
              } else {
                // Tampilkan snackbar jika dinonaktifkan
                showCustomSnackBar(
                  context,
                  'Pengingat tidak disematkan lagi',
                  type: SnackBarType.success,
                  duration: const Duration(seconds: 2),
                  showAtTop: true,
                );
              }
            },
          ),

          // SwitchListTile untuk mengaktifkan/menonaktifkan pengingat diary harian
          SwitchListTile(
            title: const Text('Pengingat Diary'),
            subtitle: const Text(
              'Nyalakan pengingat untuk menghindari lupa menulis buku harian',
            ),
            value: _diaryReminder,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              setState(() => _diaryReminder = value); // Update state
              prefs.setBool('notif_harian', value); // Simpan ke preferensi

              if (value) {
                // Jika diaktifkan, jadwalkan notifikasi harian
                await NotificationService.scheduleDailyReminder(
                  hour: _reminderTime.hour,
                  minute: _reminderTime.minute,
                );
                // Tampilkan flushbar notifikasi aktif
                Flushbar(
                  messageText: Row(
                    children: const [
                      Icon(Icons.notifications_active, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifikasi diaktifkan',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green[600]!,
                  duration: const Duration(seconds: 3),
                  flushbarPosition:
                      FlushbarPosition.TOP, // Tampilkan di atas
                  borderRadius: BorderRadius.circular(12),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  animationDuration: const Duration(milliseconds: 400),
                ).show(context);
              } else {
                // Jika dinonaktifkan, tampilkan flushbar notifikasi mati
                Flushbar(
                  messageText: Row(
                    children: const [
                      Icon(Icons.notifications_active, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifikasi dimatikan',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red[600]!,
                  duration: const Duration(seconds: 3),
                  flushbarPosition:
                      FlushbarPosition.TOP, // Tampilkan di atas
                  borderRadius: BorderRadius.circular(12),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  animationDuration: const Duration(milliseconds: 400),
                ).show(context);
              }
            },
          ),

          // ListTile untuk memilih waktu pengingat
          ListTile(
            title: const Text('Waktu Pengingat'),
            subtitle: Text('${_reminderTime.format(context)}'), // Tampilkan waktu saat ini
            onTap: () async {
              // Tampilkan time picker saat diklik
              final picked = await showTimePicker(
                context: context,
                initialTime: _reminderTime,
              );
              if (picked != null) {
                final prefs = await SharedPreferences.getInstance();
                setState(() => _reminderTime = picked); // Update waktu
                prefs.setInt('notif_hour', picked.hour); // Simpan jam
                prefs.setInt('notif_minute', picked.minute); // Simpan menit

                if (_diaryReminder) {
                  // Jika pengingat aktif, jadwalkan ulang notifikasi
                  await NotificationService.scheduleDailyReminder(
                    hour: picked.hour,
                    minute: picked.minute,
                  );
                }
              }
            },
          ),

          // ListTile untuk fitur fase pengingat (belum tersedia)
          ListTile(
            title: const Text('Fase Pengingat'),
            subtitle: const Text('Otomatis'), // Placeholder
            onTap: () {
              // Tampilkan snackbar fitur belum tersedia
              showCustomSnackBar(
                context,
                'Fitur belum tersedia',
                type: SnackBarType.warning,
                duration: const Duration(seconds: 2),
                showAtTop: true,
              );
            },
          ),
        ],
      ),
    );
  }
}
