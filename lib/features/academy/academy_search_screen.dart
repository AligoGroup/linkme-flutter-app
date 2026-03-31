import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import 'services/academy_api.dart';
import 'post_detail/post_detail_screen.dart';

/// academy_search_screen.dart | AcademySearchScreen | 学院搜索页面
/// 从底部弹出的全屏搜索页面，支持搜索课程和帖子
class AcademySearchScreen extends StatefulWidget {
  const AcademySearchScreen({super.key});

  @override
  State<AcademySearchScreen> createState() => _AcademySearchScreenState();
}

class _AcademySearchScreenState extends State<AcademySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 搜索历史
  final List<String> _searchHistory = ['Flutter开发', 'Dart语言', '移动开发'];

  // 热门搜索
  final List<String> _hotSearches = [
    'Flutter实战',
    'React Native',
    '前端开发',
    'UI设计',
    'Kotlin',
    'SwiftUI',
    '算法学习',
    '数据结构'
  ];

  @override
  void initState() {
    super.initState();
    // 延迟自动聚焦，等待页面动画完成
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// academy_search_screen.dart | _AcademySearchScreenState | _handleClose | 关闭搜索页面
  void _handleClose() {
    _searchFocusNode.unfocus();
    Navigator.of(context).pop();
  }

  /// academy_search_screen.dart | _AcademySearchScreenState | _handleSearch | 执行搜索
  /// @param query 搜索关键词
  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;

    HapticFeedback.lightImpact();

    // 添加到搜索历史
    if (!_searchHistory.contains(query)) {
      setState(() {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 10) {
          _searchHistory.removeLast();
        }
      });
    }

    // 跳转到搜索结果页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _SearchResultScreen(keyword: query),
      ),
    );
  }

  /// academy_search_screen.dart | _AcademySearchScreenState | _clearHistory | 清空搜索历史
  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    // iOS和Android的状态栏高度处理
    final topPadding = MediaQuery.of(context).padding.top;

    return GestureDetector(
      // 点击空白区域取消聚焦
      onTap: () {
        _searchFocusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 顶部搜索栏
            Container(
              padding: EdgeInsets.only(
                top: topPadding,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x0A000000),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 搜索框
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textAlignVertical: TextAlignVertical.center,
                        onSubmitted: _handleSearch,
                        decoration: InputDecoration(
                          hintText: '搜索课程、帖子...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 14,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              'assets/app_icons/svg/search-normal.svg',
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF999999),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SvgPicture.asset(
                                      'assets/app_icons/svg/close-circle.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(
                                        Color(0xFF999999),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          isCollapsed: true,
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 取消按钮
                  GestureDetector(
                    onTap: _handleClose,
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 搜索内容区域
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 搜索历史
                  if (_searchHistory.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '搜索历史',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        GestureDetector(
                          onTap: _clearHistory,
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/app_icons/svg/trash.svg',
                                width: 16,
                                height: 16,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF999999),
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '清空',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _searchHistory.map((keyword) {
                        return _buildHistoryChip(keyword);
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 热门搜索
                  const Text(
                    '热门搜索',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _hotSearches.asMap().entries.map((entry) {
                      final index = entry.key;
                      final keyword = entry.value;
                      return _buildHotSearchChip(keyword, index);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// academy_search_screen.dart | _AcademySearchScreenState | _buildHistoryChip | 搜索历史标签
  /// @param keyword 关键词
  Widget _buildHistoryChip(String keyword) {
    return GestureDetector(
      onTap: () {
        _searchController.text = keyword;
        _handleSearch(keyword);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/app_icons/svg/clock.svg',
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                Color(0xFF999999),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              keyword,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// academy_search_screen.dart | _AcademySearchScreenState | _buildHotSearchChip | 热门搜索标签
  /// @param keyword 关键词
  /// @param index 索引（用于显示排名）
  Widget _buildHotSearchChip(String keyword, int index) {
    final isTop3 = index < 3;

    return GestureDetector(
      onTap: () {
        _searchController.text = keyword;
        _handleSearch(keyword);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isTop3
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isTop3 ? null : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
          border: isTop3
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTop3)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFC06FFF)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF999999),
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              keyword,
              style: TextStyle(
                fontSize: 13,
                color: isTop3 ? AppColors.primary : const Color(0xFF666666),
                fontWeight: isTop3 ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// _SearchResultScreen | 搜索结果页面
class _SearchResultScreen extends StatefulWidget {
  final String keyword;

  const _SearchResultScreen({required this.keyword});

  @override
  State<_SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<_SearchResultScreen> {
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSearchResults();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadSearchResults();
    }
  }

  Future<void> _loadSearchResults({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final page = refresh ? 0 : _currentPage;
      final result = await AcademyApi.searchPosts(
        keyword: widget.keyword,
        page: page,
        size: 10,
      );

      if (mounted) {
        final List<dynamic> content = result['content'] ?? [];
        final posts = content.map((e) => e as Map<String, dynamic>).toList();

        setState(() {
          if (refresh) {
            _searchResults = posts;
            _currentPage = 0;
          } else {
            _searchResults.addAll(posts);
          }
          _currentPage = page + 1;
          _hasMore = !(result['last'] ?? true);
        });
      }
    } catch (e) {
      print('搜索失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('搜索失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '搜索: ${widget.keyword}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ),
      body: _searchResults.isEmpty && !_isLoading
          ? const Center(
              child: Text('暂无搜索结果',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount:
                  _searchResults.length + (_hasMore || _isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _searchResults.length) {
                  return _buildPostCard(_searchResults[index]);
                } else {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
              },
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
            ],
            Text(
              post['contentPreview'] ?? '',
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(post['authorName'] ?? '用户',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF666666))),
                const Spacer(),
                Text('${post['likeCount'] ?? 0} 赞',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
                const SizedBox(width: 16),
                Text('${post['commentCount'] ?? 0} 评论',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
