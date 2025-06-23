import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:tugas_uas/widgets/custom_snackbar.dart';

class GoogleDriveHelper {
  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  static Future<void> uploadToDrive(
    BuildContext context,
    String filename,
    String jsonContent,
  ) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('Login Google dibatalkan');

      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);

      final driveApi = drive.DriveApi(client);

      final media = drive.Media(
        Stream.value(utf8.encode(jsonContent)),
        utf8.encode(jsonContent).length,
        contentType: 'application/json',
      );

      final file = drive.File()..name = filename;

      await driveApi.files.create(file, uploadMedia: media);

      showCustomSnackBar(
        context,
        'File berhasil diunggah ke Google Drive',
        type: SnackBarType.success,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Gagal upload: $e');
      showCustomSnackBar(
        context,
        'Gagal upload: $e',
        type: SnackBarType.error,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    }
  }
}

/// Client Google dari authHeaders
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
