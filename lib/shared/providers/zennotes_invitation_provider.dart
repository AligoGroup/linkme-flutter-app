import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/zennotes_invitation.dart';
import '../../core/network/websocket_manager.dart';
import '../../features/notes/services/notes_api.dart';

/// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | ZenNotes邀请通知状态管理
/// 管理笔记本协作邀请的接收、存储和显示
class ZenNotesInvitationProvider extends ChangeNotifier {
  ZenNotesInvitationProvider() {
    _listenToWebSocket();
  }

  final List<ZenNotesInvitation> _invitations = [];
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  int? _userId;

  /// 获取所有邀请列表
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | invitations
  List<ZenNotesInvitation> get invitations => List.unmodifiable(_invitations);

  /// 获取未读邀请数量
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | unreadCount
  int get unreadCount => _invitations.where((inv) => !inv.isRead).length;

  /// 设置当前用户ID并从服务器加载邀请列表
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | setUserId | userId
  Future<void> setUserId(int userId) async {
    debugPrint('[ZenNotesInvitationProvider] 设置用户ID: $userId');
    _userId = userId;
    // 先从本地加载缓存
    await _loadInvitationsFromLocal();
    // 然后从服务器加载最新数据
    await loadInvitationsFromServer();
    debugPrint(
        '[ZenNotesInvitationProvider] 用户ID设置完成，当前邀请数: ${_invitations.length}');
  }

  /// 从服务器加载邀请列表
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | loadInvitationsFromServer
  Future<void> loadInvitationsFromServer() async {
    if (_userId == null) return;

    try {
      debugPrint('[ZenNotesInvitationProvider] 从服务器加载邀请列表...');
      final response = await NotesApi.getInvitations(userId: _userId!);

      if (response['success'] == true) {
        final List<dynamic> data = response['data'] as List<dynamic>;

        // 获取本地已读状态
        final prefs = await SharedPreferences.getInstance();
        final readIdsKey = 'zennotes_read_ids_$_userId';
        final readIds = prefs.getStringList(readIdsKey) ?? [];

        // 清空并重新加载
        _invitations.clear();
        for (final json in data) {
          try {
            final invitation = ZenNotesInvitation.fromServerResponse(
              json as Map<String, dynamic>,
              isRead: readIds.contains(json['id'].toString()),
            );
            _invitations.add(invitation);
          } catch (e) {
            debugPrint('[ZenNotesInvitationProvider] 解析邀请失败: $e');
          }
        }

        notifyListeners();
        debugPrint(
            '[ZenNotesInvitationProvider] 从服务器加载了 ${_invitations.length} 条邀请');
      }
    } catch (e) {
      debugPrint('[ZenNotesInvitationProvider] 从服务器加载邀请失败: $e');
    }
  }

  /// 监听WebSocket消息，接收新的邀请通知
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | _listenToWebSocket
  void _listenToWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketManager().messageStream.listen((event) {
      debugPrint(
          '[ZenNotesInvitationProvider] 收到WebSocket消息: ${event['type']}');
      final messageType = event['type'] as String?;

      if (messageType == 'ZENNOTES_INVITATION') {
        try {
          debugPrint('[ZenNotesInvitationProvider] 解析ZenNotes邀请消息: $event');
          final invitation = ZenNotesInvitation.fromWebSocketMessage(event);
          _addInvitation(invitation);
          debugPrint(
              '[ZenNotesInvitationProvider] 成功添加新邀请: ${invitation.notebookTitle}, 邀请人: ${invitation.inviterName}');
        } catch (e, stackTrace) {
          debugPrint('[ZenNotesInvitationProvider] 解析邀请失败: $e');
          debugPrint('[ZenNotesInvitationProvider] 堆栈: $stackTrace');
        }
      }
    });
    debugPrint('[ZenNotesInvitationProvider] WebSocket监听已启动');
  }

  /// 添加新邀请到列表
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | _addInvitation | invitation
  void _addInvitation(ZenNotesInvitation invitation) {
    // 检查是否已存在相同的邀请（根据笔记本ID和邀请人ID）
    final existingIndex = _invitations.indexWhere(
      (inv) =>
          inv.notebookId == invitation.notebookId &&
          inv.inviterId == invitation.inviterId,
    );

    if (existingIndex != -1) {
      // 更新现有邀请
      _invitations[existingIndex] = invitation;
    } else {
      // 添加新邀请到列表开头
      _invitations.insert(0, invitation);
    }

    notifyListeners();
    _saveInvitationsToLocal();
  }

  /// 标记邀请为已读
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | markAsRead | invitationId
  Future<void> markAsRead(String invitationId) async {
    final index = _invitations.indexWhere((inv) => inv.id == invitationId);
    if (index != -1) {
      _invitations[index] = _invitations[index].copyWith(isRead: true);
      notifyListeners();
      await _saveInvitationsToLocal();
      await _saveReadIds();
    }
  }

  /// 保存已读邀请ID列表到本地
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | _saveReadIds
  Future<void> _saveReadIds() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIdsKey = 'zennotes_read_ids_$_userId';
      final readIds =
          _invitations.where((inv) => inv.isRead).map((inv) => inv.id).toList();
      await prefs.setStringList(readIdsKey, readIds);
    } catch (e) {
      debugPrint('[ZenNotesInvitationProvider] 保存已读ID失败: $e');
    }
  }

  /// 标记所有邀请为已读
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | markAllAsRead
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _invitations.length; i++) {
      if (!_invitations[i].isRead) {
        _invitations[i] = _invitations[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
    await _saveInvitationsToLocal();
  }

  /// 删除邀请
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | removeInvitation | invitationId
  Future<void> removeInvitation(String invitationId) async {
    _invitations.removeWhere((inv) => inv.id == invitationId);
    notifyListeners();
    await _saveInvitationsToLocal();
  }

  /// 清空所有邀请
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | clearAll
  Future<void> clearAll() async {
    _invitations.clear();
    notifyListeners();
    await _saveInvitationsToLocal();
  }

  /// 从本地存储加载邀请列表
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | _loadInvitationsFromLocal
  Future<void> _loadInvitationsFromLocal() async {
    if (_userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'zennotes_invitations_$_userId';
      final jsonString = prefs.getString(key);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _invitations.clear();
        _invitations.addAll(
          jsonList.map((json) =>
              ZenNotesInvitation.fromJson(json as Map<String, dynamic>)),
        );
        notifyListeners();
        debugPrint(
            '[ZenNotesInvitationProvider] 从本地加载了 ${_invitations.length} 条邀请');
      }
    } catch (e) {
      debugPrint('[ZenNotesInvitationProvider] 加载本地邀请失败: $e');
    }
  }

  /// 保存邀请列表到本地存储
  /// zennotes_invitation_provider.dart | ZenNotesInvitationProvider | _saveInvitationsToLocal
  Future<void> _saveInvitationsToLocal() async {
    if (_userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'zennotes_invitations_$_userId';
      final jsonList = _invitations.map((inv) => inv.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(key, jsonString);
      debugPrint(
          '[ZenNotesInvitationProvider] 保存了 ${_invitations.length} 条邀请到本地');
    } catch (e) {
      debugPrint('[ZenNotesInvitationProvider] 保存本地邀请失败: $e');
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
