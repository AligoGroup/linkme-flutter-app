import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/services/hot_service.dart';
import '../../shared/providers/community_notification_provider.dart';
import '../../shared/models/community_notification.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/lottie_refresh_indicator.dart';

class CommunityNotificationsScreen extends StatelessWidget {
  const CommunityNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CommunityNotificationProvider>();
    // 打开页面后即清空未读，避免返回首页红点还在
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted)
        context.read<CommunityNotificationProvider>().markAllRead();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('社区通知'),
        actions: [
          if (p.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  context.read<CommunityNotificationProvider>().markAllRead(),
              child: const Text('全部已读'),
            ),
        ],
      ),
      body: LottieRefreshIndicator(
        onRefresh: () async {
          await context.read<CommunityNotificationProvider>().syncFromServer(
            listComments: (aid) async {
              final res = await HotService().listComments(aid);
              return res.success && res.data != null
                  ? res.data!
                  : <Map<String, dynamic>>[];
            },
          );
        },
        child: _CommunityList(),
      ),
    );
  }
}

class _CommunityList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityNotificationProvider>();
    final items = provider.items;
    if (items.isEmpty) {
      return const Center(
          child: Text('暂无社区通知', style: TextStyle(color: AppColors.textLight)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final n = items[index];
        switch (n.type) {
          case CommunityNotificationType.publish:
            return _PublishCard(n: n);
          case CommunityNotificationType.like:
            return _LikeCard(n: n);
          case CommunityNotificationType.reply:
            return _ReplyCard(n: n);
        }
      },
    );
  }
}

class _PublishCard extends StatelessWidget {
  final CommunityNotification n;
  const _PublishCard({required this.n});

  @override
  Widget build(BuildContext context) {
    // 用自定义容器绘制卡片，保证主图在卡片内左右与顶边“无留白”填充
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 顶部大图：与卡片圆角对齐，左右/顶部无留白
        ClipRRect(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              n.articleImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: const Text('图片加载失败',
                      style: TextStyle(color: AppColors.textLight))),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.articleTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('发布成功啦 · ${_formatTime(n.createdAt)}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  context.push('/hot/article', extra: {
                    'id': n.articleId,
                    'title': n.articleTitle,
                    'imageUrl': n.articleImageUrl,
                  });
                  context.read<CommunityNotificationProvider>().markAllRead();
                },
                style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 0),
                    padding: EdgeInsets.zero),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Text('立即查看', style: TextStyle(color: Color(0xFFFF7A00))),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: Color(0xFFFF7A00)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _LikeCard extends StatelessWidget {
  final CommunityNotification n;
  const _LikeCard({required this.n});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 左侧主图：与右侧内容同高，铺满上下
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 86,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 86,
                  height: 86, // 基准，FittedBox 会等比填充并覆盖
                  child: Image.network(
                    n.articleImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 86,
                        height: 86,
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textLight)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 标题
              Text(n.articleTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              // 中间具体内容
              Text(
                  '${n.fromUserName ?? '用户'} 赞了${n.likeTargetIsComment ? '你的评论' : '你的文章'}'
                  '${n.likeTargetIsComment && (n.commentText?.isNotEmpty ?? false) ? '：${n.commentText}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              // 底部：左侧头像；右侧时间 + 查看详情
              Row(children: [
                CircleAvatar(
                    radius: 11,
                    backgroundImage: (n.fromUserAvatar ?? '').isEmpty
                        ? null
                        : NetworkImage(n.fromUserAvatar!)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_formatTime(n.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight))),
                TextButton(
                  onPressed: () {
                    context.push('/hot/article', extra: {
                      'id': n.articleId,
                      'title': n.articleTitle,
                      'imageUrl': n.articleImageUrl,
                      if (n.likeTargetIsComment && (n.commentId ?? 0) > 0)
                        'scrollToCommentId': n.commentId,
                    });
                    context.read<CommunityNotificationProvider>().markAllRead();
                  },
                  style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 0),
                      padding: EdgeInsets.zero),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Text('查看详情', style: TextStyle(color: Color(0xFFFF7A00))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Color(0xFFFF7A00)),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final CommunityNotification n;
  const _ReplyCard({required this.n});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 左侧主图：与右侧内容同高，铺满上下
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 86,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: Image.network(
                    n.articleImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 86,
                        height: 86,
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textLight)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 标题
              Text(n.articleTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              // 中间：评论/回复内容
              Text(n.commentText ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              // 底部：左头像，右时间+查看详情
              Row(children: [
                CircleAvatar(
                    radius: 11,
                    backgroundImage: (n.fromUserAvatar ?? '').isEmpty
                        ? null
                        : NetworkImage(n.fromUserAvatar!)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_formatTime(n.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight))),
                TextButton(
                  onPressed: () {
                    context.push('/hot/article', extra: {
                      'id': n.articleId,
                      'title': n.articleTitle,
                      'imageUrl': n.articleImageUrl,
                      if ((n.commentId ?? 0) > 0)
                        'scrollToCommentId': n.commentId,
                    });
                    context.read<CommunityNotificationProvider>().markAllRead();
                  },
                  style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 0),
                      padding: EdgeInsets.zero),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Text('查看详情', style: TextStyle(color: Color(0xFFFF7A00))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Color(0xFFFF7A00)),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

String _formatTime(DateTime t) {
  final now = DateTime.now();
  final d = now.difference(t);
  if (d.inMinutes < 1) return '刚刚';
  if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
  if (d.inHours < 24) return '${d.inHours} 小时前';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
