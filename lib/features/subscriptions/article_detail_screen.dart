import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../shared/providers/subscription_provider.dart';
import '../../shared/models/subscription_article.dart';
import '../../widgets/common/official_badge.dart';
import '../../widgets/common/linkme_loader.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/fade_slide_in.dart';
import '../../widgets/common/lite_html.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/models/message.dart';

String _formatDateTime(DateTime dt) {
  return '${dt.year}-${_2(dt.month)}-${_2(dt.day)} ${_2(dt.hour)}:${_2(dt.minute)}';
}

String _2(int n) => n.toString().padLeft(2, '0');

class ArticleDetailScreen extends StatelessWidget {
  final String channelId;
  final String articleId;
  const ArticleDetailScreen({super.key, required this.channelId, required this.articleId});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SubscriptionProvider>();
    final a = sp.getArticle(channelId, articleId);
    if (a == null) {
      // 首次进入时，若本地未加载该频道文章，触发一次加载
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final sp0 = context.read<SubscriptionProvider>();
          await sp0.ensureArticles(channelId);
          // 若仍未找到，主动刷新一次，兼容刚发布未拉取到的场景
          if (sp0.getArticle(channelId, articleId) == null) {
            await sp0.refreshArticles(channelId);
          }
        } catch (_) {}
      });
      return Scaffold(
        appBar: AppBar(title: const Text('文章详情')),
        body: const Center(child: SizedBox(height: 30, child: LinkMeLoader(fontSize: 20))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('文章详情'),
        actions: [
          // 分享图标：与返回图标大小一致
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.share_outlined, size: 24),
            onPressed: () => shareArticle(context, a),
          ),
        ],
      ),
      body: ArticleDetailView(
        article: _ArticleVM.from(a),
        showHeader: false,
        onShare: () => shareArticle(context, a),
      ),
    );
  }

}

// 嵌入第三栏的详情视图（图片+标题+摘要+正文+时间+发布者）
class ArticleDetailView extends StatelessWidget {
  final _ArticleVM article;
  final VoidCallback? onBack; // 第三栏模式下的返回
  final bool showHeader; // 需要标题栏时为true（第三栏），在屏幕页中用AppBar则false
  final VoidCallback? onShare; // 顶部分享
  const ArticleDetailView({super.key, required this.article, this.onBack, this.showHeader = true, this.onShare});
  factory ArticleDetailView.fromArticle(SubscriptionArticle a, {VoidCallback? onBack, bool showHeader = true, VoidCallback? onShare}) =>
      ArticleDetailView(article: _ArticleVM.from(a), onBack: onBack, showHeader: showHeader, onShare: onShare);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth;
      final contentW = maxW > 840 ? 720.0 : (maxW > 600 ? 560.0 : maxW);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFEDEDED), width: 1)),
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (onBack != null) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      article.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  // 右侧分享按钮
                  IconButton(
                    tooltip: '分享',
                    onPressed: onShare,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          // 正文滚动（滚动条靠右）
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentW),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(delay: const Duration(milliseconds: 40), child: _cover(article.cover)),
                        const SizedBox(height: 14),
                        FadeSlideIn(delay: const Duration(milliseconds: 80), child: Text(article.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                        const SizedBox(height: 8),
                        FadeSlideIn(delay: const Duration(milliseconds: 120), child: Text(_stripHtml(article.summary), style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)))),
                        const SizedBox(height: 10),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 160),
                          child: Row(children: [
                            const OfficialBadge(size: 14),
                            const SizedBox(width: 8),
                            const Text('LinkMe', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                            const SizedBox(width: 10),
                            Text(article.time, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        // Render simple HTML (b/i/u/br/div/p) instead of showing raw tags
                        FadeSlideIn(delay: const Duration(milliseconds: 200), child: LiteHtml(article.content)),
                        const Divider(height: 32),
                        FadeSlideIn(delay: const Duration(milliseconds: 240), child: const Text('最新动态', style: TextStyle(fontWeight: FontWeight.w700))),
                        const SizedBox(height: 8),
                        FadeSlideIn(delay: const Duration(milliseconds: 260), child: const Text('后续将支持图文、活动报名与推送设置，敬请期待。', style: TextStyle(color: AppColors.textLight))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _cover(String? url) {
    final u = (url ?? '').trim();
    if (u.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          u,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _coverPlaceholder(),
        ),
      );
    }
    return _coverPlaceholder();
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [Color(0xFFE0F2FE), Color(0xFFDBEAFE)]),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image, color: Color(0xFF60A5FA), size: 48),
    );
  }
}

class _ArticleVM {
  final String title;
  final String summary;
  final String content;
  final String? cover;
  final String time;
  final String? channelId;
  final String? id;
  _ArticleVM(this.title, this.summary, this.content, this.cover, this.time, {this.channelId, this.id});

  static _ArticleVM from(article) => _ArticleVM(
        article.title,
        article.summary,
        article.content,
        article.cover,
        _formatDateTime(article.publishedAt),
        channelId: article.channelId,
        id: article.id,
      );
}

String _stripHtml(String s) => s.replaceAll(RegExp(r"<[^>]+>"), '').replaceAll('&nbsp;', ' ').trim();

// 触发分享：弹出底部选择器，选择好友或群聊后，发送带文章信息的 link 消息
Future<void> shareArticle(BuildContext context, SubscriptionArticle a) async {
  final auth = context.read<AuthProvider>();
  final chat = context.read<ChatProvider>();
  if (auth.user == null) {
    // ignore: use_build_context_synchronously
    context.showInfoToast('请先登录再分享');
    return;
  }

  final conversations = List.of(chat.conversationList);
  if (conversations.isEmpty) {
    // ignore: use_build_context_synchronously
    context.showInfoToast('暂无可分享的会话');
    return;
  }

  String? pickedId;
  bool pickedIsGroup = false;

  // 简易选择器：底部弹出最近会话列表，点击即可分享
  // 不改动现有导航结构，避免影响布局
  await showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Text('分享至', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = conversations[i];
                  final isGroup = c.type.toString().contains('group');
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surface,
                      backgroundImage: (c.avatar != null && c.avatar!.isNotEmpty) ? NetworkImage(c.avatar!) : null,
                      child: (c.avatar == null || c.avatar!.isEmpty)
                          ? Text((c.displayName.isNotEmpty ? c.displayName[0] : '?'))
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
              ),
            ),
          ],
        ),
      );
    },
  );

  if (pickedId == null) return; // 取消

  // 构造分享消息内容（JSON字符串，前端识别为文章卡片）
  final payload = {
    'type': 'ARTICLE_SHARE',
    'channelId': a.channelId,
    'articleId': a.id,
    'title': a.title,
    'summary': a.summary,
    'cover': a.cover,
    'publishedAt': a.publishedAt.toIso8601String(),
  };
  final content = jsonEncode(payload);

  // 发送消息
  final ok = await chat.sendMessage(
    senderId: auth.user!.id,
    content: content,
    contactId: pickedId!,
    isGroup: pickedIsGroup,
    type: MessageType.link,
  );
  if (ok != null) {
    // ignore: use_build_context_synchronously
    context.showSuccessToast('已分享给${pickedIsGroup ? '群聊' : '好友'}');
  } else {
    // 更友好的错误提示（不改变界面布局）
    final err = context.read<ChatProvider>().errorMessage;
    // ignore: use_build_context_synchronously
    context.showErrorToast(err != null && err.isNotEmpty ? '分享失败：$err' : '分享失败，请稍后重试');
  }
}
