import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrahUserProfile {
  const OrahUserProfile({required this.fullName, required this.email});

  final String fullName;
  final String email;
}

class OrahUserProfileService {
  OrahUserProfileService._();
  static final instance = OrahUserProfileService._();

  static const _nameKey = 'orah_profile_full_name';
  static const _emailKey = 'orah_profile_email';
  static const _subscribersKey = 'orah_subscriber_database_v1';
  static const _voiceGreetingKey = 'orah_voice_greeting_enabled';
  static const _subscriberApiUrl = String.fromEnvironment('ORAH_SUBSCRIBER_API_URL');

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterTts _tts = FlutterTts();

  Future<OrahUserProfile?> loadProfile() async {
    try {
      final name = await _storage
          .read(key: _nameKey)
          .timeout(const Duration(seconds: 2));
      final email = await _storage
          .read(key: _emailKey)
          .timeout(const Duration(seconds: 2));
      if (name != null && email != null &&
          name.trim().isNotEmpty && email.trim().isNotEmpty) {
        return OrahUserProfile(fullName: name, email: email);
      }
    } catch (_) {
      // Secure storage may be unavailable on some Android installs. Fall back
      // to the non-secret profile cache so the app can still start.
    }

    // Preferences are a secondary cache only. If this platform channel also
    // fails, treat the profile as unavailable and let the app show registration
    // rather than blocking startup. No notes are touched here.
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final name = prefs.getString(_nameKey);
      final email = prefs.getString(_emailKey);
      if (name == null || email == null ||
          name.trim().isEmpty || email.trim().isEmpty) {
        return null;
      }
      return OrahUserProfile(fullName: name, email: email);
    } catch (_) {
      return null;
    }
  }

  Future<void> register({required String fullName, required String email}) async {
    final normalizedName = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedName.isEmpty) throw ArgumentError('Please enter your full name.');
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
      throw ArgumentError('Please enter a valid email address.');
    }

    // If a newsletter endpoint is configured, confirm subscription before
    // marking registration complete locally. The endpoint must enforce its
    // own validation and abuse protection; no server/database secret belongs
    // in a mobile app.
    if (_subscriberApiUrl.isNotEmpty) {
      final uri = Uri.tryParse(_subscriberApiUrl);
      if (uri == null || uri.scheme != 'https') {
        throw StateError('Subscriber service must use HTTPS.');
      }
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': normalizedName,
          'email': normalizedEmail,
          'source': 'orah_android_app',
          'subscribed_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Subscriber service returned HTTP ' + response.statusCode.toString() + '.');
      }
    }

    // Profile and local subscriber roster are protected by Android secure
    // storage. Without a configured remote endpoint, the roster stays on this
    // device; central newsletter delivery needs a backend endpoint.
    try {
      await _storage
          .write(key: _nameKey, value: normalizedName)
          .timeout(const Duration(seconds: 2));
      await _storage
          .write(key: _emailKey, value: normalizedEmail)
          .timeout(const Duration(seconds: 2));
      final raw = await _storage
          .read(key: _subscribersKey)
          .timeout(const Duration(seconds: 2));
      final List<dynamic> roster =
          raw == null ? <dynamic>[] : (jsonDecode(raw) as List<dynamic>);
      final exists = roster.any((entry) =>
          entry is Map && (entry['email'] as String?)?.toLowerCase() == normalizedEmail);
      if (!exists) {
        roster.add({
          'fullName': normalizedName,
          'email': normalizedEmail,
          'subscribedAt': DateTime.now().toUtc().toIso8601String(),
          'source': 'orah_android_app',
        });
        await _storage
            .write(key: _subscribersKey, value: jsonEncode(roster))
            .timeout(const Duration(seconds: 2));
      }
    } catch (error) {
      // Keep registration usable if Android secure storage is unavailable.
      // This cache contains only the profile name/email, not note contents.
      try {
        final prefs = await SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 3));
        await prefs.setString(_nameKey, normalizedName)
            .timeout(const Duration(seconds: 3));
        await prefs.setString(_emailKey, normalizedEmail)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Keep this device session usable even if every profile store fails.
        // The registration screen will still pass the entered profile to the
        // in-memory app session; persistence can be repaired separately.
      }
    }
  }

  Future<bool> voiceGreetingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceGreetingKey) ?? true;
  }

  Future<void> setVoiceGreetingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceGreetingKey, enabled);
  }

  Future<void> _applyVoice() async {
    await _tts.setLanguage('en-US');
    final rawVoices = await _tts.getVoices;
    if (rawVoices is List) {
      final voices = rawVoices.whereType<Map>().map(
        (voice) => Map<String, dynamic>.from(voice),
      ).toList();
      final englishVoices = voices.where((voice) {
        final locale = (voice['locale'] ?? voice['language'] ?? '').toString().toLowerCase();
        return locale.isEmpty || locale.startsWith('en');
      }).toList();
      final candidates = englishVoices.isEmpty ? voices : englishVoices;
      final femaleVoices = candidates.where((voice) {
        final metadata = [voice['gender'], voice['name'], voice['identifier']]
            .whereType<Object>().join(' ').toLowerCase();
        return metadata.contains('female') || metadata.contains('woman');
      }).toList();
      if (femaleVoices.isNotEmpty) {
        final selected = femaleVoices.first;
        await _tts.setVoice(selected.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ));
      }
    }
    await _tts.setPitch(1.08);
  }

  Future<void> speakGreeting(String name) async {
    try { await _tts.stop().timeout(const Duration(seconds: 2)); } catch (_) {}
    // Voice enumeration is optional: some Android TTS engines do not answer
    // getVoices reliably. Never let it prevent the actual greeting.
    try {
      await _applyVoice().timeout(const Duration(seconds: 2));
    } catch (error) {
      // Continue with the device's default voice.
    }
    try { await _tts.setLanguage('en-US').timeout(const Duration(seconds: 2)); } catch (_) {}
    try { await _tts.setSpeechRate(0.48).timeout(const Duration(seconds: 2)); } catch (_) {}
    try { await _tts.setVolume(1.0).timeout(const Duration(seconds: 2)); } catch (_) {}
    await _tts.speak('Hello, $name').timeout(const Duration(seconds: 5));
  }

  Future<void> previewVoice() async {
    try { await _tts.stop().timeout(const Duration(seconds: 2)); } catch (_) {}
    try {
      await _applyVoice().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try { await _tts.setLanguage('en-US').timeout(const Duration(seconds: 2)); } catch (_) {}
    try { await _tts.setSpeechRate(0.48).timeout(const Duration(seconds: 2)); } catch (_) {}
    try { await _tts.setVolume(1.0).timeout(const Duration(seconds: 2)); } catch (_) {}
    await _tts.speak('Hello, this is Orah Notes').timeout(const Duration(seconds: 5));
  }

  Future<void> stopGreeting() => _tts.stop();
}
