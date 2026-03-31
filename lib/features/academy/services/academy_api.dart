import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/services/auth_service.dart';

/// academy_api.dart | AcademyApi | 学院API服务
class AcademyApi {
  static final AuthService _authService = AuthService();
  static String get baseUrl => ApiConfig.academyBaseUrl;

  /// academy_api.dart | AcademyApi | getUserProfile | userId | 获取用户资料详情
  /// 包含:排名、积分、获赞、浏览、关注、粉丝、等级
  static Future<Map<String, dynamic>> getUserProfile(int userId) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '获取用户资料失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取用户资料失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | createPost | 创建帖子
  /// title: 标题(长文模式必填)
  /// content: 内容
  /// images: 图片URL列表
  /// videoUrl: 视频URL
  /// topics: 话题列表
  /// isStudyCheckIn: 是否学习打卡
  /// userId: 用户ID
  /// 返回: {postId: int, experienceGained: int, pointsGained: int}
  static Future<Map<String, dynamic>> createPost({
    String? title,
    required String content,
    List<String>? images,
    String? videoUrl,
    String? videoThumbnail,
    List<String>? topics,
    String? type,
    bool isStudyCheckIn = false,
    required int userId,
    String? nickname,
    String? avatar,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final body = {
        'content': content,
        'isStudyCheckIn': isStudyCheckIn,
      };

      if (title != null && title.isNotEmpty) {
        body['title'] = title;
      }
      if (images != null && images.isNotEmpty) {
        body['images'] = images;
        print('📷 [Academy API] 添加图片到请求: ${images.length}张 - $images');
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        body['videoUrl'] = videoUrl;
        print('🎥 [Academy API] 添加视频到请求: $videoUrl');
      }
      if (videoThumbnail != null && videoThumbnail.isNotEmpty) {
        body['videoThumbnail'] = videoThumbnail;
        print('🖼️ [Academy API] 添加视频缩略图到请求: $videoThumbnail');
      }
      if (topics != null && topics.isNotEmpty) {
        body['topics'] = topics;
      }
      if (type != null && type.isNotEmpty && type != '分类') {
        body['type'] = type;
      }
      if (nickname != null) {
        body['nickname'] = nickname;
      }
      if (avatar != null) {
        body['avatar'] = avatar;
      }

      print('📝 [Academy API] 发布帖子完整请求体: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/api/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          // 返回完整的响应数据，包含postId、experienceGained、pointsGained
          final responseData = data['data'] as Map<String, dynamic>;
          print('📝 [Academy API] 发布成功响应: $responseData');
          return responseData;
        } else {
          throw Exception(data['message'] ?? '发布失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('发布帖子失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | syncUserProfile | 同步用户资料
  static Future<void> syncUserProfile({
    required String? nickname,
    required String? avatar,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      final userId = await _authService.getCurrentUserId();
      if (token == null || userId == null) return;

      await http.post(
        Uri.parse('$baseUrl/api/posts/user/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
        body: json.encode({
          'nickname': nickname,
          'avatar': avatar,
        }),
      );
    } catch (e) {
      print('同步资料失败: $e');
    }
  }

  /// academy_api.dart | AcademyApi | uploadImage | 上传图片
  static Future<String> uploadImage(File imageFile) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      // 根据文件扩展名确定MIME类型
      String contentType = 'image/jpeg'; // 默认
      final path = imageFile.path.toLowerCase();
      if (path.endsWith('.png')) {
        contentType = 'image/png';
      } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (path.endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (path.endsWith('.webp')) {
        contentType = 'image/webp';
      } else if (path.endsWith('.heic') || path.endsWith('.heif')) {
        // iOS的HEIC格式，后端需要支持或转换
        contentType = 'image/heic';
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/image'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // 显式指定contentType，避免识别失败
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType.parse(contentType),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          // 后端返回的data可能是String或Map，需要兼容处理
          final result = data['data'];
          if (result is String) {
            return result;
          } else if (result is Map && result.containsKey('url')) {
            return result['url'] as String;
          } else {
            throw Exception('上传返回格式错误');
          }
        } else {
          throw Exception(data['message'] ?? '上传失败');
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['message'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('上传图片失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | uploadVideo | 上传视频
  static Future<String> uploadVideo(File videoFile) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      // 根据文件扩展名确定MIME类型
      String contentType = 'video/mp4'; // 默认
      final path = videoFile.path.toLowerCase();
      if (path.endsWith('.mp4')) {
        contentType = 'video/mp4';
      } else if (path.endsWith('.mov')) {
        contentType = 'video/quicktime';
      } else if (path.endsWith('.avi')) {
        contentType = 'video/x-msvideo';
      } else if (path.endsWith('.mkv')) {
        contentType = 'video/x-matroska';
      } else if (path.endsWith('.webm')) {
        contentType = 'video/webm';
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/video'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // 显式指定contentType
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        videoFile.path,
        contentType: MediaType.parse(contentType),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          // 后端返回的data是Map，包含url、size、contentType
          final result = data['data'];
          if (result is Map && result.containsKey('url')) {
            return result['url'] as String;
          } else if (result is String) {
            return result;
          } else {
            throw Exception('上传返回格式错误');
          }
        } else {
          throw Exception(data['message'] ?? '上传失败');
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['message'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('上传视频失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getHotTopics | 获取热门话题
  static Future<List<String>> getHotTopics() async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/posts/topics/hot'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return List<String>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? '获取热门话题失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取热门话题失败: $e');
      return [];
    }
  }

  /// academy_api.dart | AcademyApi | getPostCategories | 获取帖子分类列表
  static Future<List<String>> getPostCategories() async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/posts/categories'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return List<String>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? '获取分类失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取帖子分类失败: $e');
      return ['提问', '经验', '资料', '讨论']; // 失败时返回默认分类
    }
  }

  /// academy_api.dart | AcademyApi | getPosts | type, page, size, userId | 获取帖子列表
  /// type: recommend-推荐, hot-热门
  static Future<Map<String, dynamic>> getPosts({
    String type = 'recommend',
    int page = 0,
    int size = 10,
    int? userId,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      final url = '$baseUrl/api/posts?type=$type&page=$page&size=$size';

      print('🌐 [Academy API] 请求URL: $url');
      print('🔑 [Academy API] Token: ${token != null ? "已设置" : "未设置"}');
      print('👤 [Academy API] UserId: $userId');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          if (userId != null) 'X-User-Id': userId.toString(),
        },
      );

      print('📡 [Academy API] 响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ [Academy API] 响应数据: ${data['code']} - ${data['message']}');
        print('📦 [Academy API] data类型: ${data['data'].runtimeType}');
        print('📦 [Academy API] data内容: ${data['data']}');
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '获取帖子列表失败');
        }
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        print('❌ [Academy API] 错误响应: $errorBody');
        throw Exception('HTTP ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      print('❌ [Academy API] 获取帖子列表失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getPostDetail | postId, userId | 获取帖子详情
  static Future<Map<String, dynamic>> getPostDetail(
    int postId, {
    int? userId,
  }) async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          if (userId != null) 'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '获取帖子详情失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取帖子详情失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | toggleLike | postId, userId | 切换点赞状态
  static Future<bool> toggleLike(int postId, int userId) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/$postId/like'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'] as bool;
        } else {
          throw Exception(data['message'] ?? '操作失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('切换点赞状态失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | toggleFavorite | postId, userId | 切换收藏状态
  static Future<bool> toggleFavorite(int postId, int userId) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/$postId/favorite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'] as bool;
        } else {
          throw Exception(data['message'] ?? '操作失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('切换收藏状态失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getComments | postId, page, size | 获取评论列表
  static Future<Map<String, dynamic>> getComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/posts/$postId/comments?page=$page&size=$size'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '获取评论列表失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取评论列表失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | addComment | postId, content, parentId, userId | 添加评论
  static Future<int> addComment({
    required int postId,
    required String content,
    int? parentId,
    required int userId,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final body = {
        'postId': postId,
        'content': content,
      };

      if (parentId != null) {
        body['parentId'] = parentId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'] as int;
        } else {
          throw Exception(data['message'] ?? '评论失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('添加评论失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | deleteComment | commentId | 删除评论
  static Future<void> deleteComment(int commentId) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/posts/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] != 200) {
          throw Exception(data['message'] ?? '删除失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('删除评论失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | searchPosts | keyword, page, size, userId | 搜索帖子
  static Future<Map<String, dynamic>> searchPosts({
    required String keyword,
    int page = 0,
    int size = 10,
    int? userId,
  }) async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/posts/search?keyword=${Uri.encodeComponent(keyword)}&page=$page&size=$size'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          if (userId != null) 'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '搜索失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('搜索帖子失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getUserPosts | targetUserId, page, size, currentUserId | 获取用户帖子列表
  static Future<Map<String, dynamic>> getUserPosts({
    required int targetUserId,
    int page = 0,
    int size = 10,
    int? currentUserId,
  }) async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/posts/user/$targetUserId?page=$page&size=$size'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          if (currentUserId != null) 'X-User-Id': currentUserId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '获取用户帖子失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取用户帖子失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getAllCategories | 获取所有课程大分类
  static Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final token = _authService.getCurrentToken();
      final url = '$baseUrl/api/categories';

      print('🌐 [Academy API] 请求分类URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 [Academy API] 分类响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print(
            '✅ [Academy API] 分类数据: ${data['code']} - 数量: ${(data['data'] as List).length}');
        if (data['code'] == 200) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? '获取分类失败');
        }
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        print('❌ [Academy API] 分类错误响应: $errorBody');
        throw Exception('HTTP ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      print('❌ [Academy API] 获取分类失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getSubCategories | categoryId | 获取子分类列表
  static Future<List<Map<String, dynamic>>> getSubCategories(
      int categoryId) async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/categories/$categoryId/sub'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? '获取子分类失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取子分类失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | deletePost | postId, userId | 删除帖子
  static Future<void> deletePost(int postId, int userId) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/posts/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] != 200) {
          throw Exception(data['message'] ?? '删除失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('删除帖子失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | followUser | userId, targetUserId | 关注用户
  static Future<bool> followUser(int userId, int targetUserId) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/$targetUserId/follow'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'] as bool;
        } else {
          throw Exception(data['message'] ?? '关注失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('关注用户失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | unfollowUser | userId, targetUserId | 取消关注用户
  static Future<bool> unfollowUser(int userId, int targetUserId) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$targetUserId/follow'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'] as bool;
        } else {
          throw Exception(data['message'] ?? '取消关注失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('取消关注用户失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getFollowingList | userId, page, size | 获取关注列表
  static Future<Map<String, dynamic>> getFollowingList({
    required int userId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/following?page=$page&size=$size'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '获取关注列表失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取关注列表失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getFollowersList | userId, page, size | 获取粉丝列表
  static Future<Map<String, dynamic>> getFollowersList({
    required int userId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/followers?page=$page&size=$size'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '获取粉丝列表失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取粉丝列表失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | getMajorTags | 获取主攻方向标签列表
  static Future<List<Map<String, dynamic>>> getMajorTags() async {
    try {
      final token = _authService.getCurrentToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/config/major-tags'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 200) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? '获取主攻方向标签失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取主攻方向标签失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | updateProfile | 更新用户资料
  static Future<void> updateProfile({
    required int userId,
    String? nickname,
    String? avatar,
    int? majorTagId,
    String? university,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final body = <String, dynamic>{};
      if (nickname != null) body['nickname'] = nickname;
      if (avatar != null) body['avatar'] = avatar;
      if (majorTagId != null) body['majorTagId'] = majorTagId;
      if (university != null) body['university'] = university;

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] != 200) {
          throw Exception(data['message'] ?? '更新资料失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('更新用户资料失败: $e');
      rethrow;
    }
  }

  /// academy_api.dart | AcademyApi | updatePost | 更新帖子
  static Future<void> updatePost({
    required int postId,
    String? title,
    required String content,
    List<String>? images,
    String? videoUrl,
    String? videoThumbnail,
    List<String>? topics,
    String? type,
    bool isStudyCheckIn = false,
    required int userId,
  }) async {
    try {
      final token = _authService.getCurrentToken();
      if (token == null) {
        throw Exception('未登录');
      }

      final body = {
        'content': content,
        'isStudyCheckIn': isStudyCheckIn,
      };

      if (title != null && title.isNotEmpty) {
        body['title'] = title;
      }
      if (images != null && images.isNotEmpty) {
        body['images'] = images;
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        body['videoUrl'] = videoUrl;
      }
      if (videoThumbnail != null && videoThumbnail.isNotEmpty) {
        body['videoThumbnail'] = videoThumbnail;
      }
      if (topics != null && topics.isNotEmpty) {
        body['topics'] = topics;
      }
      if (type != null && type.isNotEmpty && type != '分类') {
        body['type'] = type;
      }

      print('📝 [Academy API] 更新帖子请求体: $body');

      final response = await http.put(
        Uri.parse('$baseUrl/api/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-User-Id': userId.toString(),
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] != 200) {
          throw Exception(data['message'] ?? '更新失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('更新帖子失败: $e');
      rethrow;
    }
  }
}
