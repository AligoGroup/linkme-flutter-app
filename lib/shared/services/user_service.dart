import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';
import '../models/user.dart';

class UserService {
  final ApiClient _api = ApiClient();

  Future<List<User>> search(String keyword) async {
    final trimmed = keyword.trim();
    if (kDebugMode) {
      print(
          '🔍 [UserService] 准备搜索用户 keyword="$trimmed" base=${_api.dio.options.baseUrl}');
    }
    try {
      final res = await _api.dio.get(
        '${ApiConfig.users}/search',
        queryParameters: {'keyword': trimmed},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (kDebugMode) {
        print(
            '🔍 [UserService] 请求完成 status=${res.statusCode} url=${res.realUri}');
      }
      final api =
          ApiResponse<List<dynamic>>.fromJson(res.data, (d) => d as List<dynamic>);
      if (api.success && api.data != null) {
        if (kDebugMode) {
          print(
              '🔍 [UserService] 收到 ${api.data!.length} 个结果');
        }
        return api.data!
            .map((e) => User.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (kDebugMode) {
        print(
            '⚠️ [UserService] 搜索失败 success=${api.success} message=${api.message}');
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print(
            '❌ [UserService] Dio异常: ${e.message} data=${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UserService] 未知异常: $e');
      }
      rethrow;
    }
  }
}
