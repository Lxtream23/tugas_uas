import 'package:flutter/material.dart'; // Paket UI utama Flutter
import 'dart:io'; // Untuk operasi file dan deteksi platform
import 'dart:convert'; // Untuk encoding/decoding JSON
import 'dart:async'; // Untuk Timer dan operasi async
import 'package:file_picker/file_picker.dart'; // Untuk memilih file dari device
import 'package:shared_preferences/shared_preferences.dart'; // Untuk penyimpanan lokal sederhana
import 'package:tugas_uas/services/backup_service.dart'; // Service custom untuk backup/restore
import 'package:supabase_flutter/supabase_flutter.dart'; // Untuk autentikasi dan database Supabase
import 'package:tugas_uas/services/drive_backup_service.dart' as drive_backup; // Service backup ke Google Drive (tidak dipakai langsung di file ini)
import 'package:tugas_uas/services/google_drive_helper.dart'; // Helper upload/download Google Drive
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart'; // Untuk alarm/background task di Android
import 'package:flutter/foundation.dart'; // Untuk deteksi platform (web/native)
import 'package:tugas_uas/alarm_callback.dart'; // Callback alarm untuk backup otomatis
import 'package:flutter_svg/flutter_svg.dart'; // Untuk menampilkan SVG
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom snackbar

// Halaman utama backup & restore
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

// State dari halaman BackupPage
class _BackupPageState extends State<BackupPage> {
  bool _backupOtomatis = false; // Status backup otomatis aktif/tidak
  String? _email; // Email user yang login
  DateTime? _lastSyncTime; // Waktu terakhir backup/sync
  Timer? _backupTimer; // Timer untuk backup otomatis (jika app tetap terbuka)
  int? _backupInterval; // Interval pengingat backup (dalam hari)

  @override
  void initState() {
    super.initState();
    _loadPrefs(); // Load preferensi backup otomatis
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email; // Set email user jika login
      });
    }
    _loadLastSyncTime(); // Load waktu sync terakhir
    _setupPeriodicBackup(); // Setup backup otomatis jika aktif
    _loadBackupInterval(); // Load interval pengingat backup
  }

  @override
  void dispose() {
    _backupTimer?.cancel(); // Hentikan timer jika ada
    super.dispose();
  }

  // Load preferensi backup otomatis dari SharedPreferences
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backupOtomatis = prefs.getBool('backup_otomatis') ?? false;
    });
  }

  // Mendapatkan email user (tidak dipakai di file ini)
  Future<void> _getUserEmail() async {
    // Ganti dengan logika untuk mendapatkan email pengguna
    // Misalnya, dari SharedPreferences atau layanan autentikasi
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Tidak ada email';
  }

  // Load waktu terakhir sync dari SharedPreferences
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_sync');
    if (last != null) {
      setState(() {
        _lastSyncTime = DateTime.tryParse(last);
      });
    }
  }

  // Setup backup otomatis harian jika fitur aktif
  void _setupPeriodicBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final isAutoBackup = prefs.getBool('backup_otomatis') ?? false;

    if (!isAutoBackup) return; // Jika tidak aktif, keluar

    // Cek waktu terakhir backup
    final lastBackupStr = prefs.getString('last_sync');
    final lastBackup =
        lastBackupStr != null ? DateTime.tryParse(lastBackupStr) : null;

    final now = DateTime.now();

    // Jika belum pernah backup atau sudah lebih dari 1 hari, lakukan backup
    if (lastBackup == null || now.difference(lastBackup).inHours >= 24) {
      final backupFile = await BackupService.generateBackupJson(context);
      if (backupFile != null) {
        await GoogleDriveHelper.uploadBackupJson(
          context: context,
          fileName: 'backup_${now.toIso8601String().split('T').first}.json',
          jsonData: await backupFile.readAsString(),
        );
        await prefs.setString('last_sync', now.toIso8601String());

        if (mounted) {
          setState(() {
            _lastSyncTime = now;
          });
        }
      }
    }

    // Setup timer backup harian jika aplikasi tetap terbuka
    _backupTimer?.cancel();
    _backupTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      final backupFile = await BackupService.generateBackupJson(context);
      if (backupFile != null) {
        await GoogleDriveHelper.uploadBackupJson(
          context: context,
          fileName:
              'backup_${DateTime.now().toIso8601String().split('T').first}.json',
          jsonData: await backupFile.readAsString(),
        );
        await prefs.setString('last_sync', DateTime.now().toIso8601String());
      }
    });
  }

  // Load interval pengingat backup dari SharedPreferences
  Future<void> _loadBackupInterval() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backupInterval = prefs.getInt('backup_interval');
    });
  }

  @override
  Widget build(BuildContext context) {
    // UI utama halaman backup
    return Scaffold(
      appBar: AppBar(title: const Text('Cadangkan dan Pulihkan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tombol backup ke Google Drive
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: SvgPicture.asset(
                'assets/icons/google_icon.svg',
                width: 32,
                height: 32,
              ),
            ),
            title: const Text('Backup ke Google Drive'),
            subtitle: Text(_email ?? 'Memuat email...'),
            onTap: () async {
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;

              // Ambil data catatan dari Supabase
              final data = await Supabase.instance.client
                  .from('diary_entries')
                  .select()
                  .eq('user_id', user.id);

              final jsonContent = jsonEncode(data);

              // Upload ke Google Drive
              await GoogleDriveHelper.uploadBackupJson(
                context: context,
                fileName: 'backup_diary.json',
                jsonData: jsonContent,
              );
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'last_sync',
                DateTime.now().toIso8601String(),
              );

              setState(() {
                _lastSyncTime = DateTime.now();
              });
            },
          ),
          // Info waktu backup terakhir
          ListTile(
            title: const Text('Data Backup'),
            subtitle: Text(
              _lastSyncTime != null
                  ? 'Sync terakhir: ${_lastSyncTime!.toLocal().toString().split('.')[0]}'
                  : 'Belum ada sync',
            ),
          ),

          const Divider(height: 32),
          // Switch untuk mengaktifkan backup otomatis
          SwitchListTile(
            value: _backupOtomatis,
            onChanged: (val) async {
              setState(() => _backupOtomatis = val);
              final prefs = await SharedPreferences.getInstance();
              prefs.setBool('backup_otomatis', val);

              // Jika di Android native, setup/cancel alarm background
              if (!kIsWeb && Platform.isAndroid) {
                if (val) {
                  await AndroidAlarmManager.periodic(
                    const Duration(days: 1),
                    0, // ID alarm
                    alarmBackupCallback,
                    startAt: DateTime.now().add(const Duration(seconds: 10)),
                    exact: true,
                    wakeup: true,
                    rescheduleOnReboot: true,
                  );
                } else {
                  await AndroidAlarmManager.cancel(0);
                }
              }
              // Tampilkan snackbar notifikasi
              showCustomSnackBar(
                context,
                val
                    ? 'Backup otomatis diaktifkan'
                    : 'Backup otomatis dimatikan',
                type: SnackBarType.success,
                duration: const Duration(seconds: 2),
                showAtTop: true,
              );
            },
            title: const Text('Backup otomatis'),
            subtitle: const Text(
              'Aktifkan backup otomatis untuk menghindari kelalaian dalam sinkronisasi diary',
            ),
            //secondary: const Icon(Icons.auto, color: Colors.amber),
          ),

          const Divider(),

          // Tombol backup manual
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Cadangkan Sekarang'),
            onPressed: () => BackupService.generateBackupJson(context),
          ),
          const SizedBox(height: 12),
          // Tombol restore dari file backup
          ElevatedButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Pulihkan dari File'),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Konfirmasi Pemulihan'),
                      content: const Text(
                        'Apakah kamu yakin ingin memulihkan catatan dari file backup?\nData lama bisa ditimpa.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Pulihkan'),
                        ),
                      ],
                    ),
              );

              if (confirm == true) {
                await BackupService.restoreBackup(context);
              }
            },
          ),

          const Divider(),

          // Pengaturan interval pengingat backup
          ListTile(
            title: const Text('Pengingat Cadangan'),
            subtitle: Text(
              _backupInterval != null
                  ? 'Setiap $_backupInterval hari'
                  : 'Tidak aktif',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('Pilih interval pengingat'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            _buildIntervalTile(1),   // Pilihan interval 1 hari
                            _buildIntervalTile(3),   // Pilihan interval 3 hari
                            _buildIntervalTile(7),   // Pilihan interval 7 hari
                            _buildIntervalTile(14),  // Pilihan interval 14 hari
                            _buildIntervalTile(30),  // Pilihan interval 30 hari
                            // Opsi untuk mematikan pengingat
                            ListTile(
                              title: const Text('Matikan pengingat'),
                              leading:
                                  _backupInterval == null
                                      ? const Icon(
                                        Icons.check,
                                        color: Colors.blue,
                                      )
                                      : null,
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove('backup_interval');
                                await _loadBackupInterval();
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget untuk memilih interval pengingat backup
  Widget _buildIntervalTile(int days) {
    return ListTile(
      title: Text('Setiap $days hari'),
      leading:
          _backupInterval == days
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('backup_interval', days); // Simpan interval
        await _loadBackupInterval(); // Refresh tampilan
        if (context.mounted) Navigator.pop(context); // Tutup dialog
      },
    );
  }
}
