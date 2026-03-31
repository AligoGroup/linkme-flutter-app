import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../../core/network/websocket_manager.dart';
import '../services/friendship_service.dart';
import '../services/message_service.dart';
import '../services/emotion_service.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import '../models/user_emotion_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linkme_flutter/shared/models/chat_search_result.dart';
import '../../core/network/network_manager.dart';
import '../../core/network/server_health.dart';
import 'dart:convert';
import 'dart:async';

class ChatProvider extends ChangeNotifier {
  static const String _snapshotKeyPrefix = 'chat_snapshot_v1_u_';
  static const int _maxCachedMessages = 60;

  final WebSocketManager _wsManager = WebSocketManager();
  final FriendshipService _friendshipService = FriendshipService();
  final MessageService _messageService = MessageService();
  final EmotionService _emotionService = EmotionService();
  final GroupService _groupService = GroupService();
  final NotificationService _notificationService = NotificationService();
  bool _isConnected = false;
  bool _initialized = false; // 防止重复初始化导致数据重复
  int? _selfUserId; // 当前登录用户ID，用于会话归属与未读计算
  final Map<String, DateTime> _lastReadAt = {}; // 本地最后已读时间，用于离线计算未读
  // 本地持久化的置顶会话ID集合（字符串）
  Set<String> _pinnedConvIds = <String>{};

  // 最近通过WebSocket接收到的消息（用于防止刷新时丢失）
  final Map<String, Message> _recentWebSocketMessages = {};

  // Friends and contacts
  List<User> _friends = [];
  List<dynamic> _groups = []; // 临时使用 dynamic，后续创建 Group 模型
  Map<String, bool> _userOnlineStatus = {};
  Set<int> _blockedUserIds = <int>{};

  // Conversations
  List<Conversation> _conversationList = [];
  Map<String, List<Message>> _conversations =
      {}; // key: contactId, value: messages
  List<Message> _pinnedMessages = [];

  // UI State
  bool _isLoading = false;
  String? _errorMessage;
  int _pendingRequestsCount = 0;

  // Getters
  List<User> get friends => _friends;
  List<dynamic> get groups => _groups;
  Map<String, bool> get userOnlineStatus => _userOnlineStatus;
  List<Conversation> get conversationList =>
      List.unmodifiable(_conversationList);
  Map<String, List<Message>> get conversations => _conversations;
  List<Message> get pinnedMessages => _pinnedMessages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get pendingRequestsCount => _pendingRequestsCount;
  bool get isConnected => _isConnected;
  bool get isInitialized => _initialized;
  bool isFriendBlocked(int friendId) => _blockedUserIds.contains(friendId);
  bool isConversationBlocked(String conversationId) {
    final id = int.tryParse(conversationId);
    if (id == null) return false;
    return _blockedUserIds.contains(id);
  }

  // 暴露某会话的最后已读时间（用于“新消息顶部”定位）
  DateTime? lastReadAt(String conversationId) => _lastReadAt[conversationId];

  // 仅在首次需要时初始化（加载好友、消息并连接WS）
  Future<void> initializeIfNeeded(int userId, String token) async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _selfUserId = userId;
    try {
      await _notificationService.initialize();
      await _loadCachedSnapshot(userId);
      await _loadPinnedConversations(userId);
      await _loadLastReadAt(userId);
      await fetchBlockedFriends(userId);
      await fetchFriends(userId);
      await fetchGroups(userId); // 先加载群列表，后续构建会话需要
      await fetchMessages(userId);
      await connectWebSocket(userId, token);
    } catch (e) {
      // 若失败，不回滚已加载的数据，避免循环初始化
      print('❌ ChatProvider.initializeIfNeeded 失败: $e');
    }
  }

  // 在列表中查找与 target 相同或“近似”的消息：
  // - 优先按 id 完全相等
  // - 否则按 senderId + 内容完全相同 + 时间差 <= 3 秒 + 同会话 近似匹配
  int _indexOfSameOrSimilar(List<Message> list, Message target) {
    // 列表已按会话分组，因此不必再检查会话；同时兼容 API/WS 字段差异
    // 1) 按 id 精确匹配
    for (int i = list.length - 1; i >= 0; i--) {
      if (list[i].id == target.id) return i;
    }
    // 2) 近似匹配：同 sender + 内容相同 + 时间差 <= 600s（放宽以避免 HTTP/WS 回推时间戳不一致导致的重复）
    final norm = (target.content).trim();
    for (int i = list.length - 1; i >= 0; i--) {
      final m = list[i];
      if (m.senderId != target.senderId) continue;
      if (m.content.trim() != norm) continue;
      final dt = m.createdAt.difference(target.createdAt).inSeconds.abs();
      if (dt <= 600) return i;
    }
    return -1;
  }

  // 获取置顶会话
  List<Conversation> get pinnedConversations =>
      _conversationList.where((c) => c.isPinned).toList();

  // 获取普通会话
  List<Conversation> get normalConversations =>
      _conversationList.where((c) => !c.isPinned).toList();

  // 获取总未读数
  int get totalUnreadCount => _conversationList.fold(
      0, (sum, conversation) => sum + conversation.unreadCount);

  // Get all contacts (friends + groups)
  List<dynamic> get allContacts {
    final contacts = <dynamic>[];
    contacts.addAll(_friends.map((f) => {'type': 'user', ...f.toJson()}));
    contacts.addAll(_groups.map((g) => {'type': 'group', ...g}));
    return contacts;
  }

  // WebSocket Connection
  Future<void> connectWebSocket(int userId, String token) async {
    try {
      await _wsManager.connect(userId.toString(), token);

      // 监听WebSocket状态变化
      _wsManager.statusStream.listen((status) {
        _isConnected = status == WebSocketStatus.connected;
        notifyListeners();
      });

      // 监听WebSocket消息
      _wsManager.messageStream.listen((message) {
        _handleWebSocketMessage(message);
      });

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'WebSocket连接失败: $e';
      notifyListeners();
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    try {
      final messageType = data['type'];

      switch (messageType) {
        case 'CHAT_MESSAGE':
          _handleNewChatMessage(data);
          break;
        case 'PRIVATE_MESSAGE':
        case 'GROUP_MESSAGE':
          _handleNewChatMessage(data);
          break;
        case 'MESSAGE_RECALLED':
          final int id = (data['messageId'] as num).toInt();
          // 从所有会话中移除该消息
          _conversations.forEach((k, v) => v.removeWhere((m) => m.id == id));
          // 如果有会话的 lastMessage 是它，重算
          for (var i = 0; i < _conversationList.length; i++) {
            if (_conversationList[i].lastMessage?.id == id) {
              final list = _conversations[_conversationList[i].id] ?? [];
              final newLast = list.isNotEmpty ? list.last : null;
              _conversationList[i] = _conversationList[i].copyWith(
                lastMessage: newLast,
                lastActivity:
                    newLast?.createdAt ?? _conversationList[i].lastActivity,
              );
            }
          }
          break;
        case 'USER_STATUS_CHANGE':
          _handleUserStatusChange(data);
          break;
        case 'FRIEND_REQUEST':
          _handleFriendRequest(data);
          break;
        case 'FRIEND_REQUEST_ACCEPTED':
          _handleFriendRequestAccepted(data);
          break;
        case 'ZENNOTES_INVITATION':
          _handleZenNotesInvitation(data);
          break;
        case 'ONLINE_FRIENDS_LIST':
          _handleOnlineFriendsList(data);
          break;
        default:
          print('未处理的WebSocket消息类型: $messageType');
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = '解析WebSocket消息失败: $e';
      notifyListeners();
    }
  }

  void _handleNewChatMessage(Map<String, dynamic> data) {
    // 处理新的聊天消息
    try {
      // 统一解析消息ID：优先 id，其次 messageId，再次 msgId，最后兜底时间戳
      final dynamicId =
          data['id'] ?? data['messageId'] ?? data['msgId'] ?? data['mid'];
      final parsedId = (dynamicId is num)
          ? dynamicId.toInt()
          : int.tryParse(dynamicId?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch;

      // 解析发送者信息：优先从 sender 对象中提取，回退到单独字段
      int senderId = data['senderId'] ?? 0;
      String senderName = '未知用户';
      String? senderAvatar;

      if (data['sender'] is Map<String, dynamic>) {
        final sender = data['sender'] as Map<String, dynamic>;
        senderId = (sender['id'] as num?)?.toInt() ?? senderId;
        senderName = sender['nickname'] ?? sender['username'] ?? '未知用户';
        senderAvatar = sender['avatar'];
      } else if (data['senderName'] != null) {
        senderName = data['senderName'];
        senderAvatar = data['senderAvatar'];
      }

      final base = Message(
        id: parsedId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        receiverId: data['receiverId'],
        content: data['content'] ?? '',
        type:
            _parseMessageType(data['messageType'] ?? (data['type'] ?? 'TEXT')),
        createdAt: (data['createdAt'] != null)
            ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(
                data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
        groupId: (data['groupId'] as num?)?.toInt(),
        // shared/providers/chat_provider.dart | _handleNewChatMessage | 通话卡片字段解析
        // 作用：从WebSocket消息中解析通话卡片相关字段
        callRoomUuid: data['callRoomUuid'] as String?,
        callType: data['callType'] as String?,
        callResult: data['callResult'] as String?,
        callDurationSeconds: (data['callDurationSeconds'] as num?)?.toInt(),
      );
      Message toAdd = base;
      if (data['replyTo'] is Map<String, dynamic>) {
        final r = data['replyTo'] as Map<String, dynamic>;
        final rs = r['sender'] as Map<String, dynamic>?;
        toAdd = base.copyWith(
          replyToMessageId: (r['id'] as num?)?.toInt(),
          replyToSenderId: rs != null
              ? (rs['id'] as num?)?.toInt()
              : (r['senderId'] as num?)?.toInt(),
          replyToSenderName:
              rs != null ? (rs['nickname'] ?? rs['username']) : r['senderName'],
          replyToPreview: r['content'] as String?,
          replyToCreatedAt: r['createdAt'] != null
              ? DateTime.tryParse(r['createdAt'].toString())
              : null,
        );
      }
      // 计算会话ID（对私聊必须是“对方ID”，不能是当前用户ID）
      final String convId;
      if (toAdd.groupId != null) {
        convId = toAdd.groupId!.toString();
      } else {
        final me = _selfUserId;
        if (me != null) {
          convId = (toAdd.senderId == me
                  ? toAdd.receiverId ?? toAdd.senderId
                  : toAdd.senderId)
              .toString();
        } else {
          // 无法判定当前用户，尽量不要归到自己
          convId = (toAdd.receiverId ?? toAdd.senderId).toString();
        }
      }

      // 写入内存缓存
      _recentWebSocketMessages[convId] = toAdd;
      // 强类型获取并回写，避免被推断为 List<Message?>
      final List<Message> list = _conversations[convId] ?? <Message>[];
      _conversations[convId] = list;
      // 去重：先按ID，再按“近似”（同sender、同内容、时间差<=3秒）
      int idx = _indexOfSameOrSimilar(list, toAdd);
      if (idx == -1) {
        list.add(toAdd);
      } else {
        list[idx] = toAdd;
      }
      // 仅对"来自对方"的消息累计未读
      final isIncoming =
          _selfUserId == null ? true : toAdd.senderId != _selfUserId;
      _updateConversationWithNewMessage(toAdd,
          conversationId: convId, isIncoming: isIncoming);

      print('收到新消息: ${toAdd.content}');

      // 如果是来自对方的消息，更新徽章和发送通知
      if (isIncoming) {
        // 更新应用图标徽章
        _notificationService.updateBadgeCount(totalUnreadCount);

        // 仅在Android端显示通知
        _notificationService.showMessageNotification(
          title: toAdd.senderName,
          body: toAdd.content,
          payload: convId,
        );
      }
    } catch (e) {
      print('处理新消息失败: $e');
    }
  }

  void _handleUserStatusChange(Map<String, dynamic> data) {
    final userId = data['userId'].toString();
    final status = data['status'];

    _userOnlineStatus[userId] = status == 'ONLINE';
    print('用户 $userId 状态变更为: $status');
  }

  void _handleFriendRequest(Map<String, dynamic> data) {
    // 处理好友请求
    print('收到好友请求: ${data['senderName']}');
    // 这里可以显示通知或更新好友请求列表
  }

  void _handleFriendRequestAccepted(Map<String, dynamic> data) {
    // 处理好友请求被接受
    print('好友请求被接受: ${data['accepterName']}');
    // 这里可以刷新好友列表
  }

  void _handleZenNotesInvitation(Map<String, dynamic> data) {
    print('收到ZenNotes邀请: ${data['notebookTitle']}');
    
    final notebookTitle = data['notebookTitle'];
    final inviterName = data['inviterName'];
    final inviterAvatar = data['inviterAvatar'];
    final notebookId = data['notebookId'];
    final timestamp = data['timestamp'];
    
    // 构造系统通知消息内容
    final messageContent = jsonEncode({
      'type': 'zennotes_invitation',
      'notebookId': notebookId,
      'notebookTitle': notebookTitle,
      'inviterName': inviterName,
      'inviterAvatar': inviterAvatar,
      'timestamp': timestamp,
    });

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch,
      senderId: 0, // 系统ID
      senderName: 'ZenNotes助手',
      senderAvatar: null,
      content: messageContent,
      type: MessageType.system,
      createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp ?? DateTime.now().millisecondsSinceEpoch),
      isRead: false,
    );

    const systemConvId = 'system_zennotes';
    
    // 查找或创建会话
    final existingIndex = _conversationList.indexWhere((c) => c.id == systemConvId);
    if (existingIndex == -1) {
      _conversationList.add(Conversation(
        id: systemConvId,
        type: ConversationType.private,
        name: 'ZenNotes助手',
        avatar: null, // 可以设置一个默认的系统头像
        participants: [],
        lastMessage: message,
        unreadCount: 1,
        lastActivity: message.createdAt,
        isPinned: true,
      ));
    } else {
      _conversationList[existingIndex] = _conversationList[existingIndex].copyWith(
        lastMessage: message,
        lastActivity: message.createdAt,
        unreadCount: _conversationList[existingIndex].unreadCount + 1,
      );
    }
    
    // 添加消息到会话
    final list = _conversations[systemConvId] ?? <Message>[];
    _conversations[systemConvId] = list;
    list.add(message);
    
    _sortConversations();
    
    // 显示通知
    _notificationService.showMessageNotification(
      title: 'ZenNotes邀请',
      body: '$inviterName 邀请您协作编辑 "$notebookTitle"',
      payload: systemConvId,
    );
    
    notifyListeners();
  }

  // 确保好友出现在会话列表（即便没有消息）
  void ensureConversationForFriend(int friendId, {User? friendData}) {
    final convId = friendId.toString();
    final resolvedFriend = _resolveFriendSnapshot(friendId, friendData);
    final existingIndex = _conversationList.indexWhere(
      (c) => c.type == ConversationType.private && c.id == convId,
    );

    final targetName = resolvedFriend.nickname ?? resolvedFriend.username;

    if (existingIndex != -1) {
      final current = _conversationList[existingIndex];
      final participants = current.participants;
      final needsParticipantUpdate = participants.isEmpty ||
          participants.first.id != resolvedFriend.id ||
          participants.first.nickname != resolvedFriend.nickname ||
          participants.first.avatar != resolvedFriend.avatar ||
          participants.first.status != resolvedFriend.status;
      final needsMetaUpdate =
          current.name != targetName || current.avatar != resolvedFriend.avatar;

      if (needsParticipantUpdate || needsMetaUpdate) {
        _conversationList[existingIndex] = current.copyWith(
          name: targetName,
          avatar: resolvedFriend.avatar,
          participants: [resolvedFriend],
        );
        notifyListeners();
      }
      return;
    }

    _conversationList.add(Conversation(
      id: convId,
      type: ConversationType.private,
      name: targetName,
      avatar: resolvedFriend.avatar,
      participants: [resolvedFriend],
      lastMessage: null,
      unreadCount: 0,
      lastActivity: DateTime.now(),
      isPinned: _pinnedConvIds.contains(convId),
    ));
    _sortConversations();
    notifyListeners();
  }

  User _resolveFriendSnapshot(int friendId, User? fallback) {
    final friend = _friends.where((f) => f.id == friendId).firstOrNull;
    if (friend != null) return friend;
    if (fallback != null) return fallback;
    return User(
      id: friendId,
      username: 'user$friendId',
      email: 'user$friendId@placeholder.local',
      nickname: '用户$friendId',
      status: UserStatus.offline,
    );
  }

  bool _syncConversationsWithFriends() {
    bool updated = false;
    for (var i = 0; i < _conversationList.length; i++) {
      final conv = _conversationList[i];
      if (conv.type != ConversationType.private) continue;
      final friendId = int.tryParse(conv.id);
      if (friendId == null) continue;
      final friend = _friends.where((f) => f.id == friendId).firstOrNull;
      if (friend == null) continue;
      final targetName = friend.nickname ?? friend.username;
      final participants = conv.participants;
      final needsParticipants = participants.isEmpty ||
          participants.first.id != friend.id ||
          participants.first.nickname != friend.nickname ||
          participants.first.avatar != friend.avatar ||
          participants.first.status != friend.status;
      final needsName = conv.name != targetName;
      final needsAvatar = conv.avatar != friend.avatar;
      if (!needsParticipants && !needsName && !needsAvatar) continue;
      _conversationList[i] = conv.copyWith(
        name: targetName,
        avatar: friend.avatar,
        participants: [friend],
      );
      updated = true;
    }
    return updated;
  }

  void _handleOnlineFriendsList(Map<String, dynamic> data) {
    final onlineUserIds = List<String>.from(data['onlineUserIds'] ?? []);
    for (String userId in onlineUserIds) {
      _userOnlineStatus[userId] = true;
    }
    print('在线好友列表: $onlineUserIds');
  }

  MessageType _parseMessageType(String type) {
    switch (type.toUpperCase()) {
      case 'TEXT':
        return MessageType.text;
      case 'IMAGE':
        return MessageType.image;
      case 'FILE':
        return MessageType.file;
      case 'AUDIO':
        return MessageType.audio;
      case 'VIDEO':
        return MessageType.video;
      case 'LINK':
        return MessageType.link;
      default:
        return MessageType.text;
    }
  }

  void _updateConversationWithNewMessage(Message message,
      {required String conversationId, bool isIncoming = true}) {
    // 查找并更新对应的会话
    final conversationIndex = _conversationList.indexWhere(
      (conv) => conv.id == conversationId,
    );

    if (conversationIndex != -1) {
      // 更新现有会话
      final lastRead = _lastReadAt[conversationId];
      final shouldCount = isIncoming &&
          (lastRead == null || message.createdAt.isAfter(lastRead));
      _conversationList[conversationIndex] =
          _conversationList[conversationIndex].copyWith(
        lastMessage: message,
        lastActivity: message.createdAt,
        unreadCount: _conversationList[conversationIndex].unreadCount +
            (shouldCount ? 1 : 0),
      );

      print('🔄 更新会话 $conversationId 的最新消息: ${message.content}');
    } else {
      // 如果会话不存在，需要创建新会话
      print('⚠️ 会话 $conversationId 不存在，尝试创建新会话');
      final unreadInc = (isIncoming &&
              (_lastReadAt[conversationId] == null ||
                  message.createdAt.isAfter(_lastReadAt[conversationId]!)))
          ? 1
          : 0;

      if (message.isGroup) {
        // 群聊：从 _groups 中查找群信息
        final gid = int.tryParse(conversationId);
        Map<String, dynamic>? g;
        if (gid != null) {
          g = _groups
              .where((e) => (e['id'] ?? e['groupId']) == gid)
              .map((e) => e as Map<String, dynamic>?)
              .firstOrNull;
        }
        final name = g != null ? (g['name'] ?? g['groupName'] ?? '群聊') : '群聊';
        final avatar = g != null ? (g['avatar']) : null;
        _conversationList.add(Conversation(
          id: conversationId,
          type: ConversationType.group,
          name: name,
          avatar: avatar,
          participants: const [],
          lastMessage: message,
          unreadCount: unreadInc,
          lastActivity: message.createdAt,
          isPinned: _pinnedConvIds.contains(conversationId),
        ));
        print('✅ 创建群会话: $name (#$conversationId)');
      } else {
        // 私聊：查找好友信息
        final friendId = int.tryParse(conversationId);
        if (friendId != null) {
          final friend = _friends.where((f) => f.id == friendId).firstOrNull;
          if (friend != null) {
            final newConversation = Conversation(
              id: conversationId,
              type: ConversationType.private,
              name: friend.nickname ?? friend.username,
              avatar: friend.avatar,
              participants: [friend],
              lastMessage: message,
              unreadCount: unreadInc,
              lastActivity: message.createdAt,
              isPinned: _pinnedConvIds.contains(conversationId),
            );
            _conversationList.add(newConversation);
            print('✅ 创建新会话: ${friend.nickname ?? friend.username}');
          } else {
            // 找不到好友信息也创建占位会话，保证未读数可见
            _conversationList.add(Conversation(
              id: conversationId,
              type: ConversationType.private,
              name: '用户$conversationId',
              participants: const [],
              lastMessage: message,
              unreadCount: unreadInc,
              lastActivity: message.createdAt,
              isPinned: _pinnedConvIds.contains(conversationId),
            ));
            print('✅ 创建临时私聊会话: 用户$conversationId');
          }
        }
      }
    }

    // 重新排序会话列表
    _sortConversations();
  }

  void upsertLocalMessage(String conversationId, Message message) {
    final list = _conversations[conversationId] ?? <Message>[];
    _conversations[conversationId] = list;
    final idx = list.indexWhere((m) => m.id == message.id);
    if (idx == -1) {
      list.add(message);
    } else {
      list[idx] = message;
    }
    _updateConversationWithNewMessage(
      message,
      conversationId: conversationId,
      isIncoming: false,
    );
    notifyListeners();
  }

  void markLocalMessageFailed(
      String conversationId, int localId, MessageSendStatus status) {
    final list = _conversations[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == localId);
    if (idx == -1) return;
    final updated = list[idx].copyWith(sendStatus: status);
    list[idx] = updated;
    _updateConversationWithNewMessage(
      updated,
      conversationId: conversationId,
      isIncoming: false,
    );
    if (_selfUserId != null &&
        (status == MessageSendStatus.failedOffline ||
            status == MessageSendStatus.failedServer)) {
      unawaited(_persistLocalShadowMessage(
        userId: _selfUserId!,
        conversationId: conversationId,
        message: updated,
      ));
    }
    notifyListeners();
  }

  void replaceLocalMessage(
      String conversationId, int localId, Message replacement) {
    final list = _conversations[conversationId] ?? <Message>[];
    _conversations[conversationId] = list;
    final idx = list.indexWhere((m) => m.id == localId);
    if (idx != -1) {
      list[idx] = replacement;
    } else {
      final similarIdx = _indexOfSameOrSimilar(list, replacement);
      if (similarIdx != -1) {
        list[similarIdx] = replacement;
      } else {
        list.add(replacement);
      }
    }
    _updateConversationWithNewMessage(
      replacement,
      conversationId: conversationId,
      isIncoming: false,
    );
    if (_selfUserId != null) {
      unawaited(_removeLocalShadowMessages(
        userId: _selfUserId!,
        conversationId: conversationId,
        messageIds: [localId, replacement.id],
      ));
    }
    notifyListeners();
  }

  void _handleWebSocketError(dynamic error) {
    _isConnected = false;
    _errorMessage = 'WebSocket错误: $error';
    notifyListeners();

    // 尝试重连
    _scheduleReconnect();
  }

  void _handleWebSocketClose() {
    _isConnected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      // 如果还没有连接，尝试重连
      if (!_isConnected) {
        // connectWebSocket(currentUserId); // 需要保存当前用户ID
      }
    });
  }

  // 断开WebSocket连接
  Future<void> disconnect() async {
    try {
      _wsManager.disconnect();
      _isConnected = false;
      notifyListeners();
    } catch (e) {
      print('断开WebSocket连接失败: $e');
    }
  }

  // 完整重置聊天状态（登出时调用）
  void reset() {
    try {
      _wsManager.disconnect();
    } catch (_) {}
    _isConnected = false;
    _initialized = false;
    // 使用重新赋值，避免某些来自服务层的固定长度/不可变列表触发 clear 时报错
    _friends = [];
    _groups = [];
    _userOnlineStatus = {};
    _conversationList = [];
    _conversations = {};
    _pinnedMessages = [];
    _blockedUserIds = <int>{};
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  // Friends Management
  Future<void> fetchFriends(int userId) async {
    print('📱 fetchFriends 开始执行，用户ID: $userId');
    _isLoading = true;
    _errorMessage = null;
    print('📱 设置 _isLoading = true, 调用 notifyListeners()');
    notifyListeners();

    try {
      print('🔄 开始加载好友列表，用户ID: $userId');
      print('🔗 调用 _friendshipService.getFriends($userId)');

      final friends = await _friendshipService.getFriends(userId);
      print(
          '📋 _friendshipService.getFriends 返回结果: ${friends?.length ?? 0} 个好友');

      if (friends != null) {
        _friends = friends;
        print('✅ 好友列表赋值成功，当前 _friends.length = ${_friends.length}');

        // 初始化在线状态
        _userOnlineStatus.clear();
        for (final friend in friends) {
          _userOnlineStatus[friend.id.toString()] =
              friend.status == UserStatus.online;
          print(
              '👥 设置好友 ${friend.username}(ID:${friend.id}) 在线状态: ${friend.status}');
        }
        final synced = _syncConversationsWithFriends();
        if (synced) {
          print('🔄 已使用最新好友资料刷新会话头像/昵称');
        }

        print('✅ 成功加载 ${friends.length} 个好友');
        _errorMessage = null;
      } else {
        print('⚠️ _friendshipService.getFriends 返回 null');
        _friends = [];
      }
    } catch (e) {
      print('❌ 获取好友列表异常: $e');
      print('❌ 异常类型: ${e.runtimeType}');
      if (e is Error) {
        print('❌ 异常堆栈: ${e.stackTrace}');
      }
      // 离线或服务异常时，保留现有好友列表，避免列表被清空
      _errorMessage = '加载好友列表失败: $e';
    } finally {
      print('📱 fetchFriends 执行完毕，设置 _isLoading = false');
      _isLoading = false;
      print('📱 最终好友数量: ${_friends.length}，调用 notifyListeners()');
      notifyListeners();
    }
  }

  // 发送好友申请
  Future<bool> sendFriendRequest(int userId, int friendId) async {
    try {
      print('🔄 发送好友申请: $userId -> $friendId');
      final success =
          await _friendshipService.sendFriendRequest(userId, friendId);

      if (success) {
        print('✅ 好友申请发送成功');
      } else {
        print('❌ 好友申请发送失败');
      }

      return success;
    } catch (e) {
      print('❌ 发送好友申请异常: $e');
      _errorMessage = '发送好友申请失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 同意好友申请
  Future<bool> acceptFriendRequest(int requestId) async {
    try {
      print('🔄 同意好友申请: $requestId');
      final success = await _friendshipService.acceptFriendRequest(requestId);

      if (success) {
        print('✅ 已同意好友申请');
        // 重新获取好友列表
        // fetchFriends(currentUserId);
      }

      return success;
    } catch (e) {
      print('❌ 同意好友申请异常: $e');
      _errorMessage = '同意好友申请失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 拒绝好友申请
  Future<bool> rejectFriendRequest(int requestId) async {
    try {
      print('🔄 拒绝好友申请: $requestId');
      final success = await _friendshipService.rejectFriendRequest(requestId);

      if (success) {
        print('✅ 已拒绝好友申请');
      }

      return success;
    } catch (e) {
      print('❌ 拒绝好友申请异常: $e');
      _errorMessage = '拒绝好友申请失败: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> blockFriend(int userId, int friendId) async {
    try {
      print('🔒 拉黑好友: $userId -> $friendId');
      final success = await _friendshipService.blockFriend(userId, friendId);
      if (success) {
        _blockedUserIds.add(friendId);
        notifyListeners();
        await fetchBlockedFriends(userId);
      }
      return success;
    } catch (e) {
      print('❌ 拉黑好友异常: $e');
      _errorMessage = '拉黑好友失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 获取好友申请
  Future<List<Map<String, dynamic>>> getPendingRequests(int userId) async {
    try {
      print('🔄 获取好友申请: $userId');
      final requests = await _friendshipService.getPendingRequests(userId);
      _pendingRequestsCount = requests.length;
      notifyListeners();

      print('✅ 获取到 ${requests.length} 个好友申请');
      return requests;
    } catch (e) {
      print('❌ 获取好友申请异常: $e');
      _errorMessage = '获取好友申请失败: $e';
      notifyListeners();
      return [];
    }
  }

  // 我收到的所有申请记录
  Future<List<Map<String, dynamic>>> getAllReceivedRequests(int userId) async {
    try {
      final list = await _friendshipService.getAllReceived(userId);
      return list;
    } catch (e) {
      _errorMessage = '获取收到的好友申请失败: $e';
      notifyListeners();
      return [];
    }
  }

  // 我发出的所有申请记录
  Future<List<Map<String, dynamic>>> getAllSentRequests(int userId) async {
    try {
      final list = await _friendshipService.getAllSent(userId);
      return list;
    } catch (e) {
      _errorMessage = '获取发出的好友申请失败: $e';
      notifyListeners();
      return [];
    }
  }

  // 删除好友
  Future<bool> deleteFriend(int userId, int friendId) async {
    try {
      print('🔄 删除好友: $userId -> $friendId');
      final success = await _friendshipService.deleteFriend(userId, friendId);

      if (success) {
        print('✅ 好友删除成功');
        // 从本地列表中移除
        _friends.removeWhere((friend) => friend.id == friendId);
        _userOnlineStatus.remove(friendId.toString());
        _blockedUserIds.remove(friendId);
        _conversationList.removeWhere((conv) =>
            conv.type == ConversationType.private &&
            conv.id == friendId.toString());
        _conversations.remove(friendId.toString());
        await fetchBlockedFriends(userId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      print('❌ 删除好友异常: $e');
      _errorMessage = '删除好友失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 从后端获取我加入的群聊
  Future<void> fetchGroups(int userId) async {
    try {
      print('🔄 开始获取群聊列表，用户ID: $userId');
      final groups = await _groupService.getMyGroups();
      _groups = groups;
      print('✅ 成功获取 ${groups.length} 个群聊');
      // 将群聊合并到会话列表中（即便暂时没有消息也能看到群）
      await _mergeGroupsIntoConversations();
      notifyListeners();
    } catch (e) {
      print('❌ 获取群聊列表失败: $e');
      _errorMessage = '获取群聊列表失败: $e';
      notifyListeners();
    }
  }

  // 将已加入的群聊合并到会话列表（若后端通讯录不返回群作为联系人，确保主页也能看到群）
  Future<void> _mergeGroupsIntoConversations() async {
    try {
      for (final g in _groups) {
        final gid = (g['id'] ?? g['groupId']).toString();
        if (gid.isEmpty) continue;

        final name = g['name'] ?? g['groupName'] ?? '群聊';
        final avatar = g['avatar'];

        // 最近一条消息（优先用现有缓存/网络获取）
        Message? last;
        DateTime lastAt = DateTime.now();

        // 先看内存中的消息缓存
        final wsMsg = _recentWebSocketMessages[gid];
        if (wsMsg != null) {
          last = wsMsg;
          lastAt = wsMsg.createdAt;
        } else {
          // 尝试读取网络最新消息（不强依赖，失败忽略）
          try {
            final msgs = await _messageService.getGroupMessages(int.parse(gid),
                page: 0, size: 1);
            if (msgs.isNotEmpty) {
              last = msgs.last;
              lastAt = last!.createdAt;
              _conversations[gid] = msgs; // 记住以便进入会话时可见
            } else {
              // 用群的更新时间/创建时间作为最近活动时间
              final ts = g['updatedAt'] ?? g['createdAt'];
              final parsed = ts is String ? DateTime.tryParse(ts) : null;
              lastAt = parsed ?? DateTime.now();
            }
          } catch (_) {
            final ts = g['updatedAt'] ?? g['createdAt'];
            final parsed = ts is String ? DateTime.tryParse(ts) : null;
            lastAt = parsed ?? DateTime.now();
          }
        }

        final idx = _conversationList
            .indexWhere((c) => c.type == ConversationType.group && c.id == gid);
        if (idx == -1) {
          _conversationList.add(Conversation(
            id: gid,
            type: ConversationType.group,
            name: name,
            avatar: avatar,
            participants: const [],
            lastMessage: last,
            unreadCount: 0,
            lastActivity: last?.createdAt ?? lastAt,
            isPinned: _pinnedConvIds.contains(gid),
          ));
          print('🧩 新增群会话: $name (#$gid)');
        } else {
          // 更新名称/头像/最近活动
          _conversationList[idx] = _conversationList[idx].copyWith(
            name: name,
            avatar: avatar ?? _conversationList[idx].avatar,
            lastMessage: last ?? _conversationList[idx].lastMessage,
            lastActivity: (last?.createdAt ?? lastAt)
                    .isAfter(_conversationList[idx].lastActivity)
                ? (last?.createdAt ?? lastAt)
                : _conversationList[idx].lastActivity,
          );
        }
      }

      _deduplicateConversations();
      _applyPinnedFromLocal();
      _sortConversations();
    } catch (e) {
      print('⚠️ 合并群会话失败: $e');
    }
  }

  // 创建群聊
  Future<Map<String, dynamic>?> createGroup({
    required String groupName,
    required String description,
    required List<int> memberIds,
    required int creatorId,
  }) async {
    try {
      print('🔄 创建群聊: $groupName');
      final result = await _groupService.createGroup(
        groupName: groupName,
        description: description,
        memberIds: memberIds,
      );

      if (result != null) {
        // 创建成功后刷新群聊列表
        await fetchGroups(creatorId);
        print('✅ 群聊创建成功并已刷新列表');
        _errorMessage = null;
        return result;
      } else {
        _errorMessage = '创建群聊失败';
        notifyListeners();
        return null;
      }
    } catch (e) {
      print('❌ 创建群聊异常: $e');
      _errorMessage = '创建群聊失败: $e';
      notifyListeners();
      return null;
    }
  }

  // 解散群聊
  Future<bool> dissolveGroup(int groupId, int userId) async {
    try {
      print('🔄 解散群聊: $groupId');
      final success = await _groupService.dissolveGroup(groupId, userId);

      if (success) {
        // 解散成功后从本地列表移除
        _groups.removeWhere((group) => group['id'] == groupId);

        // 同时移除相关的会话
        _conversationList.removeWhere((conv) =>
            conv.type == ConversationType.group &&
            conv.id == groupId.toString());
        _conversations.remove(groupId.toString());

        print('✅ 群聊解散成功并已更新本地数据');
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '解散群聊失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ 解散群聊异常: $e');
      _errorMessage = '解散群聊失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 退出群聊
  Future<bool> leaveGroup(int groupId, int userId) async {
    try {
      print('🔄 退出群聊: $groupId');
      final success = await _groupService.leaveGroup(groupId, userId);

      if (success) {
        // 退出成功后从本地列表移除
        _groups.removeWhere((group) => group['id'] == groupId);

        // 同时移除相关的会话
        _conversationList.removeWhere((conv) =>
            conv.type == ConversationType.group &&
            conv.id == groupId.toString());
        _conversations.remove(groupId.toString());

        print('✅ 退出群聊成功并已更新本地数据');
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '退出群聊失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ 退出群聊异常: $e');
      _errorMessage = '退出群聊失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 添加群成员
  Future<bool> addGroupMembers(
      int groupId, List<int> memberIds, int operatorId) async {
    try {
      print('🔄 添加群成员: $groupId, 新成员: $memberIds');
      final success =
          await _groupService.addGroupMembers(groupId, memberIds, operatorId);

      if (success) {
        // 添加成功后可以选择刷新群详情
        print('✅ 添加群成员成功');
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '添加群成员失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ 添加群成员异常: $e');
      _errorMessage = '添加群成员失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 移除群成员
  Future<bool> removeGroupMember(
      int groupId, int memberId, int operatorId) async {
    try {
      print('🔄 移除群成员: $groupId, 成员: $memberId');
      final success =
          await _groupService.removeGroupMember(groupId, memberId, operatorId);

      if (success) {
        print('✅ 移除群成员成功');
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '移除群成员失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ 移除群成员异常: $e');
      _errorMessage = '移除群成员失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 更新群信息
  Future<Map<String, dynamic>?> updateGroupInfo({
    required int groupId,
    required int operatorId,
    String? groupName,
    String? description,
    String? avatar,
  }) async {
    try {
      print('🔄 更新群信息: $groupId');
      final result = await _groupService.updateGroupInfo(
        groupId: groupId,
        groupName: groupName,
        description: description,
        avatar: avatar,
      );

      if (result != null) {
        Map<String, dynamic> safeResult = {};
        if (result is Map<String, dynamic>) {
          safeResult = result;
        } else if (result is Map) {
          // 宽松地把 key 转成字符串，避免 Map<String,dynamic>.from 的泛型限制抛错
          result.forEach((k, v) {
            safeResult[k.toString()] = v;
          });
        }
        // 计算本地需要覆盖的字段（优先使用用户提交的值，保证立刻生效）
        final String? newName = (groupName?.trim().isNotEmpty ?? false)
            ? groupName!.trim()
            : (safeResult['name'] ?? safeResult['groupName'])?.toString();
        final String? newAvatar = (avatar?.trim().isNotEmpty ?? false)
            ? avatar!.trim()
            : safeResult['avatar']?.toString();

        // 更新本地群聊列表中的信息
        final groupIndex = _groups.indexWhere(
            (group) => (group['id'] ?? group['groupId']) == groupId);
        if (groupIndex != -1) {
          Map<String, dynamic> updated = {};
          // 宽松合并：把旧值与新值分别做字符串键转换再合并，避免 _Map<dynamic,dynamic> 抛错
          try {
            final oldMap = _groups[groupIndex];
            if (oldMap is Map) {
              oldMap.forEach((k, v) => updated[k.toString()] = v);
            }
          } catch (_) {}
          safeResult.forEach((k, v) => updated[k] = v);
          if (newName != null) {
            updated['name'] = newName;
            updated['groupName'] = newName;
          }
          if (newAvatar != null) {
            updated['avatar'] = newAvatar;
          }
          _groups[groupIndex] = updated;
        }

        // 更新会话列表中的群聊信息
        final convIndex = _conversationList.indexWhere((conv) =>
            conv.type == ConversationType.group &&
            conv.id == groupId.toString());
        if (convIndex != -1) {
          _conversationList[convIndex] = _conversationList[convIndex].copyWith(
            name: newName ?? _conversationList[convIndex].name,
            avatar: newAvatar ?? _conversationList[convIndex].avatar,
          );
        }

        print('✅ 群信息更新成功并已同步本地数据');
        // 先立刻通知，确保UI同步
        notifyListeners();
        // 再异步刷新群列表（失败也忽略），避免阻塞或抛错影响本次更新可见性
        unawaited(Future(() async {
          try {
            await fetchGroups(operatorId);
          } catch (e) {
            print('⚠️ 刷新群列表失败(忽略): $e');
          }
        }));
        return safeResult;
      } else {
        // 返回 null 由调用方决定是否提示；避免在主界面冒出“加载失败”覆盖层
        return null;
      }
    } catch (e, st) {
      // 不因刷新失败影响本地可见性：在 try 块内我们已经执行了本地覆盖并 notify 过，
      // 若异常发生在异步刷新阶段，仅记录日志即可。
      print('❌ 更新群信息异常(已忽略全局提示): $e\n$st');
      return null;
    }
  }

  // 获取群详情（包含成员列表）
  Future<Map<String, dynamic>?> getGroupDetailWithMembers(int groupId) async {
    try {
      print('🔄 获取群详情: $groupId');

      // 获取群基本信息
      final groupDetail = await _groupService.getGroupDetail(groupId);
      if (groupDetail == null) {
        _errorMessage = '获取群详情失败';
        notifyListeners();
        return null;
      }

      // 获取群成员列表
      final members = await _groupService.getGroupMembers(groupId);

      // 合并信息
      final result = {
        ...groupDetail,
        'members': members,
      };

      print('✅ 获取群详情成功，成员数: ${members.length}');
      _errorMessage = null;
      return result;
    } catch (e) {
      print('❌ 获取群详情异常: $e');
      _errorMessage = '获取群详情失败: $e';
      notifyListeners();
      return null;
    }
  }

  // Messages
  Future<void> fetchMessages(int userId) async {
    // 目标：离线/服务器异常时，不清空现有列表与消息，仅在成功获取后再替换
    _isLoading = true;
    notifyListeners();

    // 备份当前内存数据
    final prevConversations = Map<String, List<Message>>.from(_conversations);
    final prevList = List<Conversation>.from(_conversationList);

    try {
      print('🔄 开始加载用户消息，用户ID: $userId');

      // 获取聊天联系人列表（最近聊天）
      print('📞 调用 _messageService.getChatContacts($userId)');
      final contacts = await _messageService.getChatContacts(userId);
      print('📋 getChatContacts 返回结果: ${contacts?.length ?? 0} 个联系人');

      // 保存当前本地最新消息的时间戳，用于对比
      final Map<String, DateTime> localLatestMessageTimes = {};
      final Map<String, Message> localLatestMessages = {};

      for (final conversation in _conversationList) {
        if (conversation.lastMessage != null) {
          localLatestMessageTimes[conversation.id] =
              conversation.lastMessage!.createdAt;
          localLatestMessages[conversation.id] = conversation.lastMessage!;
        }
      }

      // 使用临时容器构建新数据
      final Map<String, List<Message>> nextConversations = {};
      final List<Conversation> nextList = [];

      // 为每个联系人获取最近的消息
      for (final contact in contacts) {
        // 后端返回的数据格式为 {id, nickname, avatar, username}，而非 {userId/groupId}
        final contactId = contact['userId']?.toString() ??
            contact['groupId']?.toString() ??
            contact['id']?.toString();
        print(
            '🔍 处理联系人: ${contact['nickname'] ?? contact['username']}, contactId: $contactId');
        if (contactId == null) {
          print('⚠️ 跳过联系人（无有效ID）: $contact');
          continue;
        }

        try {
          List<Message> messages;

          if (contact['isGroup'] == true) {
            // 群聊消息
            messages = await _messageService.getGroupMessages(
              int.parse(contactId),
              page: 0,
              size: 50,
            );
          } else {
            // 私聊消息
            print('📱 获取私聊消息: userId=$userId, contactId=$contactId');
            messages = await _messageService.getPrivateMessages(
              userId,
              int.parse(contactId),
              page: 0,
              size: 50,
            );
            print('📱 获取到私聊消息数量: ${messages.length}');
          }
          // 过滤本地“仅自己隐藏”的消息，确保卡片最后一条也不会是隐藏项
          try {
            final hidden = await _getHiddenMessageIds(
                conversationId: contactId, userId: userId);
            if (hidden.isNotEmpty) {
              messages = messages.where((m) => !hidden.contains(m.id)).toList();
            }
          } catch (e) {
            print('过滤本地隐藏消息失败: $e');
          }

          messages = await _withLocalShadowMessages(
            baseMessages: messages,
            conversationId: contactId,
            userId: userId,
          );

          if (messages.isNotEmpty) {
            nextConversations[contactId] = messages;

            // 创建会话对象
            List<User> participants = [];
            String displayName = contact['name'] ??
                contact['nickname'] ??
                contact['username'] ??
                '未知';
            String? displayAvatar = contact['avatar'];

            if (contact['isGroup'] != true) {
              // 对于私聊，查找对应的好友用户信息
              final contactUser = _friends
                  .where((friend) => friend.id.toString() == contactId)
                  .firstOrNull;

              if (contactUser != null) {
                participants = [contactUser];
                displayName = contactUser.nickname ?? contactUser.username;
                displayAvatar = contactUser.avatar;
                print('📝 找到好友信息: ${displayName}, 头像: ${displayAvatar}');
              } else {
                // 如果没有在好友列表找到，从联系人信息创建临时用户对象
                print('⚠️ 在好友列表中未找到联系人 $contactId，使用联系人信息');
                final tempUser = User(
                  id: int.parse(contactId),
                  username: contact['username'] ?? 'user_$contactId',
                  email: contact['email'] ?? '',
                  nickname: displayName,
                  avatar: displayAvatar,
                  status: UserStatus.offline,
                );
                participants = [tempUser];
              }
            } else {
              // 群聊处理（保留原逻辑）
              print('📝 处理群聊: $displayName');
            }

            // 检查是否有本地更新的消息
            Message finalLastMessage = messages.last;
            DateTime finalLastActivity = messages.last.createdAt;

            // 检查本地和WebSocket缓存的消息，使用最新的
            Message? candidateMessage = localLatestMessages[contactId];
            DateTime? candidateTime = localLatestMessageTimes[contactId];

            // 检查WebSocket缓存的消息
            if (_recentWebSocketMessages.containsKey(contactId)) {
              final wsMessage = _recentWebSocketMessages[contactId]!;
              if (candidateMessage == null ||
                  wsMessage.createdAt.isAfter(candidateTime!)) {
                candidateMessage = wsMessage;
                candidateTime = wsMessage.createdAt;
                print('🔄 发现WebSocket缓存的更新消息: ${wsMessage.content}');
              }
            }

            // 如果有更新的消息（本地或WebSocket），使用它
            if (candidateMessage != null &&
                candidateTime != null &&
                candidateTime.isAfter(messages.last.createdAt)) {
              print('🔄 使用更新的消息: ${candidateMessage.content}');
              finalLastMessage = candidateMessage;
              finalLastActivity = candidateTime;

              // 将更新的消息添加到对话中（如果不存在）
              final existingMessage = _conversations[contactId]!
                  .where((m) => m.id == candidateMessage!.id)
                  .firstOrNull;
              if (existingMessage == null) {
                _conversations[contactId]!.add(candidateMessage);
              }
            }

            // 计算未读：优先使用后端提供的 unreadCount；否则按本地 lastReadAt 计算
            final int serverUnread = contact['unreadCount'] ?? 0;
            int computedUnread = 0;
            if (serverUnread <= 0) {
              final lastRead = _lastReadAt[contactId];
              if (lastRead == null) {
                computedUnread =
                    messages.where((m) => !m.isFromMe(userId)).length;
              } else {
                computedUnread = messages
                    .where((m) =>
                        !m.isFromMe(userId) && m.createdAt.isAfter(lastRead))
                    .length;
              }
            }

            final conversation = Conversation(
              id: contactId,
              type: contact['isGroup'] == true
                  ? ConversationType.group
                  : ConversationType.private,
              name: displayName,
              avatar: displayAvatar,
              participants: participants,
              lastMessage: finalLastMessage,
              unreadCount: serverUnread > 0 ? serverUnread : computedUnread,
              lastActivity: finalLastActivity,
              isPinned: contact['isPinned'] == true,
            );

            print('✅ 创建会话: ${displayName}, 参与者数: ${participants.length}');
            nextList.add(conversation);
          }
        } catch (e) {
          print('❌ 获取联系人 $contactId 消息失败: $e');
        }
      }

      // 如果没有聊天记录，从好友列表创建空会话项（仅显示好友，无消息内容）
      if (nextList.isEmpty && _friends.isNotEmpty) {
        print('📝 没有聊天记录，为好友创建空会话项...');
        for (final friend in _friends) {
          final conversation = Conversation(
            id: friend.id.toString(),
            type: ConversationType.private,
            name: friend.nickname ?? friend.username,
            avatar: friend.avatar,
            participants: [friend],
            lastMessage: null, // 确实没有消息记录
            unreadCount: 0,
            lastActivity: friend.createdAt ?? DateTime.now(),
            isPinned: false,
          );
          nextList.add(conversation);
          print('📝 为好友 ${friend.nickname ?? friend.username} 创建空会话项（无消息内容）');
        }
      }

      // 按时间排序会话列表
      // 将构建的 nextList 去重并排序
      final map = <String, Conversation>{};
      for (final c in nextList) {
        map[c.id] = c;
      }
      final deduped = map.values.toList();
      deduped.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      // 清理超过10分钟的WebSocket消息缓存
      _cleanupWebSocketCache();

      // 用新数据替换旧数据（先替换，再合并群，会避免被后续替换覆盖）
      _conversations
        ..clear()
        ..addAll(nextConversations);
      _conversationList
        ..clear()
        ..addAll(deduped);

      // 合并群会话（仍然可能为空，但不会覆盖已构建的 next 列表）
      await _mergeGroupsIntoConversations();

      // 与先前列表做一次并集，避免后端未返回的会话被“刷新”丢失
      final prevMap = {for (final c in prevList) c.id: c};
      final currMap = {for (final c in _conversationList) c.id: c};
      for (final entry in prevMap.entries) {
        currMap.putIfAbsent(entry.key, () => entry.value);
      }
      // 冻结排序时，按照旧顺序优先；否则按默认规则
      final freeze = _shouldFreezeOrder();
      if (freeze) {
        final prevIndex = <String, int>{};
        for (var i = 0; i < prevList.length; i++) {
          prevIndex[prevList[i].id] = i;
        }
        final stabilized = currMap.values.toList()
          ..sort((a, b) {
            final ai = prevIndex[a.id];
            final bi = prevIndex[b.id];
            if (ai != null && bi != null) return ai.compareTo(bi);
            if (ai != null) return -1;
            if (bi != null) return 1;
            return b.lastActivity.compareTo(a.lastActivity);
          });
        _conversationList
          ..clear()
          ..addAll(stabilized);
      } else {
        _conversationList
          ..clear()
          ..addAll(currMap.values);
      }

      // 对消息列表也做并集保留（新数据优先）
      final mergedConvs = Map<String, List<Message>>.from(prevConversations);
      for (final e in nextConversations.entries) {
        mergedConvs[e.key] = e.value; // 覆盖或新增
      }
      _conversations
        ..clear()
        ..addAll(mergedConvs);

      _deduplicateConversations();
      _sortConversations();
      print(
          '✅ 成功加载 ${_conversations.length} 个消息会话，${_conversationList.length} 个会话项');
      _errorMessage = null;
      unawaited(_cacheSnapshot(userId));
    } catch (e) {
      print('❌ 获取消息失败: $e');
      // 离线/服务异常等情况下，保持旧数据不变
      _errorMessage = '获取消息失败: $e';
      _conversations
        ..clear()
        ..addAll(prevConversations);
      _conversationList
        ..clear()
        ..addAll(prevList);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send Message
  Future<Message?> sendMessage({
    required int senderId,
    required String content,
    required String contactId,
    bool isGroup = false,
    MessageType type = MessageType.text,
    int? replyToMessageId,
  }) async {
    try {
      print('🔄 发送消息: ${isGroup ? "群聊" : "私聊"} $contactId, 内容: $content');

      Message? sentMessage;

      if (isGroup) {
        // 发送群聊消息
        sentMessage = await _messageService.sendGroupMessage(
          senderId,
          int.parse(contactId),
          content,
          replyToMessageId: replyToMessageId,
          type: type,
        );
      } else {
        // 发送私聊消息
        sentMessage = await _messageService.sendPrivateMessage(
          senderId,
          int.parse(contactId),
          content,
          replyToMessageId: replyToMessageId,
          type: type,
        );
      }

      if (sentMessage != null) {
        print('✅ 消息发送成功，消息ID: ${sentMessage.id}');

        // 添加到本地对话
        // 强类型获取并回写，避免被推断为 List<Message?>
        final List<Message> list = _conversations[contactId] ?? <Message>[];
        _conversations[contactId] = list;
        int idx = _indexOfSameOrSimilar(list, sentMessage);
        if (idx == -1) {
          list.add(sentMessage);
        } else {
          list[idx] = sentMessage;
        }

        // 如果是引用回复，保存引用元数据，避免重新进入后丢失引用UI
        try {
          if (sentMessage.replyToMessageId != null) {
            await _saveReplyMeta(
              userId: senderId,
              conversationId: contactId,
              message: sentMessage,
            );
          }
        } catch (_) {}

        // 更新会话列表中的最后消息
        final conversationIndex =
            _conversationList.indexWhere((c) => c.id == contactId);
        if (conversationIndex != -1) {
          _conversationList[conversationIndex] =
              _conversationList[conversationIndex].copyWith(
            lastMessage: sentMessage,
            lastActivity: sentMessage.createdAt,
          );

          // 重新排序会话列表
          _conversationList
              .sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
        }

        // 通过WebSocket发送消息给其他在线用户
        if (_wsManager.isConnected) {
          // 携带 messageId 与 createdAt，便于接收端精确去重
          _wsManager.sendChatMessage(
            receiverId: contactId,
            content: content,
            type: type.name.toUpperCase(),
            isGroup: isGroup,
            messageId: sentMessage.id,
            createdAt: sentMessage.createdAt,
          );
        }

        _errorMessage = null;
        notifyListeners();
        return sentMessage;
      } else {
        throw Exception('消息发送失败');
      }
    } catch (e) {
      print('❌ 发送消息失败: $e');
      _errorMessage = '发送消息失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  // 删除消息（仅自己）并从本地会话移除
  Future<bool> deleteMessageForMe({
    required int messageId,
    required String conversationId,
    required int currentUserId,
  }) async {
    try {
      final success = await _messageService.deleteMessageForMe(messageId);
      if (success) {
        final list = _conversations[conversationId];
        if (list != null) {
          list.removeWhere((m) => m.id == messageId);
          // 更新会话列表的最后一条消息
          final idx =
              _conversationList.indexWhere((c) => c.id == conversationId);
          if (idx != -1) {
            final newLast = list.isNotEmpty ? list.last : null;
            _conversationList[idx] = _conversationList[idx].copyWith(
              lastMessage: newLast,
              lastActivity:
                  newLast?.createdAt ?? _conversationList[idx].lastActivity,
            );
          }
          // 记录在本地隐藏集合中
          await _addHiddenMessageId(
            conversationId: conversationId,
            messageId: messageId,
            userId: currentUserId,
          );
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _errorMessage = '删除消息失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 撤回消息（所有人不可见）
  Future<bool> recallMessage(
      {required int messageId, required String conversationId}) async {
    try {
      final success = await _messageService.recallMessage(messageId);
      if (success) {
        final list = _conversations[conversationId];
        if (list != null) {
          list.removeWhere((m) => m.id == messageId);
          // 更新会话列表的最后一条消息
          final idx =
              _conversationList.indexWhere((c) => c.id == conversationId);
          if (idx != -1) {
            final newLast = list.isNotEmpty ? list.last : null;
            _conversationList[idx] = _conversationList[idx].copyWith(
              lastMessage: newLast,
              lastActivity:
                  newLast?.createdAt ?? _conversationList[idx].lastActivity,
            );
          }
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _errorMessage = '撤回消息失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 加载特定对话的消息（支持分页）
  Future<List<Message>> loadConversationMessages(int userId, String contactId,
      {bool isGroup = false, int page = 0, int size = 50}) async {
    try {
      print('🔄 加载对话消息: $contactId, 页面: $page');

      List<Message> messages;

      if (isGroup) {
        messages = await _messageService.getGroupMessages(
          int.parse(contactId),
          page: page,
          size: size,
        );
      } else {
        messages = await _messageService.getPrivateMessages(
          userId,
          int.parse(contactId),
          page: page,
          size: size,
        );
      }

      // 本地持久化的“仅自己隐藏”，确保删除后重新进入也不显示
      try {
        final hidden = await _getHiddenMessageIds(
            conversationId: contactId, userId: userId);
        if (hidden.isNotEmpty) {
          messages = messages.where((m) => !hidden.contains(m.id)).toList();
        }
      } catch (e) {
        print('过滤本地隐藏消息失败: $e');
      }

      // 回填缺失的引用信息，确保重新进入后仍显示“引用”卡片
      try {
        messages = await _backfillReplyFromLocal(
          messages: messages,
          userId: userId,
          conversationId: contactId,
        );
      } catch (e) {
        print('回填引用信息失败: $e');
      }

      messages = await _withLocalShadowMessages(
        baseMessages: messages,
        conversationId: contactId,
        userId: userId,
      );

      // 如果是第一页，替换现有消息；否则添加到列表前面（历史消息）
      if (page == 0) {
        _conversations[contactId] = messages;
      } else {
        final existingMessages = _conversations[contactId] ?? [];
        _conversations[contactId] = [...messages, ...existingMessages];
      }

      print('✅ 加载到 ${messages.length} 条消息');
      notifyListeners();
      return messages;
    } catch (e) {
      print('❌ 加载对话消息失败: $e');
      _errorMessage = '加载消息失败: $e';
      notifyListeners();
      return [];
    }
  }

  // —— 本地隐藏消息持久化（确保删除后始终隐藏） ——
  Future<Set<int>> _getHiddenMessageIds(
      {required String conversationId, required int userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'hidden_msgs_' + userId.toString() + '_' + conversationId;
      final list = prefs.getStringList(key) ?? const [];
      return list.map((e) => int.tryParse(e)).whereType<int>().toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> _addHiddenMessageId(
      {required String conversationId,
      required int messageId,
      required int userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'hidden_msgs_' + userId.toString() + '_' + conversationId;
      final list = prefs.getStringList(key) ?? <String>[];
      if (!list.contains(messageId.toString())) {
        list.add(messageId.toString());
        await prefs.setStringList(key, list);
      }
    } catch (_) {}
  }

  // —— 本地保留消息（被拉黑/删除时的失败消息） ——
  String _localShadowKey(int userId, String conversationId) =>
      'local_shadow_msgs_${userId}_$conversationId';

  Future<void> _persistLocalShadowMessage({
    required int userId,
    required String conversationId,
    required Message message,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localShadowKey(userId, conversationId);
      final existing = prefs.getStringList(key) ?? <String>[];
      final serialized = jsonEncode(_serializeLocalMessage(message));

      final filtered = existing.where((raw) {
        try {
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic>) {
            final id = (data['id'] as num?)?.toInt();
            return id != message.id;
          }
          return true;
        } catch (_) {
          return false;
        }
      }).toList();

      filtered.add(serialized);
      await prefs.setStringList(key, filtered);
    } catch (e) {
      print('保存本地保留消息失败: $e');
    }
  }

  Future<void> _removeLocalShadowMessages({
    required int userId,
    required String conversationId,
    required Iterable<int> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final ids = messageIds.toSet();
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localShadowKey(userId, conversationId);
      final existing = prefs.getStringList(key);
      if (existing == null || existing.isEmpty) return;

      final filtered = existing.where((raw) {
        try {
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic>) {
            final id = (data['id'] as num?)?.toInt();
            if (id == null) return false;
            return !ids.contains(id);
          }
          return true;
        } catch (_) {
          return false;
        }
      }).toList();

      await prefs.setStringList(key, filtered);
    } catch (e) {
      print('移除本地保留消息失败: $e');
    }
  }

  Future<List<Message>> _loadLocalShadowMessages({
    required int userId,
    required String conversationId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localShadowKey(userId, conversationId);
      final stored = prefs.getStringList(key) ?? const <String>[];
      final result = <Message>[];
      for (final raw in stored) {
        final msg = _decodeLocalShadowMessage(raw);
        if (msg != null) {
          result.add(msg);
        }
      }
      result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return result;
    } catch (e) {
      print('加载本地保留消息失败: $e');
      return [];
    }
  }

  Future<List<Message>> _withLocalShadowMessages({
    required List<Message> baseMessages,
    required String conversationId,
    required int userId,
  }) async {
    try {
      final localOnly = await _loadLocalShadowMessages(
        userId: userId,
        conversationId: conversationId,
      );
      if (localOnly.isEmpty) return baseMessages;
      final merged = List<Message>.from(baseMessages);
      for (final local in localOnly) {
        final idx = _indexOfSameOrSimilar(merged, local);
        if (idx == -1) {
          merged.add(local);
        } else {
          merged[idx] = local;
        }
      }
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return merged;
    } catch (e) {
      print('合并本地保留消息失败: $e');
      return baseMessages;
    }
  }

  Map<String, dynamic> _serializeLocalMessage(Message message) {
    final data = message.toJson();
    data['sender'] = {
      'id': message.senderId,
      'nickname': message.senderName,
      'avatar': message.senderAvatar,
    };
    data['senderName'] = message.senderName;
    if (message.senderAvatar != null) {
      data['senderAvatar'] = message.senderAvatar;
    }
    data['sendStatus'] = message.sendStatus?.name;
    return data;
  }

  Message? _decodeLocalShadowMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final base = Message.fromJson(data);
      final status = _parseLocalSendStatus(data['sendStatus']);
      return base.copyWith(
        senderName: data['senderName'] ?? base.senderName,
        senderAvatar: data['senderAvatar'] ?? base.senderAvatar,
        sendStatus: status ?? base.sendStatus,
      );
    } catch (e) {
      print('解析本地保留消息失败: $e');
      return null;
    }
  }

  MessageSendStatus? _parseLocalSendStatus(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().toLowerCase();
    for (final status in MessageSendStatus.values) {
      if (status.name.toLowerCase() == value) {
        return status;
      }
    }
    return null;
  }

  // —— 本地“最后已读时间”持久化 ——
  Future<void> _loadLastReadAt(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = prefs.getKeys();
      for (final k in all) {
        final prefix = 'last_read_' + userId.toString() + '_';
        if (k.startsWith(prefix)) {
          final convId = k.substring(prefix.length);
          final iso = prefs.getString(k);
          if (iso != null) {
            final dt = DateTime.tryParse(iso);
            if (dt != null) _lastReadAt[convId] = dt;
          }
        }
      }
    } catch (e) {
      print('加载 lastReadAt 失败: $e');
    }
  }

  Future<void> _saveLastReadAt(
      {required String conversationId, required int? userId}) async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_read_' + userId.toString() + '_' + conversationId,
          DateTime.now().toIso8601String());
    } catch (e) {
      print('保存 lastReadAt 失败: $e');
    }
  }

  // —— 引用回复信息持久化与回填 ——
  Future<void> _saveReplyMeta({
    required int userId,
    required String conversationId,
    required Message message,
  }) async {
    if (message.replyToMessageId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'reply_meta_' + userId.toString() + '_' + conversationId;
      final raw = prefs.getString(key);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}
      }
      map[message.id.toString()] = {
        'replyToMessageId': message.replyToMessageId,
        if (message.replyToSenderId != null)
          'replyToSenderId': message.replyToSenderId,
        if (message.replyToSenderName != null)
          'replyToSenderName': message.replyToSenderName,
        if (message.replyToPreview != null)
          'replyToPreview': message.replyToPreview,
        if (message.replyToCreatedAt != null)
          'replyToCreatedAt': message.replyToCreatedAt!.toIso8601String(),
      };
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {}
  }

  Future<List<Message>> _backfillReplyFromLocal({
    required List<Message> messages,
    required int userId,
    required String conversationId,
  }) async {
    if (messages.isEmpty) return messages;
    final byId = {for (final m in messages) m.id: m};
    Map<String, dynamic> meta = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs
          .getString('reply_meta_' + userId.toString() + '_' + conversationId);
      if (raw != null && raw.isNotEmpty) {
        meta = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    final out = <Message>[];
    for (final m in messages) {
      if (m.replyToMessageId != null && m.replyToPreview == null) {
        final ref = byId[m.replyToMessageId!];
        if (ref != null) {
          out.add(m.copyWith(
            replyToSenderId: ref.senderId,
            replyToSenderName: ref.senderName,
            replyToPreview: ref.content,
            replyToCreatedAt: ref.createdAt,
          ));
          continue;
        }
        // 退化: 使用本地存的元数据
        final entry = meta[m.id.toString()];
        if (entry is Map<String, dynamic>) {
          out.add(m.copyWith(
            replyToSenderId: (entry['replyToSenderId'] as num?)?.toInt(),
            replyToSenderName: entry['replyToSenderName'] as String?,
            replyToPreview: entry['replyToPreview'] as String?,
            replyToCreatedAt: entry['replyToCreatedAt'] != null
                ? DateTime.tryParse(entry['replyToCreatedAt'] as String)
                : null,
          ));
          continue;
        }
      }
      out.add(m);
    }
    return out;
  }

  // 标记消息为已读
  Future<bool> markMessageAsRead(int messageId) async {
    try {
      final success = await _messageService.markAsRead(messageId);
      if (success) {
        print('✅ 消息已标记为已读: $messageId');
      }
      return success;
    } catch (e) {
      print('❌ 标记消息已读失败: $e');
      return false;
    }
  }

  // 获取聊天消息（简化版本，用于ChatDetailScreen）
  Future<List<Message>> getChatMessages({
    required String conversationId,
    required bool isGroup,
    required int userId,
  }) async {
    try {
      print('🔄 获取聊天消息: conversationId=$conversationId, isGroup=$isGroup');

      // 如果本地已有消息，直接返回
      if (_conversations.containsKey(conversationId) &&
          _conversations[conversationId]!.isNotEmpty) {
        print('✅ 从本地缓存返回 ${_conversations[conversationId]!.length} 条消息');
        return _conversations[conversationId]!;
      }

      // 从服务器加载消息
      final messages = await loadConversationMessages(
        userId,
        conversationId,
        isGroup: isGroup,
        page: 0,
        size: 50,
      );

      print('✅ 从服务器加载到 ${messages.length} 条消息');
      return messages;
    } catch (e) {
      print('❌ 获取聊天消息失败: $e');
      return [];
    }
  }

  // —— 置顶会话持久化 ——
  Future<void> _loadPinnedConversations(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list =
          prefs.getStringList('pinned_conversations_' + userId.toString()) ??
              const <String>[];
      _pinnedConvIds = list.toSet();
    } catch (_) {
      _pinnedConvIds = <String>{};
    }
  }

  Future<void> _savePinnedConversations(
      {required int? userId, required Set<String> ids}) async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'pinned_conversations_' + userId.toString(), ids.toList());
    } catch (_) {}
  }

  Future<void> fetchBlockedFriends(int userId) async {
    try {
      final ids = await _friendshipService.getBlockedFriends(userId);
      _blockedUserIds = ids.toSet();
      notifyListeners();
    } catch (e) {
      print('获取拉黑列表失败: $e');
    }
  }

  void _applyPinnedFromLocal() {
    if (_pinnedConvIds.isEmpty) return;
    for (var i = 0; i < _conversationList.length; i++) {
      final c = _conversationList[i];
      final shouldPinned = _pinnedConvIds.contains(c.id);
      if (c.isPinned != shouldPinned) {
        _conversationList[i] = c.copyWith(isPinned: shouldPinned);
      }
    }
  }

  // Pinned Messages
  Future<bool> pinMessage(Message message) async {
    try {
      print('🔄 置顶消息: ${message.id}');
      final pinnedMessage = await _messageService.pinMessage(message.id);

      if (pinnedMessage != null) {
        // 更新本地置顶消息列表
        if (!_pinnedMessages.any((m) => m.id == pinnedMessage.id)) {
          _pinnedMessages.add(pinnedMessage);
        }

        // 更新对话中的消息状态
        for (final contactId in _conversations.keys) {
          final messages = _conversations[contactId]!;
          final index = messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            messages[index] = pinnedMessage;
            break;
          }
        }

        notifyListeners();
        print('✅ 消息置顶成功');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 置顶消息失败: $e');
      _errorMessage = '置顶消息失败: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unpinMessage(int messageId) async {
    try {
      print('🔄 取消置顶消息: $messageId');
      final unpinnedMessage = await _messageService.unpinMessage(messageId);

      if (unpinnedMessage != null) {
        // 更新本地置顶消息列表
        _pinnedMessages.removeWhere((m) => m.id == messageId);

        // 更新对话中的消息状态
        for (final contactId in _conversations.keys) {
          final messages = _conversations[contactId]!;
          final index = messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            messages[index] = unpinnedMessage;
            break;
          }
        }

        notifyListeners();
        print('✅ 取消置顶成功');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 取消置顶失败: $e');
      _errorMessage = '取消置顶失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 获取置顶消息
  Future<List<Message>> fetchPinnedMessages(
      int userId, int chatId, bool isGroup) async {
    try {
      print('🔄 获取置顶消息: $chatId');
      final messages =
          await _messageService.getPinnedMessages(userId, chatId, isGroup);
      _pinnedMessages = messages;
      notifyListeners();

      print('✅ 获取到 ${messages.length} 条置顶消息');
      return messages;
    } catch (e) {
      print('❌ 获取置顶消息失败: $e');
      _errorMessage = '获取置顶消息失败: $e';
      notifyListeners();
      return [];
    }
  }

  // Get last message for a contact
  Message? getLastMessage(String contactId) {
    final messages = _conversations[contactId];
    if (messages == null || messages.isEmpty) return null;
    return messages.last;
  }

  // Check if user is online
  bool isUserOnline(String userId) {
    return _userOnlineStatus[userId] ?? false;
  }

  // Search users
  Future<List<User>> searchUsers(String query) async {
    try {
      if (kDebugMode) {
        print('🔍 [ChatProvider] searchUsers("$query")');
      }
      final svc = UserService();
      final users = await svc.search(query);
      if (kDebugMode) {
        print('🔍 [ChatProvider] searchUsers 返回 ${users.length} 个用户');
      }
      return users;
    } catch (e) {
      _errorMessage = '搜索用户失败: $e';
      if (kDebugMode) {
        print('❌ [ChatProvider] 搜索失败: $e');
      }
      notifyListeners();
      return [];
    }
  }

  // Conversation Management Methods

  // 加载会话列表
  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 开始加载会话列表');

      // 如果没有现有对话数据，尝试获取用户ID并重新加载
      if (_conversations.isEmpty) {
        print('📝 没有现有对话数据，尝试重新加载消息');
        // 这里应该从AuthProvider获取当前用户ID并调用fetchMessages
        // 暂时跳过，保持现有逻辑
      }

      // 从现有的对话数据构建会话列表
      if (_conversations.isNotEmpty) {
        _conversationList.clear();

        for (final entry in _conversations.entries) {
          final contactId = entry.key;
          final messages = entry.value;

          if (messages.isNotEmpty) {
            final lastMessage = messages.last;

            // 重新构建参与者信息和显示名称
            List<User> participants = [];
            String displayName = '未知用户';
            String? displayAvatar;

            if (!lastMessage.isGroup) {
              // 私聊：从好友列表查找对应用户
              final contactUser = _friends
                  .where((friend) => friend.id.toString() == contactId)
                  .firstOrNull;

              if (contactUser != null) {
                participants = [contactUser];
                displayName = contactUser.nickname ?? contactUser.username;
                displayAvatar = contactUser.avatar;
                print('🔄 重新加载好友信息: ${displayName}');
              } else {
                // 尝试从消息中获取发送者信息（排除自己）
                final otherSenders = messages
                    .where((msg) => msg.senderId.toString() == contactId)
                    .toList();
                if (otherSenders.isNotEmpty) {
                  displayName = otherSenders.first.senderName;
                  displayAvatar = otherSenders.first.senderAvatar;
                }
                print('⚠️ 从消息获取用户信息: $displayName');
              }
            } else {
              // 群聊
              displayName = lastMessage.senderName; // 这里可能需要群名
            }

            final conversation = Conversation(
              id: contactId,
              type: lastMessage.isGroup
                  ? ConversationType.group
                  : ConversationType.private,
              name: displayName,
              avatar: displayAvatar,
              participants: participants,
              lastMessage: lastMessage,
              unreadCount: 0,
              lastActivity: lastMessage.createdAt,
              isPinned: _pinnedConvIds.contains(contactId),
            );

            _conversationList.add(conversation);
          }
        }
      }

      // 去重并排序会话列表
      _deduplicateConversations();
      _applyPinnedFromLocal();
      _sortConversations();

      print('✅ 成功加载 ${_conversationList.length} 个会话');
    } catch (e) {
      print('❌ 加载会话失败: $e');
      _errorMessage = '加载会话失败：${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 刷新会话列表
  Future<void> refreshConversations([int? userId]) async {
    print('🔄 刷新会话列表');
    try {
      // 使用传入的用户ID，如果没有则使用当前保存的用户ID
      int? currentUserId = userId;

      // 如果没有用户ID且存在好友，从好友列表中推断当前用户ID
      if (currentUserId == null && _friends.isNotEmpty) {
        // 从对话消息中查找当前用户发送的消息来推断用户ID
        for (final conversation in _conversations.values) {
          for (final message in conversation) {
            // 查找发送给其他用户的消息，推断当前用户ID
            final friendIds = _friends.map((f) => f.id).toSet();
            if (friendIds.contains(message.receiverId) &&
                message.senderId != message.receiverId) {
              currentUserId = message.senderId;
              break;
            }
          }
          if (currentUserId != null) break;
        }
      }

      if (currentUserId != null) {
        print('🔄 使用用户ID: $currentUserId 刷新会话列表');

        // 重新加载好友列表以确保最新信息
        await fetchFriends(currentUserId);

        // 重新加载消息
        await fetchMessages(currentUserId);

        print('✅ 会话列表刷新完成');
      } else {
        print('⚠️ 无法获取当前用户ID，使用本地数据刷新');
        // 如果无法获取用户ID，只重新排序现有会话
        _sortConversations();
        notifyListeners();
      }
    } catch (e) {
      print('❌ 刷新会话列表失败(保持现状不动): $e');
      // 不再回退到 loadConversations，避免无网时列表顺序变化或卡片丢失
      notifyListeners();
    }
  }

  // 置顶/取消置顶会话
  void togglePinConversation(String conversationId) {
    final index = _conversationList.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversationList[index] = _conversationList[index].copyWith(
        isPinned: !_conversationList[index].isPinned,
      );
      // 更新本地集合并持久化
      if (_conversationList[index].isPinned) {
        _pinnedConvIds.add(conversationId);
      } else {
        _pinnedConvIds.remove(conversationId);
      }
      unawaited(
          _savePinnedConversations(userId: _selfUserId, ids: _pinnedConvIds));
      _sortConversations();
      notifyListeners();
    }
  }

  // 静音/取消静音会话
  void toggleMuteConversation(String conversationId) {
    final index = _conversationList.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversationList[index] = _conversationList[index].copyWith(
        isMuted: !_conversationList[index].isMuted,
      );
      notifyListeners();
    }
  }

  // 删除会话
  void deleteConversation(String conversationId) {
    _conversationList.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  // 标记会话为已读
  void markConversationAsRead(String conversationId) {
    final index = _conversationList.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversationList[index] =
          _conversationList[index].copyWith(unreadCount: 0);
      // 记录最后已读时间并持久化
      final now = DateTime.now();
      _lastReadAt[conversationId] = now;
      unawaited(
          _saveLastReadAt(conversationId: conversationId, userId: _selfUserId));
      // 清理该会话的WS缓存，避免下一次刷新误判
      try {
        _recentWebSocketMessages.remove(conversationId);
      } catch (_) {}
      // 更新应用图标徽章
      _notificationService.updateBadgeCount(totalUnreadCount);
      notifyListeners();
    }
  }

  // 搜索会话
  List<Conversation> searchConversations(String query) {
    if (query.trim().isEmpty) return conversationList;

    final lowercaseQuery = query.toLowerCase();
    return _conversationList.where((conversation) {
      return conversation.displayName.toLowerCase().contains(lowercaseQuery) ||
          conversation.lastMessageText.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // 聊天记录搜索（客户端聚合）
  Future<List<ChatSearchResult>> searchMessages(
      {required int userId,
      required String query,
      int limitPerConv = 3}) async {
    final kw = query.trim();
    if (kw.isEmpty) return [];
    final lower = kw.toLowerCase();
    final results = <ChatSearchResult>[];

    for (final conv in _conversationList) {
      List<Message> messages = _conversations[conv.id] ?? [];
      if (messages.isEmpty) {
        try {
          if (conv.type == ConversationType.group) {
            messages = await _messageService
                .getGroupMessages(int.parse(conv.id), page: 0, size: 50);
          } else {
            messages = await _messageService.getPrivateMessages(
                userId, int.parse(conv.id),
                page: 0, size: 50);
          }
          _conversations[conv.id] = messages;
        } catch (_) {}
      }
      if (messages.isEmpty) continue;

      int picked = 0;
      for (int i = messages.length - 1; i >= 0; i--) {
        final m = messages[i];
        final text = m.content.toLowerCase();
        if (text.contains(lower)) {
          final idx = text.indexOf(lower);
          final start = idx - 10 < 0 ? 0 : idx - 10;
          final end = idx + kw.length + 10 > m.content.length
              ? m.content.length
              : idx + kw.length + 10;
          final snippet = m.content.substring(start, end);
          results.add(ChatSearchResult(
            conversationId: conv.id,
            isGroup: conv.type == ConversationType.group,
            title: conv.displayName,
            snippet: snippet,
            time: m.createdAt,
          ));
          picked++;
          if (picked >= limitPerConv) break;
        }
      }
    }

    results.sort((a, b) => b.time.compareTo(a.time));
    return results;
  }

  // 排序会话列表
  void _sortConversations() {
    final freeze = _shouldFreezeOrder();
    if (freeze) {
      // 冻结模式：仅做“稳定置顶”，保持两个分区内的相对顺序不变
      final pinned = _conversationList.where((c) => c.isPinned).toList();
      final others = _conversationList.where((c) => !c.isPinned).toList();
      _conversationList
        ..clear()
        ..addAll(pinned)
        ..addAll(others);
      return;
    }
    _conversationList.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.lastActivity.compareTo(a.lastActivity);
    });
  }

  bool _shouldFreezeOrder() {
    try {
      final offline = NetworkManager().isOffline;
      final serverDown = ServerHealth().status == ServerStatus.error;
      return offline || serverDown;
    } catch (_) {
      return false;
    }
  }

  // 去重会话列表（按会话ID）
  void _deduplicateConversations() {
    final map = <String, Conversation>{};
    for (final c in _conversationList) {
      map[c.id] = c; // 后出现的覆盖前面的，保持较新的数据
    }
    _conversationList
      ..clear()
      ..addAll(map.values);
  }

  Future<void> _loadCachedSnapshot(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_snapshotKeyPrefix$userId');
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;

      final friendsJson = data['friends'];
      if (friendsJson is List) {
        _friends = friendsJson
            .whereType<Map>()
            .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final groupsJson = data['groups'];
      if (groupsJson is List) {
        _groups = groupsJson.map((g) {
          if (g is Map) return Map<String, dynamic>.from(g);
          return g;
        }).toList();
      }

      final convListJson = data['conversationList'];
      if (convListJson is List) {
        _conversationList = convListJson
            .whereType<Map>()
            .map((e) =>
                Conversation.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final convMapJson = data['conversations'];
      if (convMapJson is Map) {
        final restored = <String, List<Message>>{};
        convMapJson.forEach((key, value) {
          if (value is List) {
            final list = value
                .whereType<Map>()
                .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            restored[key] = list;
          }
        });
        if (restored.isNotEmpty) {
          _conversations
            ..clear()
            ..addAll(restored);
        }
      }

      if (_conversationList.isNotEmpty || _friends.isNotEmpty) {
        _deduplicateConversations();
        _applyPinnedFromLocal();
        _sortConversations();
        notifyListeners();
      }
    } catch (e) {
      print('读取聊天缓存失败: $e');
    }
  }

  Future<void> _cacheSnapshot(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'friends': _friends.map((f) => f.toJson()).toList(),
        'groups': _groups
            .map((g) => g is Map ? g : {})
            .toList(),
        'conversationList':
            _conversationList.map((c) => c.toJson()).toList(),
        'conversations': _conversations.map((key, list) {
          final trimmed = list.length > _maxCachedMessages
              ? list.sublist(list.length - _maxCachedMessages)
              : List<Message>.from(list);
          return MapEntry(
              key, trimmed.map((m) => m.toJson()).toList());
        }),
      };
      await prefs.setString(
          '$_snapshotKeyPrefix$userId', jsonEncode(payload));
    } catch (e) {
      print('缓存聊天快照失败: $e');
    }
  }

  // 生成模拟会话数据
  List<Conversation> _generateMockConversations() {
    final users = [
      User(
        id: 1,
        username: 'alice',
        email: 'alice@example.com',
        nickname: '爱丽丝',
        avatar: null,
        status: UserStatus.online,
      ),
      User(
        id: 2,
        username: 'bob',
        email: 'bob@example.com',
        nickname: '鲍勃',
        avatar: null,
        status: UserStatus.offline,
      ),
      User(
        id: 3,
        username: 'charlie',
        email: 'charlie@example.com',
        nickname: '查理',
        avatar: null,
        status: UserStatus.online,
      ),
      User(
        id: 4,
        username: 'diana',
        email: 'diana@example.com',
        nickname: '黛安娜',
        avatar: null,
        status: UserStatus.online,
      ),
      User(
        id: 5,
        username: 'eve',
        email: 'eve@example.com',
        nickname: '夏娃',
        avatar: null,
        status: UserStatus.offline,
      ),
    ];

    return [
      Conversation(
        id: '1',
        type: ConversationType.private,
        name: '',
        participants: [users[0]],
        lastMessage: Message(
          id: 1,
          senderId: users[0].id,
          senderName: users[0].nickname ?? users[0].username,
          receiverId: 1, // 假设当前用户ID为1
          content: '你好！最近怎么样？',
          type: MessageType.text,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        unreadCount: 2,
        lastActivity: DateTime.now().subtract(const Duration(minutes: 5)),
        isPinned: true,
      ),
      Conversation(
        id: '2',
        type: ConversationType.private,
        name: '',
        participants: [users[1]],
        lastMessage: Message(
          id: 2,
          senderId: users[1].id,
          senderName: users[1].nickname ?? users[1].username,
          receiverId: 1, // 假设当前用户ID为1
          content: '今天天气不错',
          type: MessageType.text,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        unreadCount: 0,
        lastActivity: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Conversation(
        id: '3',
        type: ConversationType.group,
        name: '工作小组',
        participants: [users[2], users[3], users[4]],
        lastMessage: Message(
          id: 3,
          senderId: users[2].id,
          senderName: users[2].nickname ?? users[2].username,
          groupId: 3, // 群聊ID
          content: '明天开会记得带资料',
          type: MessageType.text,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        unreadCount: 5,
        lastActivity: DateTime.now().subtract(const Duration(hours: 2)),
        isMuted: true,
      ),
      Conversation(
        id: '4',
        type: ConversationType.private,
        name: '',
        participants: [users[3]],
        lastMessage: Message(
          id: 4,
          senderId: users[3].id,
          senderName: users[3].nickname ?? users[3].username,
          receiverId: 1, // 假设当前用户ID为1
          content: '[图片]',
          type: MessageType.image,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        unreadCount: 1,
        lastActivity: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Conversation(
        id: '5',
        type: ConversationType.group,
        name: '朋友圈',
        participants: [users[0], users[1], users[4]],
        lastMessage: Message(
          id: 5,
          senderId: users[4].id,
          senderName: users[4].nickname ?? users[4].username,
          groupId: 5, // 群聊ID
          content: '周末一起去看电影吗？',
          type: MessageType.text,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        unreadCount: 0,
        lastActivity: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 情绪监测相关方法

  /// 检查是否需要显示情绪警告
  Future<bool> shouldShowEmotionAlert(int userId, int friendId) async {
    try {
      return await _emotionService.checkEmotionAlert(userId, friendId);
    } catch (e) {
      print('检查情绪警告失败: $e');
      return false;
    }
  }

  /// 获取情绪警告信息
  Future<UserEmotionAlert?> getEmotionAlertInfo(
      int userId, int friendId) async {
    try {
      return await _emotionService.getEmotionAlertInfo(userId, friendId);
    } catch (e) {
      print('获取情绪警告信息失败: $e');
      return null;
    }
  }

  /// 为消息列表添加情绪监测信息（优化版本）
  Future<List<Message>> enrichMessagesWithEmotionData(
      List<Message> messages, int currentUserId) async {
    if (messages.isEmpty) return messages;

    final enrichedMessages = <Message>[];

    // 获取所有需要检查情绪的好友ID（去重）
    final friendIds = messages
        .where((msg) => !msg.isFromMe(currentUserId))
        .map((msg) => msg.senderId)
        .toSet()
        .toList();

    // 批量获取所有好友的情绪警告信息
    final Map<int, UserEmotionAlert?> emotionAlerts = {};

    try {
      // 并行获取所有好友的情绪警告信息
      final futures = friendIds.map((friendId) async {
        try {
          final shouldShow =
              await shouldShowEmotionAlert(friendId, currentUserId);
          if (shouldShow) {
            final alertInfo =
                await getEmotionAlertInfo(friendId, currentUserId);
            return MapEntry(friendId, alertInfo);
          }
          return MapEntry(friendId, null);
        } catch (e) {
          print('获取好友 $friendId 的情绪数据失败: $e');
          return MapEntry(friendId, null);
        }
      });

      final results = await Future.wait(futures);
      for (final entry in results) {
        emotionAlerts[entry.key] = entry.value;
      }
    } catch (e) {
      print('批量获取情绪数据失败: $e');
    }

    // 找到每个好友的最新消息，只在最新消息上显示情绪提醒
    // 这样每次好友发送新消息时，如果达到阈值就会在新消息上显示提醒
    final Map<int, int> latestMessageIndexByFriend = {};
    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (!message.isFromMe(currentUserId)) {
        final friendId = message.senderId;
        if (!latestMessageIndexByFriend.containsKey(friendId)) {
          latestMessageIndexByFriend[friendId] = i;
        }
      }
    }

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];

      if (!message.isFromMe(currentUserId)) {
        final friendId = message.senderId;
        final alertInfo = emotionAlerts[friendId];
        final isLatestFromFriend = latestMessageIndexByFriend[friendId] == i;

        // 只在该好友的最新消息上显示情绪提醒
        if (alertInfo != null &&
            alertInfo.keywordCount >= 3 &&
            isLatestFromFriend) {
          print(
              '🔔 为最新消息ID ${message.id} 添加情绪提醒，好友ID: $friendId，关键词计数: ${alertInfo.keywordCount}');

          final enrichedMessage = message.copyWith(
            hasEmotionAlert: true,
            emotionTipText: alertInfo.emotionTipText,
            isThirdEmotionKeyword: true,
          );
          enrichedMessages.add(enrichedMessage);
          continue;
        } else {
          if (alertInfo != null && alertInfo.keywordCount >= 3) {
            print(
                '📝 好友ID $friendId 有警告信息但不是最新消息，关键词计数: ${alertInfo.keywordCount}');
          }
        }
      }

      // 如果没有情绪警告，添加原始消息
      enrichedMessages.add(message);
    }

    return enrichedMessages;
  }

  /// 关闭情绪警告
  Future<bool> dismissEmotionAlert(int userId, int friendId) async {
    try {
      return await _emotionService.dismissAlert(userId, friendId);
    } catch (e) {
      print('关闭情绪警告失败: $e');
      return false;
    }
  }

  // 清理WebSocket消息缓存
  void _cleanupWebSocketCache() {
    final cutoffTime = DateTime.now().subtract(const Duration(minutes: 10));
    final keysToRemove = <String>[];

    _recentWebSocketMessages.forEach((key, message) {
      if (message.createdAt.isBefore(cutoffTime)) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _recentWebSocketMessages.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      print('🧹 清理了 ${keysToRemove.length} 个过期的WebSocket消息缓存');
    }
  }

  @override
  void dispose() {
    // _wsChannel?.sink.close();
    super.dispose();
  }
}
