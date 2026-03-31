import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../models/message.dart';
import '../services/message_service.dart';

class PinnedMessageProvider extends ChangeNotifier {
  final Map<String, List<Message>> _pinnedMessages = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Message> getPinnedMessages(String conversationId) {
    return _pinnedMessages[conversationId] ?? [];
  }

  // 加载置顶消息
  Future<void> loadPinnedMessages(String conversationId, {bool isGroup = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final messageService = MessageService();
      final currentUserId = 1; // TODO: 从AuthProvider获取当前用户ID
      final chatId = int.parse(conversationId);
      
      final pinnedMessages = await messageService.getPinnedMessages(currentUserId, chatId, isGroup);
      _pinnedMessages[conversationId] = pinnedMessages;
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载置顶消息失败: $e';
      _pinnedMessages[conversationId] = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  // 置顶消息
  Future<bool> pinMessage(String conversationId, Message message) async {
    try {
      final messageService = MessageService();
      final pinnedMessage = await messageService.pinMessage(message.id);
      
      if (pinnedMessage != null) {
        // 更新本地缓存
        final currentPinned = _pinnedMessages[conversationId] ?? [];
        _pinnedMessages[conversationId] = [pinnedMessage, ...currentPinned];
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = '置顶消息失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 取消置顶消息
  Future<bool> unpinMessage(String conversationId, String messageId) async {
    try {
      final messageService = MessageService();
      final unpinnedMessage = await messageService.unpinMessage(int.parse(messageId));
      
      if (unpinnedMessage != null) {
        // 从本地缓存中移除
        final currentPinned = _pinnedMessages[conversationId] ?? [];
        _pinnedMessages[conversationId] = currentPinned
            .where((message) => message.id.toString() != messageId)
            .toList();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = '取消置顶失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 检查消息是否已置顶
  bool isMessagePinned(String conversationId, String messageId) {
    final pinnedMessages = _pinnedMessages[conversationId] ?? [];
    return pinnedMessages.any((message) => message.id == messageId);
  }

  // 获取最新的置顶消息
  Message? getLatestPinnedMessage(String conversationId) {
    final pinnedMessages = _pinnedMessages[conversationId] ?? [];
    if (pinnedMessages.isEmpty) return null;
    
    // 按置顶时间排序，返回最新的
    final sortedMessages = pinnedMessages.toList()
      ..sort((a, b) => (b.pinnedAt ?? b.createdAt).compareTo(a.pinnedAt ?? a.createdAt));
    
    return sortedMessages.first;
  }

  // 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 生成模拟置顶消息数据
  List<Message> _generateMockPinnedMessages(String conversationId, bool isGroup) {
    final now = DateTime.now();
    return [
      Message(
        id: 1,
        senderId: isGroup ? 1 : int.tryParse(conversationId) ?? 1,
        senderName: isGroup ? '管理员' : '张三',
        groupId: isGroup ? int.parse(conversationId) : null,
        receiverId: isGroup ? null : int.parse(conversationId),
        content: isGroup 
          ? '欢迎来到本群'
            : '📅 别忘了明天下午2点的会议',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(days: 1)),
        isPinned: true,
        pinnedById: 1, // pinnedBy: 'current_user_id',
        pinnedAt: now.subtract(const Duration(hours: 6)),
      ),
      if (isGroup)
        Message(
          id: 2,
            senderId: 2,
          senderName: '李四',
          groupId: int.parse(conversationId),
          content: '📌 群公告：本群是技术交流群，请大家文明讨论，禁止发送无关内容。请遵守相关规定，共同维护良好的交流环境。',
          type: MessageType.text,
          createdAt: now.subtract(const Duration(days: 3)),
          isPinned: true,
          pinnedById: 1, // pinnedBy: 'user_123',
          pinnedAt: now.subtract(const Duration(days: 2)),
        ),
      if (isGroup)
        Message(
          id: 3,
            senderId: 3,
          senderName: '王五',
          groupId: int.parse(conversationId),
          content: '🔗 项目文档链接：https://example.com/docs',
          type: MessageType.text,
          createdAt: now.subtract(const Duration(days: 5)),
          isPinned: true,
          pinnedById: 1, // pinnedBy: 'user_456',
          pinnedAt: now.subtract(const Duration(days: 4)),
        ),
    ];
  }
}