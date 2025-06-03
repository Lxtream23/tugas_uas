import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class GoogleDriveHelper {
  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  static Future<drive.DriveApi?> getDriveApi() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    final client = GoogleHttpClient(authHeaders);
    return drive.DriveApi(client);
  }

  static Future<void> uploadBackup(File file) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) return;

    final fileToUpload =
        drive.File()
          ..name = 'backup_diary_${DateTime.now().millisecondsSinceEpoch}.json';

    await driveApi.files.create(
      fileToUpload,
      uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
    );
  }
}

class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = IOClient();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}
