import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/chat_provider.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群聊'),
        actions: [
          TextButton(
            onPressed: () => context.push('/create-group'),
            child: const Text('创建'),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chat, _) {
          final groups = chat.groups;
          if (groups.isEmpty) {
            return const Center(child: Text('暂无群聊'));
          }
          return ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final g = groups[index];
              final name = g['name'] ?? g['groupName'] ?? '未命名群聊';
              final avatar = g['avatar'] as String?;
              final id = g['id'].toString();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surface,
                  backgroundImage: (avatar != null &&
                          avatar.isNotEmpty &&
                          !avatar.startsWith('GROUP_AVATAR:'))
                      ? NetworkImage(avatar)
                      : null,
                  child: (avatar == null || avatar.startsWith('GROUP_AVATAR:'))
                      ? const Icon(Icons.group)
                      : null,
                ),
                title: Text(name, style: AppTextStyles.body1),
                subtitle: Text('ID: $id', style: AppTextStyles.caption),
                onTap: () {
                  // 进入群聊对话
                  context.push('/chat/$id?type=group');
                },
                onLongPress: () {
                  // 查看群信息
                  context.push('/group-info/$id');
                },
              );
            },
          );
        },
      ),
    );
  }
}
