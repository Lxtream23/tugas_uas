import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveHelper {
  static final _googleSignIn = GoogleSignIn(
    clientId:
        kIsWeb
            ? '658021506260-9cld2l1msjk48qaeuebkontdgnoumdfg.apps.googleusercontent.com' // ganti ini
            : null,
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile',
      'openid',
    ],
  );

  static Future<void> uploadBackupJson({
    required BuildContext context,
    required String fileName,
    required String jsonData,
  }) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('Login Google dibatalkan');

      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(client);

      final media = drive.Media(
        Stream.value(utf8.encode(jsonData)),
        utf8.encode(jsonData).length,
        contentType: 'application/json',
      );

      final file = drive.File()..name = fileName;

      await driveApi.files.create(file, uploadMedia: media);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Backup berhasil ke Google Drive')),
        );
      }
    } catch (e) {
      debugPrint('❌ Gagal upload ke Google Drive: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal upload ke Google Drive: $e')),
        );
      }
    }
  }

  static Future<void> uploadBackupJsonSilently({
    required String fileName,
    required String jsonData,
  }) async {
    // Gunakan access token dari SharedPreferences (simpan saat login)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    final uri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['metadata'] = json.encode({
      'name': fileName,
      'mimeType': 'application/json',
    });

    request.files.add(
      http.MultipartFile.fromString(
        'file',
        jsonData,
        filename: fileName,
        contentType: MediaType('application', 'json'),
      ),
    );

    final response = await request.send();
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('❌ Gagal upload background: ${response.statusCode}');
    }
  }
}
