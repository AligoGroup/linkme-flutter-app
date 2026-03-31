import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../models/subscription_channel.dart';
import '../models/subscription_article.dart';

class SubscriptionService {
  final ApiClient _api = ApiClient();

  Future<List<SubscriptionChannel>> listChannels({int page = 0, int size = 20}) async {
    final res = await _api.dio.get(
      '${ApiConfig.baseUrl}/subscriptions',
      queryParameters: { 'page': page, 'size': size },
      options: Options(headers: { 'Accept': 'application/json' }),
    );
    final data = res.data;
    if (data is Map && data['success'] == true) {
      final list = (data['data']?['accounts'] as List? ?? const []);
      return list.map((e) => _mapChannel(e)).toList();
    }
    return [];
  }

  Future<List<SubscriptionArticle>> listArticles(int channelId, {int page = 0, int size = 20}) async {
    final res = await _api.dio.get(
      '${ApiConfig.baseUrl}/subscriptions/$channelId/articles',
      queryParameters: { 'page': page, 'size': size },
      options: Options(headers: { 'Accept': 'application/json' }),
    );
    final data = res.data;
    if (data is Map && data['success'] == true) {
      final list = (data['data']?['articles'] as List? ?? const []);
      return list.map((e) => _mapArticle(e)).toList();
    }
    return [];
  }

  Future<SubscriptionArticle?> getArticle(int channelId, int articleId) async {
    final res = await _api.dio.get(
      '${ApiConfig.baseUrl}/subscriptions/$channelId/articles/$articleId',
      options: Options(headers: { 'Accept': 'application/json' }),
    );
    final data = res.data;
    if (data is Map && data['success'] == true) {
      return _mapArticle(data['data']);
    }
    return null;
  }

  SubscriptionChannel _mapChannel(Map json) {
    return SubscriptionChannel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      description: json['intro'] ?? json['description'],
      avatar: json['avatar'],
      official: (json['official'] ?? true) == true,
    );
  }

  SubscriptionArticle _mapArticle(Map json) {
    DateTime _parseTime(v) {
      if (v == null) return DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      final s = v.toString();
      // 支持 "2025-10-01T12:00:00" 或 "2025-10-01 12:00:00"
      return DateTime.tryParse(s.replaceFirst(' ', 'T')) ?? DateTime.now();
    }

    return SubscriptionArticle(
      id: (json['id'] ?? '').toString(),
      channelId: (json['accountId'] ?? json['channelId'] ?? '').toString(),
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      content: json['content'] ?? '',
      cover: json['coverImage'],
      publishedAt: _parseTime(json['publishedAt']),
      official: true,
    );
  }
}

