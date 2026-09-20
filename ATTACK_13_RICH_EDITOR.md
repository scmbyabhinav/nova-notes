# Attack 13 — Rich Note Editor

NOVA Notes now has a lightweight, portable rich-text layer based on Markdown.

## Editing tools
- Bold
- Italic
- Strikethrough
- Headings
- Bulleted lists
- Numbered lists
- Block quotes
- Links
- Checklist mode

## Preview
The editor now has Edit / Preview mode. Preview renders Markdown with selectable text and GitHub-Flavored Markdown support.

## Storage
Notes continue to use portable text/Markdown content rather than a proprietary editor database. Existing plain-text notes remain readable.

## Compatibility
Markdown remains useful for export and portability. PDF/Word export currently exports the note content as text; a future document-rendering pass can translate rich Markdown styling into native DOCX/PDF formatting.

## Validation
Local Flutter analyzer, tests and device testing remain pending until Flutter is installed on the development machine.
