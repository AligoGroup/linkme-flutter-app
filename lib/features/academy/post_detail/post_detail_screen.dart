import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/custom_toast.dart';
import '../../../core/widgets/avatar_viewer.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/video_preview_widget.dart';
import '../../../shared/providers/auth_provider.dart';
import '../services/academy_api.dart';
import '../create_post/create_post_screen.dart';
import 'package:provider/provider.dart';

/// 帖子详情页面 - 学习打卡模式
class PostDetailScreen extends StatefulWidget {
  final int postId;
  final bool isArticle;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.isArticle = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _appBarAlpha = 0.0;

  // 帖子详情数据
  Map<String, dynamic>? _postDetail;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingDetail = false;
  bool _isLoadingComments = false;
  bool _isLiked = false;
  bool _isFavorited = false;
  bool _isFollowing = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _canSendComment = false; // 是否可以发送评论
  String? _academyAvatar; // 学院用户头像

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      double offset = _scrollController.offset;
      double newAlpha = 0.0;
      if (offset > 40) {
        newAlpha = (offset - 40) / 40;
        if (newAlpha > 1.0) newAlpha = 1.0;
      }
      if (newAlpha != _appBarAlpha) {
        setState(() {
          _appBarAlpha = newAlpha;
        });
      }
    });

    // 监听评论输入
    _commentController.addListener(() {
      final canSend = _commentController.text.trim().isNotEmpty;
      if (canSend != _canSendComment) {
        setState(() {
          _canSendComment = canSend;
        });
      }
    });

    _loadPostDetail();
    _loadComments();
    _loadAcademyProfile();
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _loadPostDetail | 加载帖子详情
  Future<void> _loadPostDetail() async {
    if (_isLoadingDetail) return;

    setState(() => _isLoadingDetail = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      final detail = await AcademyApi.getPostDetail(
        widget.postId,
        userId: userId,
      );

      if (mounted) {
        print('📦 [Post Detail] 帖子详情数据: $detail');
        print('📦 [Post Detail] 图片字段: ${detail['images']}');
        print(
            '📦 [Post Detail] 作者信息: authorName=${detail['authorName']}, authorAvatar=${detail['authorAvatar']}, authorLevel=${detail['authorLevel']}');
        setState(() {
          _postDetail = detail;
          _isLiked = detail['isLiked'] ?? false;
          _isFollowing = detail['isFollowing'] ?? false;
          _likeCount = detail['likeCount'] ?? 0;
          _commentCount = detail['commentCount'] ?? 0;
        });
      }
    } catch (e) {
      print('加载帖子详情失败: $e');
      if (mounted) {
        CustomToast.showError(context, '加载失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _loadComments | 加载评论列表
  Future<void> _loadComments() async {
    if (_isLoadingComments) return;

    setState(() => _isLoadingComments = true);

    try {
      final result = await AcademyApi.getComments(widget.postId);

      if (mounted) {
        final List<dynamic> content = result['content'] ?? [];
        setState(() {
          _comments = content.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      print('加载评论失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _loadAcademyProfile | 加载学院用户资料
  Future<void> _loadAcademyProfile() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) return;

      final profile = await AcademyApi.getUserProfile(userId);

      if (mounted) {
        setState(() {
          _academyAvatar = profile['avatar'];
        });
      }
    } catch (e) {
      print('加载学院用户资料失败: $e');
    }
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _toggleLike | 切换点赞状态
  Future<void> _toggleLike() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      CustomToast.showWarning(context, '请先登录');
      return;
    }

    try {
      final newLikedState = await AcademyApi.toggleLike(widget.postId, userId);

      if (mounted) {
        setState(() {
          _isLiked = newLikedState;
          _likeCount += newLikedState ? 1 : -1;
        });
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      print('点赞操作失败: $e');
      if (mounted) {
        CustomToast.showError(context, '操作失败');
      }
    }
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _toggleFollow | 切换关注状态
  Future<void> _toggleFollow() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      CustomToast.showWarning(context, '请先登录');
      return;
    }

    final authorId = _postDetail?['authorId'];
    if (authorId == null) return;

    // 不能关注自己
    if (userId == authorId) {
      CustomToast.showWarning(context, '不能关注自己');
      return;
    }

    try {
      final success = _isFollowing
          ? await AcademyApi.unfollowUser(userId, authorId)
          : await AcademyApi.followUser(userId, authorId);

      if (mounted && success) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
        CustomToast.showSuccess(context, _isFollowing ? '关注成功' : '已取消关注');
        HapticFeedback.lightImpact();
      } else if (mounted && !success) {
        CustomToast.showWarning(context, _isFollowing ? '已经关注过了' : '未关注该用户');
      }
    } catch (e) {
      print('关注操作失败: $e');
      if (mounted) {
        CustomToast.showError(context, '操作失败');
      }
    }
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _toggleFavorite | 切换收藏状态
  Future<void> _toggleFavorite() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      CustomToast.showWarning(context, '请先登录');
      return;
    }

    try {
      final newFavoritedState =
          await AcademyApi.toggleFavorite(widget.postId, userId);

      if (mounted) {
        setState(() {
          _isFavorited = newFavoritedState;
        });
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      print('收藏操作失败: $e');
      if (mounted) {
        CustomToast.showError(context, '操作失败');
      }
    }
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _submitComment | 提交评论
  Future<void> _submitComment(String content) async {
    if (content.trim().isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      CustomToast.showWarning(context, '请先登录');
      return;
    }

    try {
      await AcademyApi.addComment(
        postId: widget.postId,
        content: content,
        userId: userId,
      );

      if (mounted) {
        setState(() {
          _commentCount += 1;
        });
        _loadComments(); // 重新加载评论列表
        CustomToast.showSuccess(context, '评论成功');
      }
    } catch (e) {
      print('评论失败: $e');
      if (mounted) {
        CustomToast.showError(context, '评论失败');
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDetail || _postDetail == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFF333333), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: _appBarAlpha > 0
            ? Opacity(
                opacity: _appBarAlpha,
                child: Transform.translate(
                  offset: const Offset(-8, 0), // 调整位置以保留约2px视觉间距
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          AvatarViewer.show(
                            context,
                            imageUrl: _postDetail?['authorAvatar'],
                            name: _postDetail?['authorName'] ?? '用户',
                          );
                        },
                        child: Hero(
                          tag: 'avatar_${_postDetail?['authorAvatar']}',
                          child: ClipOval(
                            child: Container(
                              width: 32,
                              height: 32,
                              color: Colors.grey[200],
                              child: _postDetail?['authorAvatar'] != null
                                  ? Image.network(
                                      _postDetail!['authorAvatar'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          SvgPicture.asset(
                                        'assets/app_icons/svg/user.svg',
                                        fit: BoxFit.scaleDown,
                                        width: 20,
                                        height: 20,
                                        colorFilter: const ColorFilter.mode(
                                            Colors.grey, BlendMode.srcIn),
                                      ),
                                    )
                                  : SvgPicture.asset(
                                      'assets/app_icons/svg/user.svg',
                                      fit: BoxFit.scaleDown,
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(
                                          Colors.grey, BlendMode.srcIn),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _postDetail?['authorName'] ?? '用户',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/app_icons/svg/more.svg',
              width: 24,
              height: 24,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
            ),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildUserInfo(),
                const SizedBox(height: 12),
                _buildContent(),
                const SizedBox(height: 12),
                _buildImages(),
                const SizedBox(height: 16),
                _buildTags(),
                const SizedBox(height: 24),
                // 底部时间 - 从后端获取真实数据
                Text(
                  _formatTime(_postDetail?['createdAt']),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
                const SizedBox(height: 24),
                // 分割区
                Container(
                    height: 8,
                    color: const Color(0xFFF5F5F5),
                    margin: const EdgeInsets.symmetric(horizontal: 0 - 16)),
                const SizedBox(height: 16),
                _buildCommentSectionHeader(),
                _buildCommentList(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final authorId = _postDetail?['authorId'];
    final isOwnPost = currentUserId == authorId;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            AvatarViewer.show(
              context,
              imageUrl: _postDetail?['authorAvatar'],
              name: _postDetail?['authorName'] ?? '用户',
            );
          },
          child: Hero(
            tag: 'avatar_${_postDetail?['authorAvatar']}',
            child: ClipOval(
              child: Container(
                width: 40,
                height: 40,
                color: Colors.grey[200],
                child: _postDetail?['authorAvatar'] != null
                    ? Image.network(_postDetail!['authorAvatar'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => SvgPicture.asset(
                            'assets/app_icons/svg/user.svg',
                            fit: BoxFit.scaleDown,
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                                Colors.grey, BlendMode.srcIn)))
                    : SvgPicture.asset('assets/app_icons/svg/user.svg',
                        fit: BoxFit.scaleDown,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                            Colors.grey, BlendMode.srcIn)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _postDetail?['authorName'] ?? '用户',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.green, width: 0.5),
                    ),
                    child: Text('Lv${_postDetail?['authorLevel'] ?? 1}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatTime(_postDetail?['createdAt'])}  阅读 ${_postDetail?['viewCount'] ?? 0}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
        // 关注按钮 - 只在不是自己的帖子时显示
        if (!isOwnPost && currentUserId != null)
          GestureDetector(
            onTap: _toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _isFollowing ? const Color(0xFFF5F5F5) : AppColors.primary,
                borderRadius: BorderRadius.circular(4),
                border: _isFollowing
                    ? Border.all(color: const Color(0xFFE0E0E0), width: 1)
                    : null,
              ),
              child: Text(
                _isFollowing ? '已关注' : '关注',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _isFollowing ? const Color(0xFF666666) : Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final DateTime time = DateTime.parse(createdAt.toString());
      return '${time.month}-${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _buildContent | 构建帖子内容区域
  Widget _buildContent() {
    final content = _postDetail?['content'] ?? '';
    final images = _postDetail?['images'] as List?;

    if (widget.isArticle && _postDetail?['title'] != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            _postDetail?['title'] ?? '',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                height: 1.4),
          ),
          const SizedBox(height: 20),
          // 长文内容 - 支持图文穿插渲染
          _buildRichContent(content, images),
        ],
      );
    } else {
      return Text(
        content,
        style: const TextStyle(
            fontSize: 16, color: Color(0xFF333333), height: 1.6),
      );
    }
  }

  /// 渲染富文本内容（支持图文和视频穿插）
  Widget _buildRichContent(String content, List? images) {
    // 如果没有图片和视频，直接显示纯文本
    final videoUrl = _postDetail?['videoUrl'];
    if ((images == null || images.isEmpty) &&
        (videoUrl == null || (videoUrl as String).isEmpty)) {
      return Text(
        content,
        style: const TextStyle(
            fontSize: 16, color: Color(0xFF333333), height: 1.6),
      );
    }

    // 检查是否包含图片或视频标记
    final RegExp imgPattern = RegExp(r'\[img:(\d+)\]');
    final RegExp videoPattern = RegExp(r'\[video:(\d+)\]');
    final hasImageMarkers = imgPattern.hasMatch(content);
    final hasVideoMarkers = videoPattern.hasMatch(content);

    // 如果没有图片或视频标记，说明是旧文章，在文本末尾显示所有媒体
    if (!hasImageMarkers && !hasVideoMarkers) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: const TextStyle(
                fontSize: 16, color: Color(0xFF333333), height: 1.6),
          ),
          const SizedBox(height: 16),
          // 优先显示视频
          if (videoUrl != null && (videoUrl as String).isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildVideoThumbnail(
                  videoUrl, _postDetail?['videoThumbnail']),
            ),
            const SizedBox(height: 12),
          ],
          // 显示所有图片
          if (images != null && images.isNotEmpty)
            ...images.asMap().entries.map((entry) {
              final index = entry.key;
              final imageUrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    // 打开图片查看器
                    ImageViewer.show(
                      context,
                      imageUrls: images.map((e) => e.toString()).toList(),
                      initialIndex: index,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ 图片加载失败: $imageUrl');
                        return _buildPlaceholderImage();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      );
    }

    // 解析内容中的图片和视频标记 [img:0], [video:0] 等
    final List<Widget> widgets = [];
    int lastIndex = 0;

    // 合并图片和视频标记的匹配
    final RegExp mediaPattern = RegExp(r'\[(img|video):(\d+)\]');

    for (final match in mediaPattern.allMatches(content)) {
      // 添加图片前的文本
      if (match.start > lastIndex) {
        String text = content.substring(lastIndex, match.start);

        // 智能处理换行：
        // 1. 移除标记前的单个换行（因为标记本身会占一行）
        // 2. 保留其他所有换行和空格
        if (text.endsWith('\n')) {
          text = text.substring(0, text.length - 1);
        }

        if (text.isNotEmpty) {
          widgets.add(
            Text(
              text,
              style: const TextStyle(
                  fontSize: 16, color: Color(0xFF333333), height: 1.6),
            ),
          );
        }
      }

      // 添加图片或视频
      final mediaType = match.group(1); // 'img' 或 'video'
      final mediaIndex = int.tryParse(match.group(2) ?? '');

      if (mediaType == 'video' &&
          videoUrl != null &&
          (videoUrl as String).isNotEmpty) {
        // 显示视频
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildVideoThumbnail(
                  videoUrl, _postDetail?['videoThumbnail']),
            ),
          ),
        );
      } else if (mediaType == 'img' &&
          mediaIndex != null &&
          images != null &&
          mediaIndex < images.length) {
        // 显示图片
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: GestureDetector(
              onTap: () {
                // 打开图片查看器
                ImageViewer.show(
                  context,
                  imageUrls: images.map((e) => e.toString()).toList(),
                  initialIndex: mediaIndex,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  images[mediaIndex].toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ 图片加载失败: ${images[mediaIndex]}');
                    return _buildPlaceholderImage();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    // 添加剩余文本
    if (lastIndex < content.length) {
      String text = content.substring(lastIndex);

      // 移除标记后的单个换行
      if (text.startsWith('\n')) {
        text = text.substring(1);
      }

      if (text.isNotEmpty) {
        widgets.add(
          Text(
            text,
            style: const TextStyle(
                fontSize: 16, color: Color(0xFF333333), height: 1.6),
          ),
        );
      }
    }

    // 显示未使用的图片（没有标记的图片）
    if (images != null && images.isNotEmpty) {
      // 找出所有已使用的图片索引
      final usedImageIndices = <int>{};
      for (final match in imgPattern.allMatches(content)) {
        final index = int.tryParse(match.group(1) ?? '');
        if (index != null) {
          usedImageIndices.add(index);
        }
      }

      // 显示未使用的图片
      for (int i = 0; i < images.length; i++) {
        if (!usedImageIndices.contains(i)) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: GestureDetector(
                onTap: () {
                  ImageViewer.show(
                    context,
                    imageUrls: images.map((e) => e.toString()).toList(),
                    initialIndex: i,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    images[i].toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ 图片加载失败: ${images[i]}');
                      return _buildPlaceholderImage();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// post_detail_screen.dart | _PostDetailScreenState | _buildImages | 构建帖子图片/视频区域
  Widget _buildImages() {
    if (widget.isArticle) return const SizedBox.shrink(); // 长文模式图片已经在内容中渲染

    final videoUrl = _postDetail?['videoUrl'];
    final images = _postDetail?['images'];
    final hasVideo = videoUrl != null && (videoUrl as String).isNotEmpty;
    final hasImages = images != null && (images as List).isNotEmpty;

    // 如果既没有视频也没有图片，不显示
    if (!hasVideo && !hasImages) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 显示视频（如果有）
        if (hasVideo) ...[
          AspectRatio(
            aspectRatio: 16 / 9,
            child:
                _buildVideoThumbnail(videoUrl, _postDetail?['videoThumbnail']),
          ),
          if (hasImages) const SizedBox(height: 12), // 视频和图片之间的间距
        ],
        // 显示图片（如果有）
        if (hasImages) ...[
          Builder(
            builder: (context) {
              final imageList = images as List;
              final imageCount = imageList.length > 3 ? 3 : imageList.length;

              return Row(
                children: List.generate(imageCount, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: index < imageCount - 1 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () {
                          // 打开图片查看器
                          ImageViewer.show(
                            context,
                            imageUrls:
                                imageList.map((e) => e.toString()).toList(),
                            initialIndex: index,
                          );
                        },
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageList[index].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholderImage(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholderImage({IconData? customIcon}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(customIcon ?? Icons.image,
          color: const Color(0xFFCCCCCC), size: 32),
    );
  }

  /// 构建视频缩略图
  Widget _buildVideoThumbnail(String videoUrl, dynamic thumbnailUrl) {
    return VideoPreviewWidget(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl != null ? thumbnailUrl.toString() : null,
      aspectRatio: 16 / 9,
    );
  }

  Widget _buildTags() {
    final topics = _postDetail?['topics'] as List?;
    final isStudyCheckIn = _postDetail?['isStudyCheckIn'] ?? false;

    // 如果没有话题且不是学习打卡，不显示标签
    if ((topics == null || topics.isEmpty) && !isStudyCheckIn) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // 显示学习打卡标签
          if (isStudyCheckIn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.task_alt,
                      size: 14, color: Color(0xFF999999)),
                  const SizedBox(width: 4),
                  const Text('学习打卡',
                      style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                ],
              ),
            ),
          // 显示话题标签
          if (topics != null)
            ...topics.map((topic) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/app_icons/svg/hashtag.svg',
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                          AppColors.primary, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      topic.toString(),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCommentSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '全部评论 ($_commentCount条)',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333)),
        ),
        Row(
          children: [
            const Text('最新',
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF999999))), // 默认灰色
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('最热',
                  style: TextStyle(fontSize: 12, color: Colors.blue)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentList() {
    if (_isLoadingComments) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('暂无评论',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _comments.length,
      padding: const EdgeInsets.only(top: 16),
      itemBuilder: (context, index) {
        return _buildCommentItem(_comments[index]);
      },
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Container(
            width: 36,
            height: 36,
            color: Colors.grey[200],
            child: comment['userAvatar'] != null
                ? Image.network(comment['userAvatar'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => SvgPicture.asset(
                        'assets/app_icons/svg/user.svg',
                        fit: BoxFit.scaleDown,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                            Colors.grey, BlendMode.srcIn)))
                : SvgPicture.asset('assets/app_icons/svg/user.svg',
                    fit: BoxFit.scaleDown,
                    width: 20,
                    height: 20,
                    colorFilter:
                        const ColorFilter.mode(Colors.grey, BlendMode.srcIn)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment['userName'] ?? '用户',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333))),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(2)),
                    child: Text('Lv${comment['userLevel'] ?? 1}',
                        style:
                            const TextStyle(fontSize: 9, color: Colors.blue)),
                  ),
                  const Spacer(),
                  // 三个点菜单按钮
                  GestureDetector(
                    onTap: () => _showCommentMenu(context, comment),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: SvgPicture.asset(
                        'assets/app_icons/svg/more.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF999999),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(comment['content'] ?? '',
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF333333))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(_formatCommentTime(comment['createdAt']),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999))),
                  const Spacer(),
                  SvgPicture.asset('assets/app_icons/svg/message.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF999999), BlendMode.srcIn)),
                  const SizedBox(width: 4),
                  const Text('0',
                      style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  const SizedBox(width: 16),
                  SvgPicture.asset('assets/app_icons/svg/heart.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF999999), BlendMode.srcIn)),
                  const SizedBox(width: 4),
                  Text('${comment['likeCount'] ?? 0}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCommentTime(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final DateTime time = DateTime.parse(createdAt.toString());
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inMinutes < 1) {
        return '刚刚';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}分钟前';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}小时前';
      } else {
        return '${time.month}-${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 左侧：评论、点赞、收藏图标
            _buildActionIcon(
                'assets/app_icons/svg/message.svg', '$_commentCount', null),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: _toggleLike,
              child: _buildActionIcon('assets/app_icons/svg/heart.svg',
                  '$_likeCount', _isLiked ? AppColors.primary : null),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: _toggleFavorite,
              child: _buildActionIcon(
                  'assets/app_icons/svg/star.svg',
                  _isFavorited ? '已收藏' : '收藏',
                  _isFavorited ? AppColors.primary : null),
            ),
            const SizedBox(width: 16),

            // 右侧：写评论输入框
            Expanded(
              child: GestureDetector(
                onTap: () => _showCommentModal(context),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.only(
                      left: 4, right: 12), // 左侧留少点padding因为有margin
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      // 输入框内的头像（加大尺寸）- 使用学院用户头像
                      Container(
                        margin: const EdgeInsets.only(right: 8), // 与灰色边缘保留间距
                        child: ClipOval(
                          child: Container(
                            width: 28,
                            height: 28,
                            color: Colors.grey[200],
                            child: _academyAvatar != null
                                ? Image.network(
                                    _academyAvatar!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        SvgPicture.asset(
                                      'assets/app_icons/svg/user.svg',
                                      fit: BoxFit.scaleDown,
                                      width: 16,
                                      height: 16,
                                      colorFilter: const ColorFilter.mode(
                                          Colors.grey, BlendMode.srcIn),
                                    ),
                                  )
                                : SvgPicture.asset(
                                    'assets/app_icons/svg/user.svg',
                                    fit: BoxFit.scaleDown,
                                    width: 16,
                                    height: 16,
                                    colorFilter: const ColorFilter.mode(
                                        Colors.grey, BlendMode.srcIn),
                                  ),
                          ),
                        ),
                      ),
                      const Text('和小伙伴唠嗑趴！',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF999999))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentInputModal(
        onSubmit: (content) {
          _submitComment(content);
        },
      ),
    );
  }

  Widget _buildActionIcon(String iconPath, String count, Color? activeColor) {
    final color = activeColor ?? const Color(0xFF333333);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          iconPath,
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        Text(count, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  void _showMoreOptions(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final postAuthorId = _postDetail?['authorId'];
    final isOwnPost = currentUserId == postAuthorId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost) ...[
              // 自己的帖子：显示编辑和删除选项
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/edit.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('编辑帖子'),
                onTap: () {
                  Navigator.pop(context);
                  _editPost();
                },
              ),
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/trash.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFFF3B30),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text(
                  '删除帖子',
                  style: TextStyle(color: Color(0xFFFF3B30)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
            ] else ...[
              // 别人的帖子：显示屏蔽和举报选项
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/close-circle.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('屏蔽用户'),
                onTap: () {
                  Navigator.pop(context);
                  CustomToast.showWarning(context, '开发中');
                },
              ),
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/danger.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('举报'),
                onTap: () {
                  Navigator.pop(context);
                  CustomToast.showWarning(context, '开发中');
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 编辑帖子
  Future<void> _editPost() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          postId: widget.postId,
          postData: _postDetail,
        ),
      ),
    );

    // 编辑成功后刷新帖子详情
    if (result == true && mounted) {
      _loadPostDetail();
    }
  }

  /// 删除帖子
  Future<void> _deletePost() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      CustomToast.showWarning(context, '请先登录');
      return;
    }

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，确定要删除这篇帖子吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AcademyApi.deletePost(widget.postId, userId);
      if (mounted) {
        CustomToast.showSuccess(context, '删除成功');
        // 返回上一页并传递删除成功的标记
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('删除帖子失败: $e');
      if (mounted) {
        CustomToast.showError(context, '删除失败');
      }
    }
  }

  /// 显示评论操作菜单
  void _showCommentMenu(BuildContext context, Map<String, dynamic> comment) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final commentUserId = comment['userId'];
    final isOwnComment = currentUserId == commentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnComment)
              // 自己的评论：显示删除选项
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/trash.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFFF3B30),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text(
                  '删除评论',
                  style: TextStyle(color: Color(0xFFFF3B30)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment);
                },
              )
            else ...[
              // 别人的评论：显示屏蔽和举报选项
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/close-circle.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('屏蔽用户'),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(comment);
                },
              ),
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/danger.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('举报'),
                onTap: () {
                  Navigator.pop(context);
                  _reportComment(comment);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 删除评论
  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final commentId = comment['id'];

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('确定要删除这条评论吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AcademyApi.deleteComment(commentId);

      if (mounted) {
        CustomToast.showSuccess(context, '删除成功');
        // 从列表中移除
        setState(() {
          _comments.removeWhere((c) => c['id'] == commentId);
        });
        // 更新评论数
        if (_postDetail != null) {
          _postDetail!['commentCount'] =
              (_postDetail!['commentCount'] ?? 1) - 1;
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, '删除失败');
      }
    }
  }

  /// 屏蔽用户
  Future<void> _blockUser(Map<String, dynamic> comment) async {
    CustomToast.showInfo(context, '屏蔽功能开发中');
    // TODO: 实现屏蔽用户功能
  }

  /// 举报评论
  Future<void> _reportComment(Map<String, dynamic> comment) async {
    CustomToast.showInfo(context, '举报功能开发中');
    // TODO: 实现举报功能
  }
}

class _CommentInputModal extends StatefulWidget {
  final Function(String) onSubmit;

  const _CommentInputModal({required this.onSubmit});

  @override
  State<_CommentInputModal> createState() => _CommentInputModalState();
}

class _CommentInputModalState extends State<_CommentInputModal> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;
  bool _shareToDynamic = false;
  final List<String> _images = []; // 模拟图片列表

  bool get _canSendComment =>
      _controller.text.trim().isNotEmpty || _images.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    // 自动聚焦
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleAddImage() {
    setState(() {
      // 模拟添加图片
      _images.add('placeholder_image');
    });
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty && _images.isEmpty) return;
    widget.onSubmit(_controller.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: _isExpanded ? screenHeight * 0.9 : null,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        child: Column(
          mainAxisSize: _isExpanded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部输入区域
            Flexible(
              fit: _isExpanded ? FlexFit.tight : FlexFit.loose,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: 40,
                          maxHeight: _isExpanded ? double.infinity : 100,
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          textInputAction:
                              TextInputAction.newline, // 始终保持换行模式，防止键盘收起
                          onChanged: (text) {
                            if (!_isExpanded && text.endsWith('\n')) {
                              // 未展开模式下，回车即发送
                              _controller.text =
                                  text.substring(0, text.length - 1);
                              _controller.selection =
                                  TextSelection.fromPosition(TextPosition(
                                      offset: _controller.text.length));
                              _handleSend();
                            }
                          },
                          cursorColor: const Color(0xFFFF4081),
                          decoration: const InputDecoration(
                            hintText: '你猜我的评论区在等待谁?',
                            hintStyle: TextStyle(
                                color: Color(0xFFCCCCCC), fontSize: 15),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            filled: false, // 显式去除填充背景
                            fillColor: Colors.transparent,
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                        // 强制保持焦点，防止键盘收起
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_focusNode.hasFocus) {
                            _focusNode.requestFocus();
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: SvgPicture.asset(
                          'assets/app_icons/svg/maximize-4.svg', // 更简洁的图标
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                              Color(0xFF999999), BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 图片展示区域
            if (_images.isNotEmpty)
              Container(
                height: 80,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),

            // 底部工具栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 工具图标组 - 图片功能放左侧
                  GestureDetector(
                    onTap: _handleAddImage,
                    child: SvgPicture.asset(
                      'assets/app_icons/svg/gallery.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF999999), BlendMode.srcIn),
                    ),
                  ),

                  const Spacer(),

                  // 发布按钮
                  GestureDetector(
                    onTap: _canSendComment ? _handleSend : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _canSendComment
                            ? const Color(0xFFFF99B3) // 亮粉色 - 可点击
                            : const Color(0xFFE0E0E0), // 灰色 - 不可点击
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '发布',
                        style: TextStyle(
                            color: _canSendComment
                                ? Colors.white
                                : const Color(0xFF999999),
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolIcon(String assetPath) {
    return SvgPicture.asset(
      assetPath,
      width: 24,
      height: 24,
      colorFilter: const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn),
    );
  }
}
