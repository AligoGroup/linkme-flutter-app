import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/custom_toast.dart';
import '../../core/widgets/avatar_viewer.dart';
import '../../shared/providers/auth_provider.dart';
import '../../widgets/custom/user_avatar.dart';
import 'post_detail/post_detail_screen.dart';
import 'services/academy_api.dart';

/// academy_profile_screen.dart | AcademyProfileScreen | 学院个人中心页面
class AcademyProfileScreen extends StatefulWidget {
  const AcademyProfileScreen({super.key});

  @override
  State<AcademyProfileScreen> createState() => _AcademyProfileScreenState();
}

class _AcademyProfileScreenState extends State<AcademyProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  String? _academyNickname;
  String? _academyAvatar;
  String? _university;
  String? _education;
  String? _majorTag;

  int _ranking = 0;
  int _points = 0;
  int _awards = 0;
  int _postsViewed = 0;
  int _following = 0;
  int _followers = 0;
  int _level = 1;

  bool _isVip = false;
  DateTime? _vipExpireDate;
  bool _isLoadingProfile = false;

  bool _isRefreshing = false;
  bool _refreshSuccess = false;
  double _refreshOffset = 0;

  bool _isScrolled = false;
  double _toolbarOpacity = 0.0;
  bool _isDraggingList = false;

  bool _isEmpty = false;
  bool _isError = false;

  // 帖子列表数据
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoadingPosts = false;
  int _currentPostPage = 0;
  bool _hasMorePosts = true;

  // 关注列表数据
  List<Map<String, dynamic>> _followingList = [];
  bool _isLoadingFollowing = false;
  int _currentFollowingPage = 0;
  bool _hasMoreFollowing = true;

  // 粉丝列表数据
  List<Map<String, dynamic>> _followersList = [];
  bool _isLoadingFollowers = false;
  int _currentFollowersPage = 0;
  bool _hasMoreFollowers = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _scrollController.addListener(_onScroll);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadUserProfile();
    _loadUserPosts();

    // 监听Tab切换，加载对应数据
    _tabController.addListener(() {
      if (_tabController.index == 1 && _followingList.isEmpty) {
        _loadFollowingList();
      } else if (_tabController.index == 2 && _followersList.isEmpty) {
        _loadFollowersList();
      }
    });
  }

  /// academy_profile_screen.dart | _AcademyProfileScreenState | _loadUserPosts | 加载用户帖子列表
  Future<void> _loadUserPosts({bool refresh = false}) async {
    if (_isLoadingPosts) return;

    setState(() => _isLoadingPosts = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      final user = authProvider.user;

      if (user == null) {
        print('用户未登录');
        return;
      }

      final page = refresh ? 0 : _currentPostPage;
      final result = await AcademyApi.getPosts(
        type: 'user',
        page: page,
        size: 10,
        userId: user.id, // 查询当前用户或目标用户的帖子
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        final List<dynamic> content = result['content'] ?? [];
        final posts = content.map((e) => e as Map<String, dynamic>).toList();

        setState(() {
          if (refresh) {
            _userPosts = posts;
            _currentPostPage = 0;
            _isEmpty = posts.isEmpty;
          } else {
            _userPosts.addAll(posts);
            // 首次加载时也要设置_isEmpty
            if (page == 0) {
              _isEmpty = posts.isEmpty;
            }
          }
          _currentPostPage = page + 1;
          _hasMorePosts = !(result['last'] ?? true);
          _isError = false;
        });
      }
    } catch (e) {
      print('加载用户帖子列表失败: $e');
      if (mounted) {
        setState(() {
          _isError = true;
          if (refresh) _isEmpty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  /// 加载关注列表
  Future<void> _loadFollowingList({bool refresh = false}) async {
    if (_isLoadingFollowing) return;

    setState(() => _isLoadingFollowing = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        print('用户未登录');
        return;
      }

      final page = refresh ? 0 : _currentFollowingPage;
      final result = await AcademyApi.getFollowingList(
        userId: userId,
        page: page,
        size: 20,
      );

      if (mounted) {
        final List<dynamic> content = result['content'] ?? [];
        final users = content.map((e) => e as Map<String, dynamic>).toList();

        setState(() {
          if (refresh) {
            _followingList = users;
            _currentFollowingPage = 0;
          } else {
            _followingList.addAll(users);
          }
          _currentFollowingPage = page + 1;
          _hasMoreFollowing = !(result['last'] ?? true);
        });
      }
    } catch (e) {
      print('加载关注列表失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollowing = false);
      }
    }
  }

  /// 加载粉丝列表
  Future<void> _loadFollowersList({bool refresh = false}) async {
    if (_isLoadingFollowers) return;

    setState(() => _isLoadingFollowers = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        print('用户未登录');
        return;
      }

      final page = refresh ? 0 : _currentFollowersPage;
      final result = await AcademyApi.getFollowersList(
        userId: userId,
        page: page,
        size: 20,
      );

      if (mounted) {
        final List<dynamic> content = result['content'] ?? [];
        final users = content.map((e) => e as Map<String, dynamic>).toList();

        setState(() {
          if (refresh) {
            _followersList = users;
            _currentFollowersPage = 0;
          } else {
            _followersList.addAll(users);
          }
          _currentFollowersPage = page + 1;
          _hasMoreFollowers = !(result['last'] ?? true);
        });
      }
    } catch (e) {
      print('加载粉丝列表失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollowers = false);
      }
    }
  }

  /// 加载用户资料(排名、积分、获赞、浏览、关注、粉丝、等级)
  Future<void> _loadUserProfile() async {
    if (_isLoadingProfile) return;

    setState(() => _isLoadingProfile = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        print('用户未登录');
        return;
      }

      final profile = await AcademyApi.getUserProfile(userId);

      if (mounted) {
        setState(() {
          // 更新基本资料
          _academyNickname = profile['nickname'];
          _academyAvatar = profile['avatar'];
          _university = profile['university'];
          _majorTag = profile['majorTag'];
          _education = profile['education'];

          // 更新等级和积分
          _level = profile['level'] ?? 1;
          _points = profile['points'] ?? 0;
          _ranking = profile['ranking'] ?? 0;

          // 更新统计数据
          final stats = profile['stats'];
          if (stats != null) {
            _awards = stats['likeReceivedCount'] ?? 0;
            _postsViewed = stats['viewCount'] ?? 0;
            _following = stats['followingCount'] ?? 0;
            _followers = stats['followerCount'] ?? 0;
          }

          // 更新VIP状态
          _isVip = profile['isVip'] ?? false;
          if (profile['vipExpireDate'] != null) {
            _vipExpireDate = DateTime.parse(profile['vipExpireDate']);
          }
        });
      }
    } catch (e) {
      print('加载用户资料失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载用户资料失败: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    // 计算透明度：100开始渐变，160完全显示 (适配较小的Header高度)
    double newOpacity = 0.0;
    if (offset > 100) {
      newOpacity = ((offset - 100) / 60).clamp(0.0, 1.0);
    }

    if (newOpacity != _toolbarOpacity) {
      setState(() {
        _toolbarOpacity = newOpacity;
        _isScrolled = offset > 100;
      });
    }
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshOffset = 0;
    });

    // 重新加载用户资料
    await _loadUserProfile();

    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _refreshSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _refreshSuccess = false);
    }
  }

  void _openEditProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _EditProfilePage(
          nickname: _academyNickname,
          avatar: _academyAvatar,
          majorTag: _majorTag,
          university: _university,
          education: _education,
        ),
      ),
    );

    // 如果编辑成功，刷新资料
    if (result == true && mounted) {
      _loadUserProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final displayNickname = _academyNickname ?? user?.nickname ?? '未设置昵称';
    final displayAvatar = _academyAvatar ?? user?.avatar;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 315,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: Color.lerp(
                      Colors.white, const Color(0xFF333333), _toolbarOpacity),
                ),
              ),
              titleSpacing: 0,
              title: Opacity(
                opacity: _toolbarOpacity,
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AvatarViewer.show(
                          context,
                          imageUrl: displayAvatar,
                          name: displayNickname,
                        );
                      },
                      child: Hero(
                        tag: 'avatar_$displayAvatar',
                        child: UserAvatar(
                            imageUrl: displayAvatar,
                            name: displayNickname,
                            size: 32),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayNickname,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // TODO: 更换背景图
                  },
                  icon: SvgPicture.asset(
                    'assets/app_icons/svg/gallery.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      Color.lerp(Colors.white, const Color(0xFF333333),
                          _toolbarOpacity)!,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _openEditProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                            Colors.white.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.1),
                            _toolbarOpacity),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color.lerp(
                              Colors.white.withValues(alpha: 0.3),
                              AppColors.primary.withValues(alpha: 0.3),
                              _toolbarOpacity)!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/app_icons/svg/edit.svg',
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              Color.lerp(Colors.white, AppColors.primary,
                                  _toolbarOpacity)!,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '编辑资料',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color.lerp(Colors.white, AppColors.primary,
                                  _toolbarOpacity),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // 背景渐变
                    Container(
                      height: 260,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF87CEEB), Color(0xFF4A90E2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // 底部晕染模糊过渡
                    Positioned(
                      top: 160,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 头像、昵称、等级在背景图上
                    Positioned(
                      top: 108,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      AvatarViewer.show(
                                        context,
                                        imageUrl: displayAvatar,
                                        name: displayNickname,
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Hero(
                                        tag: 'avatar_$displayAvatar',
                                        child: UserAvatar(
                                            imageUrl: displayAvatar,
                                            name: displayNickname,
                                            size: 72),
                                      ),
                                    ),
                                  ),
                                  if (_isVip)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFFD700),
                                              Color(0xFFFFA500)
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: const Text(
                                          'V',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayNickname,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black26,
                                              blurRadius: 8)
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'Lv.$_level',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 主攻方向、大学、学历
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_majorTag != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _majorTag!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (_university != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/app_icons/svg/building.svg',
                                        width: 12,
                                        height: 12,
                                        colorFilter: const ColorFilter.mode(
                                            Color(0xFF666666), BlendMode.srcIn),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(_university!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF666666))),
                                    ],
                                  ),
                                ),
                              if (_education != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/app_icons/svg/teacher.svg',
                                        width: 12,
                                        height: 12,
                                        colorFilter: const ColorFilter.mode(
                                            Color(0xFF666666), BlendMode.srcIn),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(_education!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF666666))),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 0),
                        ],
                      ),
                    ),
                    // 统计数据
                    Positioned(
                      top: 265,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildStatItem('排名', _ranking.toString()),
                            _buildStatItem('积分', _points.toString()),
                            _buildStatItem('获赞', _awards.toString()),
                            _buildStatItem('浏览', _postsViewed.toString()),
                            _buildStatItem('关注', _following.toString()),
                            _buildStatItem('粉丝', _followers.toString()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 统计数据与会员卡片区域
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    // 会员卡片
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2A2D3E), Color(0xFF1F2029)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [],
                              border: Border.all(
                                  color: const Color(0xFF3E4152), width: 1),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF3E7E9),
                                            Color(0xFFE3EEFF)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.diamond_outlined,
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'LinkMe 会员',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFF2E5C8),
                                                  fontFamily: 'Outfit',
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                    colors: [
                                                      Color(0xFFD4AF37),
                                                      Color(0xFFFFD700)
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'PRO',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF2A2D3E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            '解锁 AI 助手、云端同步等 12 项特权',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        _buildVipFeatureItem(
                                            Icons.smart_toy_outlined, 'AI助手'),
                                        const SizedBox(width: 16),
                                        _buildVipFeatureItem(
                                            Icons.cloud_upload_outlined, '云同步'),
                                        const SizedBox(width: 16),
                                        _buildVipFeatureItem(
                                            Icons.remove_red_eye_outlined,
                                            '访客'),
                                      ],
                                    ),
                                    ScaleTransition(
                                      scale: _pulseAnimation,
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          // TODO: 开通会员
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFF2E5C8),
                                                Color(0xFFD4AF37)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFD4AF37)
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _isVip ? '立即续费' : '立即开通',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2A2D3E),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 装饰性背景圆圈
                          Positioned(
                            top: -40,
                            right: -40,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF2E5C8)
                                    .withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tab栏
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: const Color(0xFF666666),
                  labelStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.normal),
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 4,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: UnderlineTabIndicator(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(width: 4, color: AppColors.primary),
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: '帖子'),
                    Tab(text: '关注'),
                    Tab(text: '粉丝'),
                    Tab(text: '评论'),
                    Tab(text: '笔记'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsList(),
            _buildFollowingList(),
            _buildFollowersList(),
            _buildCommentsList(),
            _buildNotesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipFeatureItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildRefreshIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: (_refreshOffset > 0 || _isRefreshing || _refreshSuccess) ? 50 : 0,
      color: const Color(0xFFF6F7FB),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_refreshSuccess)
            SvgPicture.asset(
              'assets/app_icons/svg/tick-circle.svg',
              width: 16,
              height: 16,
              colorFilter:
                  const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            )
          else if (_isRefreshing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          else
            SvgPicture.asset(
              'assets/app_icons/svg/arrow-down.svg',
              width: 16,
              height: 16,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn),
            ),
          const SizedBox(width: 8),
          Text(
            _refreshSuccess
                ? '刷新成功'
                : (_isRefreshing
                    ? '正在刷新'
                    : (_refreshOffset > 60 ? '松手刷新' : '下拉刷新')),
            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (_isDraggingList &&
              notification.metrics.pixels < 0 &&
              !_isRefreshing) {
            setState(() => _refreshOffset = -notification.metrics.pixels);
          }
        } else if (notification is ScrollEndNotification) {
          if (_refreshOffset > 60 && !_isRefreshing) {
            _startRefresh();
          } else {
            setState(() => _refreshOffset = 0);
          }
        }
        return false;
      },
      child: Listener(
        onPointerDown: (_) => _isDraggingList = true,
        onPointerUp: (_) => _isDraggingList = false,
        onPointerCancel: (_) => _isDraggingList = false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildRefreshIndicator()),
            if (_userPosts.isEmpty)
              if (_isError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset('assets/app_icons/svg/danger.svg',
                            width: 48,
                            height: 48,
                            colorFilter: const ColorFilter.mode(
                                Color(0xFFCCCCCC), BlendMode.srcIn)),
                        const SizedBox(height: 16),
                        const Text('服务器错误，请稍后重试',
                            style: TextStyle(
                                color: Color(0xFF999999), fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else if (_isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset('assets/app_icons/svg/document.svg',
                            width: 48,
                            height: 48,
                            colorFilter: const ColorFilter.mode(
                                Color(0xFFCCCCCC), BlendMode.srcIn)),
                        const SizedBox(height: 16),
                        const Text('当前没有帖子',
                            style: TextStyle(
                                color: Color(0xFF999999), fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < _userPosts.length) {
                      return _buildPostCard(_userPosts[index]);
                    } else if (_hasMorePosts && !_isLoadingPosts) {
                      _loadUserPosts();
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                    } else if (_isLoadingPosts) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                    }
                    return null;
                  },
                  childCount: _userPosts.length + 1,
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final isArticle =
        post['title'] != null && (post['title'] as String).isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: post['id'] as int,
              isArticle: isArticle,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isArticle) ...[
              // 长文模式：左文右图
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post['contentPreview'] ?? '',
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF666666)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (post['images'] != null &&
                      (post['images'] as List).isNotEmpty) ...[
                    const SizedBox(width: 12),
                    // 长文主图 (1张)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        (post['images'] as List).first.toString(),
                        width: 100,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderImage(100, 75),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              // 打卡模式：上文下多图
              RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF333333), height: 1.5),
                  children: [
                    TextSpan(text: post['contentPreview'] ?? ''),
                    const TextSpan(
                      text: ' 全文',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (post['images'] != null &&
                  (post['images'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                // 打卡图 (最多显示3张)
                Row(
                  children: List.generate(
                    (post['images'] as List).length > 3
                        ? 3
                        : (post['images'] as List).length,
                    (index) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              (post['images'] as List)[index].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholderImage(
                                      double.infinity, double.infinity),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            // 用户信息
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: post['authorAvatar'] != null
                      ? NetworkImage(post['authorAvatar'])
                      : null,
                  child: post['authorAvatar'] == null
                      ? SvgPicture.asset(
                          'assets/app_icons/svg/user.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                              AppColors.primary, BlendMode.srcIn),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(post['authorName'] ?? '用户',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333))),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Lv.${post['authorLevel'] ?? 1}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFF9800),
                          fontWeight: FontWeight.w600)),
                ),
                if (post['isVip'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('VIP',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                Text(_formatTime(post['createdAt']),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
            if (post['latestComment'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/app_icons/svg/message.svg',
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF999999), BlendMode.srcIn),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post['latestComment'],
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF666666)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (post['topics'] != null &&
                    (post['topics'] as List).isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('#${(post['topics'] as List).first}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary)),
                  ),
                const Spacer(),
                _buildActionButton('assets/app_icons/svg/heart.svg',
                    '${post['likeCount'] ?? 0}'),
                const SizedBox(width: 16),
                _buildActionButton('assets/app_icons/svg/message.svg',
                    '${post['commentCount'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic createdAt) {
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
      } else if (diff.inDays < 7) {
        return '${diff.inDays}天前';
      } else {
        return '${time.month}-${time.day}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildActionButton(String iconPath, String count) {
    return Row(
      children: [
        SvgPicture.asset(
          iconPath,
          width: 18,
          height: 18,
          colorFilter:
              const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn),
        ),
        const SizedBox(width: 4),
        Text(count,
            style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
      ],
    );
  }

  Widget _buildFollowingList() {
    if (_isLoadingFollowing && _followingList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/app_icons/svg/user-group.svg',
              width: 64,
              height: 64,
              colorFilter: const ColorFilter.mode(
                Color(0xFFCCCCCC),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有关注任何人',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _followingList.length + (_hasMoreFollowing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _followingList.length) {
          if (!_isLoadingFollowing) {
            _loadFollowingList();
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _buildUserCard(_followingList[index], isFollowing: true);
      },
    );
  }

  Widget _buildFollowersList() {
    if (_isLoadingFollowers && _followersList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followersList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/app_icons/svg/user-group.svg',
              width: 64,
              height: 64,
              colorFilter: const ColorFilter.mode(
                Color(0xFFCCCCCC),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有粉丝',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _followersList.length + (_hasMoreFollowers ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _followersList.length) {
          if (!_isLoadingFollowers) {
            _loadFollowersList();
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _buildUserCard(_followersList[index], isFollowing: false);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user,
      {required bool isFollowing}) {
    final nickname = user['nickname'] ?? '用户${user['userId']}';
    final avatar = user['avatar'];
    final level = user['level'] ?? 1;
    final majorTag = user['majorTag'];
    final university = user['university'];
    final education = user['education'];
    final isVip = user['isVip'] ?? false;
    final userIsFollowing = user['isFollowing'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Stack(
            children: [
              ClipOval(
                child: Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey[200],
                  child: avatar != null
                      ? Image.network(avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              UserAvatar(name: nickname, size: 56))
                      : UserAvatar(name: nickname, size: 56),
                ),
              ),
              if (isVip)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Text(
                      'V',
                      style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Lv.$level',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFFF9800),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (majorTag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(majorTag,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.primary)),
                      ),
                    if (university != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/app_icons/svg/building.svg',
                            width: 11,
                            height: 11,
                            colorFilter: const ColorFilter.mode(
                                Color(0xFF999999), BlendMode.srcIn),
                          ),
                          const SizedBox(width: 3),
                          Text(university,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF999999))),
                        ],
                      ),
                    if (education != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/app_icons/svg/teacher.svg',
                            width: 11,
                            height: 11,
                            colorFilter: const ColorFilter.mode(
                                Color(0xFF999999), BlendMode.srcIn),
                          ),
                          const SizedBox(width: 3),
                          Text(education,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF999999))),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await _toggleFollowUser(user['userId'], userIsFollowing);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: userIsFollowing
                    ? const Color(0xFFF5F5F5)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                userIsFollowing ? '已关注' : (isFollowing ? '回关' : '关注'),
                style: TextStyle(
                  fontSize: 13,
                  color: userIsFollowing
                      ? const Color(0xFF666666)
                      : AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 切换关注用户
  Future<void> _toggleFollowUser(
      int targetUserId, bool currentlyFollowing) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) return;

    try {
      final success = currentlyFollowing
          ? await AcademyApi.unfollowUser(userId, targetUserId)
          : await AcademyApi.followUser(userId, targetUserId);

      if (success && mounted) {
        // 更新列表中的关注状态
        setState(() {
          // 更新关注列表
          for (var user in _followingList) {
            if (user['userId'] == targetUserId) {
              user['isFollowing'] = !currentlyFollowing;
            }
          }
          // 更新粉丝列表
          for (var user in _followersList) {
            if (user['userId'] == targetUserId) {
              user['isFollowing'] = !currentlyFollowing;
            }
          }

          // 更新统计数据
          if (currentlyFollowing) {
            _following = _following > 0 ? _following - 1 : 0;
          } else {
            _following++;
          }
        });
      }
    } catch (e) {
      print('关注操作失败: $e');
    }
  }

  Widget _buildCommentsList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 8,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/app_icons/svg/message.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                      AppColors.primary, BlendMode.srcIn),
                ),
                const SizedBox(width: 8),
                const Text('我评论了帖子',
                    style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                const Spacer(),
                const Text('1小时前',
                    style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '这是我发表的评论内容，写得很精彩...',
              style: TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '原帖：这是原帖的标题内容...',
                style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/app_icons/svg/note.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                      AppColors.primary, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('学习笔记标题',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333))),
                  SizedBox(height: 4),
                  Text('3天前 · 来自Flutter课程',
                      style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.image, color: Color(0xFFCCCCCC)),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

class _EditProfilePage extends StatefulWidget {
  final String? nickname;
  final String? avatar;
  final String? majorTag;
  final String? university;
  final String? education;

  const _EditProfilePage({
    this.nickname,
    this.avatar,
    this.majorTag,
    this.university,
    this.education,
  });

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  late String? _nickname;
  late String? _avatar;
  late String? _majorTag;
  int? _majorTagId;
  late String? _university;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nickname = widget.nickname;
    _avatar = widget.avatar;
    _majorTag = widget.majorTag;
    _university = widget.university;
  }

  Future<void> _saveProfile() async {
    if (!_hasChanges || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      await AcademyApi.updateProfile(
        userId: userId,
        nickname: _nickname,
        avatar: _avatar,
        majorTagId: _majorTagId,
        university: _university,
      );

      if (mounted) {
        CustomToast.showSuccess(context, '保存成功');
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('保存资料失败: $e');
      if (mounted) {
        CustomToast.showError(context, '保存失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '请输入昵称',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != _nickname) {
      setState(() {
        _nickname = result;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        CustomToast.showInfo(context, '正在上传...');
        final imageUrl = await AcademyApi.uploadImage(File(image.path));
        setState(() {
          _avatar = imageUrl;
          _hasChanges = true;
        });
        if (mounted) {
          CustomToast.showSuccess(context, '头像上传成功');
        }
      }
    } catch (e) {
      print('选择头像失败: $e');
      if (mounted) {
        CustomToast.showError(context, '上传失败');
      }
    }
  }

  Future<void> _selectMajorTag() async {
    try {
      final tags = await AcademyApi.getMajorTags();
      if (!mounted) return;

      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '选择主攻方向',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 24),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return ListTile(
                      title: Text(tag['name']),
                      trailing: _majorTag == tag['name']
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, tag),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _majorTag = result['name'];
          _majorTagId = result['id'];
          _hasChanges = true;
        });
      }
    } catch (e) {
      print('获取主攻方向标签失败: $e');
      if (mounted) {
        CustomToast.showError(context, '加载失败');
      }
    }
  }

  Future<void> _editUniversity() async {
    final controller = TextEditingController(text: _university);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑学校'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '请输入学校名称',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != _university) {
      setState(() {
        _university = result;
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: Color(0xFF333333)),
        ),
        title: const Text(
          '编辑资料',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: TextButton.styleFrom(
                foregroundColor: _hasChanges ? AppColors.primary : Colors.grey,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Container(
            color: Colors.white,
            child: _buildEditItem(
              '头像',
              trailing: ClipOval(
                child: Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey[200],
                  child: _avatar != null
                      ? Image.network(_avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => UserAvatar(
                              name: _nickname ?? user?.nickname, size: 56))
                      : UserAvatar(name: _nickname ?? user?.nickname, size: 56),
                ),
              ),
              onTap: _selectAvatar,
            ),
          ),
          const SizedBox(height: 1),
          Container(
            color: Colors.white,
            child: _buildEditItem(
              '昵称',
              value: _nickname ?? user?.nickname ?? '未设置',
              onTap: _editNickname,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            color: Colors.white,
            child: _buildEditItem(
              '主攻方向',
              value: _majorTag ?? '点击添加',
              onTap: _selectMajorTag,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            color: Colors.white,
            child: _buildEditItem(
              '学校',
              value: _university ?? '点击添加',
              onTap: _editUniversity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditItem(String label,
      {String? value, Widget? trailing, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF333333))),
            const Spacer(),
            if (trailing != null)
              trailing
            else if (value != null)
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      color: value.contains('点击') || value == '未设置'
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF999999))),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
