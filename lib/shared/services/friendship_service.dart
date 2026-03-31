import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';
import '../models/user.dart';

class FriendshipService {
  final ApiClient _apiClient = ApiClient();

  /// 获取好友列表
  Future<List<User>> getFriends(int userId) async {
    print('🌐 FriendshipService.getFriends 开始执行，用户ID: $userId');
    try {
      final url = '${ApiConfig.friends}/$userId';
      print('🌐 请求URL: $url');
      print('🌐 当前ApiConfig.friends: ${ApiConfig.friends}');

      print('🌐 发送GET请求...');
      final response = await _apiClient.dio.get(url);
      print('🌐 收到HTTP响应，状态码: ${response.statusCode}');
      print('🌐 响应数据: ${response.data}');

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      print(
          '🌐 ApiResponse解析结果: success=${apiResponse.success}, message=${apiResponse.message}');

      if (apiResponse.success && apiResponse.data != null) {
        print('🌐 开始转换用户数据，原始数据长度: ${apiResponse.data!.length}');
        final userList = apiResponse.data!.map((json) {
          print('🌐 转换用户数据: $json');
          return User.fromJson(json as Map<String, dynamic>);
        }).toList();
        print('🌐 用户列表转换完成，最终用户数: ${userList.length}');
        return userList;
      } else {
        print('🌐 API响应失败: ${apiResponse.message}');
        throw Exception(apiResponse.message);
      }
    } catch (e) {
      print('❌ 获取好友列表失败: $e');
      print('❌ 异常类型: ${e.runtimeType}');
      if (e is DioException) {
        print('❌ DioException详情: ${e.response?.data}');
        print('❌ 状态码: ${e.response?.statusCode}');
      }
      throw Exception('获取好友列表失败: $e');
    }
  }

  /// 发送好友申请
  Future<bool> sendFriendRequest(int userId, int friendId) async {
    try {
      final response = await _apiClient.dio
          .post('${ApiConfig.friends}/request/$userId/$friendId');
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      return apiResponse.success;
    } catch (e) {
      print('发送好友申请失败: $e');
      return false;
    }
  }

  /// 同意好友申请
  Future<bool> acceptFriendRequest(int requestId) async {
    try {
      final response =
          await _apiClient.dio.post('${ApiConfig.friends}/accept/$requestId');
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      return apiResponse.success;
    } catch (e) {
      print('同意好友申请失败: $e');
      return false;
    }
  }

  /// 拒绝好友申请
  Future<bool> rejectFriendRequest(int requestId) async {
    try {
      final response =
          await _apiClient.dio.post('${ApiConfig.friends}/reject/$requestId');
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      return apiResponse.success;
    } catch (e) {
      print('拒绝好友申请失败: $e');
      return false;
    }
  }

  /// 获取待处理的好友申请
  Future<List<Map<String, dynamic>>> getPendingRequests(int userId) async {
    try {
      final response =
          await _apiClient.dio.get('${ApiConfig.friends}/requests/$userId');
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) => json as Map<String, dynamic>)
            .toList();
      }
      throw Exception(apiResponse.message);
    } catch (e) {
      print('获取好友申请失败: $e');
      throw Exception('获取好友申请失败: $e');
    }
  }

  /// 我收到的所有申请记录（含状态）
  Future<List<Map<String, dynamic>>> getAllReceived(int userId) async {
    final res = await _apiClient.dio
        .get('${ApiConfig.friends}/requests/received-all/$userId');
    final api = ApiResponse<List<dynamic>>.fromJson(
        res.data, (d) => d as List<dynamic>);
    if (api.success && api.data != null) {
      return api.data!.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  /// 我发出的所有申请记录（含状态）
  Future<List<Map<String, dynamic>>> getAllSent(int userId) async {
    final res = await _apiClient.dio
        .get('${ApiConfig.friends}/requests/sent-all/$userId');
    final api = ApiResponse<List<dynamic>>.fromJson(
        res.data, (d) => d as List<dynamic>);
    if (api.success && api.data != null) {
      return api.data!.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  /// 删除好友
  Future<bool> deleteFriend(int userId, int friendId) async {
    try {
      final response = await _apiClient.dio.delete(
        '${ApiConfig.friends}/$friendId',
        queryParameters: {'userId': userId},
      );
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      return apiResponse.success;
    } catch (e) {
      print('删除好友失败: $e');
      return false;
    }
  }

  /// 获取用户详情
  Future<User> getUserProfile(int userId) async {
    print('🌐 FriendshipService.getUserProfile 开始执行，用户ID: $userId');
    try {
      final url = '${ApiConfig.users}/$userId';
      print('🌐 请求URL: $url');
      print('🌐 当前ApiConfig.users: ${ApiConfig.users}');

      print('🌐 发送GET请求...');
      final response = await _apiClient.dio.get(url);
      print('🌐 收到HTTP响应，状态码: ${response.statusCode}');
      print('🌐 响应数据: ${response.data}');

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      print(
          '🌐 ApiResponse解析结果: success=${apiResponse.success}, message=${apiResponse.message}');

      if (apiResponse.success && apiResponse.data != null) {
        print('🌐 开始转换用户数据: ${apiResponse.data}');
        final user = User.fromJson(apiResponse.data!);
        print('🌐 用户数据转换完成: ${user.username}');
        return user;
      } else {
        print('🌐 API响应失败: ${apiResponse.message}');
        throw Exception(apiResponse.message);
      }
    } catch (e) {
      print('❌ 获取用户详情失败: $e');
      print('❌ 异常类型: ${e.runtimeType}');
      if (e is DioException) {
        print('❌ DioException详情: ${e.response?.data}');
        print('❌ 状态码: ${e.response?.statusCode}');
      }
      throw Exception('获取用户详情失败: $e');
    }
  }

  /// 拉黑好友
  Future<bool> blockFriend(int userId, int friendId) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConfig.friends}/block',
        data: {
          'userId': userId,
          'friendId': friendId,
        },
      );
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      if (!apiResponse.success) {
        throw Exception(apiResponse.message ?? '拉黑好友失败');
      }
      return true;
    } catch (e) {
      print('拉黑好友失败: $e');
      rethrow;
    }
  }

  /// 获取拉黑列表
  Future<List<int>> getBlockedFriends(int userId) async {
    try {
      final response =
          await _apiClient.dio.get('${ApiConfig.friends}/blocks/$userId');
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) {
              if (json is Map<String, dynamic>) {
                return (json['id'] as num).toInt();
              }
              if (json is num) return json.toInt();
              return null;
            })
            .whereType<int>()
            .toList();
      }
      return [];
    } catch (e) {
      print('获取拉黑列表失败: $e');
      return [];
    }
  }
}
