import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/subscription_provider.dart';
import '../../shared/models/subscription_channel.dart';
import '../../shared/models/subscription_article.dart';
import '../../widgets/common/official_badge.dart';
import '../../core/theme/app_colors.dart';
import 'article_detail_screen.dart';
import '../../core/widgets/unified_toast.dart';
import '../../widgets/common/fade_slide_in.dart';
import '../../widgets/common/empty_state.dart';

String _humanTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  return '${diff.inDays} 天前';
}
String _stripHtml(String s) => s.replaceAll(RegExp(r"<[^>]+>"), '').replaceAll('&nbsp;', ' ').trim();

class ChannelArticleListScreen extends StatelessWidget {
  final String channelId;
  const ChannelArticleListScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    // 进入列表页时确保该频道文章已加载
    provider.ensureArticles(channelId);
    final channel = provider.channels.firstWhere((c) => c.id == channelId, orElse: () => const SubscriptionChannel(id: 'unknown', name: '未知频道'));
    final list = provider.articlesOf(channelId);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(channel.name),
          const SizedBox(width: 8),
          if (channel.official) const OfficialBadge(size: 14),
        ]),
      ),
      body: ChannelArticleListView(
        channelId: channelId,
        showHeader: false, // 使用AppBar作为标题
        onOpenArticle: (id) {
          context.showLoadingToast('加载中...');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ArticleDetailScreen(channelId: channelId, articleId: id)),
          );
          Future.delayed(const Duration(milliseconds: 350), Toast.hide);
        },
      ),
    );
  }

}

// 嵌入式第三栏卡片展示（居中、卡片：图片+标题+摘要+时间+发布者）
class ChannelArticleListView extends StatelessWidget {
  final String channelId;
  final void Function(String articleId) onOpenArticle;
  final VoidCallback? onBack; // 第三栏模式下提供返回
  final bool showHeader;
  const ChannelArticleListView({super.key, required this.channelId, required this.onOpenArticle, this.onBack, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    provider.ensureArticles(channelId);
    final list = provider.articlesOf(channelId);
    final channel = provider.channels.firstWhere((c) => c.id == channelId, orElse: () => const SubscriptionChannel(id: 'unknown', name: '未知频道'));
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
                Text(channel.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (channel.official) const OfficialBadge(size: 14),
              ],
            ),
          ),
        // 列表（滚动条靠右）
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final maxW = c.maxWidth;
            final cardW = maxW > 840 ? 720.0 : (maxW > 600 ? 560.0 : maxW);
            if (list.isEmpty) {
              // 空状态（移动端与桌面端共用此视图，不改变现有布局）
              return const EmptyState(
                icon: Icons.article_outlined,
                title: '暂无文章',
                subtitle: '该订阅号还没有发布内容',
              );
            }
            return Scrollbar(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final a = list[i];
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardW),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: 40 * i),
                        child: Card(
                          clipBehavior: Clip.antiAlias, // 剪裁水波纹，避免溢出
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFEFEFEF))),
                          child: InkWell(
                            onTap: () => onOpenArticle(a.id),
                            borderRadius: BorderRadius.circular(12),
                            splashColor: const Color(0x1A000000), // 轻微水波纹
                            highlightColor: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cover(a.cover),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(_stripHtml(a.summary), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280))),
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        const CircleAvatar(radius: 10, child: Text('L', style: TextStyle(fontSize: 12))),
                                        const SizedBox(width: 6),
                                        const Text('LinkMe', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                        const SizedBox(width: 10),
                                        Text(_humanTime(a.publishedAt), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      ]),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _cover(String? url) {
    final u = (url ?? '').trim();
    if (u.isNotEmpty) {
      // 显示真实封面，加载失败时优雅降级为占位渐变图
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Image.network(
          u,
          height: 160,
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
      height: 160,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)]),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image, color: Color(0xFF93C5FD)),
    );
  }
}
