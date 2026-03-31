import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/websocket_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/services/hot_service.dart';
import '../../widgets/common/gradient_icon.dart';
import '../../widgets/common/gradient_text.dart';
import 'hot_search_result_screen.dart';
import 'widgets/hot_rank_card.dart';

/// 统一入口：桌面端用 Desktop 布局，其他平台用 Mobile 布局
class HotScreen extends StatelessWidget {
  const HotScreen({super.key});

  static bool get _isMacOSDesktop => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (_isMacOSDesktop) return const _HotDesktopScreen();
    return const _HotMobileScreen();
  }
}

/// 移动端实现
class _HotMobileScreen extends StatefulWidget {
  const _HotMobileScreen();

  @override
  State<_HotMobileScreen> createState() => _HotMobileScreenState();
}

class _HotMobileScreenState extends State<_HotMobileScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _rankCards = const [];
  List<String> _categories = const [];
  int _selectedCat = 0;
  bool _showPublishBtn = true;
  bool _searchFocused = false; // 搜索框聚焦状态，用于控制左侧图标/标题的缩放消失

  @override
  void initState() {
    super.initState();
    _restoreCache();
    // 拉取卡片与分类
    HotService().fetchRankCards().then((res) {
      if (!mounted) return;
      if (res.success && res.data != null) {
        final cards = res.data!
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() { _rankCards = cards; });
        _HotCache.saveRankCards(cards);
      }
    });
    HotService().fetchCategories().then((res) {
      if (!mounted) return;
      if (res.success && res.data != null) {
        final cats = res.data!
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final names = cats.map((e)=> e['name'].toString()).toList();
        setState(() { _categories = names; });
        _HotCache.saveCategories(cats);
      }
    });
    // 监听 WebSocket 实时事件：菜单/分类/排行更新
    WebSocketManager().messageStream.listen((msg) {
      final t = (msg['type'] ?? '').toString();
      if (t == 'HOT_CATEGORIES_UPDATED') {
        HotService().fetchCategories().then((res) {
          if (!mounted) return;
          if (res.success && res.data != null) {
            final cats = res.data!
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final names = cats.map((e)=> e['name'].toString()).toList();
            setState(() { _categories = names; });
            _HotCache.saveCategories(cats);
          }
        });
      } else if (t == 'HOT_RANK_UPDATED') {
        HotService().fetchRankCards().then((res) {
          if (!mounted) return;
          if (res.success && res.data != null) {
            final cards = res.data!
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            setState(() { _rankCards = cards; });
            _HotCache.saveRankCards(cards);
          }
        });
      }
    });
  }

  void _restoreCache() {
    _HotCache.loadRankCards().then((list) {
      if (!mounted || list == null) return;
      setState(() { _rankCards = list; });
    });
    _HotCache.loadCategories().then((list) {
      if (!mounted || list == null) return;
      final names = list.map((e) => (e['name'] ?? '').toString()).toList();
      setState(() { _categories = names; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _rankCards.map((c) => _buildHotCard(c['title']?.toString() ?? '热榜', cardId: (c['id'] as num?)?.toInt())).toList();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        // 与返回图标保持 1px 间距；搜索框放到标题右侧并占满剩余宽度
        titleSpacing: 1,
        centerTitle: false,
        title: Row(
          children: [
            // 左侧“火苗+热度榜单”，在聚焦时做一个横向收缩+淡出动画
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(sizeFactor: anim, axis: Axis.horizontal, axisAlignment: -1.0, child: child),
              ),
              child: _searchFocused
                  ? const SizedBox.shrink(key: ValueKey('hot_title_hidden'))
                  : Row(
                      key: const ValueKey('hot_title_visible'),
                      children: const [
                        GradientIcon(icon: Icons.local_fire_department, size: 20, gradient: AppColors.hotGradient),
                        SizedBox(width: 6),
                        Text('热度榜单'),
                        SizedBox(width: 14),
                      ],
                    ),
            ),
            // 搜索框右侧预留与手机边框同等间距（通常为 16），右侧不动；左侧根据上面动画平滑拉伸
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _HotSearchFieldMobile(
                  onFocusChange: (f) => setState(() => _searchFocused = f),
                ),
              ),
            ),
          ],
        ),
      ),
      // 整页保持一个垂直滚动列表：热点卡片 -> 菜单(可横向滑动) -> 两栏文章
      // 点击空白处可收起键盘
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // 更鲁棒：
              // - 任何开始/更新/越界 → 隐藏
              // - UserScroll(direction == idle) 或 ScrollEnd → 立即显示
              if (n is UserScrollNotification) {
                if (n.direction == ScrollDirection.idle) {
                  if (!_showPublishBtn) setState(() => _showPublishBtn = true);
                } else {
                  if (_showPublishBtn) setState(() => _showPublishBtn = false);
                }
                return false;
              }
              if (n is ScrollStartNotification || n is ScrollUpdateNotification || n is OverscrollNotification) {
                if (_showPublishBtn) setState(() => _showPublishBtn = false);
              } else if (n is ScrollEndNotification) {
                if (!_showPublishBtn) setState(() => _showPublishBtn = true);
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: 12)),
                // 热点卡片区域
                SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, viewport) {
                      final screenW = viewport.maxWidth;
                      const double outer = 12; // 首末与屏幕边距
                      const double gap = 5;   // 两卡间距 5px
                      final double base = (screenW - 40) * 0.6;
                      final double targetW = base + 70;
                      final double maxW = screenW - outer * 2 - gap;
                      final double cardW = targetW.clamp(220.0, maxW);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: outer),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < pages.length; i++) ...[
                                SizedBox(width: cardW, child: pages[i]),
                                if (i != pages.length - 1) SizedBox(width: gap),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                // 吸附的分类菜单
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryHeaderDelegate(
                    minExtent: 44,
                    maxExtent: 44,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _CategoryMenu(
                          categories: _categories,
                          selectedIndex: _selectedCat,
                          onSelected: (i) => setState(() => _selectedCat = i),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                // 列表内容
                SliverToBoxAdapter(
                  child: Builder(builder: (context) {
                    final Key currentKey = ValueKey(_selectedCat);
                    return _categories.isEmpty
                          ? const SizedBox.shrink()
                          : _MHArticlesMasonry(key: currentKey, category: _categories[_selectedCat]);
                  }),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
              ],
            ),
          ),
          // 右侧 20% 高度处的发布按钮（滑动时隐藏，停止后显示）
          _PublishButton(visible: _showPublishBtn || MediaQuery.of(context).viewInsets.bottom > 0),
          ],
        ),
      ),
    );
  }

  Widget _buildHotCard(String title, {int? cardId}) => buildHotCard(title, scale: 0.6, cardId: cardId);
}

/// 桌面端实现：标题在标题栏下方 5px，右侧带搜索框；卡片固定为“移动端宽度”
class _HotDesktopScreen extends StatefulWidget {
  const _HotDesktopScreen();

  @override
  State<_HotDesktopScreen> createState() => _HotDesktopScreenState();
}

class _HotDesktopScreenState extends State<_HotDesktopScreen> {
  List<Map<String, dynamic>> _rankCards = const [];
  List<String> _categories = const [];
  int _selectedCat = 0;
  final ScrollController _scrollCtrl = ScrollController();

  static const double _titlebarSpace = 28; // 与桌面主页一致的顶部保留
  static const double _afterTitlebarGap = 5; // 题目要求：与关闭按钮下方 5px 间距
  static const double _hPadding = 16;
  static const double _mobileCardWidth = 335; // 近似移动端卡片宽度

  @override
  void initState() {
    super.initState();
    _restoreCache();
    HotService().fetchRankCards().then((res) {
      if (!mounted) return;
      if (res.success && res.data != null) {
        final cards = res.data!
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() { _rankCards = cards; });
        _HotCache.saveRankCards(cards);
      }
    });
    HotService().fetchCategories().then((res) {
      if (!mounted) return;
      if (res.success && res.data != null) {
        final cats = res.data!
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final names = cats.map((e)=> e['name'].toString()).toList();
        setState(() { _categories = names; });
        _HotCache.saveCategories(cats);
      }
    });
    // 桌面端补充实时订阅：后台更新分类后自动刷新
    WebSocketManager().messageStream.listen((msg) {
      final t = (msg['type'] ?? '').toString();
      if (t == 'HOT_CATEGORIES_UPDATED') {
        HotService().fetchCategories().then((res) {
          if (!mounted) return;
          if (res.success && res.data != null) {
            final cats = res.data!
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final names = cats.map((e)=> e['name'].toString()).toList();
            setState(() { _categories = names; });
            _HotCache.saveCategories(cats);
          }
        });
      } else if (t == 'HOT_RANK_UPDATED') {
        HotService().fetchRankCards().then((res) {
          if (!mounted) return;
          if (res.success && res.data != null) {
            final cards = res.data!
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            setState(() { _rankCards = cards; });
            _HotCache.saveRankCards(cards);
          }
        });
      }
    });
  }

  void _restoreCache() {
    _HotCache.loadRankCards().then((list) {
      if (!mounted || list == null) return;
      setState(() { _rankCards = list; });
    });
    _HotCache.loadCategories().then((list) {
      if (!mounted || list == null) return;
      final names = list.map((e) => (e['name'] ?? '').toString()).toList();
      setState(() { _categories = names; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // 我们自己处理标题栏留白
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: _titlebarSpace + _afterTitlebarGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPadding),
              child: Row(
                children: const [
                  // 标题
                  GradientIcon(icon: Icons.local_fire_department, size: 20, gradient: AppColors.hotGradient),
                  SizedBox(width: 8),
                  Text('热度榜单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(width: 5),
                  // 紧挨着标题右侧，间距 5px，不顶到窗口最右
                  _HotSearchField(width: 300),
                  Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RawScrollbar(
                controller: _scrollCtrl,
                thumbVisibility: true,
                interactive: true,
                thickness: 4,
                radius: const Radius.circular(3),
                crossAxisMargin: 0, // 贴紧窗口右侧
                mainAxisMargin: 0,
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  child: LayoutBuilder(
                    builder: (context, viewport) {
                      // 让滚动内容至少占满视口宽度，保证滚动条贴到窗口最右侧
                      return ConstrainedBox(
                        constraints: BoxConstraints(minWidth: viewport.maxWidth),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _hPadding, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 上方热榜卡片（全部来自后台配置）
                              Wrap(
                                alignment: WrapAlignment.start,
                                spacing: 16,
                                runSpacing: 16,
                                children: _rankCards
                                    .map((c) => SizedBox(width: _mobileCardWidth, child: _HotDesktopCard(title: (c['title'] ?? '热榜').toString(), cardId: (c['id'] as num?)?.toInt())))
                                    .toList(),
                              ),
                              const SizedBox(height: 20),
                              // 左侧品类菜单
                              if (_categories.isNotEmpty)
                                _CategoryMenu(
                                  categories: _categories,
                                  selectedIndex: _selectedCat,
                                  onSelected: (i) => setState(() => _selectedCat = i),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text('暂无分类', style: TextStyle(color: AppColors.textLight)),
                                ),
                              const SizedBox(height: 10),
                              // 文章瀑布/网格
                              _ArticleGrid(category: _categories[_selectedCat]),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // 底部版权信息（窗口底部居中）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  '橘猫集团，Link Me',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textLight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotDesktopCard extends StatelessWidget {
  final String title; final int? cardId;
  const _HotDesktopCard({required this.title, this.cardId});

  @override
  Widget build(BuildContext context) => buildHotCard(title, cardId: cardId);
}

/// 底部左侧的品类菜单（示例样式：选中项红色且带下划线，其余灰色）
class _CategoryMenu extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _CategoryMenu({required this.categories, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      children: [
        for (int i = 0; i < categories.length; i++)
          _CatItem(
            label: categories[i],
            active: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
      ],
    );
  }
}

class _CatItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CatItem({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = active ? const Color(0xFFFF3B30) : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: textColor)),
            const SizedBox(height: 2),
            SizedBox(
              width: 60, // 预留包裹宽度，保证下划线可居中（线本身更短）
              child: Align(
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeInOut,
                  width: active ? 28 : 0,
                  height: 2,
                  decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleGrid extends StatefulWidget {
  final String category;
  const _ArticleGrid({required this.category});
  @override State<_ArticleGrid> createState() => _ArticleGridState();
}

class _ArticleGridState extends State<_ArticleGrid> {
  List<_Article> _items = const [];
  @override void initState(){
    super.initState();
    _loadFromCache();
    _load();
  }
  @override void didUpdateWidget(covariant _ArticleGrid old){
    super.didUpdateWidget(old);
    if (old.category != widget.category) {
      _loadFromCache();
      _load();
    }
  }
  Future<void> _loadFromCache() async {
    final cached = await _HotCache.loadArticles(widget.category);
    if (cached != null && mounted) {
      setState(() { _items = cached; });
    }
  }
  Future<void> _load() async {
    final res = await HotService().listByCategory(category: widget.category, page: 0, size: 20);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final next = ((res.data!['articles'] as List?) ?? []).map(_Article.fromMap).toList();
      setState(() { _items = next; });
      unawaited(_HotCache.saveArticles(widget.category, next));
    } else if (_items.isEmpty) {
      setState(() { _items = const []; });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('暂无内容', style: TextStyle(color: AppColors.textLight)));
    return Wrap(spacing: 16, runSpacing: 16, children: [for (final a in _items) SizedBox(width: 360, child: _ArticleCard(article: a))]);
  }
}

class _Article {
  final int? id;
  final String title;
  final String summary;
  final String publisher;
  final String publishedAt;
  final String imageUrl;
  const _Article({this.id, required this.title, required this.summary, required this.publisher, required this.publishedAt, required this.imageUrl});

  factory _Article.fromMap(dynamic json) {
    if (json is! Map) {
      return _Article(
        id: null,
        title: '',
        summary: '',
        publisher: '',
        publishedAt: '',
        imageUrl: '',
      );
    }
    return _Article(
      id: (json['id'] as num?)?.toInt(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      publisher: (json['authorName'] ?? json['publisher'] ?? '用户发布').toString(),
      publishedAt: (json['createdAt'] ?? json['publishedAt'] ?? '').toString(),
      imageUrl: (json['coverImage'] ?? json['imageUrl'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'publisher': publisher,
        'publishedAt': publishedAt,
        'imageUrl': imageUrl,
      };
}

class _ArticleCard extends StatefulWidget {
  final _Article article;
  const _ArticleCard({required this.article});

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final borderWidth = 1.0 / MediaQuery.of(context).devicePixelRatio;
    final borderColor = _hover ? const Color(0xFFFF7A00) : const Color(0xFFE6E6E6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final a = widget.article;
          final payload = {
            'id': a.id,
            'title': a.title,
            'summary': a.summary,
            'publisher': a.publisher,
            'publishedAt': a.publishedAt,
            'imageUrl': a.imageUrl,
          };
          try { context.push('/hot/article', extra: payload); } catch (_) {}
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主图
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                child: AspectRatio(
                  aspectRatio: 16/9,
                  child: Image.network(widget.article.imageUrl, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.article.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(widget.article.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(widget.article.publisher, style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
                        ),
                        Text(widget.article.publishedAt, style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotCache {
  static const String _rankCardsKey = 'hot_rank_cards_cache_v1';
  static const String _categoriesKey = 'hot_categories_cache_v1';
  static const String _articlesPrefix = 'hot_articles_cache_v1_';

  static Future<List<Map<String, dynamic>>?> loadRankCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_rankCardsKey);
      if (raw == null || raw.isEmpty) return null;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRankCards(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rankCardsKey, jsonEncode(data));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>?> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_categoriesKey);
      if (raw == null || raw.isEmpty) return null;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCategories(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_categoriesKey, jsonEncode(data));
    } catch (_) {}
  }

  static Future<List<_Article>?> loadArticles(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_articlesPrefix + category);
      if (raw == null || raw.isEmpty) return null;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => _Article.fromMap(e))
          .toList();
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveArticles(String category, List<_Article> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _articlesPrefix + category, jsonEncode(articles.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}

/// 移动端：心理健康主题文章数据模型
class _MHArticle {
  final int? id; // 后端文章ID（hot_articles）
  final String title;
  final String summary;
  final String publisher;
  final String publishedAt;
  final String imageUrl;
  final int reads;
  final int heat;
  final int comments;
  final bool isHot;
  const _MHArticle({
    this.id,
    required this.title,
    required this.summary,
    required this.publisher,
    required this.publishedAt,
    required this.imageUrl,
    required this.reads,
    required this.heat,
    required this.comments,
    this.isHot = false,
  });
}

/// 右侧发布按钮（相机 + 发布内容），滑动隐藏，停止后显示
class _PublishButton extends StatelessWidget {
  final bool visible;
  const _PublishButton({required this.visible});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final double kb = media.viewInsets.bottom; // 键盘高度
    // 关键：在键盘收起动画期间，避免按钮先沉到底部再回弹到 20%。
    // 使用 max(键盘+5, 屏幕*20%)，这样当 kb 从一个正值逐渐减小到 0 时，
    // 按钮始终不会低于 20% 的位置。
    final double targetBottom = (kb > 0)
        ? ((kb + 5) > (size.height * 0.20) ? (kb + 5) : (size.height * 0.20))
        : (size.height * 0.20);
    return AnimatedPositioned(
      right: 0,
      bottom: targetBottom,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : const Offset(1.0, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/hot/publish'),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFF3D00)]),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(5), bottomLeft: Radius.circular(5)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.photo_camera_outlined, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('发布内容', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 演示数据已删除；文章瀑布流完全走后端

class _MHArticlesMasonry extends StatefulWidget {
  final String category;
  const _MHArticlesMasonry({super.key, required this.category});

  @override
  State<_MHArticlesMasonry> createState() => _MHArticlesMasonryState();
}

class _MHArticlesMasonryState extends State<_MHArticlesMasonry> {
  List<_MHArticle> _data = const [];

  @override
  void initState() {
    super.initState();
    _load();
    // 监听后端广播：有新文章发布/文章更新时刷新当前分类
    WebSocketManager().messageStream.listen((msg) {
      final t = (msg['type'] ?? '').toString();
      if (t == 'HOT_ARTICLES_UPDATED') {
        if (mounted) _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MHArticlesMasonry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) _load();
  }

  Future<void> _load() async {
    final res = await HotService().listByCategory(category: widget.category, page: 0, size: 20);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = (res.data!['articles'] as List? ?? []);
      setState(() {
        _data = list.map((m) => _MHArticle(
          id: (m['id'] as num?)?.toInt(),
          title: m['title']?.toString() ?? '',
          summary: m['summary']?.toString() ?? '',
          publisher: (m['authorName'] ?? '用户发布').toString(),
          publishedAt: (m['createdAt'] ?? '').toString(),
          imageUrl: m['coverImage']?.toString() ?? '',
          reads: 0, heat: 0, comments: 0, isHot: false,
        )).toList();
      });
    } else {
      setState(() { _data = const []; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return LayoutBuilder(
      builder: (context, c) {
        final double hPad = 12;
        final double gutter = 8;
        final double colW = (c.maxWidth - hPad * 2 - gutter) / 2;
        if (data.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
            child: SizedBox(
              height: 80,
              child: Center(child: Text('暂无内容', style: TextStyle(color: AppColors.textLight))),
            ),
          );
        }
        final left = <Widget>[];
        final right = <Widget>[];
        for (int i = 0; i < data.length; i++) {
          final card = _MHArticleCard(
            article: data[i],
            width: colW,
            onTap: () {
              final a = data[i];
              final payload = {
                'id': a.id,
                'title': a.title,
                'summary': a.summary,
                'publisher': a.publisher,
                'publishedAt': a.publishedAt,
                'imageUrl': a.imageUrl,
                'reads': a.reads,
                'heat': a.heat,
                'comments': a.comments,
                'isHot': a.isHot,
              };
              // 路由到文章详情
              try {
                // 需要 go_router 上下文扩展
                // ignore: use_build_context_synchronously
                context.push('/hot/article', extra: payload);
              } catch (_) {}
            },
          );
          if (i % 2 == 0) {
            left.add(card);
          } else {
            right.add(card);
          }
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: colW,
                child: Column(children: _withSpacing(left, 8)),
              ),
              SizedBox(width: gutter),
              SizedBox(
                width: colW,
                child: Column(children: _withSpacing(right, 8)),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _withSpacing(List<Widget> items, double space) {
    final out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(SizedBox(height: space));
    }
    return out;
  }
}

class _MHArticleCard extends StatelessWidget {
  final _MHArticle article;
  final double width;
  final VoidCallback? onTap;
  const _MHArticleCard({required this.article, required this.width, this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderWidth = 1.0 / MediaQuery.of(context).devicePixelRatio;
    final card = Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEFEFEF), width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主图
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(article.imageUrl, fit: BoxFit.cover),
                ),
                if (article.isHot)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text('热点', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(article.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
                const SizedBox(height: 8),
                // 发布者 + 时间
                Row(
                  children: [
                    Expanded(child: Text(article.publisher, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    Text(article.publishedAt, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
                const SizedBox(height: 8),
                // 指标：阅读在左，热度/评论在右
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 3),
                    Text(_formatK(article.reads), style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                    const Spacer(),
                    const Icon(Icons.local_fire_department, size: 14, color: Color(0xFFFF7A00)),
                    const SizedBox(width: 3),
                    Text(_formatK(article.heat), style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                    const SizedBox(width: 10),
                    const Icon(Icons.mode_comment_outlined, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 3),
                    Text(_formatK(article.comments), style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: card),
    );
  }

  static String _formatK(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return n.toString();
  }
}

/// 右上角搜索框，5px 圆角，聚焦橙色描边；右侧“搜索”文本按钮；左侧搜索图标；提示词每2-3秒轮换
class _HotSearchField extends StatefulWidget {
  final double width;
  const _HotSearchField({required this.width});

  @override
  State<_HotSearchField> createState() => _HotSearchFieldState();
}

class _HotSearchFieldState extends State<_HotSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Timer _timer;
  int _hintIndex = 0;

  final List<String> _hotHints = const [
    '瑞幸 热度 680万+',
    '奶茶 热度 673万+',
    '冰咖啡 热度 643万+',
    '饺子 热度 618万+',
    '蛋糕 热度 615万+',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _controller.text.isNotEmpty) return;
      setState(() { _hintIndex = (_hintIndex + 1) % _hotHints.length; });
    });
    _focusNode.addListener(() => setState(() {}));
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1),
    );

    return SizedBox(
      width: widget.width,
      height: 34,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        cursorColor: const Color(0xFFFF7A00), // 橙色光标
        cursorHeight: 16, // 不要撑满
        cursorRadius: const Radius.circular(2),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          // 让提示文本与输入内容在可视高度内垂直居中
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textLight),
          // 搜索图标后的小红标记：仅在未聚焦时展示，避免与输入光标并存
          // 仅在未聚焦且输入为空时显示红色小标记，避免看起来像“光标卡住”
          prefix: (!_focusNode.hasFocus && _controller.text.isEmpty)
              ? Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 2,
                  height: 16,
                  color: Color(0xFFFF4848),
                )
              : null,
          hintText: _controller.text.isEmpty ? _hotHints[_hintIndex] : null,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 12),
          enabledBorder: baseBorder,
          focusedBorder: focusedBorder,
          // 右侧“搜索”文本按钮，保留 3px 内边距，不撑满
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(3),
            child: SizedBox(
              height: double.infinity, // 使按钮在 3px 内边距内垂直铺满
              child: TextButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  // TODO: 执行搜索逻辑
                },
                style: ButtonStyle(
                  padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                  minimumSize: const MaterialStatePropertyAll(Size(0, 0)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    const Color orange = Color(0xFFFF7A00);
                    const Color orangeLight = Color(0xFFFFA24D);
                    if (states.contains(MaterialState.hovered)) return orangeLight;
                    return orange;
                  }),
                  foregroundColor: const MaterialStatePropertyAll(Colors.white),
                  overlayColor: const MaterialStatePropertyAll(Color(0x33FFFFFF)),
                  shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                ),
                child: const Text('搜索', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 移动端 AppBar 内的搜索框：
/// - 样式与桌面端 _HotSearchField 保持一致
/// - 仅将左侧的放大镜替换为一个可展开的选项按钮（搜资源 / 搜微光）
class _HotSearchFieldMobile extends StatefulWidget {
  final ValueChanged<bool>? onFocusChange;
  const _HotSearchFieldMobile({this.onFocusChange});

  @override
  State<_HotSearchFieldMobile> createState() => _HotSearchFieldMobileState();
}

class _HotSearchFieldMobileState extends State<_HotSearchFieldMobile> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Timer _timer;
  int _hintIndex = 0;
  List<Map<String, dynamic>> _menus = const [];
  int? _selectedLabelId;
  // 记录前缀选项区域的实际尺寸，使弹出的选项宽度与之保持一致
  final GlobalKey _prefixKey = GlobalKey();
  Size? _prefixSize;
  // 整个搜索框容器 Key，用于计算菜单与输入框的相对位置
  final GlobalKey _fieldKey = GlobalKey();
  // 自绘下拉菜单（不走 showMenu，避免键盘收起）
  final LayerLink _menuLink = LayerLink();
  OverlayEntry? _menuEntry;
  bool _menuOpen = false;

  static const List<String> _hotHints = <String>[
    '瑞幸 热度 680万+',
    '奶茶 热度 673万+',
    '冰咖啡 热度 643万+',
    '饺子 热度 618万+',
    '蛋糕 热度 615万+',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _controller.text.isNotEmpty) return;
      setState(() { _hintIndex = (_hintIndex + 1) % _hotHints.length; });
    });
    _focusNode.addListener(() {
      widget.onFocusChange?.call(_focusNode.hasFocus);
      setState(() {});
    });
    _controller.addListener(() => setState(() {}));
    _loadMenus();
    WebSocketManager().messageStream.listen((msg) { if ((msg['type'] ?? '') == 'HOT_MENUS_UPDATED') _loadMenus(); });
  }

  Future<void> _loadMenus() async {
    final res = await HotService().fetchMenus();
    if (!mounted || !res.success || res.data == null) return;
    setState(() {
      _menus = res.data!;
      if (_selectedLabelId == null && _menus.isNotEmpty) {
        _selectedLabelId = (_menus.first['id'] as num?)?.toInt();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    _menuEntry?.remove();
    _focusNode.dispose();
    super.dispose();
  }

  String get _scopeLabel {
    if (_selectedLabelId == null) return '选择';
    final m = _menus.firstWhere((e)=> e['id']==_selectedLabelId, orElse: ()=> const {'label':'选择'});
    return (m['label'] ?? '选择').toString();
  }

  @override
  Widget build(BuildContext context) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1),
    );

    // 左侧可展开选项（在输入框内的 prefixIcon 位置）
    Widget _buildScopeButton() {
      final textStyle = const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600);
      // 使用 GlobalKey 获取该区域宽度
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _prefixKey.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject() as RenderBox?;
          if (box != null) {
            final size = box.size;
            if (_prefixSize == null || (size.width - _prefixSize!.width).abs() > 0.5) {
              setState(() => _prefixSize = size);
            }
          }
        }
      });

      void _hideMenu() {
        _menuEntry?.remove();
        _menuEntry = null;
        _menuOpen = false;
      }

      void _openMenu() {
        if (_menuOpen) { _hideMenu(); return; }
        // 保持键盘：不推动新路由，仅插入 OverlayEntry
        _focusNode.requestFocus();
        final fieldCtx = _fieldKey.currentContext;
        if (fieldCtx == null) return;
        final fieldBox = fieldCtx.findRenderObject() as RenderBox;
        final double yOffset = fieldBox.size.height + 2;
        final double menuW = ((_prefixSize?.width ?? 120) - 2).clamp(60.0, 260.0);
        _menuEntry = OverlayEntry(
          builder: (ctx) => Stack(children: [
            // 点击任意空白关闭菜单，但不影响键盘焦点
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _menuLink,
              showWhenUnlinked: false,
              offset: Offset(0, yOffset),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints.tightFor(width: menuW),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final m in _menus)
                        InkWell(
                          onTap: () {
                            setState(() => _selectedLabelId = (m['id'] as num).toInt());
                            _hideMenu();
                            // 保持焦点
                            _focusNode.requestFocus();
                          },
                          child: Container(
                            height: 36,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              (m['label'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedLabelId == m['id'] ? const Color(0xFFFF3B30) : AppColors.textPrimary,
                                fontWeight: _selectedLabelId == m['id'] ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        );
        Overlay.of(context).insert(_menuEntry!);
        _menuOpen = true;
      }

      return CompositedTransformTarget(
        link: _menuLink,
        child: Padding(
          key: _prefixKey,
          padding: const EdgeInsets.only(left: 8, right: 6),
          child: InkWell(
            onTap: _openMenu,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_scopeLabel, style: textStyle),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more, size: 16, color: AppColors.textPrimary),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      key: _fieldKey,
      height: 34,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          // 键盘回撤的同时执行搜索
          final kw = _controller.text.trim();
          if (_selectedLabelId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HotSearchResultScreen(labelId: _selectedLabelId!, keyword: kw)),
            );
          }
        },
        cursorColor: const Color(0xFFFF7A00),
        cursorHeight: 16,
        cursorRadius: const Radius.circular(2),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          // 让提示文本与输入内容在可视高度内垂直居中
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          prefixIcon: _buildScopeButton(),
          // 左侧的红色小标记：与桌面端一致，未聚焦时显示
          // 仅在未聚焦且输入为空时显示红色小标记，避免看起来像“光标卡住”
          prefix: (!_focusNode.hasFocus && _controller.text.isEmpty)
              ? Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 2,
                  height: 16,
                  color: const Color(0xFFFF4848),
                )
              : null,
          hintText: _controller.text.isEmpty ? _hotHints[_hintIndex] : null,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 12),
          enabledBorder: baseBorder,
          focusedBorder: focusedBorder,
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(3),
            child: SizedBox(
              height: double.infinity,
              child: TextButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  if (_selectedLabelId != null) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HotSearchResultScreen(labelId: _selectedLabelId!, keyword: _controller.text.trim())));
                  }
                },
                style: ButtonStyle(
                  padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                  minimumSize: const MaterialStatePropertyAll(Size(0, 0)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    const Color orange = Color(0xFFFF7A00);
                    const Color orangeLight = Color(0xFFFFA24D);
                    if (states.contains(MaterialState.hovered)) return orangeLight;
                    return orange;
                  }),
                  foregroundColor: const MaterialStatePropertyAll(Colors.white),
                  overlayColor: const MaterialStatePropertyAll(Color(0x33FFFFFF)),
                  shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                ),
                child: const Text('搜索', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 组装卡片数据（桌面和移动共用）
Widget buildHotCard(String title, {double scale = 1.0, int? cardId}) => _HotRankCardLoader(title: title, scale: scale, cardId: cardId);

class _HotRankCardLoader extends StatefulWidget {
  final String title; final double scale; final int? cardId;
  const _HotRankCardLoader({required this.title, required this.scale, this.cardId});
  @override State<_HotRankCardLoader> createState() => _HotRankCardLoaderState();
}

class _HotRankCardLoaderState extends State<_HotRankCardLoader> {
  List<HotItem> _items = const [];
  @override void initState(){ super.initState(); _load(); WebSocketManager().messageStream.listen((msg){ if ((msg['type'] ?? '') == 'HOT_RANK_UPDATED') _load(); }); }
  Future<void> _load() async {
    final res = (widget.cardId == null)
        ? await HotService().fetchRank()
        : await HotService().fetchRankByCard(widget.cardId!);
    if (!mounted) return;
    setState(() {
      if (res.success && res.data != null) {
        _items = res.data!.map((m) => HotItem(
          title: (m['title'] ?? '').toString(),
          summary: (m['summary'] as String?) ?? '',
          heat: (m['heat'] as num? ?? 0).toInt(),
          shops: (m['shops'] as num? ?? 0).toInt(),
          promo: (m['promo'] as bool?) ?? ((m['promo'] as num?)?.toInt() == 1),
          icon: Icons.local_fire_department,
          imageUrl: (m['imageUrl'] as String?),
          articleId: (m['articleId'] as num?)?.toInt(),
        )).toList();
      } else {
        _items = const [];
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return HotRankCard(
      scale: widget.scale,
      titleBuilder: (context) => Row(
        children: [
          const GradientIcon(icon: Icons.local_fire_department, size: 18, gradient: AppColors.hotGradient),
          const SizedBox(width: 6),
          GradientText(widget.title, style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700), gradient: AppColors.hotGradient),
          const Spacer(),
          GradientText('查看全部榜单 ›', style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600), gradient: AppColors.hotGradient),
        ],
      ),
      items: _items,
      onItemTap: (item) {
        final id = item.articleId;
        if (id != null) {
          try {
            context.push('/hot/article', extra: {
              'id': id,
              'title': item.title,
              'summary': item.summary ?? '',
              'imageUrl': item.imageUrl ?? '',
              'heat': item.heat,
            });
          } catch (_) {}
        }
      },
    );
  }
}

// 吸附分类头的委托
class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double _min;
  final double _max;
  final Widget child;
  _CategoryHeaderDelegate({required double minExtent, required double maxExtent, required this.child})
      : _min = minExtent, _max = maxExtent;

  @override
  double get minExtent => _min;

  @override
  double get maxExtent => _max;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate._min != _min || oldDelegate._max != _max;
  }
}
