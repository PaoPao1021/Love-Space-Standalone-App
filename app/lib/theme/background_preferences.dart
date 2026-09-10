import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/storage/account_cache.dart';

class BackgroundPreferences extends ChangeNotifier {
  Uint8List? image;
  double opacity = .8;
  String _account = '';
  AccountCache? _cache;
  bool _disposed = false;
  Future<void> scopeTo(String account, AccountCache cache) async {
    if (_disposed || _account == account) return;
    _account = account;
    // An immutable account scope prevents a pending write crossing accounts.
    final scopedCache = AccountCache()..scopeTo(account);
    _cache = scopedCache;
    image = null;
    opacity = .8;
    notifyListeners();
    if (account.isEmpty) return;
    final saved = await scopedCache.readJson('appearance.background');
    if (_disposed || _account != account || saved == null) return;
    try {
      final encoded = saved['image'] as String?;
      image = encoded == null ? null : base64Decode(encoded);
      opacity = ((saved['opacity'] as num?)?.toDouble() ?? .8).clamp(.1, 1);
    } on FormatException {
      image = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> save({
    Uint8List? bytes,
    double? value,
    bool reset = false,
  }) async {
    if (_disposed) return;
    if (reset) {
      image = null;
      opacity = .8;
    }
    if (bytes != null) image = bytes;
    if (value != null) opacity = value.clamp(.1, 1);
    notifyListeners();
    await _cache?.writeJson('appearance.background', {
      'image': image == null ? null : base64Encode(image!),
      'opacity': opacity,
    });
  }
}
