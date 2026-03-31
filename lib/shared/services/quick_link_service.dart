import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';
import '../models/quick_link.dart';

class QuickLinkService {
  final ApiClient _apiClient = ApiClient();

  /// 获取私聊快捷链接
  Future<List<QuickLink>> getQuickLinks(int userId, int peerUserId) async {
    try {
      print('📡 API调用: GET ${ApiConfig.quickLinks}/$userId/$peerUserId');
      
      final response = await _apiClient.dio.get(
        '${ApiConfig.quickLinks}/$userId/$peerUserId'
      );
      
      print('📡 API响应状态: ${response.statusCode}');
      print('📡 API响应数据: ${response.data}');
      
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        final quickLinks = apiResponse.data!
            .map((json) => QuickLink.fromJson(json as Map<String, dynamic>))
            .toList();
        print('✅ 成功解析 ${quickLinks.length} 个快捷链接');
        return quickLinks;
      }
      print('⚠️ API调用成功但没有数据');
      return [];
    } catch (e) {
      print('❌ 获取快捷链接失败: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      
      // 返回空列表而不是抛出异常
      return [];
    }
  }

  /// 获取群聊快捷链接
  Future<List<QuickLink>> getGroupQuickLinks(int userId, int groupId) async {
    try {
      print('📡 API调用: GET ${ApiConfig.quickLinks}/group/$userId/$groupId');
      
      final response = await _apiClient.dio.get(
        '${ApiConfig.quickLinks}/group/$userId/$groupId'
      );
      
      print('📡 API响应状态: ${response.statusCode}');
      print('📡 API响应数据: ${response.data}');
      
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        final quickLinks = apiResponse.data!
            .map((json) => QuickLink.fromJson(json as Map<String, dynamic>))
            .toList();
        print('✅ 成功解析群聊 ${quickLinks.length} 个快捷链接');
        return quickLinks;
      }
      print('⚠️ 群聊API调用成功但没有数据');
      return [];
    } catch (e) {
      print('❌ 获取群聊快捷链接失败: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      
      // 返回空列表而不是抛出异常
      return [];
    }
  }

  /// 添加私聊快捷链接
  Future<QuickLink?> addQuickLink({
    required int userId,
    required int peerUserId,
    required String title,
    required String url,
    String? color,
  }) async {
    try {
      print('📡 API调用: POST ${ApiConfig.quickLinks}/add');
      print('📡 请求数据: userId=$userId, peerUserId=$peerUserId, title=$title, url=$url');
      
      final response = await _apiClient.dio.post(
        '${ApiConfig.quickLinks}/add',
        data: {
          'userId': userId,
          'peerUserId': peerUserId,
          'title': title,
          'url': url,
          if (color != null) 'color': color,
        },
      );
      
      print('📡 API响应状态: ${response.statusCode}');
      print('📡 API响应数据: ${response.data}');
      
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        final quickLink = QuickLink.fromJson(apiResponse.data!);
        print('✅ 快捷链接添加成功: ${quickLink.title}');
        return quickLink;
      }
      print('⚠️ 添加快捷链接API调用成功但没有返回数据');
      return null;
    } catch (e) {
      print('❌ 添加快捷链接失败: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      return null;
    }
  }

  /// 添加群聊快捷链接
  Future<QuickLink?> addGroupQuickLink({
    required int userId,
    required int groupId,
    required String title,
    required String url,
    String? color,
  }) async {
    try {
      print('📡 API调用: POST ${ApiConfig.quickLinks}/add (群聊)');
      print('📡 请求数据: userId=$userId, groupId=$groupId, title=$title, url=$url');
      
      final response = await _apiClient.dio.post(
        '${ApiConfig.quickLinks}/add',
        data: {
          'userId': userId,
          'groupId': groupId,
          'title': title,
          'url': url,
          if (color != null) 'color': color,
        },
      );
      
      print('📡 API响应状态: ${response.statusCode}');
      print('📡 API响应数据: ${response.data}');
      
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        final quickLink = QuickLink.fromJson(apiResponse.data!);
        print('✅ 群聊快捷链接添加成功: ${quickLink.title}');
        return quickLink;
      }
      print('⚠️ 添加群聊快捷链接API调用成功但没有返回数据');
      return null;
    } catch (e) {
      print('❌ 添加群聊快捷链接失败: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      return null;
    }
  }

  /// 删除快捷链接
  Future<bool> deleteQuickLink(int linkId, int userId) async {
    try {
      print('📡 API调用: DELETE ${ApiConfig.quickLinks}/$linkId?userId=$userId');
      
      final response = await _apiClient.dio.delete(
        '${ApiConfig.quickLinks}/$linkId',
        queryParameters: {'userId': userId},
      );
      
      print('📡 API响应状态: ${response.statusCode}');
      print('📡 API响应数据: ${response.data}');
      
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      
      if (apiResponse.success) {
        print('✅ 快捷链接删除成功');
        return true;
      }
      print('⚠️ 删除快捷链接API调用失败: ${apiResponse.message}');
      return false;
    } catch (e) {
      print('❌ 删除快捷链接失败: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      return false;
    }
  }
}