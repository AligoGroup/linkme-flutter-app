import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_manager.dart';
import '../models/app_feature_setting.dart';
import '../services/app_feature_service.dart';
import 'auth_provider.dart';

class AppFeatureProvider extends ChangeNotifier {
  static const String _cacheKey = 'app_feature_snapshot_cache';

  final AppFeatureService _service = AppFeatureService();
  final Map<String, bool> _flags = {};
  AppFeatureSnapshot? _snapshot;
  bool _initialized = false;
  bool _loading = false;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  AuthProvider? _authProvider;
  VoidCallback? _authListener;

  bool get isInitialized => _initialized;
  bool get isLoading => _loading;

  bool get navMessageEnabled => _flags['NAV_MESSAGE'] ?? true;
  bool get navFriendsEnabled => _flags['NAV_FRIENDS'] ?? true;
  bool get navStoreEnabled => _flags['NAV_STORE'] ?? true;
  bool get navAcademyEnabled => _flags['NAV_ACADEMY'] ?? true;
  bool get navProfileEnabled => _flags['NAV_PROFILE'] ?? true;
  bool get walletEnabled => _flags['MODULE_WALLET'] ?? true;

  AppFeatureSnapshot? get snapshot => _snapshot;

  void attachAuthProvider(AuthProvider authProvider) {
    if (_authProvider != null && _authListener != null) {
      _authProvider!.authStateListenable.removeListener(_authListener!);
    }
    _authProvider = authProvider;
    _authListener = () {
      if (_authProvider?.isLoggedIn == true) {
        refresh();
      }
    };
    authProvider.authStateListenable.addListener(_authListener!);
    if (authProvider.isLoggedIn) {
      refresh();
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadCachedSnapshot();
    _listenRealtime();
    _ensureAnonymousWebSocket();
  }

  Future<void> refresh() async {
    if (_authProvider?.isLoggedIn != true) {
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final next = await _service.fetchFeatures();
      _snapshot = next;
      _syncFlags(next);
      unawaited(_cacheSnapshot(next));
    } catch (e) {
      debugPrint('加载 App 功能配置失败: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _syncFlags(AppFeatureSnapshot snapshot) {
    final Map<String, bool> next = {};
    for (final item in snapshot.nav) {
      next[item.featureKey] = item.enabled;
    }
    for (final item in snapshot.modules) {
      next[item.featureKey] = item.enabled;
    }
    bool changed = false;
    if (next.length != _flags.length) {
      changed = true;
    } else {
      for (final entry in next.entries) {
        if (_flags[entry.key] != entry.value) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      _flags
        ..clear()
        ..addAll(next);
      notifyListeners();
    }
  }

  void _listenRealtime() {
    _wsSub?.cancel();
    _wsSub = WebSocketManager().messageStream.listen((event) {
      if (event['type'] != 'APP_FEATURES_UPDATED') return;
      final nav = (event['nav'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AppFeatureSetting.fromJson(e.cast<String, dynamic>()))
          .toList();
      final modules = (event['modules'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AppFeatureSetting.fromJson(e.cast<String, dynamic>()))
          .toList();
      _snapshot = AppFeatureSnapshot(nav: nav, modules: modules);
      _syncFlags(_snapshot!);
      unawaited(_cacheSnapshot(_snapshot!));
    });
  }

  void _ensureAnonymousWebSocket() {
    final ws = WebSocketManager();
    if (!ws.isConnected) {
      ws.connect('0', '');
    }
  }

  Future<void> _loadCachedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final nav = (decoded['nav'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AppFeatureSetting.fromJson(e.cast<String, dynamic>()))
          .toList();
      final modules = (decoded['modules'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AppFeatureSetting.fromJson(e.cast<String, dynamic>()))
          .toList();
      final snapshot = AppFeatureSnapshot(nav: nav, modules: modules);
      _snapshot = snapshot;
      _syncFlags(snapshot);
    } catch (e) {
      debugPrint('读取 App 功能配置缓存失败: $e');
    }
  }

  Future<void> _cacheSnapshot(AppFeatureSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
    } catch (e) {
      debugPrint('缓存 App 功能配置失败: $e');
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    if (_authListener != null && _authProvider != null) {
      _authProvider!.authStateListenable.removeListener(_authListener!);
    }
    super.dispose();
  }
}
