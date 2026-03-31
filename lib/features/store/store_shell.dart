import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'dart:ui' as ui;
import '../../core/theme/app_colors.dart';
import '../search/search_page.dart';
import 'product_detail_page.dart';

/// 商城整体壳：独立的底部导航与页面栈（购物/品牌/分类/购物车/我的）
/// 注意：不展示返回图标，但保留 iOS 的边缘手势返回（由路由栈提供）
class StoreShell extends StatefulWidget {
  const StoreShell({super.key});

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int _index = 0; // 0:购物 1:品牌 2:分类 3:购物车 4:我的

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _StoreHomePage(),
      const _PlaceholderPage(title: '品牌'),
      const _PlaceholderPage(title: '分类'),
      const _PlaceholderPage(title: '购物车'),
      const _PlaceholderPage(title: '我的'),
    ];

    return Scaffold(
      // 不使用 AppBar，避免状态栏区域被白色覆盖；顶部由自定义头部负责绘制
      extendBody: true, // 让内容延伸到底部，便于底栏磨砂看到背后内容
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _StoreBottomBar(index: _index, onTap: (i) => setState(() => _index = i)),
      backgroundColor: Colors.white,
    );
  }
}

class _StoreBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _StoreBottomBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavSpec('购物', Icons.shopping_bag_outlined, Icons.shopping_bag),
      _NavSpec('品牌', Icons.workspace_premium_outlined, Icons.workspace_premium),
      _NavSpec('分类', Icons.grid_view_outlined, Icons.grid_view_rounded),
      _NavSpec('购物车', Icons.shopping_cart_outlined, Icons.shopping_cart),
      _NavSpec('我的', Icons.person_outline, Icons.person),
    ];

    // 自适应底部安全区：不再使用 SafeArea 增加内边距，直接把安全区高度加到容器高度，
    // 让底栏背景完全贴住屏幕底部，避免出现“底部留空”的观感。
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const baseHeight = 64.0; // 底栏内容可见高度（适当加高）

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            border: const Border(top: BorderSide(color: Color(0x1A000000), width: 0.5)),
          ),
          // 高度 = 可见高度 + 底部安全区，确保背景铺满到底
          height: baseHeight + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset), // 图标文本避开手势区
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: _StoreNavItem(spec: items[i], active: i == index),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavSpec(this.label, this.icon, this.activeIcon);
}

class _StoreNavItem extends StatelessWidget {
  final _NavSpec spec;
  final bool active;
  const _StoreNavItem({required this.spec, required this.active});

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF9EC1); // 浅粉
    final grad = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [pink, Colors.white],
      stops: [0.7, 1.0],
    );
    final inactive = AppColors.textLight;
    final icon = active ? spec.activeIcon : spec.icon;

    Widget iconWidget = Icon(icon, size: 22, color: active ? Colors.white : inactive);
    if (active) {
      iconWidget = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect r) => grad.createShader(r),
        child: iconWidget,
      );
    }

    Widget label = Text(
      spec.label,
      style: TextStyle(fontSize: 11, color: active ? Colors.white : inactive, fontWeight: active ? FontWeight.w600 : FontWeight.normal),
    );
    if (active) {
      label = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect r) => grad.createShader(r),
        child: label,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(height: 4),
        label,
      ],
    );
  }
}

// 首页：自定义红色顶部 + 菜单 + 倒三角形活动位 + 搜索框 + 占位商品数据
class _StoreHomePage extends StatefulWidget {
  const _StoreHomePage();
  @override
  State<_StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<_StoreHomePage> {
  int _menuIndex = 1; // 0:特价 1:首页 2:秒送 3:外卖 4:新品
  // 吸附控制：测量快捷入口位置并决定是否显示叠加的文本菜单
  final GlobalKey _quickKey = GlobalKey();
  bool _showPinnedQuick = false;
  final List<_Product> _products = const [
    _Product(
      name: 'Apple iPhone 15 Pro Max 256G 钛金属机身 A17 Pro 芯片',
      imageUrl: 'https://picsum.photos/seed/iphone/400/300',
      store: 'Apple官方旗舰店',
      promo: '限时直降',
      coupon: '满3000减200',
      price: 9999,
      discountPrice: 8799,
      sales: 26891,
    ),
    _Product(
      name: '华为 MateBook 14 锐龙版 16G 512G 高色域轻薄本',
      imageUrl: 'https://picsum.photos/seed/laptop/400/300',
      store: '华为自营',
      promo: '热销爆款',
      coupon: '领券立减150',
      price: 5299,
      discountPrice: 4999,
      sales: 13811,
    ),
    _Product(
      name: 'iPad Air 5 10.9 寸学习平板 A14 芯片 支持二代笔',
      imageUrl: 'https://picsum.photos/seed/ipad/400/300',
      store: 'Apple授权专卖',
      promo: '学生专享',
      coupon: '满300减50',
      price: 4399,
      discountPrice: 4199,
      sales: 5219,
    ),
    _Product(
      name: '索尼 WH-1000XM5 头戴式主动降噪耳机 新款',
      imageUrl: 'https://picsum.photos/seed/headphones/400/300',
      store: '索尼官方旗舰店',
      promo: '官方立减',
      coupon: '下单返20元券',
      price: 2999,
      discountPrice: 2499,
      sales: 33211,
    ),
    _Product(
      name: '虚拟商品·视频会员年卡（全平台通用）',
      imageUrl: 'https://picsum.photos/seed/digital/400/300',
      store: '数字馆',
      promo: '数字专供',
      coupon: '买就送红包',
      price: 298,
      discountPrice: 258,
      sales: 98211,
    ),
    _Product(
      name: '小米 Pad 6 Pro 12+256 2.8K 144Hz 高刷',
      imageUrl: 'https://picsum.photos/seed/xiaomi/400/300',
      store: '小米自营旗舰店',
      promo: '店铺券',
      coupon: '满2000减200',
      price: 2699,
      discountPrice: 2499,
      sales: 2211,
    ),
    _Product(
      name: '联想拯救者 Y9000P 2024 i9 RTX4060 游戏本',
      imageUrl: 'https://picsum.photos/seed/thinkpad/400/300',
      store: '联想京东自营',
      promo: '晒单返E卡',
      coupon: '满6000减600',
      price: 8999,
      discountPrice: 8299,
      sales: 15199,
    ),
    _Product(
      name: 'AirPods Pro 2 蓝牙耳机 主动降噪 自适应通透',
      imageUrl: 'https://picsum.photos/seed/airpods/400/300',
      store: 'Apple官方旗舰店',
      promo: '好评返现',
      coupon: '下单领券50',
      price: 1999,
      discountPrice: 1699,
      sales: 89219,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 与顶部固定头一致的高度（用来定位叠加的吸附菜单）
    final statusH = MediaQuery.of(context).padding.top;
    const menuH = 44.0;
    const searchH = 40.0;
    const gap = 2.0;
    final headerH = statusH + menuH + gap + searchH;

    final scroll = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final ctx = _quickKey.currentContext;
        if (ctx != null && mounted) {
          final box = ctx.findRenderObject();
          if (box is RenderBox) {
            final pos = box.localToGlobal(Offset.zero);
            final bottom = pos.dy + box.size.height;
            final shouldShow = bottom <= headerH + 0.5; // 越过搜索框底部后吸附显示
            if (shouldShow != _showPinnedQuick) setState(() => _showPinnedQuick = shouldShow);
          }
        }
        return false;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 顶部头部（含状态栏+顶部菜单+右侧梯形+搜索框）固定
          SliverPersistentHeader(
            pinned: true,
            delegate: _FixedHeaderDelegate(
              height: headerH,
              builder: (context) => _StoreHeader(menuIndex: _menuIndex, onMenuChanged: (i) => setState(() => _menuIndex = i)),
            ),
          ),
          // 快捷入口：正常随内容滚动（用 key 测量位置）
          SliverToBoxAdapter(child: _QuickShortcuts(key: _quickKey)),
          // 旧的“占位式”吸附已关闭，改为叠加式吸附（不占用布局高度）
          // 流式商品卡片（两列）
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 12),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, c) {
                  const spacing = 3.0;
                  final colW = (c.maxWidth - spacing) / 2;
                  final left = <Widget>[];
                  final right = <Widget>[];
                  for (var i = 0; i < _products.length; i++) {
                    final w = SizedBox(width: colW, child: _ProductCardWidget(product: _products[i]));
                    if (i.isEven) {
                      left.add(w);
                      if (i < _products.length - 1) left.add(const SizedBox(height: spacing));
                    } else {
                      right.add(w);
                      if (i < _products.length - 1) right.add(const SizedBox(height: spacing));
                    }
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: colW,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
                      ),
                      const SizedBox(width: spacing),
                      SizedBox(
                        width: colW,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    // 叠加的吸附文本菜单：固定在搜索框下方，进入触发区时淡入
    return Stack(
      children: [
        scroll,
        Positioned(
          top: headerH, // 置于搜索框正下方
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showPinnedQuick,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              opacity: _showPinnedQuick ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _showPinnedQuick ? Offset.zero : const Offset(0, -0.12),
                child: const _PinnedQuickTextOverlay(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 商品卡片移除（按需后续再加入）

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title（开发中）', style: const TextStyle(color: AppColors.textSecondary)));
  }
}

// 顶部：红色菜单 + 右侧倒梯形活动位 + 搜索框（无扫码/拍照图标）
class _StoreHeader extends StatelessWidget {
  final int menuIndex;
  final ValueChanged<int> onMenuChanged;
  const _StoreHeader({required this.menuIndex, required this.onMenuChanged});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFA3A4A); // 视觉主红
    const redDeep = Color(0xFFEF3341);
    final statusH = MediaQuery.of(context).padding.top; // 覆盖状态栏
    const menuH = 44.0;
    const searchH = 40.0; // 高度+2
    const gap = 2.0; // 菜单下方2px
    const blendH = searchH; // 过渡高度

    final totalH = statusH + menuH + gap + blendH;

    return SizedBox(
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 顶部红背景（含状态栏）
          Container(
            height: statusH + menuH + gap,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [red, redDeep],
              ),
            ),
          ),

          // 顶部菜单（放在状态栏下方）
          Positioned(
            left: 12,
            right: 110, // 给右侧活动位留空间
            top: statusH + 8,
            height: menuH - 8,
            child: _TopMenu(index: menuIndex, onChanged: onMenuChanged),
          ),

          // 右侧倒梯形活动位：紧贴右侧并覆盖状态栏区域
          Positioned(
            right: 0,
            top: 0,
            child: _ActivityTrapezoid(height: statusH + menuH - 1, width: 110),
          ),

          // 红白过渡缓冲层
          Positioned(
            left: 0,
            right: 0,
            top: statusH + menuH + gap,
            height: blendH,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEF3341), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            top: statusH + menuH + gap,
            height: searchH,
            child: const _SearchBar(),
          ),

          // 两侧红色渐变衔接条
          Positioned(left: 0, top: statusH + menuH + gap, child: const _SideBlend(width: 12)),
          Positioned(right: 0, top: statusH + menuH + gap, child: const _SideBlend(width: 12, alignRight: true)),
        ],
      ),
    );
  }
}

class _TopMenu extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _TopMenu({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // 与截图一致："特价  首页  秒送 [外卖]  新品"，其中“外卖”为黄色角标，不是独立菜单项
    const items = ['特价', '首页', '秒送', '新品'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _TopMenuItem(text: items[i], active: index == i, showYellowTag: items[i] == '秒送', onTap: () => onChanged(i)),
            const SizedBox(width: 16),
          ]
        ],
      ),
    );
  }
}

class _TopMenuItem extends StatelessWidget {
  final String text;
  final bool active;
  final bool showYellowTag;
  final VoidCallback onTap;
  const _TopMenuItem({required this.text, required this.active, required this.onTap, this.showYellowTag = false});
  @override
  Widget build(BuildContext context) {
    Widget title = Text(
      text,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
    );
    if (showYellowTag) {
      title = Row(
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFFFEC6A), borderRadius: BorderRadius.circular(4)),
            child: const Text('外卖', style: TextStyle(color: Color(0xFF333333), fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 4),
          Opacity(
            opacity: active ? 1.0 : 0.0,
            child: Container(width: 28, height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          ),
        ],
      ),
    );
  }
}

class _ActivityTrapezoid extends StatelessWidget {
  final double width;
  final double height;
  const _ActivityTrapezoid({this.width = 96, this.height = 86});
  @override
  Widget build(BuildContext context) {
    // 倾斜梯形：顶部略短、底部略长，左斜切，四角小圆角；尺寸可根据状态栏动态伸展
    return ClipPath(
      clipper: _RightTrapezoidClipper(radius: 8),
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF7B8A), Color(0xFFFF5E6F)],
          ),
        ),
        child: const Center(child: Icon(Icons.local_offer, color: Colors.white)),
      ),
    );
  }
}

class _RightTrapezoidClipper extends CustomClipper<Path> {
  final double radius; // 小圆角
  const _RightTrapezoidClipper({this.radius = 6});
  @override
  Path getClip(Size size) {
    final r = radius;
    // 倒置梯形：左侧斜边（左上→右下），右侧为直角边并贴屏幕右侧
    // 通过 topInset(上边距) 和 bottomInset(下边距) 控制斜率：bottomInset > topInset
    final topInset = size.width * 0.16;
    final bottomInset = size.width * 0.34;

    final path = Path();
    // 从左上斜边起点开始，顺时针
    path.moveTo(topInset, 0);
    // 顶边到右上角（带圆角）
    path.lineTo(size.width - r, 0);
    path.quadraticBezierTo(size.width, 0, size.width, r);
    // 右侧直边
    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(size.width, size.height, size.width - r, size.height);
    // 底边到左下斜边起点
    path.lineTo(bottomInset, size.height);
    // 左侧斜边回到顶部
    path.lineTo(topInset, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();
  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFA3A4A);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6), // 圆角增加3px -> 6px
          border: Border.all(color: red, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x26FA3A4A), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.search, color: Color(0xFFBBBBBB), size: 18),
            const SizedBox(width: 6),
            // 竖杠在“搜索文本”左侧，不替代搜索图标
            Container(width: 1, height: 14, color: const Color(0xFFDDDDDD)),
            const SizedBox(width: 6),
            const Text('iphone', style: TextStyle(color: Color(0xFF555555), fontSize: 14)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(4)),
              child: const Text('国家补贴', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            const Text('搜索', style: TextStyle(color: red, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _SideBlend extends StatelessWidget {
  final double width;
  final bool alignRight;
  const _SideBlend({required this.width, this.alignRight = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignRight ? Alignment.centerRight : Alignment.centerLeft,
            end: alignRight ? Alignment.centerLeft : Alignment.centerRight,
            colors: const [Color(0x00FA3A4A), Color(0x33FA3A4A)],
          ),
        ),
      ),
    );
  }
}

// 顶部固定头部委托（不随内容滚动）
class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final WidgetBuilder builder;
  final double height;
  const _FixedHeaderDelegate({required this.builder, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return builder(context);
  }

  @override
  bool shouldRebuild(covariant _FixedHeaderDelegate oldDelegate) => oldDelegate.height != height;
}

// 文本菜单吸附头：仅显示文本菜单，作为 pinned header。
// 使用 shrinkOffset 控制“可见度”，当该头部刚进入（shrinkOffset==0）且前一个快捷入口仍可见时，透明；
// 当快捷入口离开（内容覆盖）后，显示文本。
class _QuickTextPinnedDelegate extends SliverPersistentHeaderDelegate {
  static const double _height = 30;
  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final visible = overlapsContent; // 当被后续内容覆盖时认为应显示
    return IgnorePointer(
      ignoring: !visible,
      child: Container(
        color: Colors.white.withOpacity(visible ? 1.0 : 0.0),
        child: visible ? const _QuickTextMenu() : const SizedBox.shrink(),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _QuickTextPinnedDelegate oldDelegate) => false;
}

class _QuickTextMenu extends StatelessWidget {
  const _QuickTextMenu();
  @override
  Widget build(BuildContext context) {
    const items = ['快捷入口', '手机', '笔记本', '平板', '耳机', '虚拟商品'];
    return SizedBox(
      height: 30,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => Center(child: Text(items[i], style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemCount: items.length,
      ),
    );
  }
}

// 叠加式的吸附文本菜单容器（带背景）
class _PinnedQuickTextOverlay extends StatelessWidget {
  const _PinnedQuickTextOverlay();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      color: Colors.white,
      child: const _QuickTextMenu(),
    );
  }
}

// 固定高度的 SliverPersistentHeader 委托
class _PinnedMenuDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(BuildContext) builder;
  final double height;
  const _PinnedMenuDelegate({required this.builder, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return builder(context);
  }

  @override
  bool shouldRebuild(covariant _PinnedMenuDelegate oldDelegate) => false;
}

class _PinnedMenu extends StatelessWidget {
  final int index; final ValueChanged<int> onChanged;
  const _PinnedMenu({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 2), // 吸附到搜索框下方 2px
      child: SizedBox(height: 44, child: _TopMenuCondensed(index: index, onChanged: onChanged)),
    );
  }
}

class _TopMenuCondensed extends StatelessWidget {
  final int index; final ValueChanged<int> onChanged;
  const _TopMenuCondensed({required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const items = ['特价', '首页', '秒送', '新品'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        for (int i = 0; i < items.length; i++) ...[
          _TopMenuConItem(text: items[i], active: index == i, tag: items[i] == '秒送' ? '外卖' : null, onTap: () => onChanged(i)),
          const SizedBox(width: 16),
        ]
      ]),
    );
  }
}

class _TopMenuConItem extends StatelessWidget {
  final String text; final bool active; final String? tag; final VoidCallback onTap;
  const _TopMenuConItem({required this.text, required this.active, this.tag, required this.onTap});
  @override
  Widget build(BuildContext context) {
    Widget title = Text(text, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16));
    if (tag != null) {
      title = Row(children: [
        Text(text, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFFEC6A), borderRadius: BorderRadius.circular(4)), child: Text(tag!, style: const TextStyle(color: Color(0xFF333333), fontSize: 11, fontWeight: FontWeight.w700))),
      ]);
    }
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 2),
          Opacity(
            opacity: active ? 1.0 : 0.0,
            child: Container(width: 28, height: 2, decoration: BoxDecoration(color: const Color(0xFFFF3D6E), borderRadius: BorderRadius.circular(2))),
          )
        ],
      ),
    );
  }
}

class _Product {
  final String name;
  final String imageUrl;
  final String store;
  final String promo;
  final String coupon;
  final double price;
  final double? discountPrice;
  final int sales;
  const _Product({
    required this.name,
    required this.imageUrl,
    required this.store,
    required this.promo,
    required this.coupon,
    required this.price,
    required this.discountPrice,
    required this.sales,
  });
}

class _ProductCardWidget extends StatelessWidget {
  final _Product product;
  const _ProductCardWidget({required this.product});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = (product.discountPrice ?? product.price) < product.price;
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F1F1)),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 主图：固定纵横比，加载中保持轮廓不压缩
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              child: AspectRatio(
                aspectRatio: 1.0, // 统一主图比例（方形），避免加载时高度塌陷
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(color: const Color(0xFFF5F5F5));
                  },
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF5F5F5), child: const Icon(Icons.image_not_supported, color: Color(0xFFCCCCCC))),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _chip(text: product.promo, color: const Color(0xFFFFEEF0), textColor: const Color(0xFFFF3D6E)),
                _chip(text: product.coupon, color: const Color(0xFFE9FAF0), textColor: const Color(0xFF1FAA65)),
              ]),
            ),
            const SizedBox(height: 6),
            // 店铺名 + 月销（移动到优惠信息下方）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(child: Text(product.store, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                  Text('月销 ${product.sales}', style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                if (hasDiscount) ...[
                  Text('¥${product.discountPrice!.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFF3D6E), fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Text('¥${product.price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12, decoration: TextDecoration.lineThrough)),
                ] else ...[
                  Text('¥${product.price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF333333), fontSize: 16, fontWeight: FontWeight.w700)),
                ],
                const Spacer(),
                Container(
                  width: 24, // 加号图标放大一倍
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF9EC1),
                  ),
                  child: const Center(child: Icon(Icons.add, size: 16, color: Colors.white)),
                ),
              ]),
            ),
          ]),
        ),
        // 右下角浮动加号已改为价格行内右侧展示
      ]),
    );

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            title: product.name,
            price: (product.discountPrice ?? product.price).toDouble(),
            images: [
              product.imageUrl,
              // 简单复用不同尺寸的图，真实项目可替换为商品图集
              product.imageUrl.replaceAll('/seed/', '/seed2/'),
              product.imageUrl.replaceAll('/seed/', '/seed3/'),
            ],
            activity: '双11 优惠进行中',
          ),
        ));
      },
      child: card,
    );
  }

  Widget _chip({required String text, required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
// --- Quick Shortcuts ---
class _QuickShortcuts extends StatefulWidget {
  const _QuickShortcuts({super.key});
  @override
  State<_QuickShortcuts> createState() => _QuickShortcutsState();
}

class _QuickShortcutsState extends State<_QuickShortcuts> with SingleTickerProviderStateMixin {
  final ScrollController _sc = ScrollController();
  double _offset = 0.0;
  late final AnimationController _loader;

  final List<Map<String, String>> _items = const [
    {'name': '快捷入口', 'url': 'https://example.com'},
    {'name': '手机', 'url': 'https://example.com/category/phones'},
    {'name': '笔记本', 'url': 'https://example.com/category/laptops'},
    {'name': '平板', 'url': 'https://example.com/category/tablets'},
    {'name': '耳机', 'url': 'https://example.com/category/headphones'},
    {'name': '虚拟商品', 'url': 'https://example.com/category/digital'},
  ];

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _sc.addListener(() {
      if (!mounted) return;
      setState(() => _offset = _sc.offset);
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double iconSize = 44;
    const double spacing = 16;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            controller: _sc,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final it in _items) ...[
                    _ShortcutItem(name: it['name']!, url: it['url']!, iconSize: iconSize),
                    const SizedBox(width: spacing),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 进度显示：由“滑块”改为“颜色填充”样式。
          // 样式：超细轨道 + 3px 高的填充色，随滚动进度或循环动画从左到右填充。
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 0),
            child: LayoutBuilder(
              builder: (context, c) {
                final fullW = c.maxWidth;
                const double trackW = 44; // 固定长度，避免过长
                final centerLeft = (fullW - trackW) / 2;

                // 进度：滚动时根据 offset -> [0,1]；未滚动时使用循环动画
                double progress = _loader.value;
                if (_sc.hasClients && _sc.position.activity != null && _sc.position.activity!.isScrolling) {
                  final max = _sc.position.maxScrollExtent;
                  progress = max <= 0 ? 0.0 : (_offset / max).clamp(0.0, 1.0);
                }

                final fillW = trackW * progress;

                return SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      // 轨道：超细，水平居中
                      Positioned(
                        left: centerLeft,
                        right: centerLeft,
                        top: 3, // 垂直居中偏移
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDEDED),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // 填充色：从左到右按进度填充
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: centerLeft,
                        top: 2,
                        height: 3,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: fillW,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3D6E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String name; final String url; final double iconSize;
  const _ShortcutItem({required this.name, required this.url, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F0F0)),
            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Color(0xFFCCCCCC))),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: iconSize + 8,
          child: Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        )
      ],
    );
  }
}
