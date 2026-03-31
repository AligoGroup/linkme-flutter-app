import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../models/favorite.dart';
import '../models/message.dart';
import '../services/favorite_service.dart';

class FavoriteProvider extends ChangeNotifier {
  final List<Favorite> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  final FavoriteService _favoriteService = FavoriteService();

  // Getters
  List<Favorite> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 加载收藏列表
  Future<void> loadFavorites(int ownerId, {int page = 0, int size = 20}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 加载收藏列表: ownerId=$ownerId, page=$page');
      
      final favorites = await _favoriteService.getFavorites(ownerId, page: page, size: size);
      
      if (page == 0) {
        _favorites.clear();
        _favorites.addAll(favorites);
      } else {
        _favorites.addAll(favorites);
      }
      
      print('✅ 成功加载 ${favorites.length} 个收藏');
      _errorMessage = null;
      
    } catch (e) {
      print('❌ 加载收藏失败: $e');
      _errorMessage = '加载收藏失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 收藏消息
  Future<bool> favoriteMessage({
    required int ownerId,
    required int messageId,
    required String content,
    int? targetUserId,
    int? targetGroupId,
    String? targetName,
    String? targetAvatar,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _errorMessage = null;
      print('🔄 收藏消息: messageId=$messageId');
      
      final favorite = await _favoriteService.favoriteMessage(
        ownerId: ownerId,
        messageId: messageId,
        content: content,
        targetUserId: targetUserId,
        targetGroupId: targetGroupId,
        targetName: targetName,
        targetAvatar: targetAvatar,
        metadata: metadata,
      );

      if (favorite != null) {
        _favorites.insert(0, favorite);
        print('✅ 消息收藏成功');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 收藏消息失败: $e');
      _errorMessage = '收藏失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 收藏链接
  Future<bool> favoriteLink({
    required int ownerId,
    required String title,
    required String url,
    String? description,
  }) async {
    try {
      _errorMessage = null;
      print('🔄 收藏链接: $title');
      
      final favorite = await _favoriteService.favoriteLink(
        ownerId: ownerId,
        title: title,
        url: url,
        description: description,
      );

      if (favorite != null) {
        _favorites.insert(0, favorite);
        print('✅ 链接收藏成功');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 收藏链接失败: $e');
      _errorMessage = '收藏失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 收藏文本
  Future<bool> favoriteText({
    required int ownerId,
    required String content,
    String? title,
  }) async {
    try {
      _errorMessage = null;
      print('🔄 收藏文本: ${content.substring(0, content.length > 20 ? 20 : content.length)}...');
      
      final favorite = await _favoriteService.favoriteText(
        ownerId: ownerId,
        content: content,
        title: title,
      );

      if (favorite != null) {
        _favorites.insert(0, favorite);
        print('✅ 文本收藏成功');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 收藏文本失败: $e');
      _errorMessage = '收藏失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 删除收藏
  Future<bool> deleteFavorite(int favoriteId, int ownerId) async {
    try {
      print('🔄 删除收藏: $favoriteId');
      
      final success = await _favoriteService.deleteFavorite(favoriteId, ownerId);
      
      if (success) {
        _favorites.removeWhere((favorite) => favorite.id == favoriteId);
        print('✅ 收藏删除成功');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ 删除收藏失败: $e');
      _errorMessage = '删除收藏失败: $e';
      notifyListeners();
      return false;
    }
  }

  // 检查消息是否已收藏
  bool isMessageFavorited(int messageId) {
    return _favorites.any((favorite) => favorite.messageId == messageId);
  }

  // 通过类型获取收藏
  List<Favorite> getFavoritesByType(FavoriteType type) {
    return _favorites.where((favorite) => favorite.type == type).toList();
  }

  // 搜索收藏
  List<Favorite> searchFavorites(String query) {
    if (query.trim().isEmpty) return _favorites;
    
    final lowerQuery = query.toLowerCase();
    return _favorites.where((favorite) {
      return favorite.content.toLowerCase().contains(lowerQuery) ||
             (favorite.title?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
