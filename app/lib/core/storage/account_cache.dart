import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AccountCache {
  String _accountId = '';

  void scopeTo(String accountId) => _accountId = accountId.trim();

  String _key(String name) => 'lovespace.account.$_accountId.$name';

  Future<void> writeJson(String name, Object value) async {
    if (_accountId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(name), jsonEncode(value));
  }

  Future<Map<String, dynamic>?> readJson(String name) async {
    if (_accountId.isEmpty) return null;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(name));
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  Future<String> readText(String name) async {
    if (_accountId.isEmpty) return '';
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key(name)) ?? '';
  }

  Future<void> writeText(String name, String value) async {
    if (_accountId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await preferences.remove(_key(name));
    } else {
      await preferences.setString(_key(name), value);
    }
  }

  Future<void> clearAccount() async {
    if (_accountId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final prefix = _key('');
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith(prefix),
    )) {
      await preferences.remove(key);
    }
  }
}
