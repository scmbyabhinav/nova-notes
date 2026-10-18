import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/services/orah_google_connect_service.dart';

void main() {
  group('OrahGoogleDriveFile', () {
    test('parses Drive file metadata returned by the API', () {
      final file = OrahGoogleDriveFile.fromJson(<String, dynamic>{
        'id': 'file-123',
        'name': 'Meeting notes',
        'mimeType': 'application/vnd.google-apps.document',
        'modifiedTime': '2026-10-18T08:30:00.000Z',
        'webViewLink': 'https://drive.google.com/file/d/file-123/view',
      });

      expect(file.id, 'file-123');
      expect(file.name, 'Meeting notes');
      expect(file.mimeType, 'application/vnd.google-apps.document');
      expect(file.modifiedTime, DateTime.parse('2026-10-18T08:30:00.000Z'));
      expect(
        file.webViewLink,
        Uri.parse('https://drive.google.com/file/d/file-123/view'),
      );
    });

    test('uses safe defaults for incomplete metadata', () {
      final file = OrahGoogleDriveFile.fromJson(<String, dynamic>{});

      expect(file.id, isEmpty);
      expect(file.name, 'Untitled file');
      expect(file.mimeType, isNull);
      expect(file.modifiedTime, isNull);
      expect(file.webViewLink, isNull);
    });
  });
}
