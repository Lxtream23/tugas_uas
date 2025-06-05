import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugas_uas/services/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/services/drive_backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _backupOtomatis = false;
  String? _email;
  DateTime? _lastSyncTime;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadangkan dan Pulihkan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.g_mobiledata, size: 32),
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
              await GoogleDriveHelper.uploadToDrive(
                context,
                'backup_diary.json',
                jsonContent,
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
          // const Text(
          //   'Data Backup',
          //   style: TextStyle(fontWeight: FontWeight.bold),
          // ),
          // const SizedBox(height: 4),
          // Text('Sync terakhir: ${DateTime.now().toString().split('.')[0]}'),
          // const SizedBox(height: 16),
          SwitchListTile(
            value: _backupOtomatis,
            onChanged: (val) async {
              setState(() => _backupOtomatis = val);
              final prefs = await SharedPreferences.getInstance();
              prefs.setBool('backup_otomatis', val);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val
                        ? '✅ Backup otomatis diaktifkan'
                        : '❌ Backup otomatis dimatikan',
                  ),
                ),
              );
            },
            title: const Text('Backup otomatis'),
            subtitle: const Text(
              'Aktifkan backup otomatis untuk menghindari kelalaian dalam sinkronisasi diary',
            ),
            secondary: const Icon(Icons.auto_awesome, color: Colors.amber),
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
            subtitle: const Text('3 hari sekali'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('pengingat interval'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text('Setiap 1 hari'),
                            onTap: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setInt('backup_interval', 1);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text('Setiap 3 hari'),
                            onTap: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setInt('backup_interval', 3);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}
