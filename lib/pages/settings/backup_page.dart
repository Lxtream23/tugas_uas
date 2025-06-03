import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugas_uas/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _backupOtomatis = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backupOtomatis = prefs.getBool('backup_otomatis') ?? false;
    });
  }

  Future<void> _cadangkanSekarang() async {
    final file = await BackupService.generateBackupJson();
    if (file != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Backup berhasil dibuat')));
      // (Opsional) Upload ke Google Drive:
      // await GoogleDriveHelper.uploadBackup(file);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Gagal membuat backup')));
    }
  }

  Future<void> _pulihkanDariFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      await BackupService.restoreFromBackupJson(file);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Data berhasil dipulihkan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadangkan dan Pulihkan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey,
                child: Icon(Icons.g_mobiledata, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Backup ke Google Drive',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('lh23072002@gmail.com'),
                  ],
                ),
              ),
              const Icon(Icons.more_vert),
            ],
          ),
          const Divider(height: 32),

          const Text(
            'Data Backup',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Sync terakhir: 2025/06/02 10:21:55'),
          const SizedBox(height: 16),

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
            onPressed: _cadangkanSekarang,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Cadangkan Sekarang'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _pulihkanDariFile,
            icon: const Icon(Icons.restore),
            label: const Text('Pulihkan dari File'),
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
