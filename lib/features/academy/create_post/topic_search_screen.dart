import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../services/academy_api.dart';

/// topic_search_screen.dart | TopicSearchScreen | 话题搜索页面
/// 用于在发帖时选择话题，支持搜索和热门话题选择
class TopicSearchScreen extends StatefulWidget {
  const TopicSearchScreen({super.key});

  @override
  State<TopicSearchScreen> createState() => _TopicSearchScreenState();
}

class _TopicSearchScreenState extends State<TopicSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 热门话题
  List<String> _hotTopics = [];

  // 搜索结果
  List<String> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingTopics = false;

  @override
  void initState() {
    super.initState();
    _loadHotTopics();

    // 自动聚焦
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  /// 加载热门话题
  Future<void> _loadHotTopics() async {
    setState(() => _isLoadingTopics = true);
    try {
      final topics = await AcademyApi.getHotTopics();
      if (mounted) {
        setState(() {
          _hotTopics = topics;
        });
      }
    } catch (e) {
      print('加载热门话题失败: $e');
      // 使用默认话题
      if (mounted) {
        setState(() {
          _hotTopics = [
            'Flutter学习',
            'Dart',
            '移动开发',
            '前端技术',
            '算法面试',
            '考研上岸',
            '每日打卡',
            '求职经验'
          ];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTopics = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    // 模拟搜索
    setState(() {
      _isSearching = true;
      _searchResults = _hotTopics
          .where((topic) => topic.toLowerCase().contains(query.toLowerCase()))
          .toList();
      // 如果没有完全匹配的，添加一个"创建新话题"的选项
      if (!_searchResults.contains(query)) {
        _searchResults.add(query); // 允许用户创建新话题
      }
    });
  }

  /// 选中话题并返回
  void _selectTopic(String topic) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(topic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 16), // 右侧留空
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10), // 10px圆角
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: '搜索话题',
              hintStyle:
                  const TextStyle(fontSize: 14, color: Color(0xFF999999)),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset(
                  'assets/app_icons/svg/search-normal.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF999999), BlendMode.srcIn),
                ),
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              isCollapsed: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _selectTopic(_searchController.text);
              }
            },
            child: const Text('添加',
                style: TextStyle(fontSize: 16, color: AppColors.primary)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isSearching ? _buildSearchResults() : _buildHotTopics(),
      ),
    );
  }

  Widget _buildHotTopics() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '热门话题',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _hotTopics.map((topic) => _buildTopicChip(topic)).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final topic = _searchResults[index];
        final isExactMatch = topic == _searchController.text.trim();
        return ListTile(
          leading: SvgPicture.asset(
            'assets/app_icons/svg/hashtag.svg', // 假设有
            width: 20,
            height: 20,
            colorFilter:
                const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn),
          ),
          title: Text(isExactMatch ? '创建话题: $topic' : topic),
          onTap: () => _selectTopic(topic),
        );
      },
    );
  }

  Widget _buildTopicChip(String topic) {
    return GestureDetector(
      onTap: () => _selectTopic(topic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '# $topic',
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      ),
    );
  }
}
