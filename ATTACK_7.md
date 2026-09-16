# NOVA Notes — ATTACK 7: Files & Backup Foundation

## Added
- Portable JSON backup format for notes.
- Import/merge support in the local note repository.
- Backup service abstraction.
- Settings UI section for Files & Backup.
- Export/restore entry points prepared for native file/share integration.
- Attachment metadata field added to the Note model.

## Design
NOVA remains local-first and account-free. V1 does not require a cloud backend.

## Next integration
The laptop Flutter build will wire:
- Android file picker / save dialog
- Share sheet
- TXT export
- Markdown export
- PDF export
- Backup `.nova` file
- Restore from `.nova`

No cloud sync has been introduced.
