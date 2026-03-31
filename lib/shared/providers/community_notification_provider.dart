import 'dart:async';
import 'dart:convert';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/websocket_manager.dart';
import '../services/hot_service.dart';
import '../models/community_notification.dart';
import 'auth_provider.dart';

/// Provides a lightweight in-app inbox for community notifications.
/// Data lives locally (SharedPreferences) and is appended from:
/// - success callback after publishing an article
/// - WebSocket realtime events (best-effort; tolerant to missing fields)
class CommunityNotificationProvider extends ChangeNotifier {
  final WebSocketManager _ws = WebSocketManager();
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  AuthProvider? _auth;
  int? _selfUserId;

  List<CommunityNotification> _items = const [];
  bool _initialized = false;
  // Track my own published article ids so we can pull comments and form reply notifications
  final Set<int> _myArticleIds = <int>{};
  // Track articles where I have interacted (commented via this app), to catch replies to me
  final Set<int> _interactedArticleIds = <int>{};
  // Per-article last synced comment createdAt (ms)
  final Map<int, int> _lastCommentMs = <int, int>{};
  // cache article meta: title + coverImage
  final Map<int, Map<String, String>> _articleCache = <int, Map<String, String>>{};
  // Whether the chat-list entry should be displayed permanently once any event occurs
  bool _everShowEntry = false;

  List<CommunityNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((e) => !e.read).length;
  bool get initialized => _initialized;
  // 入口显示：仅在发生过一次事件（发布/收到互动）后显示；或已有历史通知
  bool get shouldShowEntry => _everShowEntry || _items.isNotEmpty;

  Future<void> initialize(AuthProvider auth) async {
    if (!_initialized) {
      _initialized = true;
      _auth = auth;
      _listenWS();
      _startPolling();
      // 监听登录状态变化以切换账号
      auth.authStateListenable.addListener(_onAuthChange);
    }
    await _applyUser(auth.user?.id);
    // 尝试为当前账号自举“我发布的文章”，以便无需手动刷新即可收到评论/回复
    _bootstrapMyArticlesOnce();
  }

  void _onAuthChange() {
    _applyUser(_auth?.user?.id);
  }

  Future<void> _applyUser(int? uid) async {
    if (uid == null) return; // 未登录
    if (uid == _selfUserId) return;
    _selfUserId = uid;
    // 切换账号：先清内存，再按账号加载
    _items = const [];
    _myArticleIds.clear();
    _lastCommentMs.clear();
    await _loadFromStorage();
    notifyListeners();
    // 切换账号后也执行一次自举
    _bootstrapped = false;
    _bootstrapMyArticlesOnce();
  }

  Future<void> _loadFromStorage() async {
    try {
      if (_selfUserId == null) return; // 未登录不加载，避免串号
      final prefs = await SharedPreferences.getInstance();
      final key = _storeKey();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => CommunityNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _items = list;
        notifyListeners();
      }
      final rawA = prefs.getString('${key}_articles');
      if (rawA != null && rawA.isNotEmpty) {
        final list = (jsonDecode(rawA) as List).map((e) => (e as num).toInt()).toList();
        _myArticleIds..clear()..addAll(list);
      }
      final rawC = prefs.getString('${key}_last_comment');
      if (rawC != null && rawC.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(rawC) as Map);
        _lastCommentMs
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(int.tryParse(k) ?? -1, (v as num).toInt())));
      }
      _everShowEntry = prefs.getBool('${key}_ever_show_entry') ?? false;
      final rawI = prefs.getString('${key}_interacted_articles');
      if (rawI != null && rawI.isNotEmpty) {
        final list = (jsonDecode(rawI) as List).map((e) => (e as num).toInt()).toList();
        _interactedArticleIds..clear()..addAll(list);
      }
    } catch (_) {
      // ignore corrupt store
    }
  }

  Future<void> _saveToStorage() async {
    try {
      if (_selfUserId == null) return; // 未登录不落盘
      final prefs = await SharedPreferences.getInstance();
      final key = _storeKey();
      await prefs.setString(key, jsonEncode(_items.map((e) => e.toJson()).toList()));
      await prefs.setString('${key}_articles', jsonEncode(_myArticleIds.toList()));
      await prefs.setString('${key}_last_comment', jsonEncode(_lastCommentMs.map((k, v) => MapEntry(k.toString(), v))));
      await prefs.setBool('${key}_ever_show_entry', _everShowEntry);
      await prefs.setString('${key}_interacted_articles', jsonEncode(_interactedArticleIds.toList()));
    } catch (_) {}
  }

  String _storeKey() => 'community_notify_v1_u_${_selfUserId ?? -1}';

  void _listenWS() {
    _wsSub?.cancel();
    _wsSub = _ws.messageStream.listen(_onWsMessage, onError: (_) {});
  }

  void dispose() {
    _wsSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // Robust best-effort WS parsing. Unknown shapes are ignored.
  void _onWsMessage(Map<String, dynamic> msg) {
    try {
      final t = (msg['type'] ?? '').toString();
      final tl = t.toUpperCase();
      switch (t) {
        case 'HOT_ARTICLE_PUBLISHED':
        case 'HOT_ARTICLE_CREATED':
        case 'HOT_NEW_ARTICLE':
          // only notify myself (author)
          final uid = (msg['authorId'] as num?)?.toInt() ?? (msg['userId'] as num?)?.toInt();
          if (uid == null || uid <= 0 || uid != _selfUserId) return;
          final aid = (msg['articleId'] as num?)?.toInt() ?? (msg['id'] as num?)?.toInt();
          if (aid == null) return;
          addPublishNotification(
            articleId: aid,
            title: (msg['title'] ?? '').toString(),
            imageUrl: (msg['coverImage'] ?? msg['imageUrl'] ?? '').toString(),
            createdAt: _parseDate(msg['createdAt']) ?? DateTime.now(),
          );
          break;
        case 'HOT_COMMENT_CREATED':
        case 'HOT_NEW_COMMENT':
        case 'HOT_REPLY_CREATED':
        case 'HOT_COMMENT_REPLY':
          final ownerId = (msg['articleAuthorId'] as num?)?.toInt();
          final replyToUserId = (msg['replyToUserId'] as num?)?.toInt();
          if (_selfUserId == null) return;
          if (ownerId != _selfUserId && replyToUserId != _selfUserId) return;
          final aid = (msg['articleId'] as num?)?.toInt();
          if (aid == null) return;
          final commentId = (msg['commentId'] as num?)?.toInt();
          _myArticleIds.add(aid);
          final title = (msg['articleTitle'] ?? '').toString();
          final cover = (msg['articleCover'] ?? msg['coverImage'] ?? '').toString();
          final isReply = (replyToUserId != null && replyToUserId == _selfUserId);
          addReplyNotification(
            articleId: aid,
            articleTitle: title,
            articleImageUrl: cover,
            fromUserName: (msg['fromUserName'] ?? msg['userNick'] ?? '').toString(),
            fromUserAvatar: (msg['fromUserAvatar'] ?? msg['userAvatar'] ?? '').toString(),
            commentText: (msg['content'] ?? msg['comment'] ?? '').toString(),
            commentId: commentId,
            isReply: isReply,
            createdAt: _parseDate(msg['createdAt']) ?? DateTime.now(),
          );
          // 若缺少标题/封面，后台补齐一次
          if (title.isEmpty || cover.isEmpty) {
            _ensureArticleInfo(aid).then((meta) {
              if (meta == null) return;
              final idx = _items.indexWhere((e) => e.articleId == aid && e.type == CommunityNotificationType.reply && (e.articleTitle.isEmpty || e.articleImageUrl.isEmpty));
              if (idx != -1) {
                _items[idx] = _items[idx].copyWith(
                  articleTitle: _items[idx].articleTitle.isEmpty ? (meta['title'] ?? _items[idx].articleTitle) : _items[idx].articleTitle,
                  articleImageUrl: _items[idx].articleImageUrl.isEmpty ? (meta['coverImage'] ?? _items[idx].articleImageUrl) : _items[idx].articleImageUrl,
                );
                notifyListeners();
                _saveToStorage();
              }
            });
          }
          break;
        case 'HOT_LIKE_CREATED':
        case 'HOT_NEW_LIKE':
          final toUserId = (msg['targetOwnerId'] as num?)?.toInt();
          if (_selfUserId == null || toUserId != _selfUserId) return;
          final aid = (msg['articleId'] as num?)?.toInt();
          if (aid == null) return;
          final isComment = (msg['targetType'] ?? '').toString().toLowerCase() == 'comment';
          _myArticleIds.add(aid);
          final title2 = (msg['articleTitle'] ?? '').toString();
          final cover2 = (msg['articleCover'] ?? msg['coverImage'] ?? '').toString();
          addLikeNotification(
            articleId: aid,
            articleTitle: title2,
            articleImageUrl: cover2,
            fromUserName: (msg['fromUserName'] ?? msg['userNick'] ?? '').toString(),
            fromUserAvatar: (msg['fromUserAvatar'] ?? msg['userAvatar'] ?? '').toString(),
            commentText: isComment ? (msg['comment'] ?? msg['content'] ?? '').toString() : null,
            commentId: (msg['commentId'] as num?)?.toInt(),
            likeTargetIsComment: isComment,
            createdAt: _parseDate(msg['createdAt']) ?? DateTime.now(),
          );
          if (title2.isEmpty || cover2.isEmpty) {
            _ensureArticleInfo(aid).then((meta) {
              if (meta == null) return;
              final idx = _items.indexWhere((e) => e.articleId == aid && e.type == CommunityNotificationType.like && (e.articleTitle.isEmpty || e.articleImageUrl.isEmpty));
              if (idx != -1) {
                _items[idx] = _items[idx].copyWith(
                  articleTitle: _items[idx].articleTitle.isEmpty ? (meta['title'] ?? _items[idx].articleTitle) : _items[idx].articleTitle,
                  articleImageUrl: _items[idx].articleImageUrl.isEmpty ? (meta['coverImage'] ?? _items[idx].articleImageUrl) : _items[idx].articleImageUrl,
                );
                notifyListeners();
                _saveToStorage();
              }
            });
          }
          break;
        default:
          // ignore other events
          break;
      }
    } catch (_) {
      // tolerate malformed events
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return null;
  }

  // Public APIs to append notifications programmatically
  void addPublishNotification({
    required int articleId,
    required String title,
    required String imageUrl,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    final n = CommunityNotification(
      id: 'pub_${now.millisecondsSinceEpoch}_${articleId}',
      type: CommunityNotificationType.publish,
      articleId: articleId,
      articleTitle: title,
      articleImageUrl: imageUrl,
      createdAt: now,
    );
    _items = [n, ..._items];
    _myArticleIds.add(articleId);
    _everShowEntry = true;
    _saveToStorage();
    notifyListeners();
  }

  void addLikeNotification({
    required int articleId,
    required String articleTitle,
    required String articleImageUrl,
    required String fromUserName,
    String? fromUserAvatar,
    String? commentText,
    int? commentId,
    bool likeTargetIsComment = false,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    final n = CommunityNotification(
      id: 'like_${now.millisecondsSinceEpoch}_${articleId}_${commentId ?? 0}',
      type: CommunityNotificationType.like,
      articleId: articleId,
      articleTitle: articleTitle,
      articleImageUrl: articleImageUrl,
      fromUserName: fromUserName,
      fromUserAvatar: fromUserAvatar,
      commentText: commentText,
      commentId: commentId,
      likeTargetIsComment: likeTargetIsComment,
      createdAt: now,
    );
    _items = [n, ..._items];
    _everShowEntry = true;
    _saveToStorage();
    notifyListeners();
  }

  void addReplyNotification({
    required int articleId,
    required String articleTitle,
    required String articleImageUrl,
    required String fromUserName,
    String? fromUserAvatar,
    required String commentText,
    int? commentId,
    bool isReply = false,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    final n = CommunityNotification(
      id: 'reply_${now.millisecondsSinceEpoch}_${articleId}_${commentId ?? 0}',
      type: CommunityNotificationType.reply,
      articleId: articleId,
      articleTitle: articleTitle,
      articleImageUrl: articleImageUrl,
      fromUserName: fromUserName,
      fromUserAvatar: fromUserAvatar,
      commentText: commentText,
      commentId: commentId,
      isReply: isReply,
      createdAt: now,
    );
    _items = [n, ..._items];
    _everShowEntry = true;
    _saveToStorage();
    notifyListeners();
  }

  void markAllRead() {
    bool changed = false;
    _items = _items.map((e) {
      if (!e.read) { changed = true; return e.copyWith(read: true); }
      return e;
    }).toList();
    if (changed) _saveToStorage();
    if (changed) notifyListeners();
  }

  void removeById(String id) {
    _items = _items.where((e) => e.id != id).toList();
    _saveToStorage();
    notifyListeners();
  }

  void clearAll() {
    _items = const [];
    _lastCommentMs.clear();
    _saveToStorage();
    notifyListeners();
  }

  // Pull comments for my published articles to form reply notifications (best-effort fallback when server doesn't push)
  bool _syncing = false;
  DateTime _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> syncFromServer({Future<List<Map<String, dynamic>>> Function(int articleId)? listComments}) async {
    if (_syncing) return;
    // 紧凑节流：至多每 5 秒一次
    if (DateTime.now().difference(_lastSyncAt).inSeconds < 5) return;
    _syncing = true; _lastSyncAt = DateTime.now();
    try {
      final api = listComments;
      final hot = HotService();
      final Set<int> targets = {..._myArticleIds, ..._interactedArticleIds};
      for (final aid in targets) {
        try {
          final list = api != null
              ? await api(aid)
              : ((await hot.listComments(aid)).data ?? const <Map<String, dynamic>>[]);
          // assume items sorted by time asc or not; we compute max time
          int lastMs = _lastCommentMs[aid] ?? 0;
          // Build id->userId for reply detection
          final Map<int, int> idToUser = {};
          for (final m in list) {
            final id = (m['id'] as num?)?.toInt();
            final uid = (m['userId'] as num?)?.toInt();
            if (id != null && uid != null) idToUser[id] = uid;
          }
          // Ensure article meta cached first (one request per article)
          Map<String, String>? meta = _articleCache[aid];
          meta ??= await _ensureArticleInfo(aid);
          for (final m in list) {
            final uid = (m['userId'] as num?)?.toInt();
            if (uid == null || uid == _selfUserId) continue; // skip my own
            final tsStr = (m['createdAt'] ?? '').toString();
            final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
            final ms = ts.millisecondsSinceEpoch;
            if (ms <= lastMs) continue;
            final parentId = (m['parentId'] as num?)?.toInt();
            final isReplyToMe = parentId != null && idToUser[parentId] == _selfUserId;
            final isMyArticle = _myArticleIds.contains(aid);
            // 通知范围：
            // - 我自己的文章：别人的顶层评论（评论）或对我评论的回复（回复）
            // - 我曾参与过的文章：仅当对我评论的回复（回复）
            if (isMyArticle) {
              final isReply = isReplyToMe;
              final isTopLevel = parentId == null;
              if (isTopLevel || isReply) {
                addReplyNotification(
                  articleId: aid,
                  articleTitle: (meta?['title'] ?? ''),
                  articleImageUrl: (meta?['coverImage'] ?? ''),
                  fromUserName: (m['userNick'] ?? '').toString(),
                  fromUserAvatar: (m['userAvatar'] ?? '').toString(),
                  commentText: (m['content'] ?? '').toString(),
                  commentId: (m['id'] as num?)?.toInt(),
                  isReply: isReply,
                  createdAt: ts,
                );
              }
            } else if (_interactedArticleIds.contains(aid) && isReplyToMe) {
              addReplyNotification(
                articleId: aid,
                articleTitle: (meta?['title'] ?? ''),
                articleImageUrl: (meta?['coverImage'] ?? ''),
                fromUserName: (m['userNick'] ?? '').toString(),
                fromUserAvatar: (m['userAvatar'] ?? '').toString(),
                commentText: (m['content'] ?? '').toString(),
                commentId: (m['id'] as num?)?.toInt(),
                isReply: true,
                createdAt: ts,
              );
            }
            if (ms > lastMs) lastMs = ms;
          }
          _lastCommentMs[aid] = lastMs;
        } catch (_) {}
      }
      await _saveToStorage();
    } finally {
      _syncing = false;
    }
  }

  // background polling to avoid manual refresh (≈5s interval)
  Timer? _pollTimer;
  void _startPolling() {
    _pollTimer?.cancel();
    // 首次延时 1s 拉一次，之后每 5s 拉一次
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // 尽量避免未登录或没有文章时空转
      if (_selfUserId == null || _myArticleIds.isEmpty) return;
      // 内部含 20s 节流
      syncFromServer();
    });
    // 立即触发一次（1s 后）
    Future.delayed(const Duration(seconds: 1), () { if (_selfUserId != null && _myArticleIds.isNotEmpty) syncFromServer(); });
  }

  Future<Map<String, String>?> _ensureArticleInfo(int aid) async {
    if (_articleCache.containsKey(aid)) return _articleCache[aid]!;
    try {
      final res = await HotService().getArticleDetail(aid);
      if (res.success && res.data != null) {
        final d = res.data!;
        final meta = <String, String>{
          'title': (d['title'] ?? '').toString(),
          'coverImage': (d['coverImage'] ?? '').toString(),
        };
        _articleCache[aid] = meta;
        return meta;
      }
    } catch (_) {}
    return null;
  }

  // 自举：扫描分类第一页，收集我发布的文章ID；仅执行一次
  bool _bootstrapped = false;
  Future<void> _bootstrapMyArticlesOnce() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final uid = _selfUserId;
    if (uid == null) return;
    try {
      final cats = await HotService().fetchCategories();
      final names = (cats.data ?? const []).map((e) => (e['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      for (final name in names) {
        try {
          int page = 0;
          int scanned = 0;
          while (page < 5) { // 最多扫前5页，兼顾历史文章
            final res = await HotService().listByCategory(category: name, page: page, size: 20);
            final data = res.data ?? const {};
            final list = (data['articles'] as List?) ?? const [];
            if (list.isEmpty) break;
            for (final m in list) {
              final a = m as Map;
              final aid = (a['id'] as num?)?.toInt();
              // 后端字段兼容：authorId 或 userId 或 author.id
              int? au = (a['authorId'] as num?)?.toInt();
              au ??= (a['userId'] as num?)?.toInt();
              if (au == null && a['author'] is Map) {
                au = ((a['author'] as Map)['id'] as num?)?.toInt();
              }
              if (aid != null && au != null && au == uid) _myArticleIds.add(aid);
            }
            scanned += list.length;
            // 如果总数可用且已到末尾则停止
            final total = (data['total'] as num?)?.toInt();
            final size = (data['size'] as num?)?.toInt() ?? 20;
            final curPage = (data['page'] as num?)?.toInt() ?? page;
            page = curPage + 1;
            if (total != null && scanned >= total) break;
          }
        } catch (_) {}
      }
      if (_myArticleIds.isNotEmpty) {
        // 不自动展示入口；仅用于后续拉取评论/回复
        // 立刻拉一次评论，避免等待周期
        await syncFromServer();
      }
    } catch (_) {}
  }

  // 供文章页在“我发表评论/回复成功”后调用，记录为“我参与过的文章”
  void trackInteractedArticle(int articleId) {
    if (!_interactedArticleIds.contains(articleId)) {
      _interactedArticleIds.add(articleId);
      _saveToStorage();
    }
  }
}
