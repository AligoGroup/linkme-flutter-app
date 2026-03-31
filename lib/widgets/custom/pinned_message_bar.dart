import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/pinned_message_provider.dart';
import '../../shared/models/message.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/models/conversation.dart';

class PinnedMessageBar extends StatefulWidget {
  final String conversationId;
  final bool isGroup;
  final String? groupName; // 群名称，用于显示在卡片上
  final VoidCallback? onTap;

  const PinnedMessageBar({
    super.key,
    required this.conversationId,
    this.isGroup = false,
    this.groupName,
    this.onTap,
  });

  @override
  State<PinnedMessageBar> createState() => _PinnedMessageBarState();
}

class _PinnedMessageBarState extends State<PinnedMessageBar> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late PageController _pageController;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    // 置顶消息会由父组件ChatDetailScreen统一加载
  }

  @override
  void dispose() {
    _pageController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PinnedMessageProvider>(
      builder: (context, provider, _) {
        final pinnedMessages = provider.getPinnedMessages(widget.conversationId);
        
        if (pinnedMessages.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // 与快捷链接间距3px
              const SizedBox(height: 3),
              
              // 置顶消息卡片容器
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                  ),
                  child: _buildPinnedMessageCards(pinnedMessages),
                ),
              ),
              
              // 展开/收起按钮（在卡片下方）
              _buildExpandToggleButton(pinnedMessages),
            ],
          ),
        );
      },
    );
  }

  // 构建置顶消息卡片列表
  Widget _buildPinnedMessageCards(List<Message> pinnedMessages) {
    if (pinnedMessages.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120, // 固定高度
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          // 页面切换处理（如需要可在此添加逻辑）
        },
        itemCount: pinnedMessages.length,
        itemBuilder: (context, index) {
          final message = pinnedMessages[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildPinnedMessageCard(message, index),
          );
        },
      ),
    );
  }

  // 构建单个置顶消息卡片（按需求重新设计）
  Widget _buildPinnedMessageCard(Message message, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片顶部 - 群名和删除按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // 群名显示在左上角
                Expanded(
                  child: Text(
                    _getConversationDisplayName(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // 删除按钮显示在右上角
                GestureDetector(
                  onTap: () => _deletePinnedMessage(message),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 卡片主体 - 消息内容
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildMessageContentPreview(message),
            ),
          ),
          
          // 卡片底部 - 置顶者信息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '由 ${_resolvePinnedByDisplayName(message)} 置顶',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textLight,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 构建消息内容预览
  Widget _buildMessageContentPreview(Message message) {
    // 检测是否为URL链接
    final isUrl = _isValidUrl(message.content);
    
    if (isUrl) {
      return _buildUrlPreview(message.content);
    } else {
      return _buildTextPreview(message.content);
    }
  }

  // 构建URL预览（类似web端的链接卡片）
  Widget _buildUrlPreview(String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // URL链接
        Text(
          url,
          style: AppTextStyles.body2.copyWith(
            color: AppColors.primary,
            fontSize: 13,
            decoration: TextDecoration.underline,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // 无效日期提示（模拟web端的"Invalid Date"）
        Text(
          'Invalid Date',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textLight,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // 构建文本预览
  Widget _buildTextPreview(String content) {
    return Text(
      content,
      style: AppTextStyles.body2.copyWith(
        color: AppColors.textPrimary,
        fontSize: 13,
        height: 1.4,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  // 获取对话显示名称
  String _getConversationDisplayName() {
    if (widget.isGroup && widget.groupName != null) {
      return '${widget.groupName} 群聊';
    } else if (widget.isGroup) {
      return '群聊';
    } else {
      return '私聊';
    }
  }

  // 构建展开/收起按钮（纯图标，无背景）
  Widget _buildExpandToggleButton(List<Message> pinnedMessages) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
        
        if (_isExpanded) {
          _expandController.forward();
        } else {
          _expandController.reverse();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          size: 20,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // 删除置顶消息
  Future<void> _deletePinnedMessage(Message message) async {
    final pinnedProvider = context.read<PinnedMessageProvider>();
    final success = await pinnedProvider.unpinMessage(widget.conversationId, message.id.toString());
    
    if (mounted) {
      if (success) {
        context.showSuccessToast('已取消置顶');
        // 通知父组件更新消息状态
        if (widget.onTap != null) {
          widget.onTap!();
        }
      } else {
        context.showErrorToast('取消置顶失败');
      }
    }
  }

  // 检测是否为有效URL
  bool _isValidUrl(String content) {
    return content.toLowerCase().startsWith('http://') || 
           content.toLowerCase().startsWith('https://') ||
           content.toLowerCase().contains('.com') ||
           content.toLowerCase().contains('.cn') ||
           content.toLowerCase().contains('.org');
  }

  String _resolvePinnedByDisplayName(Message message) {
    final pinnedById = message.pinnedById;
    if (pinnedById == null) {
      return message.senderName;
    }

    try {
      final auth = context.read<AuthProvider>();
      final me = auth.user;
      if (me != null && me.id == pinnedById) {
        final nickname = me.nickname;
        if (nickname != null && nickname.isNotEmpty) {
          return nickname;
        }
        if (me.username.isNotEmpty) {
          return me.username;
        }
      }
    } catch (_) {
      // ignore and fallback to other sources
    }

    final conversation = _findConversation();
    if (conversation != null) {
      for (final participant in conversation.participants) {
        if (participant.id == pinnedById) {
          final nickname = participant.nickname;
          if (nickname != null && nickname.isNotEmpty) {
            return nickname;
          }
          if (participant.username.isNotEmpty) {
            return participant.username;
          }
        }
      }
    }

    return widget.isGroup ? '群成员' : '对方';
  }

  Conversation? _findConversation() {
    try {
      final chatProvider = context.read<ChatProvider>();
      return chatProvider.conversationList
          .firstWhere((conv) => conv.id == widget.conversationId);
    } catch (_) {
      return null;
    }
  }
}

class PinnedMessagesBottomSheet extends StatelessWidget {
  final String conversationId;
  final List<Message> pinnedMessages;

  const PinnedMessagesBottomSheet({
    super.key,
    required this.conversationId,
    required this.pinnedMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部拖拽条
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  color: AppColors.primary,
                  size: 20,
                ),
                
                const SizedBox(width: 8),
                
                Text(
                  '置顶消息 (${pinnedMessages.length})',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const Spacer(),
                
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // 置顶消息列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: pinnedMessages.length,
              itemBuilder: (context, index) {
                final message = pinnedMessages[index];
                return _buildPinnedMessageItem(context, message);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageItem(BuildContext context, Message message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 消息头部信息
          Row(
            children: [
              Text(
                message.senderName,
                style: AppTextStyles.friendName.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(width: 8),
              
              Text(
                _formatTime(message.createdAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textLight,
                ),
              ),
              
              const Spacer(),
              
              // 取消置顶按钮
              GestureDetector(
                onTap: () => _unpinMessage(context, message),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.push_pin_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 消息内容
          Text(
            message.content,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unpinMessage(BuildContext context, Message message) async {
    final provider = context.read<PinnedMessageProvider>();
    final success = await provider.unpinMessage(conversationId, message.id.toString());
    
    if (context.mounted) {
      if (success) {
        context.showSuccessToast('已取消置顶');
      } else {
        context.showErrorToast('取消置顶失败');
      }
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return '${timestamp.month}月${timestamp.day}日 ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
