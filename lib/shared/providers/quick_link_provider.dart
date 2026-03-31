import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/quick_link.dart';
import '../services/quick_link_service.dart';
import '../services/group_service.dart';
import '../../core/utils/url_launcher_helper.dart';

class QuickLinkProvider extends ChangeNotifier {
  final Map<String, List<QuickLink>> _quickLinks = {};
  bool _isLoading = false;
  String? _errorMessage;
  
  final QuickLinkService _quickLinkService = QuickLinkService();
  final GroupService _groupService = GroupService();

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<QuickLink> getQuickLinks(String conversationId) {
    return _quickLinks[conversationId] ?? [];
  }

  // 加载快捷链接
  Future<void> loadQuickLinks(int userId, String conversationId, {bool isGroup = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 加载快捷链接: userId=$userId, conversationId=$conversationId, isGroup=$isGroup');
      
      List<QuickLink> quickLinks = [];
      
      try {
        if (isGroup) {
          // 群聊：App 端合并所有成员创建的快捷链接，实现“群内共享可见”；
          // 其他端保持原逻辑（只看自己的），避免影响桌面/Web 已完成布局。
          final bool isMobileApp = !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
          final int groupId = int.parse(conversationId);
          if (isMobileApp) {
            // 获取群成员
            final members = await _groupService.getGroupMembers(groupId);
            final memberIds = members
                .map((m) => m['id'])
                .whereType<num>()
                .map((n) => n.toInt())
                .toList();
            // 若接口异常或成员为空，至少加载当前用户的
            if (memberIds.isEmpty) {
              quickLinks = await _quickLinkService.getGroupQuickLinks(userId, groupId);
            } else {
              // 并发请求每个成员的群快捷链接，合并去重
              final futures = memberIds.map((uid) => _quickLinkService.getGroupQuickLinks(uid, groupId));
              final results = await Future.wait<List<QuickLink>>(futures, eagerError: false);
              final Map<int, QuickLink> map = {};
              for (final list in results) {
                for (final q in list) { map[q.id] = q; }
              }
              quickLinks = map.values.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }
          } else {
            quickLinks = await _quickLinkService.getGroupQuickLinks(userId, groupId);
          }
        } else {
          // 私聊：为确保“双方都可见”，在 App 端合并双方的快捷链接；
          // 其他端（Web/桌面）保持原行为，避免影响已完成的布局与逻辑。
          final bool isMobileApp = !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

          final int peerId = int.parse(conversationId);
          final List<QuickLink> mine = await _quickLinkService.getQuickLinks(userId, peerId);

          if (isMobileApp) {
            // 对方的（以对方为 userId）
            final List<QuickLink> theirs = await _quickLinkService.getQuickLinks(peerId, userId);
            // 合并并去重（按 id）
            final Map<int, QuickLink> map = { for (final q in [...mine, ...theirs]) q.id: q };
            quickLinks = map.values.toList();
            // 按创建时间倒序，保证最新的在前
            quickLinks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else {
            quickLinks = mine;
          }
        }
      } catch (apiError) {
        print('⚠️ API调用失败，暂时显示空列表: $apiError');
        // API调用失败时，暂时显示空列表而不是mock数据
        quickLinks = [];
      }
      
      _quickLinks[conversationId] = quickLinks;
      print('✅ 加载完成，共 ${quickLinks.length} 个快捷链接');
      
      _errorMessage = null;
    } catch (e) {
      print('❌ 加载快捷链接失败: $e');
      _errorMessage = '加载快捷链接失败: $e';
      _quickLinks[conversationId] = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 添加快捷链接
  Future<bool> addQuickLink({
    required int userId,
    required String conversationId,
    required String title,
    required String url,
    required bool isGroup,
    String? color,
  }) async {
    try {
      print('🔄 添加快捷链接: $title -> $url');
      
      QuickLink? newQuickLink;
      
      if (isGroup) {
        newQuickLink = await _quickLinkService.addGroupQuickLink(
          userId: userId,
          groupId: int.parse(conversationId),
          title: title,
          url: url,
          color: color,
        );
      } else {
        newQuickLink = await _quickLinkService.addQuickLink(
          userId: userId,
          peerUserId: int.parse(conversationId),
          title: title,
          url: url,
          color: color,
        );
      }

      if (newQuickLink != null) {
        final currentLinks = _quickLinks[conversationId] ?? [];
        _quickLinks[conversationId] = [newQuickLink, ...currentLinks];
        
        print('✅ 快捷链接添加成功');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 添加快捷链接失败: $e');
      _errorMessage = '添加快捷链接失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 删除快捷链接
  Future<bool> deleteQuickLink(int userId, String conversationId, int quickLinkId) async {
    try {
      print('🔄 删除快捷链接: $quickLinkId');
      
      final success = await _quickLinkService.deleteQuickLink(quickLinkId, userId);
      
      if (success) {
        final currentLinks = _quickLinks[conversationId] ?? [];
        _quickLinks[conversationId] = currentLinks.where(
          (link) => link.id != quickLinkId,
        ).toList();
        
        print('✅ 快捷链接删除成功');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 删除快捷链接失败: $e');
      _errorMessage = '删除快捷链接失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 打开快捷链接
  void openQuickLink(BuildContext context, String url, {String? title}) {
    UrlLauncherHelper.openUrlDirectly(context, url, title: title);
  }

  // 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 生成模拟数据
  List<QuickLink> _generateMockQuickLinks(String conversationId, bool isGroup) {
    final now = DateTime.now();
    return [
      QuickLink(
        id: 1,
        userId: 1,
        peerUserId: isGroup ? null : int.tryParse(conversationId),
        groupId: isGroup ? int.tryParse(conversationId) : null,
        title: 'Flutter 官网',
        url: 'https://flutter.dev',
        color: '#E3F2FD',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      QuickLink(
        id: 2,
        userId: 1,
        peerUserId: isGroup ? null : int.tryParse(conversationId),
        groupId: isGroup ? int.tryParse(conversationId) : null,
        title: 'GitHub',
        url: 'https://github.com',
        color: '#F3E5F5',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      QuickLink(
        id: 3,
        userId: 1,
        peerUserId: isGroup ? null : int.tryParse(conversationId),
        groupId: isGroup ? int.tryParse(conversationId) : null,
        title: 'Dart 文档',
        url: 'https://dart.dev',
        color: '#E8F5E8',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  // 生成随机浅色
  String _generateRandomColor() {
    final colors = [
      '#FFE3E3', '#E3F2FD', '#F3E5F5', '#E8F5E8',
      '#FFF3E0', '#F1F8E9', '#E0F2F1', '#F9F9F9',
    ];
    colors.shuffle();
    return colors.first;
  }
}
