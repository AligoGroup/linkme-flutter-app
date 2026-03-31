import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/app_feature_setting.dart';

class AppFeatureService {
  final ApiClient _api = ApiClient();

  Future<AppFeatureSnapshot> fetchFeatures() async {
    final Response response = await _api.dio.get(
      '/app/features',
      options: Options(headers: {'Accept': 'application/json'}),
    );
    final data = response.data;
    if (data is! Map || data['success'] != true) {
      throw Exception('获取 App 功能配置失败');
    }
    final payload = data['data'] as Map? ?? const {};
    final navList = (payload['nav'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AppFeatureSetting.fromJson(e.cast<String, dynamic>()))
        .toList();
    final moduleList = (payload['modules'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AppFeatureSetting.fromJson(e.cast<String, dynamic>()))
        .toList();
    return AppFeatureSnapshot(nav: navList, modules: moduleList);
  }
}
