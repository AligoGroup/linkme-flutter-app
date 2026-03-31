import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';
import '../models/user_emotion_alert.dart';

class EmotionService {
  final ApiClient _apiClient = ApiClient();

  /// 检查是否需要显示情绪警告
  Future<bool> checkEmotionAlert(int userId, int friendId) async {
    try {
      print('🔍 检查情绪警告 - 用户ID: $userId, 好友ID: $friendId');
      final response = await _apiClient.dio.get(
        '${ApiConfig.emotion}/alert/$userId/$friendId'
      );
      
      print('📡 API响应: ${response.data}');
      
      final apiResponse = ApiResponse<bool>.fromJson(
        response.data,
        (data) => data as bool,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        print('✅ 情绪检查结果: ${apiResponse.data}');
        return apiResponse.data!;
      }
      print('❌ 情绪检查失败或无数据');
      return false;
    } catch (e) {
      print('检查情绪警告失败: $e');
      return false;
    }
  }

  /// 获取情绪警告详细信息
  Future<UserEmotionAlert?> getEmotionAlertInfo(int userId, int friendId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.emotion}/alert-info/$userId/$friendId'
      );
      
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        return UserEmotionAlert.fromJson(apiResponse.data!);
      }
      return null;
    } catch (e) {
      print('获取情绪警告信息失败: $e');
      return null;
    }
  }

  /// 获取用户的所有情绪警告
  Future<List<UserEmotionAlert>> getUserEmotionAlerts(int friendId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.emotion}/alerts/$friendId'
      );
      
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) => UserEmotionAlert.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('获取情绪警告列表失败: $e');
      return [];
    }
  }

  /// 关闭情绪警告
  Future<bool> dismissAlert(int userId, int friendId) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConfig.emotion}/dismiss/$userId/$friendId'
      );
      
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      
      return apiResponse.success;
    } catch (e) {
      print('关闭情绪警告失败: $e');
      return false;
    }
  }
}