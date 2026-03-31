import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';

// 商品详情页（简版交互实现，贴合需求描述）
class ProductDetailPage extends StatefulWidget {
  final String title;
  final double price;
  final String? activity; // 右侧活动信息（可空）
  final List<String> images;

  const ProductDetailPage({
    super.key,
    required this.title,
    required this.price,
    required this.images,
    this.activity,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final PageController _pc;
  int _page = 0;
  int _buyMode = 0; // 0: 单品购买 1: 采购
  int _specIndex = 0;
  final ScrollController _detailSc = ScrollController();
  bool _showBackToTop = false; // 回到顶部按钮
  bool _showTopBar = false; // 顶部栏显隐
  int _topBarTab = 0; // 0:商品 1:评价 2:详情
  final _titleKey = GlobalKey();
  final _reviewsKey = GlobalKey();
  final _detailsKey = GlobalKey();

  // 示例数据：优惠券与规格
  final List<String> _coupons = const [
    '满3000减400', '21%换机补贴', '下单返9折券', '换购立减100', '整点秒杀券',
  ];
  final List<_Spec> _specs = const [
    _Spec('云白色', '#FFFFFF'),
    _Spec('天蓝色', '#87CEEB'),
    _Spec('浅金色', '#FFD700'),
    _Spec('曜石黑', '#000000'),
  ];

  @override
  void initState() {
    super.initState();
    _pc = PageController();
    _detailSc.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pc.dispose();
    _detailSc.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!_detailSc.hasClients) return;
    final offset = _detailSc.offset;
    final max = _detailSc.position.hasPixels && _detailSc.position.hasContentDimensions ? _detailSc.position.maxScrollExtent : 1.0;
    final ratio = (offset / (max == 0 ? 1 : max)).clamp(0.0, 1.0);
    final showTopBar = ratio > 0.10; // 滑动 10% 显示
    final showTop = offset > 600; // 下滑一段距离才显示回顶按钮
    // 计算顶部栏当前 tab
    int tab = _topBarTab;
    double tOff = _offsetForKey(_titleKey);
    double rOff = _offsetForKey(_reviewsKey);
    double dOff = _offsetForKey(_detailsKey);
    const margin = 80.0;
    if (offset < rOff - margin) {
      tab = 0;
    } else if (offset < dOff - margin) {
      tab = 1;
    } else {
      tab = 2;
    }
    if (showTopBar != _showTopBar || showTop != _showBackToTop || tab != _topBarTab) {
      setState(() {
        _showTopBar = showTopBar;
        _showBackToTop = showTop;
        _topBarTab = tab;
      });
    }
  }

  double _offsetForKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return double.infinity;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return double.infinity;
    final pos = box.localToGlobal(Offset.zero, ancestor: null);
    return pos.dy + _detailSc.offset; // 转为滚动偏移
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final statusH = media.padding.top; // 主图区包含状态栏

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _detailSc,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHero(statusH),
              ),
              SliverToBoxAdapter(child: _buildPriceWithMode()),
              SliverToBoxAdapter(child: _buildCoupons(context)),
              SliverToBoxAdapter(child: _buildSpecs()),
              SliverToBoxAdapter(child: Container(key: _titleKey, child: _buildTitle())),
              SliverToBoxAdapter(child: _buildActivityTags()),
              SliverToBoxAdapter(child: _buildParams(context)),
              SliverToBoxAdapter(child: _buildLogistics(context)),
              SliverToBoxAdapter(child: _buildGuarantee(context)),
              SliverToBoxAdapter(child: Container(key: _reviewsKey, child: _buildReviews(context))),
              SliverToBoxAdapter(child: _buildShopStrip(context)),
              SliverToBoxAdapter(child: Container(key: _detailsKey, child: _buildProductDetails(context))),
              const SliverToBoxAdapter(child: SizedBox(height: 120)), // 预留滚动空间，避免被底部栏遮挡
            ],
          ),

          // 顶部返回/操作按钮
          Positioned(
            top: statusH + 8,
            left: 12,
            child: _circleBtn(icon: Icons.arrow_back_ios_new, onTap: () => Navigator.of(context).maybePop()),
          ),
          Positioned(
            top: statusH + 8,
            right: 12,
            child: Row(children: [
              _circleBtn(icon: Icons.star_border, onTap: () {}),
              const SizedBox(width: 10),
              _circleBtn(icon: Icons.ios_share, onTap: () {}),
              const SizedBox(width: 10),
              _circleBtn(icon: Icons.more_horiz, onTap: () {}),
            ]),
          ),
          // 右侧 30% 高度位置的“回到顶部”悬浮按钮（默认隐藏，回顶后也隐藏）
          if (_showBackToTop) Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.7,
            child: GestureDetector(
              onTap: () async {
                await _detailSc.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
                if (mounted) setState(() => _showBackToTop = false);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), shape: BoxShape.circle),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward, size: 14, color: Colors.white),
                      SizedBox(height: 2),
                      Text('top', style: TextStyle(fontSize: 10, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 顶部栏：滑动 10% 后出现（平缓动画）
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            top: 0,
            left: 0,
            right: 0,
            height: _showTopBar ? (MediaQuery.of(context).padding.top + 44) : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showTopBar ? 1 : 0,
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0x1A000000)))),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  // 左侧：商品 / 评价 / 详情（居左排布）
                  _TopTab('商品', 0),
                  const SizedBox(width: 18),
                  _TopTab('评价', 1),
                  const SizedBox(width: 18),
                  _TopTab('详情', 2),
                  const Spacer(),
                  // 右侧：线性五角星收藏 + 分享 + 更多（黑色）
                  Row(children: const [
                    Icon(Icons.star_border, color: Colors.black, size: 20),
                    SizedBox(width: 12),
                    Icon(Icons.ios_share, color: Colors.black, size: 20),
                    SizedBox(width: 12),
                    Icon(Icons.more_horiz, color: Colors.black, size: 22),
                    SizedBox(width: 8),
                  ])
                ]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(),
    );
  }

  // 主图区（包含状态栏），支持点击放大查看
  Widget _buildHero(double statusH) {
    final h = statusH + 360.0; // 总高度（含状态栏）
    final imgs = widget.images.isEmpty ? ['https://picsum.photos/800/600'] : widget.images;
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片轮播
          PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: imgs.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _openViewer(imgs[i]),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 1,
                // 使用 AspectRatio 保持轮廓稳定
                child: Image.network(
                  imgs[i],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 底部页码指示：当前为橙色 3px 圆角横条，其他为半透明黑圆点
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < imgs.length; i++) ...[
                    if (i == _page)
                      Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(color: const Color(0xFFFF9800), borderRadius: BorderRadius.circular(2)),
                      )
                    else
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), shape: BoxShape.circle),
                      ),
                    if (i == _page && i != imgs.length - 1) const SizedBox(width: 6),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 价格 + 购买方式（选中为白底，上方价格条不被整体压住；仅选中项上抬 2px 与价格条轻微叠加）
  Widget _buildPriceWithMode() {
    final hasActivity = (widget.activity != null && widget.activity!.trim().isNotEmpty);
    const double headerH = 68; // 价格条高度
    const double tabsH = 44;   // 购买方式行高度

    final priceStrip = Container(
      height: headerH,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFEEF3), Color(0xFFF2ECFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(top: BorderSide(color: Color(0xFFEFEFEF))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // 价格
        Expanded(
          flex: 2,
          child: Row(children: [
            const Text('¥', style: TextStyle(color: Color(0xFFFF3D6E), fontSize: 16, fontWeight: FontWeight.w800)),
            Text(widget.price.toStringAsFixed(0), style: const TextStyle(color: Color(0xFFFF3D6E), fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
        ),
        // 活动
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: hasActivity
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x33FF6B9D), borderRadius: BorderRadius.circular(8)),
                    child: Text(widget.activity!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ]),
    );

    // 购买方式 tabs：选中背景=页面白色；未选中=浅灰；不画边框；整体不侵入价格区，只有选中项上抬 2px
    final modesTexts = ['单品购买', '采购'];
    final tabs = SizedBox(
      height: tabsH,
      child: _BuyModeBar(
        selected: _buyMode,
        onChanged: (i) => setState(() => _buyMode = i),
        overlap: 5,
        labels: const ['单品购买', '采购'],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        priceStrip,
        // tabs 在下方；选中项在其内部上抬 2px 叠在价格条底缘
        tabs,
      ],
    );
  }

  // 单个购买方式项（旧）保留不再使用

  // 顶部小“凸起”定义移动到文件末尾的顶级类


  // 优惠券：横向滑动 chips + 右箭头打开底部弹窗（占位）
  Widget _buildCoupons(BuildContext context) {
    const double chipHeight = 28; // 与右侧箭头保持一致的高度
    const double chipRadius = 10; // 较之前减小 3-5px（原 14）
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in _coupons) ...[
                Container(
                  height: chipHeight,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFFF8EA5), borderRadius: BorderRadius.circular(chipRadius)),
                  child: Text(c, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]
            ]),
          ),
        ),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              builder: (_) => SizedBox(
                height: 300,
                child: Center(
                  child: Text('优惠券弹窗（占位）', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            );
          },
          child: Container(
            height: chipHeight,
            width: 26,
            alignment: Alignment.center,
            child: const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
          ),
        )
      ]),
    );
  }

  // 规格卡片：横向滑动，选中粉色细边
  Widget _buildSpecs() {
    const double itemH = 60; // 降低高度
    const double imgSize = 34; // 主图缩小，并与文本水平排列
    return Container(
      color: Colors.white, // 区域背景改为白色
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择规格', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: itemH,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _specs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final s = _specs[i];
                      final sel = _specIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _specIndex = i),
                        child: Container(
                          width: 128,
                          height: itemH,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: sel ? Border.all(color: const Color(0xFFFFB3D1), width: 1) : null,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(s.thumb, width: imgSize, height: imgSize, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 右侧“全部”竖排 + 下箭头（与卡片区域垂直居中）
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (_) => SizedBox(
                      height: 360,
                      child: Center(child: Text('规格弹窗（占位）', style: TextStyle(color: AppColors.textSecondary))),
                    ),
                  );
                },
                child: Container(
                  height: itemH,
                  width: 32,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('全', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.0)),
                      Text('部', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.0)),
                      SizedBox(height: 2),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textLight),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 商品名称：最多 2 行
  Widget _buildTitle() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Text(
        widget.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.3, decoration: TextDecoration.none),
      ),
    );
  }

  // 活动标签：国家补贴（绿）、自营（浅粉）、最近购买（浅灰）
  Widget _buildActivityTags() {
    const double h = 24;
    const radius = 6.0; // 小圆角
    const greenBg = Color(0xFFE9FAF0);
    const greenText = Color(0xFF1FAA65);
    const pinkBg = Color(0xFFFFEEF3);
    const pinkText = Color(0xFFFF3D6E);
    const grayBg = Color(0xFFF3F4F6);
    const blueBlack = Color(0xFF1F2937);

    final recent = '近期 12,034 人购买';

    Widget chip(String text, {required Color bg, required Color fg}) {
      return Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SizedBox(
        height: h,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('国家补贴', bg: greenBg, fg: greenText),
              const SizedBox(width: 8),
              chip('自营商品', bg: pinkBg, fg: pinkText),
              const SizedBox(width: 8),
              chip(recent, bg: grayBg, fg: blueBlack),
            ],
          ),
        ),
      ),
    );
  }

  // 商品参数：左侧固定标题 + 横向参数（用'|'分割）；右侧箭头弹窗
  Widget _buildParams(BuildContext context) {
    const double rowH = 28;
    const params = [
      '品牌 Apple', '型号 iPhone Air', '存储 256GB', '重量 172g', '屏幕 6.1"', '电池 4300mAh',
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          // 固定标题，不随滚动
          Container(
            height: rowH,
            alignment: Alignment.centerLeft,
            child: const Text('商品参数', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 10),
          // 仅参数部分横向滚动，使用 ' | ' 分隔
          Expanded(
            child: SizedBox(
              height: rowH,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    for (int i = 0; i < params.length; i++) ...[
                      if (i > 0)
                        const Text(' | ', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                      Text(params[i], style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => _ParamsSheet(),
              );
            },
            child: Container(
              height: rowH,
              width: 26,
              alignment: Alignment.center,
              child: const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

  // 物流配送信息
  Widget _buildLogistics(BuildContext context) {
    const dot = ' · ';
    const lineH = 24.0;
    const tagBg = Color(0xFFFFF4E5); // 浅橙黄
    const tagFg = Color(0xFF8B5E3C); // 棕色文本

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：货车图标 + 文本(·分割) + 右箭头
          SizedBox(
            height: lineH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '预计送达 明日 18:00$dot 可预约',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // 第二行：配送地址 + 是否包邮（·分割）
          SizedBox(
            height: lineH,
            child: Row(
              children: [
                const SizedBox(width: 16 + 6), // 与首行图标对齐缩进
                Expanded(
                  child: Text(
                    '配送至 北京 朝阳 三环内$dot 满99包邮',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 第三行：快递公司 + 运费险（浅橙黄背景+棕色文本）
          SizedBox(
            height: lineH,
            child: Row(
              children: [
                const SizedBox(width: 16 + 6),
                const Text('快递 顺丰速运', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(6)),
                  child: const Text('运费险', style: TextStyle(fontSize: 11, color: tagFg, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 商品保障信息（可横向滑动；右侧箭头进入详情）
  Widget _buildGuarantee(BuildContext context) {
    const items = ['7天无理由退货', '官方质保', '闪电退款', '7天价保', '破损包退换'];
    const rowH = 28.0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          // 横向滑动，内容用 · 分割
          Expanded(
            child: SizedBox(
              height: rowH,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0) const Text(' · ', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                      Text(items[i], style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    ]
                  ]),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => const _GuaranteeSheet(),
              );
            },
            child: const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // 评价区：概要 + 部分评价 + 查看全部
  Widget _buildReviews(BuildContext context) {
    final chips = const ['穿起来超舒适 12', '裤型超好看 2', '显腿长 1'];
    final reviews = [
      _Review(
        user: '心***6',
        content: '很显腿长的黑色裤子，面料也很厚实不错，秋冬穿正好。',
        tag: '本店购买≥2次',
        images: const ['https://picsum.photos/200/200', 'https://picsum.photos/200/200?2'],
        rating: 5,
        ratingLabel: '超赞',
        purchaseTime: '2024-09-30',
        productName: widget.title,
        productSpec: '黑色长款 XL',
        productPrice: widget.price,
        productImage: widget.images.isNotEmpty ? widget.images.first : '#',
      ),
      _Review(
        user: '韩***静',
        content: '这个裤子真的超棒，面料很软和，穿上超舒服。',
        tag: '会员',
        images: const ['https://picsum.photos/200/200'],
        rating: 4,
        ratingLabel: '还不错',
        purchaseTime: '2024-09-18',
        productName: widget.title,
        productSpec: '黑色 XL',
        productPrice: widget.price,
        productImage: widget.images.isNotEmpty ? widget.images.first : 'https://picsum.photos/400/400',
      ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 标题行
        Row(children: [
          const Expanded(child: Text('买家评价 2000+', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewsPage())),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Text('近14天好评率 99%', style: TextStyle(fontSize: 12, color: Color(0xFFFF9800), fontWeight: FontWeight.w700)),
              SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: Color(0xFFFF9800)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        // 标签行（横向）
        SizedBox(
          height: 26,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in chips) ...[
                Container(
                  height: 26,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(13)),
                  child: Text(c, style: const TextStyle(color: Color(0xFF8B5E3C), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]
            ]),
          ),
        ),
        const SizedBox(height: 8),
        for (final r in reviews)
          _ReviewCard(
            r,
            onTapImage: (i) => _openReviewImages(r, i),
          ),
      ]),
    );
  }

  // 店铺横条
  Widget _buildShopStrip(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: NetworkImage('https://picsum.photos/1200/400'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // 店铺图标
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          padding: const EdgeInsets.all(2),
          child: ClipOval(child: Image.network('https://picsum.photos/80', fit: BoxFit.cover)),
        ),
        const SizedBox(width: 10),
        // 名称 + 自营
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Text('苹果官方旗舰店', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black, decoration: TextDecoration.none)),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: Colors.black),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Color(0xFFFF6B9D), borderRadius: BorderRadius.circular(6)),
              child: const Text('自营', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        // 进店按钮
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(16)),
          child: const Text('进店', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  // 商品详情（图片 + 介绍 + 细节图 + 服务）
  Widget _buildProductDetails(BuildContext context) {
    final pics = [
      'https://picsum.photos/800/400',
      'https://picsum.photos/800/400?2',
      'https://picsum.photos/800/400?3',
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('商品详情', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('介绍：这是一段示例商品介绍文案，用于展示商品卖点、材质、使用场景等信息。', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        for (final p in pics) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(p, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        const Text('服务', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: const [
          Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
          SizedBox(width: 6),
          Expanded(child: Text('累计收货 120 万件', style: TextStyle(fontSize: 12, color: AppColors.textPrimary))),
        ]),
        const SizedBox(height: 4),
        Row(children: const [
          Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
          SizedBox(width: 6),
          Expanded(child: Text('平台价格说明：价格可能因活动波动，以下单时为准', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ]),
      ]),
    );
  }

  // 全屏查看图片：点击空白区域关闭
  void _openViewer(String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'viewer',
      barrierColor: Colors.black.withOpacity(0.9),
      pageBuilder: (_, __, ___) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  // 评价图片查看：带顶/底部信息与底部商品卡片
  void _openReviewImages(_Review r, int initialIndex) {
    _ReviewImageOverlay.open(context, r, initialIndex,
        fallbackName: widget.title,
        fallbackSpec: '默认规格',
        fallbackPrice: widget.price,
        fallbackImage: widget.images.isNotEmpty ? widget.images.first : null);
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

}

class _Spec {
  final String name;
  final String thumb;
  const _Spec(this.name, this.thumb);
}

// 底部固定操作栏：店铺/客服 + 加入购物车/立即购买
class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x1A000000), width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      height: bottomInset + 60,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _miniIcon(Icons.storefront_outlined, '店铺', onTap: () {}),
          const SizedBox(width: 12),
          _miniIcon(Icons.headset_mic_outlined, '客服', onTap: () {}),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              Expanded(
                child: _filledBtn(
                  text: '加入购物车',
                  bg: const Color(0xFFEDEDED),
                  fg: const Color(0xFF333333),
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filledBtn(
                  text: '立即购买',
                  bg: AppColors.primary,
                  fg: Colors.white,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
            ]),
          ),
        ],
      ),
    );
  }
}

// 购买方式整条背景（两段式）：选中为白色直角梯形，未选中为浅灰，顶部选中段上叠 overlap
class _BuyModeBar extends StatefulWidget {
  final int selected; // 0:左 1:右
  final ValueChanged<int> onChanged;
  final double height; // 不含 overlap 的可见高度
  final double overlap; // 顶部向上叠进价格条
  final double slant; // 中间斜缝的水平偏移
  final double radius; // 外侧圆角（屏幕边缘将按需置 0）
  final List<String> labels;

  const _BuyModeBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.height = 44,
    this.overlap = 5,
    this.slant = 16,
    this.radius = 0, // 屏幕边缘贴合，不要圆角
    this.labels = const ['单品购买', '采购'],
  });

  @override
  State<_BuyModeBar> createState() => _BuyModeBarState();
}

class _BuyModeBarState extends State<_BuyModeBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double get _target => widget.selected == 0 ? 0.0 : 1.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: _target);
  }

  @override
  void didUpdateWidget(covariant _BuyModeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _ctrl.animateTo(_target, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styleSel = const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700);
    final styleN = const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value; // 0→左选中，1→右选中
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 背景绘制：包含 overlap 的高度，顶部上叠
            Positioned(
              top: -widget.overlap,
              left: 0,
              right: 0,
              height: widget.height + widget.overlap,
              child: CustomPaint(
                painter: _ModeBarPainter(
                  t: t,
                  slant: widget.slant,
                  radiusEdge: widget.radius, // 边缘圆角为 0 以贴边
                  overlap: widget.overlap,
                  gray: const Color(0xFFF0F0F0),
                ),
              ),
            ),

            // 文本与点击区域（不含 overlap）
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onChanged(0),
                    child: Center(child: Text(widget.labels[0], style: widget.selected == 0 ? styleSel : styleN)),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onChanged(1),
                    child: Center(child: Text(widget.labels[1], style: widget.selected == 1 ? styleSel : styleN)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ModeBarPainter extends CustomPainter {
  final double t; // 0:左选中 → 1:右选中
  final double slant; // 中缝斜偏移
  final double radiusEdge; // 边缘圆角（屏边贴合=0）
  final double overlap; // 顶部上叠
  final Color gray;
  const _ModeBarPainter({
    required this.t,
    required this.slant,
    required this.radiusEdge,
    required this.overlap,
    required this.gray,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height; // 已包含 overlap
    final baseTop = overlap; // tabs 可见区域的顶部 y
    final bottom = h;        // 底部 y

    // 斜缝位置：t 在 [0,1] 之间线性变换
    final mid = w / 2;
    final k = (1 - 2 * t); // 左选中:1 → 右选中:-1
    final seamTop = mid + slant * k;
    final seamBottom = mid - slant * k;
    const seamRound = 4.0;

    // 先画未选中段（灰色）
    final pGray = Path();
    if (t < 0.5) {
      // 右灰
      pGray.moveTo(seamTop, baseTop);
      pGray.lineTo(w - radiusEdge, baseTop);
      // 右上角（屏边贴合，radiusEdge 可能为 0）
      if (radiusEdge > 0) {
        pGray.quadraticBezierTo(w, baseTop, w, baseTop + radiusEdge);
      }
      pGray.lineTo(w, bottom);
      pGray.lineTo(seamBottom + seamRound, bottom);
      pGray.quadraticBezierTo(seamBottom, bottom, seamBottom, bottom - seamRound);
      pGray.lineTo(seamTop, baseTop + seamRound);
      pGray.quadraticBezierTo(seamTop, baseTop, seamTop + seamRound, baseTop);
    } else {
      // 左灰
      pGray.moveTo(radiusEdge, baseTop);
      pGray.lineTo(seamTop - seamRound, baseTop);
      pGray.quadraticBezierTo(seamTop, baseTop, seamTop, baseTop + seamRound);
      pGray.lineTo(seamBottom, bottom - seamRound);
      pGray.quadraticBezierTo(seamBottom, bottom, seamBottom + seamRound, bottom);
      pGray.lineTo(radiusEdge, bottom);
      // 左边贴屏（无圆角）
      pGray.lineTo(0, bottom);
      pGray.lineTo(0, baseTop);
      pGray.lineTo(radiusEdge, baseTop);
    }

    final paintGray = Paint()..color = gray;
    canvas.drawPath(pGray, paintGray);

    // 再画选中段白色（仅需上叠部分与外侧圆角，可省略底色，因为容器本身是白色）
    final pWhite = Path();
    if (t < 0.5) {
      // 左白（顶部上叠、外侧圆角）
      pWhite.moveTo(0, baseTop - overlap);
      pWhite.lineTo(seamTop - seamRound, baseTop - overlap);
      pWhite.quadraticBezierTo(seamTop, baseTop - overlap, seamTop, baseTop - overlap + seamRound);
      pWhite.lineTo(seamBottom, bottom - seamRound);
      pWhite.quadraticBezierTo(seamBottom, bottom, seamBottom - seamRound, bottom);
      pWhite.lineTo(0, bottom);
      pWhite.lineTo(0, baseTop - overlap);
      pWhite.lineTo(seamTop - seamRound, baseTop - overlap);
    } else {
      // 右白
      pWhite.moveTo(seamTop + seamRound, baseTop - overlap);
      pWhite.quadraticBezierTo(seamTop, baseTop - overlap, seamTop, baseTop - overlap + seamRound);
      pWhite.lineTo(seamBottom, bottom - seamRound);
      pWhite.quadraticBezierTo(seamBottom, bottom, seamBottom + seamRound, bottom);
      pWhite.lineTo(w, bottom);
      pWhite.lineTo(w, baseTop - overlap);
      pWhite.lineTo(seamTop + seamRound, baseTop - overlap);
      pWhite.lineTo(seamTop + seamRound, baseTop - overlap);
    }

    // 不要阴影，直接填充白色以与下方优惠券白底融合
    final paintWhite = Paint()..color = Colors.white;
    canvas.drawPath(pWhite, paintWhite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Widget _miniIcon(IconData icon, String text, {VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: AppColors.textSecondary),
        const SizedBox(height: 2),
        Text(text, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    ),
  );
}

Widget _filledBtn({required String text, required Color bg, required Color fg, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
    ),
  );
}

class _TopTab extends StatelessWidget {
  final String text; final int index;
  const _TopTab(this.text, this.index);
  @override
  Widget build(BuildContext context) {
    // 访问父 State 获取当前选中
    final state = context.findAncestorStateOfType<_ProductDetailPageState>();
    final active = state?._topBarTab == index;
    return GestureDetector(
      onTap: () {
        final s = state;
        if (s == null) return;
        GlobalKey key;
        if (index == 0) key = s._titleKey; else if (index == 1) key = s._reviewsKey; else key = s._detailsKey;
        final y = s._offsetForKey(key) - (MediaQuery.of(context).padding.top + 44);
        s._detailSc.animateTo(y.clamp(0, s._detailSc.position.maxScrollExtent), duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      },
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// 全屏图片查看（评价）：分页 + 顶部用户/时间 + 底部名称/规格 + 中间底部商品卡片
class _ReviewImageOverlay extends StatefulWidget {
  final _Review r; final int initialIndex;
  final String? fallbackName; final String? fallbackSpec; final double? fallbackPrice; final String? fallbackImage;
  const _ReviewImageOverlay({required this.r, required this.initialIndex, this.fallbackName, this.fallbackSpec, this.fallbackPrice, this.fallbackImage});

  static void open(BuildContext context, _Review r, int initialIndex, {String? fallbackName, String? fallbackSpec, double? fallbackPrice, String? fallbackImage}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'review_viewer',
      barrierColor: Colors.black.withOpacity(0.95),
      pageBuilder: (_, __, ___) => _ReviewImageOverlay(r: r, initialIndex: initialIndex, fallbackName: fallbackName, fallbackSpec: fallbackSpec, fallbackPrice: fallbackPrice, fallbackImage: fallbackImage),
    );
  }

  @override
  State<_ReviewImageOverlay> createState() => _ReviewImageOverlayState();
}

class _ReviewImageOverlayState extends State<_ReviewImageOverlay> {
  late final PageController _pc;
  int _index = 0;
  final Map<int, Size> _imgSize = {};
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pc = PageController(initialPage: _index);
    for (int i = 0; i < widget.r.images.length; i++) {
      _resolveImageSize(widget.r.images[i], i);
    }
  }
  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  void _resolveImageSize(String url, int idx) {
    final img = Image.network(url);
    final stream = img.image.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool sync) {
      _imgSize[idx] = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      stream.removeListener(listener!);
      if (mounted) setState(() {});
    }, onError: (error, stack) {
      stream.removeListener(listener!);
    });
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final mw = MediaQuery.of(context).size.width;
    final name = widget.r.productName.isNotEmpty ? widget.r.productName : (widget.fallbackName ?? '');
    final spec = widget.r.productSpec.isNotEmpty ? widget.r.productSpec : (widget.fallbackSpec ?? '');
    final price = widget.r.productPrice != 0 ? widget.r.productPrice : (widget.fallbackPrice ?? 0);
    final cover = widget.r.productImage.isNotEmpty ? widget.r.productImage : (widget.fallbackImage ?? 'https://picsum.photos/400/400');

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(children: [
        // 图片分页
        Positioned.fill(
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.r.images.length,
            itemBuilder: (_, i) => Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(widget.r.images[i], fit: BoxFit.contain),
              ),
            ),
          ),
        ),

        // 顶部：用户昵称 + 购入时间（与图片上边缘间距 5px）
        Positioned(
          left: 12,
          right: 12,
          top: () {
            final screen = MediaQuery.of(context).size;
            final sz = _imgSize[_index];
            if (sz == null || sz.width == 0 || sz.height == 0) {
              return topPad + 5; // 回退：靠安全区顶 5px
            }
            final scale = (screen.width / sz.width).clamp(0.0, double.infinity);
            double dispH = sz.height * scale;
            if (dispH > screen.height) {
              final scale2 = screen.height / sz.height;
              dispH = sz.height * scale2;
            }
            final topEdge = (screen.height - dispH) / 2;
            return (topEdge + 5).clamp(topPad + 5, double.infinity);
          }(),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x80F3F4F6), borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${widget.r.user}  ·  ${widget.r.purchaseTime}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, decoration: TextDecoration.none),
              ),
            ),
          ]),
        ),

        // 移除单独的名称+规格文本，统一放入卡片中

        // 底部中间：商品简要卡片（小圆角 + 细粉色边框）
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPad + 24,
          child: Center(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB3D1), width: 1),
              ),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(cover, width: 56, height: 56, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(spec, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('¥${price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFF3D6E), fontWeight: FontWeight.w700, fontSize: 13, decoration: TextDecoration.none)),
              ]),
            ),
          ),
        ),

        // 商品卡片上方 3px 左侧的小提示：用户 + 购买的商品
        Positioned(
          left: (mw - 280) / 2,
          bottom: bottomPad + 24 + 76 + 3, // 卡片上方 3px（卡片高约 56 + padding*2 = 76）
          child: Text(
            '${widget.r.user} 购买的商品',
            style: const TextStyle(color: Colors.white70, fontSize: 11, decoration: TextDecoration.none),
          ),
        ),
      ]),
    );
  }
}
// 参数详情弹窗（占位示例）
class _ParamsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = const [
      ['品牌', 'Apple'],
      ['型号', 'iPhone Air'],
      ['处理器', 'A 系列'],
      ['存储', '256GB'],
      ['电池', '4300mAh'],
      ['重量', '172g'],
      ['屏幕', '6.1" 120Hz'],
      ['分辨率', 'FHD+'],
    ];
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Text('商品参数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 92, child: Text(items[i][0], style: const TextStyle(color: AppColors.textSecondary))),
                      Expanded(child: Text(items[i][1], style: const TextStyle(color: AppColors.textPrimary))),
                    ],
                  ),
                ),
                itemCount: items.length,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 保障详情弹窗（占位）
class _GuaranteeSheet extends StatelessWidget {
  const _GuaranteeSheet();
  @override
  Widget build(BuildContext context) {
    const details = [
      '7天无理由退货：签收后7天内满足完好即可退货',
      '官方质保：享受品牌官方保修服务',
      '闪电退款：审核通过极速原路退回',
      '7天价保：降价补差',
      '破损包退换：到货破损免费退换',
    ];
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Text('保障信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: details.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(details[i], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// 简单的评价模型
class _Review {
  final String user;
  final String content;
  final String? tag;
  final List<String> images;
  final int rating; // 1..5
  final String ratingLabel; // 超赞/还不错/一般/差/非常差
  final String purchaseTime; // 购入时间
  final String productName;
  final String productSpec; // 购入规格
  final double productPrice;
  final String productImage;
  const _Review({
    required this.user,
    required this.content,
    this.tag,
    this.images = const [],
    this.rating = 5,
    this.ratingLabel = '超赞',
    this.purchaseTime = '2024-09-30',
    this.productName = '',
    this.productSpec = '',
    this.productPrice = 0,
    this.productImage = '',
  });
}

class _ReviewCard extends StatelessWidget {
  final _Review r;
  final void Function(int index)? onTapImage;
  const _ReviewCard(this.r, {this.onTapImage});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 头像（占位用首字母圈）
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE5E7EB)),
          alignment: Alignment.center,
          child: Text(r.user.characters.first, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ),
        const SizedBox(width: 8),
        // 内容
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 第一行：用户名（左） 评价时间（右）
            Row(children: [
              Expanded(child: Text(r.user, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Text(r.purchaseTime, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            ]),
            const SizedBox(height: 4),
            // 第二行：情绪标签 + 星级 + 已购标签 + 商品名规格
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(6)),
                child: Text(r.ratingLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF8B5E3C), fontWeight: FontWeight.w700)),
              ),
              _Stars(rating: r.rating),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE9FAF0), borderRadius: BorderRadius.circular(6)),
                child: const Text('已购', style: TextStyle(fontSize: 10, color: Color(0xFF1FAA65), fontWeight: FontWeight.w700)),
              ),
              Text('${r.productName} ${r.productSpec}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 4),
            Text(r.content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (r.images.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => onTapImage?.call(i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(r.images[i], width: 64, height: 64, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ]
          ]),
        ),
      ]),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating; // 1..5
  const _Stars({required this.rating});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 1; i <= 5; i++)
        Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: const Color(0xFFFFC107)),
    ]);
  }
}

// 评价详情页
class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final chips = const ['全部 97%好评', '图/视频 50', '追评 2', '穿起来超舒适 12', '裤型超好看 2', '显腿长 1'];
    final list = List<_Review>.generate(10, (i) => _Review(
      user: '心***${6 + i}',
      content: '很显腿长，面料很软和，穿着舒适，性价比高，值得推荐。',
      tag: i % 2 == 0 ? '会员' : null,
      images: i % 3 == 0 ? ['https://picsum.photos/400/300', 'https://picsum.photos/400/300?2'] : const [],
      rating: 5 - (i % 5),
      ratingLabel: const ['非常差', '差', '一般', '还不错', '超赞'][i % 5],
      purchaseTime: '2024-09-${(10 + i).toString().padLeft(2, '0')}',
      productName: 'Apple iPhone Air 256GB',
      productSpec: '云白色 eSIM',
      productPrice: 7999,
      productImage: 'https://picsum.photos/200/200',
    ));

    return Scaffold(
      appBar: AppBar(title: const Text('评价')),
      backgroundColor: Colors.white,
      body: Column(children: [
        SizedBox(
          height: 36,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (final c in chips) ...[
                Container(
                  height: 28,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
                  child: Text(c, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ),
              ]
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (_, i) => _ReviewCard(
              list[i],
              onTapImage: (idx) => _ReviewImageOverlay.open(context, list[i], idx),
            ),
          ),
        ),
      ]),
    );
  }
}
