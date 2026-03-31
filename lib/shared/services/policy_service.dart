import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../models/platform_policy.dart';

class PolicyService {
  final ApiClient _api = ApiClient();

  Future<List<PlatformPolicy>> list({bool? enabled}) async {
    final res = await _api.dio.get(
      '${ApiConfig.baseUrl}/policies',
      queryParameters: enabled == null ? null : { 'enabled': enabled },
      options: Options(headers: { 'Accept': 'application/json' }),
    );
    final data = res.data;
    if (data is Map && data['success'] == true) {
      final list = (data['data']?['policies'] as List? ?? const []);
      return list.map((e) => PlatformPolicy.fromJson(e)).toList();
    }
    return [];
  }

  Future<PlatformPolicy?> getByCode(String code) async {
    final res = await _api.dio.get(
      '${ApiConfig.baseUrl}/policies/$code',
      options: Options(headers: { 'Accept': 'application/json' }),
    );
    final data = res.data;
    if (data is Map && data['success'] == true) {
      return PlatformPolicy.fromJson(data['data']);
    }
    return null;
  }
}

