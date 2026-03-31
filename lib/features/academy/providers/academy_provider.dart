import 'package:flutter/foundation.dart';
import '../services/academy_api.dart';
import '../../../shared/services/auth_service.dart';

/// academy_provider.dart | AcademyProvider | 学院功能状态管理
/// 管理学院功能的数据和状态，包括帖子、课程、分类等
class AcademyProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _initialized = false;

  // 帖子列表
  List<AcademyPost> _posts = [];
  int _currentPage = 0;
  bool _hasMore = true;

  // 课程列表
  List<AcademyCourse> _courses = [];

  // 课程分类
  List<Map<String, dynamic>> _categories = [];

  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  List<AcademyPost> get posts => _posts;
  List<AcademyCourse> get courses => _courses;
  List<Map<String, dynamic>> get categories => _categories;
  bool get hasMore => _hasMore;

  /// academy_provider.dart | AcademyProvider | initialize | 初始化学院数据
  Future<void> initialize() async {
    if (_initialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 加载课程分类
      _categories = await AcademyApi.getAllCategories();
      _initialized = true;
    } catch (e) {
      debugPrint('❌ 初始化学院数据失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// academy_provider.dart | AcademyProvider | refreshPosts | type 刷新帖子列表
  /// type: recommend-推荐, hot-热门
  Future<void> refreshPosts(String type) async {
    try {
      _currentPage = 0;
      _hasMore = true;

      final userId = _authService.getCurrentUserId();
      final response = await AcademyApi.getPosts(
        type: type,
        page: 0,
        size: 10,
        userId: userId,
      );

      _posts = _parsePostList(response['content'] as List);
      _hasMore = !(response['last'] as bool);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 刷新帖子失败: $e');
      rethrow;
    }
  }

  /// academy_provider.dart | AcademyProvider | refreshCourses | 刷新课程列表
  Future<void> refreshCourses() async {
    try {
      // TODO: 实现课程列表API后再调用
      await Future.delayed(const Duration(milliseconds: 800));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 刷新课程失败: $e');
      rethrow;
    }
  }

  /// academy_provider.dart | AcademyProvider | loadMorePosts | type 加载更多帖子
  Future<void> loadMorePosts(String type) async {
    if (!_hasMore || _isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      final userId = _authService.getCurrentUserId();
      final response = await AcademyApi.getPosts(
        type: type,
        page: _currentPage + 1,
        size: 10,
        userId: userId,
      );

      final newPosts = _parsePostList(response['content'] as List);
      _posts.addAll(newPosts);
      _currentPage++;
      _hasMore = !(response['last'] as bool);
    } catch (e) {
      debugPrint('❌ 加载更多帖子失败: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 解析帖子列表数据
  List<AcademyPost> _parsePostList(List data) {
    return data.map((item) => AcademyPost.fromJson(item)).toList();
  }
}

/// academy_provider.dart | AcademyPost | 学院帖子模型
class AcademyPost {
  final int id;
  final String? title;
  final String contentPreview;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final int authorLevel;
  final bool isVip;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final String? latestComment;
  final List<String> topics;
  final bool isLiked;

  AcademyPost({
    required this.id,
    this.title,
    required this.contentPreview,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.authorLevel,
    required this.isVip,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    this.latestComment,
    required this.topics,
    required this.isLiked,
  });

  factory AcademyPost.fromJson(Map<String, dynamic> json) {
    return AcademyPost(
      id: json['id'] as int,
      title: json['title'] as String?,
      contentPreview: json['contentPreview'] as String? ?? '',
      authorId: json['authorId'] as int,
      authorName: json['authorName'] as String? ?? '未知用户',
      authorAvatar: json['authorAvatar'] as String?,
      authorLevel: json['authorLevel'] as int? ?? 1,
      isVip: json['isVip'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      latestComment: json['latestComment'] as String?,
      topics: (json['topics'] as List?)?.map((e) => e as String).toList() ?? [],
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }
}

/// academy_provider.dart | AcademyCourse | 学院课程模型
class AcademyCourse {
  final String id;
  final String title;
  final String description;
  final String? coverImage;
  final double price;
  final bool isFree;
  final bool isVipOnly;
  final bool isVipFree;
  final String category;
  final String subCategory;

  AcademyCourse({
    required this.id,
    required this.title,
    required this.description,
    this.coverImage,
    required this.price,
    required this.isFree,
    required this.isVipOnly,
    required this.isVipFree,
    required this.category,
    required this.subCategory,
  });
}
