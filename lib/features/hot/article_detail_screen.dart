import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/models/message.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/community_notification_provider.dart';
import '../../shared/services/hot_service.dart';
import '../../widgets/common/image_viewer.dart';
import '../../core/utils/app_router.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const ArticleDetailScreen({super.key, required this.data});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final FocusNode _focusNode = FocusNode();
  String? _replyTo;
  int? _replyParentId;
  int? _articleId; // 后端文章ID（hot_articles）
  int? _articleAuthorId;
  List<_Comment> _loadedComments = const [];
  List<_RenderItem> _renderList = const [];
  final ScrollController _scrollCtrl = ScrollController();
  double _toolbarOpacity = 0.0; // 0 透明，1 不透明
  // For deep-linking to a specific comment
  final Map<int, GlobalKey> _commentKeys = {};
  int? _targetCommentId;
  bool _didScrollToTarget = false;

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
  }

  int? _resolveAuthorId(Map<dynamic, dynamic> data) {
    int? uid = (data['authorId'] as num?)?.toInt();
    uid ??= (data['userId'] as num?)?.toInt();
    if (uid == null && data['author'] is Map) {
      uid = ((data['author'] as Map)['id'] as num?)?.toInt();
    }
    return uid;
  }

  @override
  void initState() {
    super.initState();
    _articleAuthorId = _resolveAuthorId(widget.data);
    // 初始化滚动监听（5% 视口高度内完成从透明到不透明的过渡）
    _scrollCtrl.addListener(() {
      final double threshold = (MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.height * 0.05).clamp(20.0, 80.0);
      final double t = (_scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0);
      final double next = (t / threshold).clamp(0.0, 1.0);
      if ((next - _toolbarOpacity).abs() > 0.01 && mounted) setState(() => _toolbarOpacity = next);
    });
    // Capture target comment id for deep-linking
    final rawTarget = (widget.data['scrollToCommentId'] ?? widget.data['commentId']);
    if (rawTarget is int) _targetCommentId = rawTarget;
    if (rawTarget is String) _targetCommentId = int.tryParse(rawTarget);
  }

  Future<void> _reloadComments() async {
    final id = _articleId;
    if (id == null) return;
    final res = await HotService().listComments(id);
    if (!mounted || !res.success || res.data == null) return;
    final list = res.data!;
    final Map<int, _Comment> index = {};
    final Set<int> idSeen = <int>{};
    final Set<String> comboSeen = <String>{};
    final List<_Comment> flat = [];
    for (final m in list) {
      final uid = (m['userId'] as num?)?.toInt();
      final pid = (m['parentId'] as num?)?.toInt() ?? 0;
      final ct = (m['content'] ?? '').toString().trim();
      final mid = (m['id'] as num?)?.toInt();
      if (mid != null) { if (idSeen.contains(mid)) continue; idSeen.add(mid); }
      else { final key = '${uid ?? -1}|$pid|$ct'; if (comboSeen.contains(key)) continue; comboSeen.add(key); }
      flat.add(_Comment(
        id: mid,
        parentId: (m['parentId'] as num?)?.toInt(),
        userId: uid,
        avatarUrl: (m['userAvatar'] ?? '').toString(),
        nick: (m['userNick'] ?? '').toString(),
        time: (m['createdAt'] ?? '').toString(),
        content: (m['content'] ?? '').toString(),
        replies: <_Comment>[],
      ));
    }
    for (final c in flat) { if (c.id != null) index[c.id!] = c; }
    final roots = <_Comment>[];
    for (final c in flat) {
      if (c.parentId != null && index.containsKey(c.parentId!)) index[c.parentId!]!.replies.add(c);
      else roots.add(c);
    }
    setState(() {
      _loadedComments = List<_Comment>.from(roots.reversed);
      _renderList = _buildRenderList(_loadedComments);
    });
    // Try to scroll to target after first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryScrollToTarget());
  }

  // Try to scroll the list to a specific comment (when opened from a notification)
  void _tryScrollToTarget() {
    if (_didScrollToTarget) return;
    final id = _targetCommentId;
    if (id == null) return;
    final key = _commentKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null) return; // not built yet; wait for next frame
    _didScrollToTarget = true;
    try {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    } catch (_) {
      _didScrollToTarget = false; // try again later if failed
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildSharePayload(int articleId) {
    final title = (widget.data['title'] ?? '').toString();
    final summary = (widget.data['summary'] ?? '').toString();
    final cover = ((widget.data['imageUrl'] ?? widget.data['coverImage']) ?? '').toString();
    final publisher = (widget.data['authorName'] ?? widget.data['publisher'] ?? '').toString();
    final publishedAt = (widget.data['publishedAt'] ?? widget.data['createdAt'] ?? '').toString();
    return {
      'type': 'HOT_ARTICLE_SHARE',
      'id': articleId,
      'articleId': articleId,
      'title': title,
      'summary': summary,
      'cover': cover,
      'imageUrl': cover,
      if (publisher.isNotEmpty) 'publisher': publisher,
      if (publishedAt.isNotEmpty) 'publishedAt': publishedAt,
    };
  }

  Future<void> _shareCurrentArticle() async {
    if (!_isMobilePlatform) return;
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      if (mounted) context.showInfoToast('请先登录再分享');
      return;
    }
    final chat = context.read<ChatProvider>();
    final conversations = List.of(chat.conversationList);
    if (conversations.isEmpty) {
      if (mounted) context.showInfoToast('暂无可分享的会话');
      return;
    }
    final articleId = _articleId ?? (widget.data['id'] ?? widget.data['articleId']) as int?;
    if (articleId == null) {
      if (mounted) context.showErrorToast('文章尚未加载完成，请稍后再试');
      return;
    }
    final payload = _buildSharePayload(articleId);
    String? pickedId;
    bool pickedIsGroup = false;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text('分享至', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (_, i) {
                    final c = conversations[i];
                    final isGroup = c.type.toString().contains('group');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surface,
                        backgroundImage: (c.avatar != null && c.avatar!.isNotEmpty) ? NetworkImage(c.avatar!) : null,
                        child: (c.avatar == null || c.avatar!.isEmpty)
                            ? Text(c.displayName.isNotEmpty ? c.displayName[0] : '?')
                            : null,
                      ),
                      title: Text(c.displayName),
                      subtitle: Text(isGroup ? '群聊' : '好友'),
                      onTap: () {
                        pickedId = c.id;
                        pickedIsGroup = isGroup;
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: conversations.length,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (pickedId == null) return;

    final ok = await chat.sendMessage(
      senderId: auth.user!.id,
      content: jsonEncode(payload),
      contactId: pickedId!,
      isGroup: pickedIsGroup,
      type: MessageType.link,
    );
    if (ok != null) {
      if (mounted) context.showSuccessToast('已分享给${pickedIsGroup ? '群聊' : '好友'}');
    } else {
      final err = context.read<ChatProvider>().errorMessage;
      if (mounted) context.showErrorToast(err != null && err.isNotEmpty ? '分享失败：$err' : '分享失败，请稍后重试');
    }
  }

  Future<void> _showMoreSheet() async {
    if (!_isMobilePlatform) return;
    final isOwner = _isCurrentUserArticleOwner();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              ),
              if (isOwner) ...[
                ListTile(
                  leading: const Icon(Icons.edit_note_outlined, color: AppColors.textPrimary),
                  title: const Text('编辑文章'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleEditArticle();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('删除文章', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteArticle();
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: const Text('举报', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.showInfoToast('已收到举报，我们会尽快处理');
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleEditArticle() async {
    final payload = _buildEditPayload();
    if (payload == null || (payload['content'] as String?)?.trim().isEmpty == true) {
      context.showInfoToast('文章内容尚未加载完成，请稍后再试');
      return;
    }
    final result = await context.push(AppRouter.hotPublish, extra: payload);
    if (!mounted) return;
    if (result == true) {
      await _refreshArticleDetail();
    }
  }

  Future<void> _confirmDeleteArticle() async {
    final id = _articleId ?? (widget.data['id'] as num?)?.toInt();
    if (id == null) {
      context.showErrorToast('文章信息未加载');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文章'),
        content: const Text('删除后将无法恢复，确定要删除这篇文章吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    context.showLoadingToast('正在删除...');
    final res = await HotService().deleteArticle(id);
    if (!mounted) return;
    if (res.success) {
      context.showSuccessToast('已删除');
      Navigator.of(context).pop(true);
    } else {
      context.showErrorToast(res.message.isNotEmpty ? res.message : '删除失败');
    }
  }

  // 在本地树中查找父评论并追加子回复
  bool _attachReplyToLocalTree(int parentId, _Comment reply) {
    bool dfs(List<_Comment> list) {
      for (int i = 0; i < list.length; i++) {
        final c = list[i];
        if (c.id == parentId) {
          // 去重：如果该回复已存在于父节点下，直接认为成功
          if (reply.id != null && c.replies.any((e) => e.id == reply.id)) return true;
          // 直接在父对象的 replies 上追加（可变列表）
          c.replies.add(reply);
          return true;
        }
        if (c.replies.isNotEmpty && dfs(c.replies)) return true;
      }
      return false;
    }
    final list = List<_Comment>.from(_loadedComments);
    final ok = dfs(list);
    if (ok) _loadedComments = list;
    return ok;
  }

  bool _existsInTree(int id) {
    bool dfs(List<_Comment> list) {
      for (final c in list) {
        if (c.id == id) return true;
        if (c.replies.isNotEmpty && dfs(c.replies)) return true;
      }
      return false;
    }
    return dfs(_loadedComments);
  }

  // 将树形评论转为渲染列表：
  // - 顶层 indent=0
  // - 所有层级的子回复统一折叠为 indent=1，并携带 replyToNick=父评论昵称
  List<_RenderItem> _buildRenderList(List<_Comment> roots) {
    final out = <_RenderItem>[];
    final Set<int> emittedIds = <int>{};
    final Set<String> emittedCombo = <String>{};
    void dfs(_Comment root) {
      if (!_alreadyEmitted(root, emittedIds, emittedCombo)) {
        out.add(_RenderItem(comment: root, indent: 0));
        _markEmitted(root, emittedIds, emittedCombo);
      }
      void visitChildren(_Comment parent) {
        for (final child in parent.replies) {
          if (!_alreadyEmitted(child, emittedIds, emittedCombo)) {
            out.add(_RenderItem(comment: child, indent: 1, replyToNick: parent.nick));
            _markEmitted(child, emittedIds, emittedCombo);
          }
          // 深层也一律以 indent=1 展示，但 replyToNick 使用其直接父级昵称
          if (child.replies.isNotEmpty) visitChildren(child);
        }
      }
      if (root.replies.isNotEmpty) visitChildren(root);
    }
    for (final r in roots) dfs(r);
    return out;
  }

  bool _alreadyEmitted(_Comment c, Set<int> ids, Set<String> combos) {
    if (c.id != null && ids.contains(c.id)) return true;
    final key = '${c.userId ?? -1}|${c.parentId ?? 0}|${c.content.trim()}';
    if (combos.contains(key)) return true;
    return false;
  }

  void _markEmitted(_Comment c, Set<int> ids, Set<String> combos) {
    if (c.id != null) ids.add(c.id!);
    combos.add('${c.userId ?? -1}|${c.parentId ?? 0}|${c.content.trim()}');
  }

  void _applyArticleDetailData(Map<String, dynamic> d) {
    widget.data['title'] = (d['title'] ?? widget.data['title']).toString();
    widget.data['summary'] = (d['summary'] ?? widget.data['summary']).toString();
    widget.data['imageUrl'] = (d['coverImage'] ?? widget.data['imageUrl']).toString();
    widget.data['coverImage'] = (d['coverImage'] ?? widget.data['coverImage']).toString();
    widget.data['publishedAt'] = (d['createdAt'] ?? widget.data['publishedAt']).toString();
    widget.data['content'] = (d['content'] ?? widget.data['content']).toString();
    widget.data['authorName'] = d['authorName'] ?? widget.data['authorName'];
    widget.data['authorAvatar'] = d['authorAvatar'] ?? widget.data['authorAvatar'];
    widget.data['category'] = d['category'] ?? widget.data['category'];
    widget.data['channel'] = d['channel'] ?? widget.data['channel'];
    widget.data['resourceType'] = d['resourceType'] ?? widget.data['resourceType'];
    widget.data['labelId'] = d['labelId'] ?? widget.data['labelId'];
    widget.data['authorId'] = d['authorId'] ?? widget.data['authorId'];
    widget.data['userId'] = d['userId'] ?? widget.data['userId'];
    if (d['author'] != null) widget.data['author'] = d['author'];
    _articleAuthorId = _resolveAuthorId(widget.data);
  }

  void _openCoverViewer(String url) {
    if (!_isMobilePlatform) return;
    final u = url.trim();
    if (u.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImageViewer(imageUrl: u)));
  }

  Future<void> _refreshArticleDetail() async {
    final id = _articleId ?? (widget.data['id'] as num?)?.toInt() ?? (widget.data['articleId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final res = await HotService().getArticleDetail(id);
      if (!mounted) return;
      if (res.success && res.data != null) {
        setState(() {
          _applyArticleDetailData(res.data!);
        });
      } else if (res.message.isNotEmpty) {
        context.showErrorToast(res.message);
      }
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('刷新文章失败');
    }
  }

  bool _isCurrentUserArticleOwner() {
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.user?.id;
      return uid != null && _articleAuthorId != null && uid == _articleAuthorId;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _buildEditPayload() {
    final id = _articleId ?? (widget.data['id'] as num?)?.toInt() ?? (widget.data['articleId'] as num?)?.toInt();
    if (id == null) return null;
    final title = (widget.data['title'] ?? '').toString();
    final summary = (widget.data['summary'] ?? '').toString();
    final content = (widget.data['content'] ?? '').toString();
    final cover = (widget.data['imageUrl'] ?? widget.data['coverImage'] ?? '').toString();
    return {
      'id': id,
      'articleId': id,
      'title': title,
      'summary': summary,
      'content': content,
      'coverImage': cover,
      'imageUrl': cover,
      'category': widget.data['category'],
      'channel': widget.data['channel'],
      'resourceType': widget.data['resourceType'],
      'labelId': widget.data['labelId'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '文章详情';
    final summary = widget.data['summary'] as String? ?? '';
    final publisher = (widget.data['authorName'] ?? widget.data['publisher'] ?? '发布者').toString();
    final authorAvatar = (widget.data['authorAvatar'] ?? '').toString();
    final publishedAt = widget.data['publishedAt'] as String? ?? '';
    final imageUrl = widget.data['imageUrl'] as String? ?? '';
    final reads = widget.data['reads']?.toString() ?? '0';
    final heat = widget.data['heat']?.toString() ?? '0';
    final content = widget.data['content'] as String?;
    final id = (widget.data['id'] ?? widget.data['articleId']) as int?;
    // 若没有内容且有ID，尝试从后端加载详情
    if (id != null && (content == null || (widget.data['title'] == null))) {
      HotService().getArticleDetail(id).then((res) {
        if (!mounted) return;
        if (res.success && res.data != null) {
          setState(() {
            final d = res.data!;
            _applyArticleDetailData(d);
          });
        }
      });
    }
    _articleId ??= (widget.data['id'] ?? widget.data['articleId']) as int?;
    _articleAuthorId ??= _resolveAuthorId(widget.data);
    // 首次进入时尝试加载评论
    if (_articleId != null && _loadedComments.isEmpty) {
      HotService().listComments(_articleId!).then((res) {
        if (!mounted) return;
        if (res.success && res.data != null) {
          final list = res.data!;
          setState(() {
            // 先按 id 建索引，将扁平列表构造成父子结构
            final Map<int, _Comment> index = {};
            // 先用 id 去重；无 id 的才用 组合键 去重，过滤历史遗留重复
            final Set<int> idSeen = <int>{};
            final Set<String> comboSeen = <String>{};
            final List<_Comment> flat = [];
            for (final m in list) {
              final uid = (m['userId'] as num?)?.toInt();
              final pid = (m['parentId'] as num?)?.toInt() ?? 0;
              final ct = (m['content'] ?? '').toString().trim();
              final mid = (m['id'] as num?)?.toInt();
              if (mid != null) { if (idSeen.contains(mid)) continue; idSeen.add(mid); }
              else { final key = '${uid ?? -1}|$pid|$ct'; if (comboSeen.contains(key)) continue; comboSeen.add(key); }
              flat.add(_Comment(
                id: (m['id'] as num?)?.toInt(),
                parentId: (m['parentId'] as num?)?.toInt(),
                userId: uid,
                avatarUrl: (m['userAvatar'] ?? 'https://picsum.photos/48').toString(),
                nick: (m['userNick'] ?? '用户${m['userId']}').toString(),
                time: (m['createdAt'] ?? '').toString(),
                content: (m['content'] ?? '').toString(),
                // 使用可变列表，便于后续在同一对象上追加子回复
                replies: <_Comment>[],
              ));
            }
            for (final c in flat) { if (c.id != null) index[c.id!] = c; }
            final List<_Comment> roots = [];
            for (final c in flat) {
              if (c.parentId != null && index.containsKey(c.parentId!)) {
                // 直接在父对象的 replies 上追加，保持引用一致
                index[c.parentId!]!.replies.add(c);
              } else {
                roots.add(c);
              }
            }
            // 顶层按时间倒序（新在上），子回复按原顺序
            _loadedComments = List<_Comment>.from(roots.reversed);
            _renderList = _buildRenderList(_loadedComments);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryScrollToTarget());
        }
      });
    }

    final bool hasHeaderImage = imageUrl.isNotEmpty;
    final Color fg = hasHeaderImage
        ? (Color.lerp(Colors.white, Colors.black87, _toolbarOpacity) ?? Colors.black87)
        : Colors.black87;
    final Color bg = hasHeaderImage
        ? (Color.lerp(Colors.transparent, Colors.white, _toolbarOpacity) ?? Colors.white)
        : Colors.white;
    final SystemUiOverlayStyle overlay = hasHeaderImage
        ? (_toolbarOpacity < 0.5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        : SystemUiOverlayStyle.dark;

    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        extendBodyBehindAppBar: hasHeaderImage, // 无主图时不需要延伸到状态栏
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg)),
          leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: fg), onPressed: () => context.pop()),
        actions: [
          if (_isMobilePlatform) ...[
            IconButton(
              tooltip: '分享',
              onPressed: _shareCurrentArticle,
              icon: Icon(Icons.share_outlined, color: fg),
            ),
            IconButton(
              tooltip: '更多',
              onPressed: _showMoreSheet,
              icon: Icon(Icons.more_horiz_rounded, color: fg),
            ),
          ],
        ],
        ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _openCoverViewer(imageUrl),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(imageUrl, fit: BoxFit.cover),
                              // 顶部渐变遮罩以增强标题可读性
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0x80000000), Color(0x00000000)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 底部小半圆融合晕染，避免一刀切
                      Container(
                        height: 22,
                        margin: const EdgeInsets.only(top: -11),
                        child: CustomPaint(painter: _FusionPainter()),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(summary, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textSecondary)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // 作者头像（有则展示）
                          if (authorAvatar.isNotEmpty) ...[
                            CircleAvatar(radius: 10, backgroundImage: NetworkImage(authorAvatar)),
                            const SizedBox(width: 6),
                          ],
                          Text(publisher, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                          Text(publishedAt, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                          const Spacer(),
                          const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 3),
                          Text(reads, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                          const SizedBox(width: 10),
                          const Icon(Icons.local_fire_department, size: 14, color: Color(0xFFFF7A00)),
                          const SizedBox(width: 3),
                          Text(heat, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text((widget.data['content'] as String? ?? ''), style: const TextStyle(fontSize: 15, height: 1.6)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // 评论提示区：左侧竖条（橙→白渐变）+ 文本
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: const [
                      _GradientBar(),
                      SizedBox(width: 8),
                      Text('评论', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              // 评论列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _renderList[index];
                    final cid = item.comment.id;
                    final key = (cid != null) ? (_commentKeys[cid] ??= GlobalKey()) : null;
                    return KeyedSubtree(
                      key: key,
                      child: _CommentCard(
                      comment: item.comment,
                      indentLevel: item.indent,
                      replyToNick: item.replyToNick,
                      onReply: (cid, nick) {
                        setState(() { _replyTo = nick; _replyParentId = cid; });
                        FocusScope.of(context).requestFocus(_focusNode);
                      },
                      ),
                    );
                  },
                  childCount: _renderList.length,
                ),
              ),
              if (_loadedComments.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('暂无评论', style: TextStyle(color: AppColors.textLight))),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)), // 为底部输入框留出空间
            ],
          ),
          // 底部固定评论对话框
          _CommentInput(
            focusNode: _focusNode,
            replyTo: _replyTo,
            onSend: (text) async {
              if (_articleId == null) return false;
              final res = await HotService().postComment(_articleId!, text, parentId: _replyParentId);
              if (!res.success) return false;
              // 标记我参与过该文章，便于收到“别人回复我”的通知
              try {
                context.read<CommunityNotificationProvider>().trackInteractedArticle(_articleId!);
              } catch (_) {}
              // 成功后不做本地 optimistic 插入，直接重拉一次，避免重复与错位
              await _reloadComments();
              if (!mounted) return true;
              setState(() { _replyTo = null; _replyParentId = null; });
              return true;
            },
          ),
        ],
      ),
    ),
        ),
      );
    return page;
  }
}

class _GradientBar extends StatelessWidget {
  const _GradientBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 18,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF7A00), Color(0xFFFFFFFF)],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: AppColors.textLight),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }
}

// 将主图与正文的过渡做成一个“向上圆弧”的白色融合盖，避免生硬切割
class _FusionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    // 圆弧向上凸起：弧顶提升一半高度，形成半圆融合
    final double bump = h; // 弧度
    path.moveTo(0, h);
    path.quadraticBezierTo(w / 2, -bump, w, h);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // 先画柔和的阴影，制造“晕染感”
    final shadowPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, shadowPaint);

    // 再画实体白色，覆盖到主图下缘
    final fill = Paint()..color = Colors.white;
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 评论输入框（底部悬浮）
class _CommentInput extends StatefulWidget {
  final FocusNode focusNode;
  final String? replyTo;
  final Future<bool> Function(String text)? onSend; // 返回 true 表示已处理
  const _CommentInput({required this.focusNode, this.replyTo, this.onSend});
  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  bool _focused = false;
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  bool _sending = false; // 防止重复提交（双击/连点）
  String _lastSentKey = '';

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText && mounted) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() => mounted ? setState(() => _focused = widget.focusNode.hasFocus) : null;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 5 + viewInsets, // 跟随键盘上移
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Stack(
            children: [
              // 输入容器
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  // 仅父盒子在聚焦时显示橙色描边；非聚焦无边框
                  border: _focused ? Border.all(color: const Color(0xFFFF7A00), width: 1) : null,
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 24, spreadRadius: 2, offset: Offset(0, 10)),
                    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(-2, 0)),
                    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(2, 0)),
                  ],
                ),
                child: SizedBox(
                  height: 90,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶部内部功能区（紧凑）
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.emoji_emotions_outlined, size: 18, color: AppColors.textLight),
                            SizedBox(width: 10),
                            Icon(Icons.image_outlined, size: 18, color: AppColors.textLight),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 大空间给输入框（无内背景/边框）
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              inputDecorationTheme: const InputDecorationTheme(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: widget.focusNode,
                              maxLines: null,
                              minLines: 2,
                              cursorHeight: 18,
                              cursorColor: Color(0xFFFF7A00),
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration.collapsed(
                                hintText: widget.replyTo == null ? '说点什么...' : '回复 @${widget.replyTo} ...',
                                hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 右下角橙色“评论”按钮，仅当有内容时显示
              Positioned(
                right: 10,
                bottom: 10,
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: (_hasText && !_sending)
                      ? SizedBox(
                          key: const ValueKey('btn'),
                          height: 28,
                          child: TextButton(
                            onPressed: _onSubmit,
                            style: ButtonStyle(
                              padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                              minimumSize: const MaterialStatePropertyAll(Size(0, 0)),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: const MaterialStatePropertyAll(Color(0xFFFF7A00)),
                              foregroundColor: const MaterialStatePropertyAll(Colors.white),
                              shape: MaterialStatePropertyAll(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              ),
                            ),
                            child: const Text('评论', style: TextStyle(fontSize: 12)),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) { context.showErrorToast('请输入评论内容'); return; }
    // 简单防抖：同样的文本在 3 秒内不重复提交
    final key = text;
    if (key == _lastSentKey) return;
    _lastSentKey = key;
    setState(() { _sending = true; });
    Future<bool> handled = widget.onSend?.call(text) ?? Future.value(false);
    handled.whenComplete(() {
      // 3 秒后允许再次提交相同文本
      Future.delayed(const Duration(seconds: 3), () { if (mounted && _lastSentKey == key) _lastSentKey = ''; });
    }).then((ok) {
      if (!mounted) return;
      setState(() { _sending = false; });
      if (ok) {
        _controller.clear();
        FocusScope.of(context).unfocus();
        context.showSuccessToast('评论已发送');
      } else {
        context.showErrorToast('发送失败，请稍后重试');
      }
    });
  }
}

class _CommentCard extends StatelessWidget {
  final _Comment comment;
  final int indentLevel;
  final String? replyToNick;
  final void Function(int id, String nick)? onReply;
  const _CommentCard({required this.comment, this.indentLevel = 0, this.replyToNick, this.onReply});

  @override
  Widget build(BuildContext context) {
    final leftPad = 16.0 + indentLevel * 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(leftPad, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundImage: NetworkImage(comment.avatarUrl), radius: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.nick, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(comment.time, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (indentLevel > 0 && replyToNick != null && replyToNick!.isNotEmpty) ...[
            Text('回复 $replyToNick', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
          ],
          Text(comment.content, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 6),
          // 右侧一行：点赞 与 回复，图标+文本严格对齐
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Meta(icon: Icons.favorite_border, text: comment.likes.toString()),
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { final id = comment.id ?? -1; if (id > 0) onReply?.call(id, comment.nick); },
                child: const _Meta(icon: Icons.reply_outlined, text: '回复'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Comment {
  final int? id;
  final int? parentId;
  final int? userId;
  final String avatarUrl;
  final String nick;
  final String time;
  final String content;
  final int likes;
  final List<_Comment> replies;
  const _Comment({this.id, this.parentId, this.userId, required this.avatarUrl, required this.nick, required this.time, required this.content, this.likes = 0, this.replies = const []});
}

class _RenderItem {
  final _Comment comment;
  final int indent;
  final String? replyToNick;
  const _RenderItem({required this.comment, required this.indent, this.replyToNick});
}

// 演示评论与正文已删除，评论/内容全部来自后端
