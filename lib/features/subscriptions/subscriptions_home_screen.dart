import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/subscription_provider.dart';
import '../../widgets/common/official_badge.dart';
import '../../core/theme/app_colors.dart';
import 'channel_article_list_screen.dart';

class SubscriptionsHomeScreen extends StatelessWidget {
  const SubscriptionsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    // 首次进入时拉取频道列表
    // 不改变现有布局，仅触发一次数据加载
    // ignore: unused_local_variable
    final _ = (() { provider.initialize(); return 0; })();
    return Scaffold(
      appBar: AppBar(title: const Text('订阅号')),
      // 移动端：保留 AppBar 上的标题，列表内部不再重复显示一级标题
      body: _SubscriptionsHomeView(
        onOpenChannel: (id) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChannelArticleListScreen(channelId: id)),
          );
        },
        showHeader: false,
      ),
    );
  }
}

// 提供给桌面端右侧面板的嵌入式视图
class SubscriptionsHomeView extends StatelessWidget {
  final void Function(String channelId) onOpenChannel;
  final bool showHeader; // 嵌入桌面右侧面板时需要内部标题
  const SubscriptionsHomeView({super.key, required this.onOpenChannel, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    // 进入嵌入视图也确保数据已加载
    final sp = context.watch<SubscriptionProvider>();
    sp.initialize();
    return _SubscriptionsHomeView(onOpenChannel: onOpenChannel, showHeader: showHeader);
  }
}

class _SubscriptionsHomeView extends StatelessWidget {
  final void Function(String channelId) onOpenChannel;
  final bool showHeader;
  const _SubscriptionsHomeView({required this.onOpenChannel, required this.showHeader});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final list = provider.channels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部标题（仅在嵌入桌面右侧面板时显示）
        if (showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEDEDED), width: 1)),
            ),
            child: const Text('订阅号', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        Expanded(
          child: Scrollbar(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final c = list[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(c.name.substring(0, 1), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Row(children: [
                    Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (c.official) const SizedBox(width: 6),
                    if (c.official) const OfficialBadge(size: 14),
                  ]),
                  subtitle: Text(c.description ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => onOpenChannel(c.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
