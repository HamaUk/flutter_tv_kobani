import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Validates user-facing login codes from
/// `sync/global/loginCodes` where each child is:
///   { "code": "...", "active": true, "expiresAt": "2026-05-01T00:00:00.000Z" }
///
/// Codes with a past `expiresAt` are treated as inactive.
class LoginCodesService {
  static const _rtdbPath = 'sync/global/loginCodes';
  static const _cacheKey = 'login_codes_cache_v1';

  static Future<bool> validate(String raw) async {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return false;

    try {
      final snap = await FirebaseDatabase.instance.ref(_rtdbPath).get();
      if (snap.exists && snap.value != null) {
        final ok = _matchSnapshot(snap.value, normalized);
        await _storeCacheFromSnapshot(snap.value);
        return ok;
      }
    } catch (_) {
      // Offline / Firebase error → try cache
    }
    return _matchCached(normalized);
  }

  static String _normalize(String s) =>
      s.trim().toLowerCase();

  static bool _isExpired(dynamic expiresAt) {
    if (expiresAt == null) return false; // No expiry means permanent.
    try {
      final dt = DateTime.parse('$expiresAt');
      return DateTime.now().toUtc().isAfter(dt);
    } catch (_) {
      return false;
    }
  }

  static bool _matchSnapshot(dynamic data, String normalized) {
    Iterable values;
    if (data is Map) {
      values = data.values;
    } else if (data is List) {
      values = data.where((v) => v != null);
    } else {
      return false;
    }

    for (final v in values) {
      if (v is! Map) continue;
      final active = v['active'] != false;
      final code = _normalize('${v['code'] ?? ''}');
      if (!active || code.isEmpty || code != normalized) continue;
      if (_isExpired(v['expiresAt'])) continue;
      return true;
    }
    return false;
  }

  static Future<void> _storeCacheFromSnapshot(dynamic data) async {
    final codes = <String>[];
    if (data is Map) {
      for (final v in data.values) {
        if (v is Map && v['active'] != false) {
          if (_isExpired(v['expiresAt'])) continue;
          final c = _normalize('${v['code'] ?? ''}');
          if (c.isNotEmpty) codes.add(c);
        }
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_cacheKey, codes);
  }

  static Future<bool> _matchCached(String normalized) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_cacheKey) ?? [];
    return list.contains(normalized);
  }
}
