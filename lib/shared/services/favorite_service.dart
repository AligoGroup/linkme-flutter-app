import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';
import '../models/favorite.dart';

class FavoriteService {
  final ApiClient _apiClient = ApiClient();

  /// 添加收藏（发送给后端的字段做白名单过滤，避免 LocalDateTime 解析失败或多余字段导致 500）
  Future<Favorite?> addFavorite(Favorite favorite) async {
    try {
      // 仅发送后端实体可识别的字段；不发送 createdAt/title/url/description 等额外字段
      final String typeStr = favorite.type.name.toUpperCase() == 'TEXT'
          ? 'MESSAGE' // 后端未定义 TEXT，统一折叠为 MESSAGE
          : favorite.type.name.toUpperCase();
      final Map<String, dynamic> payload = {
        'ownerId': favorite.ownerId,
        'userId': favorite.ownerId, // 兼容后端可能使用的 userId 字段
        if (favorite.messageId != null) 'messageId': favorite.messageId,
        if (favorite.targetUserId != null) 'targetUserId': favorite.targetUserId,
        if (favorite.targetGroupId != null) 'targetGroupId': favorite.targetGroupId,
        'type': typeStr,
        'content': favorite.content,
        if (favorite.targetName != null && favorite.targetName!.isNotEmpty) 'targetName': favorite.targetName,
        if (favorite.targetAvatar != null && favorite.targetAvatar!.isNotEmpty) 'targetAvatar': favorite.targetAvatar,
      };
      final String? extraPayload = favorite.extra ?? favorite.url;
      if (extraPayload != null && extraPayload.isNotEmpty) {
        payload['extra'] = extraPayload;
      }

      final response = await _apiClient.dio.post(
        ApiConfig.favorites,
        data: payload,
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return Favorite.fromJson(apiResponse.data!);
      }
      return null;
    } on DioException catch (e) {
      // 打印更详细的错误，便于定位 500 的真因
      print('添加收藏失败: DioException ${e.response?.statusCode} ${e.response?.data}');
      return null;
    } catch (e) {
      print('添加收藏失败: $e');
      return null;
    }
  }

  /// 获取用户收藏列表
  Future<List<Favorite>> getFavorites(int ownerId, {int page = 0, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.favorites}/$ownerId',
        queryParameters: {
          'page': page,
          'size': size,
        },
      );
      
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) => Favorite.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('获取收藏列表失败: $e');
      return [];
    }
  }

  /// 删除收藏
  Future<bool> deleteFavorite(int favoriteId, int ownerId) async {
    try {
      final response = await _apiClient.dio.delete(
        '${ApiConfig.favorites}/$favoriteId/$ownerId'
      );
      
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      
      return apiResponse.success;
    } catch (e) {
      print('删除收藏失败: $e');
      return false;
    }
  }

  /// 收藏消息
  Future<Favorite?> favoriteMessage({
    required int ownerId,
    required int messageId,
    required String content,
    int? targetUserId,
    int? targetGroupId,
    String? targetName,
    String? targetAvatar,
    Map<String, dynamic>? metadata,
  }) async {
    final favorite = Favorite(
      id: 0, // 服务端会生成
      ownerId: ownerId,
      messageId: messageId,
      targetUserId: targetUserId,
      targetGroupId: targetGroupId,
      type: FavoriteType.message,
      content: content,
      targetName: targetName,
      targetAvatar: targetAvatar,
      extra: metadata != null ? jsonEncode(metadata) : null,
      createdAt: DateTime.now(),
    );
    
    return await addFavorite(favorite);
  }

  /// 收藏链接
  Future<Favorite?> favoriteLink({
    required int ownerId,
    required String title,
    required String url,
    String? description,
  }) async {
    final favorite = Favorite(
      id: 0, // 服务端会生成
      ownerId: ownerId,
      type: FavoriteType.link,
      content: title,
      title: title,
      description: description,
      extra: jsonEncode({
        'linkUrl': url,
        if (description != null && description.isNotEmpty) 'description': description,
      }),
      createdAt: DateTime.now(),
    );
    
    return await addFavorite(favorite);
  }

  /// 收藏文本
  Future<Favorite?> favoriteText({
    required int ownerId,
    required String content,
    String? title,
  }) async {
    final favorite = Favorite(
      id: 0, // 服务端会生成
      ownerId: ownerId,
      type: FavoriteType.text,
      content: content,
      title: title,
      extra: jsonEncode({
        'senderName': title,
      }),
      createdAt: DateTime.now(),
    );
    
    return await addFavorite(favorite);
  }
}
