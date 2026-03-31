import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/linkme_material.dart';
import '../../widgets/custom/user_avatar.dart';
import '../../shared/providers/chat_provider.dart';
import '../../core/widgets/unified_toast.dart';
import 'note_list_screen.dart';
import 'providers/notes_provider.dart';

class NotesHomeScreen extends StatefulWidget {
  const NotesHomeScreen({super.key});

  @override
  State<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends State<NotesHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// notes_home_screen.dart | _NotesHomeScreenState | _showCreateNotebookSheet | initialVisibility
  void _showCreateNotebookSheet(NotebookVisibility initialVisibility) {
    final NotesProvider provider = context.read<NotesProvider>();
    final TextEditingController controller = TextEditingController();
    NotebookVisibility current = initialVisibility;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E3EE),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '新建笔记本',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: NotebookVisibility.values
                          .map((NotebookVisibility value) {
                        final bool selected = current == value;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              current = value;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    value == NotebookVisibility.private
                                        ? Icons.lock
                                        : Icons.people_outline,
                                    size: 18,
                                    color: selected
                                        ? Colors.black
                                        : Colors.black54,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    value == NotebookVisibility.private
                                        ? '私人'
                                        : '共享',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: selected
                                          ? Colors.black
                                          : Colors.black54,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      hintText: '例如：旅行计划',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(sheetContext).maybePop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            provider.addNotebook(controller.text, current);
                            Navigator.of(sheetContext).maybePop();
                          },
                          child: const Text('创建'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showInviteMemberSheet(Notebook notebook) {
    final chatProvider = context.read<ChatProvider>();
    final notesProvider = context.read<NotesProvider>();
    final friends = chatProvider.friends;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E3EE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '邀请协作者',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: friends.isEmpty
                      ? const Center(child: Text('暂无好友可邀请'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            return ListTile(
                              leading: UserAvatar(
                                imageUrl: friend.avatar,
                                name: friend.nickname ?? friend.username,
                                size: 40,
                              ),
                              title: Text(friend.nickname ?? friend.username),
                              trailing: TextButton(
                                onPressed: () async {
                                  final success =
                                      await notesProvider.inviteCollaborator(
                                    notebook.id,
                                    friend.id,
                                  );
                                  if (success) {
                                    if (mounted) {
                                      Navigator.pop(context);
                                      UnifiedToast.showSuccess(
                                          context, '邀请已发送');
                                    }
                                  } else {
                                    if (mounted) {
                                      UnifiedToast.showError(context, '邀请失败');
                                    }
                                  }
                                },
                                child: const Text('邀请'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// notes_home_screen.dart | _NotesHomeScreenState | _showPermissionSheet | notebook
  void _showPermissionSheet(Notebook notebook) {
    final NotesProvider provider = context.read<NotesProvider>();
    final bool isShared = notebook.visibility == NotebookVisibility.shared;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E3EE),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '笔记本权限',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetContext).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isShared
                          ? const Color(0xFFE0F7F2)
                          : const Color(0xFFE9ECF8),
                      child: Icon(
                        isShared ? Icons.public : Icons.lock,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isShared ? '共享笔记本' : '私人笔记本',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isShared ? '获得授权的用户均可查看和编辑。' : '仅您可见并编辑此笔记本。',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isShared ? AppColors.primary : Colors.black,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    provider.setNotebookVisibility(
                      notebook.id,
                      isShared
                          ? NotebookVisibility.private
                          : NotebookVisibility.shared,
                    );
                    Navigator.of(sheetContext).maybePop();
                  },
                  child: Text(
                    isShared ? '切换为私人' : '切换为共享',
                    style: TextStyle(
                      color: isShared ? AppColors.primary : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (isShared) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '协作者',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '共 ${notebook.collaborators.length} 人',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 显示所有协作者，所有者排在最前面
                ...() {
                  // 先按角色排序，所有者在前
                  final sortedCollaborators = notebook.collaborators.toList()
                    ..sort((a, b) {
                      if (a.role == 'OWNER' && b.role != 'OWNER') return -1;
                      if (a.role != 'OWNER' && b.role == 'OWNER') return 1;
                      return 0;
                    });

                  return sortedCollaborators.map((collaborator) {
                    final roleText =
                        collaborator.role == 'OWNER' ? '所有者' : '编辑者';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CollaboratorTile(
                        name: collaborator.nickname,
                        role: roleText,
                        avatarUrl: collaborator.avatar,
                        isOwner: collaborator.role == 'OWNER',
                      ),
                    );
                  });
                }(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext); // 关闭当前sheet
                    _showInviteMemberSheet(notebook); // 打开邀请sheet
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFE3E6ED), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person_add_alt_1_outlined,
                            color: Colors.black54),
                        SizedBox(width: 6),
                        Text('邀请成员', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    provider.deleteNotebook(notebook.id);
                    Navigator.of(sheetContext).maybePop();
                  },
                  child: const Text('永久删除笔记本'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider provider = context.watch<NotesProvider>();
    final List<Notebook> privateBooks =
        provider.notebooksByType(NotebookVisibility.private);
    final List<Notebook> sharedBooks =
        provider.notebooksByType(NotebookVisibility.shared);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSearchField(),
              const SizedBox(height: 28),
              _buildSectionHeader(
                icon: Icons.lock,
                title: '私人空间',
                actionColor: Colors.black,
                onAdd: () =>
                    _showCreateNotebookSheet(NotebookVisibility.private),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  const double spacing = 16;
                  final double cardWidth = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: privateBooks
                        .map(
                          (Notebook notebook) => SizedBox(
                            width: cardWidth,
                            child: _NotebookCard(
                              notebook: notebook,
                              noteCount: notebook.noteCount,
                              onOpen: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        NoteListScreen(notebook: notebook),
                                  ),
                                );
                              },
                              onOptions: () => _showPermissionSheet(notebook),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(
                icon: Icons.people_outline,
                title: '共享空间',
                actionColor: AppColors.primary,
                onAdd: () =>
                    _showCreateNotebookSheet(NotebookVisibility.shared),
              ),
              const SizedBox(height: 12),
              ...sharedBooks.map(
                (Notebook notebook) => _SharedNotebookTile(
                  notebook: notebook,
                  badgeColor: const Color(0xFFEFF7F3),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteListScreen(notebook: notebook),
                      ),
                    );
                  },
                  onMore: () => _showPermissionSheet(notebook),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            text: 'ZenNotes',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4D73FF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, color: Colors.black38, size: 18),
          ),
          hintText: '搜索...',
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color actionColor,
    required VoidCallback onAdd,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.black54, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: onAdd,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: actionColor,
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}

class _NotebookCard extends StatelessWidget {
  const _NotebookCard({
    required this.notebook,
    required this.noteCount,
    required this.onOpen,
    required this.onOptions,
  });

  final Notebook notebook;
  final int noteCount;
  final VoidCallback onOpen;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              notebook.startColor.withOpacity(0.15),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 18,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: notebook.startColor,
                  child:
                      const Icon(Icons.menu_book_outlined, color: Colors.white),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_horiz, color: Colors.black54),
                  onPressed: onOptions,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              notebook.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$noteCount 条笔记',
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedNotebookTile extends StatelessWidget {
  const _SharedNotebookTile({
    required this.notebook,
    required this.badgeColor,
    required this.onTap,
    required this.onMore,
  });

  final Notebook notebook;
  final Color badgeColor;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: badgeColor,
            child: Icon(Icons.public, color: notebook.startColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notebook.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F5FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '共享',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2B69FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._buildCollaborators(),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: onMore,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  /// notes_home_screen.dart | _SharedNotebookTile | _buildCollaborators | 构建协作者头像列表（显示前5个真实用户头像）
  List<Widget> _buildCollaborators() {
    final List<Widget> avatars = <Widget>[];

    // 如果没有协作者，返回空列表
    if (notebook.collaborators.isEmpty) {
      return avatars;
    }

    // 限制显示最多5个协作者头像
    final int maxDisplay =
        notebook.collaborators.length > 5 ? 5 : notebook.collaborators.length;

    for (int i = 0; i < maxDisplay; i++) {
      final collaborator = notebook.collaborators[i];
      avatars.add(Container(
        margin: EdgeInsets.only(left: i == 0 ? 0 : -8),
        child: UserAvatar(
          imageUrl: collaborator.avatar,
          name: collaborator.nickname,
          size: 24,
          borderColor: Colors.white,
          borderWidth: 1.5,
        ),
      ));
    }

    // 如果协作者超过5个，显示 +N 提示
    if (notebook.collaborators.length > 5) {
      avatars.add(Container(
        margin: const EdgeInsets.only(left: -8),
        child: CircleAvatar(
          radius: 12,
          backgroundColor: Colors.grey[400],
          child: Text(
            '+${notebook.collaborators.length - 5}',
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
      ));
    }

    return avatars;
  }
}

/// notes_home_screen.dart | _CollaboratorTile | 协作者信息展示组件
class _CollaboratorTile extends StatelessWidget {
  const _CollaboratorTile({
    required this.name,
    required this.role,
    this.avatarUrl,
    this.isOwner = false,
  });

  final String name;
  final String role;
  final String? avatarUrl;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isOwner ? const Color(0xFFFFF9E6) : const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
        border: isOwner
            ? Border.all(color: const Color(0xFFFFD700), width: 1)
            : null,
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: avatarUrl,
            name: name,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOwner ? const Color(0xFFFF9800) : Colors.black54,
                    fontWeight: isOwner ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isOwner ? Icons.star : Icons.verified,
            color: isOwner ? const Color(0xFFFFD700) : const Color(0xFF2B69FF),
          ),
        ],
      ),
    );
  }
}
