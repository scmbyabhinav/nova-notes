import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The supplied Orah icon family, rendered as vectors and tinted for the
/// current theme so the same artwork stays legible in light and dark mode.
class OrahAssetIcon extends StatelessWidget {
  const OrahAssetIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticsLabel,
  });

  final String name;
  final double size;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final svg = _orahIcons[name];
    if (svg == null) {
      return SizedBox.square(dimension: size);
    }
    final tint = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: semanticsLabel,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}

const Map<String, String> _orahIcons = {
  'checklist': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11.5l2.8 2.8L20.5 5.5"/><path d="M20 13v5.5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5.5a2 2 0 0 1 2-2h9.5"/></svg>''',
  'compose': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>''',
  'folder': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 8V6.5a2 2 0 0 1 2-2h3.8l1.7 2.2h9a2 2 0 0 1 2 2V8"/><path d="M3.5 8h17a1.5 1.5 0 0 1 1.5 1.5v8.5a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2V9.5A1.5 1.5 0 0 1 3.5 8z"/></svg>''',
  'folder-plus': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 8V6.5a2 2 0 0 1 2-2h3.8l1.7 2.2h9a2 2 0 0 1 2 2V8"/><path d="M3.5 8h17a1.5 1.5 0 0 1 1.5 1.5v8.5a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2V9.5A1.5 1.5 0 0 1 3.5 8z"/><line x1="12" y1="12.5" x2="12" y2="17"/><line x1="9.75" y1="14.75" x2="14.25" y2="14.75"/></svg>''',
  'menu': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="8" cy="12" r="1.15" fill="#1C1C1E" stroke="none"/><circle cx="12" cy="12" r="1.15" fill="#1C1C1E" stroke="none"/><circle cx="16" cy="12" r="1.15" fill="#1C1C1E" stroke="none"/></svg>''',
  'microphone': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2.5" width="6" height="11" rx="3"/><path d="M5.5 11v1.5a6.5 6.5 0 0 0 13 0V11"/><line x1="12" y1="19" x2="12" y2="22"/><line x1="8.5" y1="22" x2="15.5" y2="22"/></svg>''',
  'new-note': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.7 3.8a2.1 2.1 0 0 1 3 3L7.5 19.1l-4 1.1 1.1-4L16.7 3.8z"/></svg>''',
  'notes': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2.5H6.5A2 2 0 0 0 4.5 4.5v15a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8.5z"/><path d="M14 2.5v4.5a1.5 1.5 0 0 0 1.5 1.5H20"/><line x1="8.5" y1="13" x2="15.5" y2="13"/><line x1="8.5" y1="16.5" x2="15.5" y2="16.5"/><line x1="8.5" y1="9.5" x2="11.5" y2="9.5"/></svg>''',
  'pin': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.89A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.89A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/></svg>''',
  'plus': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5.5" x2="12" y2="18.5"/><line x1="5.5" y1="12" x2="18.5" y2="12"/></svg>''',
  'search': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="M20.5 20.5 16.2 16.2"/></svg>''',
  'settings': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3.2"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>''',
  'share': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12.5v6.5a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-6.5"/><polyline points="16 7.5 12 3.5 8 7.5"/><line x1="12" y1="4" x2="12" y2="15.5"/></svg>''',
  'star': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.8l2.45 5.35 5.85.55-4.4 4.05 1.3 5.75L12 15.85 6.8 18.5l1.3-5.75-4.4-4.05 5.85-.55z"/></svg>''',
  'tag': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M20.5 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L2.5 12.6V2.5h10.1l7.9 7.9a2 2 0 0 1 0 2.8z"/><circle cx="7.5" cy="7.5" r="1.15" fill="#1C1C1E" stroke="none"/></svg>''',
  'trash': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C1C1E" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 6.5h17"/><path d="M8.5 6.5V5a1.5 1.5 0 0 1 1.5-1.5h4A1.5 1.5 0 0 1 15.5 5v1.5"/><path d="M18.5 6.5v12a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2v-12"/><line x1="10" y1="11" x2="10" y2="16.5"/><line x1="14" y1="11" x2="14" y2="16.5"/></svg>''',
};

export const orahProvidedIconNames = <String>{
  'checklist', 'compose', 'folder', 'folder-plus', 'menu', 'microphone',
  'new-note', 'notes', 'pin', 'plus', 'search', 'settings', 'share', 'star',
  'tag', 'trash',
};
