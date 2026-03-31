import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response.dart';

class HotService {
  static final HotService _i = HotService._();
  factory HotService() => _i;
  HotService._();

  final _client = ApiClient();
  void _log(String message) {
    if (kDebugMode) {
      print('🔥 [HotService] $message');
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchMenus() async {
    _log('GET /hot/search-menus');
    return _client.get<List<Map<String, dynamic>>>(
      '/hot/search-menus',
      fromJson: (data) => ((data['items'] as List?) ?? []).cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchCategories() async {
    _log('GET /hot/categories');
    return _client.get<List<Map<String, dynamic>>>(
      '/hot/categories',
      fromJson: (data) => ((data['items'] as List?) ?? []).cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> publishArticle({
    required String title,
    required String summary,
    required String coverImage,
    required String content,
    required String category,
    String? channel,
    String? resourceType,
    int? labelId,
  }) async {
    _log('POST /hot/articles labelId=$labelId');
    return _client.post<Map<String, dynamic>>(
      '/hot/articles',
      data: {
        'title': title,
        'summary': summary,
        'coverImage': coverImage,
        'content': content,
        'category': category,
        'channel': channel,
        'resourceType': resourceType,
        'labelId': labelId,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> updateArticle({
    required int articleId,
    required String title,
    required String summary,
    required String coverImage,
    required String content,
    required String category,
    String? channel,
    String? resourceType,
    int? labelId,
  }) async {
    _log('PUT /hot/articles/$articleId');
    return _client.put<Map<String, dynamic>>(
      '/hot/articles/$articleId',
      data: {
        'title': title,
        'summary': summary,
        'coverImage': coverImage,
        'content': content,
        'category': category,
        'channel': channel,
        'resourceType': resourceType,
        'labelId': labelId,
      },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getArticleDetail(int id) async {
    _log('GET /hot/articles/$id');
    return _client.get<Map<String, dynamic>>(
      '/hot/articles/$id',
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<void>> deleteArticle(int id) async {
    _log('DELETE /hot/articles/$id');
    return _client.delete<void>(
      '/hot/articles/$id',
      fromJson: (_) => null,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> listByCategory({required String category, int page = 0, int size = 10}) async {
    _log('GET /hot/articles?category=$category&page=$page&size=$size');
    return _client.get<Map<String, dynamic>>(
      '/hot/articles',
      queryParameters: { 'category': category, 'page': page, 'size': size },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> hotList({int page = 0, int size = 10}) async {
    _log('GET /hot/hot-list?page=$page&size=$size');
    return _client.get<Map<String, dynamic>>(
      '/hot/hot-list',
      queryParameters: { 'page': page, 'size': size },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchRank() async {
    _log('GET /hot/rank');
    return _client.get<List<Map<String, dynamic>>>(
      '/hot/rank',
      fromJson: (data) => ((data['items'] as List?) ?? []).cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
  
  Future<ApiResponse<List<Map<String, dynamic>>>> fetchRankByCard(int cardId) async {
    _log('GET /hot/rank?cardId=$cardId');
    return _client.get<List<Map<String, dynamic>>>(
      '/hot/rank',
      queryParameters: { 'cardId': cardId },
      fromJson: (data) => ((data['items'] as List?) ?? []).cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchRankCards() async {
    _log('GET /hot/rank-cards');
    return _client.get<List<Map<String, dynamic>>>(
      '/hot/rank-cards',
      fromJson: (data) => ((data['items'] as List?) ?? []).cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> search({required int labelId, String? keyword, int page = 0, int size = 10}) async {
    _log('GET /hot/search labelId=$labelId keyword=${keyword ?? ""}');
    final params = { 'labelId': labelId.toString(), 'page': page, 'size': size };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    return _client.get<Map<String, dynamic>>(
      '/hot/search',
      queryParameters: params,
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> listComments(int articleId) async {
    _log('GET /hot/articles/$articleId/comments');
    return _client.get<List<Map<String, dynamic>>>(
      '/hot/articles/$articleId/comments',
      fromJson: (data) => ((data['comments'] as List?) ?? []).cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> postComment(int articleId, String content, {int? parentId}) async {
    _log('POST /hot/articles/$articleId/comments parentId=${parentId ?? "root"}');
    return _client.post<Map<String, dynamic>>(
      '/hot/articles/$articleId/comments',
      data: { 'content': content, if (parentId != null) 'parentId': parentId },
      fromJson: (data) => Map<String, dynamic>.from(data as Map),
    );
  }
}
