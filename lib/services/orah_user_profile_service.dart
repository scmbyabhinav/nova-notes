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
  static const _voiceGenderKey = 'orah_tts_voice_gender';
  static const _subscriberApiUrl = String.fromEnvironment('ORAH_SUBSCRIBER_API_URL');

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterTts _tts = FlutterTts();

  Future<OrahUserProfile?> loadProfile() async {
    final name = await _storage.read(key: _nameKey);
    final email = await _storage.read(key: _emailKey);
    if (name == null || email == null || name.trim().isEmpty || email.trim().isEmpty) {
      return null;
    }
    return OrahUserProfile(fullName: name, email: email);
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
    await _storage.write(key: _nameKey, value: normalizedName);
    await _storage.write(key: _emailKey, value: normalizedEmail);
    final raw = await _storage.read(key: _subscribersKey);
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
      await _storage.write(key: _subscribersKey, value: jsonEncode(roster));
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

  Future<String> voiceGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_voiceGenderKey) ?? 'female';
  }

  Future<void> setVoiceGender(String gender) async {
    if (gender != 'male' && gender != 'female') {
      throw ArgumentError.value(gender, 'gender', 'Expected male or female.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceGenderKey, gender);
    await _applyVoice(gender);
  }

  Future<void> _applyVoice(String gender) async {
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
      final matching = candidates.where((voice) {
        final metadata = [voice['gender'], voice['name'], voice['identifier']]
            .whereType<Object>().join(' ').toLowerCase();
        if (gender == 'female') {
          return metadata.contains('female') || metadata.contains('woman');
        }
        return (metadata.contains('male') && !metadata.contains('female')) || metadata.contains('man');
      }).toList();
      if (matching.isNotEmpty) {
        final selected = matching.first;
        await _tts.setVoice(selected.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ));
        await _tts.setPitch(gender == 'female' ? 1.08 : 0.68);
        return;
      }
    }
    // Some Android TTS engines expose no gender metadata; pitch is a fallback.
    await _tts.setPitch(gender == 'female' ? 1.08 : 0.68);
  }

  Future<void> speakGreeting(String name) async {
    await _tts.stop();
    await _applyVoice(await voiceGender());
    await _tts.setSpeechRate(await voiceGender() == 'male' ? 0.40 : 0.48);
    await _tts.setVolume(1.0);
    await _tts.speak('Hello, $name');
  }

  Future<void> stopGreeting() => _tts.stop();
}
