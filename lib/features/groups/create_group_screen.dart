import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../widgets/common/linkme_loader.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/user.dart';
// import removed: used AppBar TextButton instead of custom LoadingButton

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<User> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群聊'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                    width: 26,
                    height: 18,
                    child: Center(child: LinkMeLoader(fontSize: 12, compact: true)),
                  )
                : const Text('创建'),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 群聊头像
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 40,
                      color: AppColors.textLight,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 群聊名称
            TextFormField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: '群聊名称',
                hintText: '请输入群聊名称',
                prefixIcon: Icon(Icons.group),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入群聊名称';
                }
                if (value.trim().length < 2) {
                  return '群聊名称至少2个字符';
                }
                if (value.trim().length > 20) {
                  return '群聊名称不能超过20个字符';
                }
                return null;
              },
              maxLength: 20,
            ),
            
            const SizedBox(height: 16),
            
            // 群聊描述
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '群聊描述',
                hintText: '请输入群聊描述（可选）',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              maxLength: 100,
              validator: (value) {
                if (value != null && value.trim().length > 100) {
                  return '群聊描述不能超过100个字符';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // 选择成员
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('选择成员'),
                    subtitle: Text('已选择 ${_selectedMembers.length} 人'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _selectMembers,
                  ),
                  if (_selectedMembers.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedMembers.map((member) {
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundImage: member.avatar != null 
                                ? NetworkImage(member.avatar!) 
                                : null,
                              child: member.avatar == null 
                                ? Text(member.nickname?.substring(0, 1) ?? member.username.substring(0, 1))
                                : null,
                            ),
                            label: Text(member.nickname ?? member.username),
                            onDeleted: () {
                              setState(() {
                                _selectedMembers.remove(member);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 创建说明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '创建群聊说明',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 群聊创建后您将成为群主\n• 群主可以管理群成员和群信息\n• 所有成员都可以发送消息\n• 群聊最多支持100人',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // 选择成员
  void _selectMembers() async {
    final chatProvider = context.read<ChatProvider>();
    final friends = chatProvider.friends;
    
    if (friends.isEmpty) {
      context.showErrorToast('暂无好友可添加');
      return;
    }
    
    final selectedMembers = await showDialog<List<User>>(
      context: context,
      builder: (context) => _MemberSelectionDialog(
        friends: friends,
        selectedMembers: _selectedMembers,
      ),
    );
    
    if (selectedMembers != null) {
      setState(() {
        _selectedMembers = selectedMembers;
      });
    }
  }

  // 创建群聊
  void _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedMembers.isEmpty) {
      context.showErrorToast('请至少选择一个成员');
      return;
    }
    
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    
    if (authProvider.user == null) {
      context.showErrorToast('用户信息异常，请重新登录');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final memberIds = _selectedMembers.map((member) => member.id).toList();
      
      final result = await chatProvider.createGroup(
        groupName: _groupNameController.text.trim(),
        description: _descriptionController.text.trim(),
        memberIds: memberIds,
        creatorId: authProvider.user!.id,
      );
      
      if (result != null) {
        context.showSuccessToast('群聊创建成功');
        
        // 返回主页并刷新会话列表
        if (mounted) {
          context.go('/');
          // 可在此直接进入新创建的群聊:
          // final newId = result['id'];
          // context.go('/chat/' + newId.toString() + '?type=group');
        }
      } else {
        context.showErrorToast(chatProvider.errorMessage ?? '创建群聊失败');
      }
    } catch (e) {
      context.showErrorToast('创建群聊失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// 成员选择对话框
class _MemberSelectionDialog extends StatefulWidget {
  final List<User> friends;
  final List<User> selectedMembers;

  const _MemberSelectionDialog({
    required this.friends,
    required this.selectedMembers,
  });

  @override
  State<_MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<_MemberSelectionDialog> {
  late List<User> _selectedMembers;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMembers = List.from(widget.selectedMembers);
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = widget.friends.where((friend) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return (friend.nickname?.toLowerCase().contains(query) ?? false) ||
             friend.username.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('选择群成员'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // 搜索框
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索好友',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // 已选择的成员数量
            if (_selectedMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '已选择 ${_selectedMembers.length} 人',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            
            // 好友列表
            Expanded(
              child: ListView.builder(
                itemCount: filteredFriends.length,
                itemBuilder: (context, index) {
                  final friend = filteredFriends[index];
                  final isSelected = _selectedMembers.contains(friend);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedMembers.add(friend);
                        } else {
                          _selectedMembers.remove(friend);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: friend.avatar != null 
                            ? NetworkImage(friend.avatar!) 
                            : null,
                          child: friend.avatar == null 
                            ? Text(friend.nickname?.substring(0, 1) ?? friend.username.substring(0, 1))
                            : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friend.nickname ?? friend.username),
                              if (friend.nickname != null)
                                Text(
                                  friend.username,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedMembers),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
