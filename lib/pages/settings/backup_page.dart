import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugas_uas/services/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/services/drive_backup_service.dart' as drive_backup;
import 'package:tugas_uas/services/google_drive_helper.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:tugas_uas/alarm_callback.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tugas_uas/widgets/custom_snackbar.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _backupOtomatis = false;
  String? _email;
  DateTime? _lastSyncTime;
  Timer? _backupTimer;
  int? _backupInterval;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email;
      });
    }
    _loadLastSyncTime();
    _setupPeriodicBackup();
    _loadBackupInterval();
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backupOtomatis = prefs.getBool('backup_otomatis') ?? false;
    });
  }

  Future<void> _getUserEmail() async {
    // Ganti dengan logika untuk mendapatkan email pengguna
    // Misalnya, dari SharedPreferences atau layanan autentikasi
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Tidak ada email';
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_sync');
    if (last != null) {
      setState(() {
        _lastSyncTime = DateTime.tryParse(last);
      });
    }
  }

  void _setupPeriodicBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final isAutoBackup = prefs.getBool('backup_otomatis') ?? false;

    if (!isAutoBackup) return;

    // Cek waktu terakhir backup
    final lastBackupStr = prefs.getString('last_sync');
    final lastBackup =
        lastBackupStr != null ? DateTime.tryParse(lastBackupStr) : null;

    final now = DateTime.now();

    // Kalau belum pernah atau sudah lebih dari 1 hari
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

    // Opsional: Siapkan backup harian berikutnya (kalau app tetap terbuka)
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

  Future<void> _loadBackupInterval() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backupInterval = prefs.getInt('backup_interval');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadangkan dan Pulihkan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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

              // 🔁 Upload ke Google Drive
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
          //const Icon(Icons.more_vert),
          ListTile(
            title: const Text('Data Backup'),
            subtitle: Text(
              _lastSyncTime != null
                  ? 'Sync terakhir: ${_lastSyncTime!.toLocal().toString().split('.')[0]}'
                  : 'Belum ada sync',
            ),
          ),

          const Divider(height: 32),
          SwitchListTile(
            value: _backupOtomatis,
            onChanged: (val) async {
              setState(() => _backupOtomatis = val);
              final prefs = await SharedPreferences.getInstance();
              prefs.setBool('backup_otomatis', val);

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

          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Cadangkan Sekarang'),
            onPressed: () => BackupService.generateBackupJson(context),
          ),
          const SizedBox(height: 12),
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
                            _buildIntervalTile(1),
                            _buildIntervalTile(3),
                            _buildIntervalTile(7),
                            _buildIntervalTile(14),
                            _buildIntervalTile(30),
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

  // Tambahkan di bawah:
  Widget _buildIntervalTile(int days) {
    return ListTile(
      title: Text('Setiap $days hari'),
      leading:
          _backupInterval == days
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('backup_interval', days);
        await _loadBackupInterval();
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}
