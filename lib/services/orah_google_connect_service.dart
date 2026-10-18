import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Minimal, free-first Google account connection for ORAH Connect.
///
/// Only requests the non-broad `drive.file` scope. This limits access to files
/// the user opens/creates with ORAH or explicitly makes available to it.
/// Gmail permissions are deliberately not requested in this first increment.
class OrahGoogleConnectService {
  OrahGoogleConnectService._();

  static final OrahGoogleConnectService instance = OrahGoogleConnectService._();

  static const List<String> _scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  final http.Client _httpClient = http.Client();

  GoogleSignInAccount? get currentAccount => _googleSignIn.currentUser;

  bool get isConnected => currentAccount != null;

  /// Opens Google's native account/consent flow. Returns null if cancelled.
  Future<GoogleSignInAccount?> connect() => _googleSignIn.signIn();

  /// Signs out of the Google account from this app; it does not delete Drive
  /// files or sign the user out of Google elsewhere on their device.
  Future<void> disconnect() => _googleSignIn.signOut();

  Future<List<OrahGoogleDriveFile>> listAccessibleFiles({
    int pageSize = 50,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be 1–100.');
    }

    final account = currentAccount;
    if (account == null) {
      throw StateError('Connect a Google account before listing Drive files.');
    }

    final authentication = await account.authentication;
    final accessToken = authentication.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const OrahGoogleConnectException(
        'Google did not provide a Drive access token. Reconnect and try again.',
      );
    }

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', <String, String>{
      'pageSize': '$pageSize',
      'orderBy': 'modifiedTime desc',
      'fields': 'files(id,name,mimeType,modifiedTime,webViewLink)',
      'spaces': 'drive',
    });

    final response = await _httpClient.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      throw const OrahGoogleConnectException(
        'Google authorization expired. Reconnect your account and try again.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OrahGoogleConnectException(
        'Google Drive returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const OrahGoogleConnectException(
        'Google Drive returned an unexpected response.',
      );
    }
    final files = decoded['files'];
    if (files is! List<dynamic>) return const <OrahGoogleDriveFile>[];

    return List<OrahGoogleDriveFile>.unmodifiable(
      files.whereType<Map<String, dynamic>>().map(OrahGoogleDriveFile.fromJson),
    );
  }

  void dispose() => _httpClient.close();
}

class OrahGoogleDriveFile {
  const OrahGoogleDriveFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.modifiedTime,
    this.webViewLink,
  });

  final String id;
  final String name;
  final String? mimeType;
  final DateTime? modifiedTime;
  final Uri? webViewLink;

  factory OrahGoogleDriveFile.fromJson(Map<String, dynamic> json) {
    final rawModifiedTime = json['modifiedTime'];
    final rawLink = json['webViewLink'];
    return OrahGoogleDriveFile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled file',
      mimeType: json['mimeType'] as String?,
      modifiedTime: rawModifiedTime is String
          ? DateTime.tryParse(rawModifiedTime)
          : null,
      webViewLink: rawLink is String ? Uri.tryParse(rawLink) : null,
    );
  }
}

class OrahGoogleConnectException implements Exception {
  const OrahGoogleConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}
