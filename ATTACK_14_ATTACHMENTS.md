# Attack 14 — Images & Attachments

NOVA Notes now supports local note attachments.

## Added
- Pick images from gallery.
- Take a photo with the camera.
- Attach multiple files using the native file picker.
- Copy selected files into NOVA's private application documents attachment folder.
- Show image thumbnails inside the editor.
- Show file cards with filenames.
- Remove individual attachments.
- Persist attachment paths with the note.
- Preserve attachments when editing an existing note.
- Export flow now carries attachment metadata with the note object.

## Design
Attachments are stored locally. No cloud upload or account is required.

## Validation
The Flutter SDK is still not installed on the development PC, so package resolution, analyzer, tests and real Android camera/gallery/file-picker validation remain pending.
