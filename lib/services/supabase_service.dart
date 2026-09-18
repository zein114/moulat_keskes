import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _client;

  static SupabaseClient? get maybeClient => _client;

  static SupabaseClient get client {
    final value = _client;
    if (value == null) {
      throw StateError('Supabase has not been initialized.');
    }
    return value;
  }

  static Future<SupabaseClient?> initializeFromEnvironment() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty && key.isEmpty) return null;
    if (url.isEmpty || key.isEmpty) {
      throw StateError('Missing Supabase configuration');
    }
    await Supabase.initialize(url: url, publishableKey: key);
    _client = Supabase.instance.client;
    return _client;
  }
}

class DbEncoding {
  DbEncoding._();

  static const couscous = '\u0627\u0644\u0643\u0633\u0643\u0633';
  static const bassi = '\u0627\u0644\u0628\u0627\u0633\u064a';
  static const aish = '\u0627\u0644\u0639\u064a\u0634';
  static const categories = [couscous, bassi, aish];

  static const _legacyCategoryFromDb = {
    '\u00d8\u00a7\u00d9\u201e\u00d9\u0192\u00d8\u00b3\u00d9\u0192\u00d8\u00b3':
        couscous,
    '\u00d8\u00a7\u00d9\u201e\u00d8\u00a8\u00d8\u00a7\u00d8\u00b3\u00d9\u0160':
        bassi,
    '\u00d8\u00a7\u00d9\u201e\u00d8\u00b9\u00d9\u0160\u00d8\u00b4': aish,
  };

  static String text(Object? value) {
    final raw = value?.toString() ?? '';
    return _decodeMojibake(raw);
  }

  static String categoryFromDb(Object? value) {
    final raw = value?.toString() ?? '';
    final decoded = _decodeMojibake(raw);
    if (categories.contains(raw)) return raw;
    if (categories.contains(decoded)) return decoded;
    return _legacyCategoryFromDb[raw] ?? _legacyCategoryFromDb[decoded] ?? raw;
  }

  static String categoryToDb(String category) {
    if (!categories.contains(category)) {
      throw StateError('Invalid meal category: $category');
    }
    return category;
  }

  static Map<String, dynamic> decodeRow(Map<String, dynamic> row) => {
    for (final entry in row.entries)
      entry.key: entry.key == 'category'
          ? categoryFromDb(entry.value)
          : _decodeValue(entry.value),
  };

  static dynamic _decodeValue(dynamic value) {
    if (value is String) return text(value);
    if (value is List) return value.map(_decodeValue).toList();
    if (value is Map) {
      return value.map((key, value) => MapEntry(key, _decodeValue(value)));
    }
    return value;
  }

  static String _decodeMojibake(String value) {
    try {
      final decoded = utf8.decode(latin1.encode(value));
      return _looksMoreReadable(decoded, value) ? decoded : value;
    } catch (_) {
      return value;
    }
  }

  static bool _looksMoreReadable(String decoded, String original) {
    final decodedArabic = RegExp(r'[\u0600-\u06ff]').allMatches(decoded).length;
    final originalArabic = RegExp(
      r'[\u0600-\u06ff]',
    ).allMatches(original).length;
    final originalMojibake = RegExp(
      r'[\u00d8\u00d9\u00c3]',
    ).allMatches(original).length;
    return decodedArabic > originalArabic && originalMojibake > 0;
  }
}
