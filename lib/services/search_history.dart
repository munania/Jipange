import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's recent task searches (most recent first) so they can
/// be offered again next time the search field is opened.
class SearchHistory {
  static const _key = 'recent_task_searches';
  static const _maxEntries = 10;

  /// Load the saved search history, most recent first.
  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Record a query as the most recent search, de-duplicating and capping
  /// the list at [_maxEntries]. Blank queries are ignored.
  static Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    final current = await load();
    current.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    final capped = current.take(_maxEntries).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(capped));
    return capped;
  }

  /// Remove a single entry from the history.
  static Future<List<String>> remove(String query) async {
    final current = await load();
    current.removeWhere((q) => q.toLowerCase() == query.toLowerCase());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(current));
    return current;
  }

  /// Clear all saved search history.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
