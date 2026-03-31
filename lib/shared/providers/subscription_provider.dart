import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_channel.dart';
import '../models/subscription_article.dart';
import '../services/subscription_service.dart';
import '../../core/network/websocket_manager.dart';

/// Provider: 订阅号与文章（从后端API获取，移除演示数据）
class SubscriptionProvider extends ChangeNotifier {
  static const String _channelsCacheKey =
      'subscription_channels_cache_v1';
  static const String _articlesCachePrefix =
      'subscription_articles_cache_v1_';

  final SubscriptionService _service = SubscriptionService();

  final List<SubscriptionChannel> _channels = [];
  final Map<String, List<SubscriptionArticle>> _articles = {};
  bool _started = false; // 是否已启动后台刷新
  final Set<String> _articleLoadedSet = {};
  DateTime? _lastFetch;
  Duration refreshInterval = const Duration(seconds: 10); // 后台自动刷新间隔（轻量）
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  List<SubscriptionChannel> get channels => List.unmodifiable(_channels);

  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    await _loadFromCache();
    await _fetchChannels();
    _startPolling();
    _listenWebSocket();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(refreshInterval, (_) => _fetchChannels());
  }

  void _listenWebSocket() {
    _wsSub?.cancel();
    _wsSub = WebSocketManager().messageStream.listen((msg) {
      final type = (msg['type'] ?? '').toString();
      switch (type) {
        case 'SUBSCRIPTION_ARTICLE_PUBLISHED':
          final cid = (msg['channelId'] ?? msg['accountId'] ?? '').toString();
          if (cid.isEmpty) { _fetchChannels(); return; }
          // 如果随消息携带了文章详情，直接本地插入；否则触发一次拉取
          final art = msg['article'];
          if (art is Map) {
            final a = _mapArticle(art);
            // 插入到该频道的文章列表（若未加载则初始化）
            final list = _articles[cid] ?? <SubscriptionArticle>[];
            // 去重：按 id 判断
            final exists = list.any((e) => e.id == a.id);
            if (!exists) {
              list.insert(0, a);
              _articles[cid] = list;
              _articleLoadedSet.add(cid); // 标记已加载，避免立刻再次HTTP请求
              notifyListeners();
              unawaited(_cacheArticles(cid));
            }
          } else {
            // 没有详情时，退化为刷新该频道
            refreshArticles(cid);
          }
          // 同步刷新频道列表（新频道发布首篇内容时需要）
          _fetchChannels();
          break;
        case 'SUBSCRIPTION_ARTICLE_UPDATED':
          final m = msg['article'];
          if (m is Map) {
            final a = _mapArticle(m);
            final cid2 = a.channelId;
            final list = _articles[cid2] ?? <SubscriptionArticle>[];
            final idx = list.indexWhere((e) => e.id == a.id);
            if (idx >= 0) {
              list[idx] = a;
            } else {
              list.insert(0, a);
            }
            _articles[cid2] = list;
            _articleLoadedSet.add(cid2);
            notifyListeners();
            unawaited(_cacheArticles(cid2));
          }
          break;
        case 'SUBSCRIPTION_ARTICLE_DELETED':
          final cid3 = (msg['channelId'] ?? msg['accountId'] ?? '').toString();
          final aid = (msg['articleId'] ?? '').toString();
          if (cid3.isEmpty || aid.isEmpty) return;
          final list3 = _articles[cid3];
          if (list3 != null) {
            final before = list3.length;
            list3.removeWhere((e) => e.id == aid);
            if (list3.length != before) {
              _articles[cid3] = list3;
              notifyListeners();
              unawaited(_cacheArticles(cid3));
            }
          }
          break;
        case 'SUBSCRIPTION_CHANNELS_CHANGED':
        case 'SUBSCRIPTION_ACCOUNT_CREATED':
        case 'SUBSCRIPTION_ACCOUNT_UPDATED':
          _fetchChannels();
          break;
      }
    });
  }

  Future<void> _fetchChannels() async {
    try {
      final list = await _service.listChannels(page: 0, size: 50);
      // 如果数据发生变化（数量或ID顺序/名称变化），再通知UI，避免无谓重建
      bool changed = false;
      if (list.length != _channels.length) {
        changed = true;
      } else {
        for (int i = 0; i < list.length; i++) {
          final a = list[i];
          final b = _channels[i];
          if (a.id != b.id || a.name != b.name || a.description != b.description || a.avatar != b.avatar || a.official != b.official) {
            changed = true; break;
          }
        }
      }
      if (changed) {
        _channels
          ..clear()
          ..addAll(list);
        notifyListeners();
        unawaited(_cacheChannels());
      }
      _lastFetch = DateTime.now();
    } catch (_) {
      // 静默失败，等待下次轮询
    }
  }

  Future<void> ensureArticles(String channelId) async {
    if (_articleLoadedSet.contains(channelId)) return;
    try {
      final id = int.tryParse(channelId);
      if (id == null) return;
      final list = await _service.listArticles(id, page: 0, size: 50);
      _articles[channelId] = list;
      _articleLoadedSet.add(channelId);
      notifyListeners();
      unawaited(_cacheArticles(channelId));
    } catch (_) {}
  }

  Future<void> refreshArticles(String channelId) async {
    try {
      final id = int.tryParse(channelId);
      if (id == null) return;
      final list = await _service.listArticles(id, page: 0, size: 50);
      _articles[channelId] = list;
      _articleLoadedSet.add(channelId);
      notifyListeners();
      unawaited(_cacheArticles(channelId));
    } catch (_) {}
  }

  List<SubscriptionArticle> articlesOf(String channelId) {
    final list = _articles[channelId] ?? const [];
    final sorted = [...list]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted;
  }

  SubscriptionArticle? getArticle(String channelId, String articleId) {
    final list = _articles[channelId];
    if (list == null) return null;
    for (final a in list) {
      if (a.id == articleId) return a;
    }
    return null;
  }

  SubscriptionArticle _mapArticle(Map json) {
    DateTime _parseTime(v) {
      if (v == null) return DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      final s = v.toString();
      return DateTime.tryParse(s.replaceFirst(' ', 'T')) ?? DateTime.now();
    }
    return SubscriptionArticle(
      id: (json['id'] ?? '').toString(),
      channelId: (json['accountId'] ?? json['channelId'] ?? '').toString(),
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      content: json['content'] ?? '',
      cover: json['coverImage'],
      publishedAt: _parseTime(json['publishedAt']),
      official: true,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawChannels = prefs.getString(_channelsCacheKey);
      if (rawChannels != null && rawChannels.isNotEmpty) {
        final list = (jsonDecode(rawChannels) as List)
            .whereType<Map>()
            .map((e) =>
                SubscriptionChannel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (list.isNotEmpty) {
          _channels
            ..clear()
            ..addAll(list);
          notifyListeners();
        }
      }

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (!key.startsWith(_articlesCachePrefix)) continue;
        final channelId = key.substring(_articlesCachePrefix.length);
        final rawArticles = prefs.getString(key);
        if (rawArticles == null || rawArticles.isEmpty) continue;
        final list = (jsonDecode(rawArticles) as List)
            .whereType<Map>()
            .map((e) =>
                SubscriptionArticle.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (list.isNotEmpty) {
          _articles[channelId] = list;
          _articleLoadedSet.add(channelId);
        }
      }
    } catch (_) {}
  }

  Future<void> _cacheChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _channelsCacheKey,
          jsonEncode(
              _channels.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _cacheArticles(String channelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _articles[channelId];
      if (list == null) return;
      await prefs.setString(
          '$_articlesCachePrefix$channelId',
          jsonEncode(list.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }
}
