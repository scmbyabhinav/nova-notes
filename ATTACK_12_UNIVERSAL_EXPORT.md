# Attack 12 — Universal Export

NOVA Notes now has a universal export foundation.

## Supported formats
- PDF — printable document
- Word (.docx) — editable document
- Excel (.xlsx) — structured spreadsheet
- Text (.txt)
- Markdown (.md)

## Behavior
- Exports are generated locally on the device.
- The Android/iOS system share sheet is used to save or send the file.
- Checklist notes export as rows in Excel with Done + Item columns.
- Text notes export as Field + Value rows in Excel.
- No cloud service or NOVA account is required.

## Important validation
Flutter SDK is not yet installed on the development PC, so package resolution, analyzer, device testing, and release builds must be run locally after Flutter setup.

## Next
1. Install Flutter and Android tooling.
2. Run flutter pub get.
3. Run flutter analyze.
4. Run flutter test.
5. Run flutter create . if native platform folders are still absent.
6. Test PDF/DOCX/XLSX files on a real Android device and open them in compatible apps.
