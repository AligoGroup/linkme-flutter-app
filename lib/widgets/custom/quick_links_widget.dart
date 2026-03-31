import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/quick_link_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/quick_link.dart';
import '../../core/widgets/unified_toast.dart';

class QuickLinksWidget extends StatefulWidget {
  final String conversationId;
  final bool isGroup;

  const QuickLinksWidget({
    super.key,
    required this.conversationId,
    this.isGroup = false,
  });

  @override
  State<QuickLinksWidget> createState() => _QuickLinksWidgetState();
}

class _QuickLinksWidgetState extends State<QuickLinksWidget> {
  @override
  void initState() {
    super.initState();
    // 加载快捷链接
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        context.read<QuickLinkProvider>().loadQuickLinks(
          authProvider.user!.id,
          widget.conversationId,
          isGroup: widget.isGroup,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuickLinkProvider>(
      builder: (context, provider, _) {
        final quickLinks = provider.getQuickLinks(widget.conversationId);
        
        if (provider.isLoading) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Web端样式的快捷链接水平滚动
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: quickLinks.length + 1, // +1 for add button
                  itemBuilder: (context, index) {
                    if (index == quickLinks.length) {
                      return _buildAddLinkChip();
                    }
                    
                    final quickLink = quickLinks[index];
                    return _buildQuickLinkChip(quickLink);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickLinkChip(QuickLink quickLink) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _handleQuickLinkTap(quickLink),
        // 仅允许删除自己创建的快捷链接，避免误删他人链接（服务端通常也会校验）
        onLongPress: () => _handleQuickLinkLongPress(quickLink),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _parseColor(quickLink.color),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 链接图标
              Icon(
                Icons.link,
                size: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.8),
              ),
              
              const SizedBox(width: 4),
              
              // 链接标题
              Text(
                quickLink.title,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddLinkChip() {
    return GestureDetector(
      onTap: _showAddQuickLinkDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 14,
              color: AppColors.textSecondary,
            ),
            
            const SizedBox(width: 4),
            
            Text(
              '添加链接',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickLinkTap(QuickLink quickLink) {
    context.read<QuickLinkProvider>().openQuickLink(
      context, 
      quickLink.url, 
      title: quickLink.title,
    );
  }

  void _handleQuickLinkLongPress(QuickLink quickLink) {
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id;
    if (myId == null) return;
    if (quickLink.userId != myId) {
      context.showErrorToast('只能删除自己添加的快捷链接');
      return;
    }
    _showDeleteConfirmDialog(quickLink);
  }

  void _showAddQuickLinkDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加快捷链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '链接标题',
                hintText: '请输入链接标题',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '链接地址',
                hintText: '搜索',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => _handleAddQuickLink(
              titleController.text,
              urlController.text,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddQuickLink(String title, String url) async {
    if (title.trim().isEmpty || url.trim().isEmpty) {
      context.showErrorToast('请填写完整的标题和链接地址');
      return;
    }

    Navigator.of(context).pop();
    
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;
    
    final success = await context.read<QuickLinkProvider>().addQuickLink(
      userId: authProvider.user!.id,
      conversationId: widget.conversationId,
      title: title.trim(),
      url: url.trim(),
      isGroup: widget.isGroup,
    );

    if (mounted) {
      if (success) {
        // 再拉一次，确保与后端返回保持一致（避免偶发不同步）
        final provider = context.read<QuickLinkProvider>();
        provider.loadQuickLinks(authProvider.user!.id, widget.conversationId, isGroup: widget.isGroup);
        context.showSuccessToast('快捷链接添加成功');
      } else {
        context.showErrorToast('添加快捷链接失败');
      }
    }
  }

  void _showDeleteConfirmDialog(QuickLink quickLink) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除快捷链接'),
        content: Text('确定要删除快捷链接 "${quickLink.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => _handleDeleteQuickLink(quickLink),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteQuickLink(QuickLink quickLink) async {
    Navigator.of(context).pop();
    
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;
    
    final success = await context.read<QuickLinkProvider>().deleteQuickLink(
      authProvider.user!.id,
      widget.conversationId,
      quickLink.id,
    );

    if (mounted) {
      if (success) {
        context.showSuccessToast('快捷链接删除成功');
      } else {
        context.showErrorToast('删除快捷链接失败');
      }
    }
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return AppColors.primaryLight.withValues(alpha: 0.1);
    }
    
    try {
      // 移除 # 号并添加完整的透明度
      String cleanColor = colorString.replaceAll('#', '');
      if (cleanColor.length == 6) {
        cleanColor = 'FF$cleanColor';
      }
      
      return Color(int.parse(cleanColor, radix: 16)).withValues(alpha: 0.15);
    } catch (e) {
      return AppColors.primaryLight.withValues(alpha: 0.1);
    }
  }
}
