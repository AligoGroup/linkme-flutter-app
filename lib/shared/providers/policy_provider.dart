import 'dart:async';
import 'dart:convert';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/websocket_manager.dart';
import '../models/platform_policy.dart';
import '../services/policy_service.dart';

class PolicyProvider extends ChangeNotifier {
  static const String _cacheKey = 'platform_policy_cache_v1';

  final PolicyService _service = PolicyService();
  final Map<String, PlatformPolicy> _policies = {}; // code -> policy
  bool _initialized = false;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  PlatformPolicy? policyOf(String code) => _policies[code];
  bool enabled(String code) => _policies[code]?.enabled == true;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromCache();
    await refresh();
    _listenWs();
    _ensureAnonymousWs();
  }

  Future<void> refresh() async {
    try {
      final list = await _service.list();
      _policies.clear();
      for (final p in list) { _policies[p.code] = p; }
      notifyListeners();
      unawaited(_cachePolicies());
    } catch (_) {}
  }

  void _listenWs() {
    _wsSub?.cancel();
    _wsSub = WebSocketManager().messageStream.listen((msg) {
      if (msg['type'] == 'PLATFORM_POLICY_UPDATED') {
        final code = (msg['code'] ?? '').toString();
        if (code.isEmpty) return;
        final p = PlatformPolicy(
          code: code,
          title: (msg['title'] ?? '').toString(),
          content: (msg['content'] ?? '').toString(),
          enabled: (msg['enabled'] ?? false) == true,
        );
        _policies[code] = p;
        notifyListeners();
        unawaited(_cachePolicies());
      }
    });
  }

  // 为未登录场景建立匿名WS，仅用于接收策略更新事件；登录后会自动被真实用户连接替换
  void _ensureAnonymousWs() {
    final ws = WebSocketManager();
    if (!ws.isConnected) {
      // userId=0, 无token；WebSocketManager 会在后续登录时检测到 userId 改变并自动重连
      ws.connect('0', '');
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) =>
              PlatformPolicy.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isEmpty) return;
      _policies
        ..clear()
        ..addEntries(list.map((p) => MapEntry(p.code, p)));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _cachePolicies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(_policies.values.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }
}
