import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/server_models.dart';

/// Persists SysDash server profiles (including encrypted passwords & JWT tokens)
/// using platform encryption:
/// * Android: RSA-OAEP wrapped AES-256-GCM key in Android Keystore.
/// * iOS/macOS: Keychain (accessible only on this device after first unlock).
///
/// Nothing is ever written to plain-text storage.
class SecureCredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _profilesKey = 'sysdash.server_profiles.v2';
  static const _legacyProfilesKey = 'sysdash.ssh_profiles.v1';
  static const _lastProfileKey = 'sysdash.last_profile_id.v2';

  final FlutterSecureStorage _storage;

  Future<List<ServerProfile>> loadProfiles() async {
    var raw = await _storage.read(key: _profilesKey);
    // Fallback to legacy key if v2 not yet written
    raw ??= await _storage.read(key: _legacyProfilesKey);

    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      // Corrupted payload: wipe it rather than crash.
      await _storage.delete(key: _profilesKey);
      return [];
    }
  }

  Future<void> saveProfile(ServerProfile profile) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere(
      (p) =>
          p.id == profile.id ||
          (p.serverUrl == profile.serverUrl && p.username == profile.username),
    );
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.insert(0, profile);
    }
    await _writeProfiles(profiles);
    await _storage.write(key: _lastProfileKey, value: profile.id);
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles()..removeWhere((p) => p.id == id);
    await _writeProfiles(profiles);
    if (await _storage.read(key: _lastProfileKey) == id) {
      await _storage.delete(key: _lastProfileKey);
    }
  }

  Future<String?> lastProfileId() => _storage.read(key: _lastProfileKey);

  Future<void> _writeProfiles(List<ServerProfile> profiles) => _storage.write(
        key: _profilesKey,
        value: jsonEncode(profiles.map((p) => p.toJson()).toList()),
      );
}
