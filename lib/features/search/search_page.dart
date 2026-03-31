import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _tc = TextEditingController(text: '');
  bool _expanded = false; // 历史：默认折叠

  final List<String> _history = [
    '红米 13c 手机壳', '苹果 17', '华为授权体验店', '华为智能生活馆', '华为智能', '小米之家',
    'Apple 授权专营店', '蜜雪冰城', '人体工学椅', '紧身牛仔小脚裤', '一次性内裤', '华为智能手表',
    '矿泉水', '脱毛慕斯', '补水面膜',
  ];

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF8F3E);
    final topPad = MediaQuery.of(context).padding.top;
    const headerHeight = 36.0; // 搜索行高度
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(children: [
          // 顶部橙色背景，仅覆盖搜索区 + 5px 间距范围，避免影响键盘区域
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 8 + headerHeight + 5,
            child: Container(color: orange),
          ),
          Column(children: [
            SizedBox(height: topPad + 8),
            _SearchHeader(tc: _tc),
            const SizedBox(height: 5),
            // 白色主内容区：默认圆角，下拉时也是该区域随内容下拉
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _HistorySection(
                      title: '搜索历史',
                      items: _history,
                      expanded: _expanded,
                      onToggle: () => setState(() => _expanded = !_expanded),
                    ),
                    const SizedBox(height: 8),
                    _DiscoverSection(),
                    const SizedBox(height: 8),
                    _HotTodaySection(),
                  ],
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SearchHeader extends StatefulWidget {
  final TextEditingController tc;
  const _SearchHeader({required this.tc});
  @override
  State<_SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<_SearchHeader> {
  late FocusNode _fn;
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    _fn = FocusNode()..addListener(() => setState(() => _focused = _fn.hasFocus));
  }
  @override
  void dispose() { _fn.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white, // 搜索框白色背景
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _focused ? const Color(0xFFFA3A4A) : Colors.transparent, width: 1), // 聚焦时仅外部白底显示红色细边
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  focusNode: _fn,
                  controller: widget.tc,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '搜索商品 / 店铺',
                    hintStyle: TextStyle(color: Color(0xFF666666)), // 深灰提示文案
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.textPrimary,
                  textAlignVertical: TextAlignVertical.center,
                  onSubmitted: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              // 搜索按钮（在白色背景内，浅红底白字，小圆角）
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(6)),
                child: const Center(child: Text('搜索', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final String title;
  final List<String> items;
  final bool expanded;
  final VoidCallback onToggle;
  const _HistorySection({required this.title, required this.items, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final maxLines = expanded ? 6 : 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        _ChipsWithLineLimit(items: items, maxLines: maxLines, trailing: _HistoryToggleChip(expanded: expanded, onToggle: onToggle)),
      ]),
    );
  }
}

class _HistoryToggleChip extends StatelessWidget {
  final bool expanded; final VoidCallback onToggle;
  const _HistoryToggleChip({required this.expanded, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}

class _ChipsWithLineLimit extends StatelessWidget {
  final List<String> items; final int maxLines; final Widget? trailing;
  const _ChipsWithLineLimit({required this.items, required this.maxLines, this.trailing});

  @override
  Widget build(BuildContext context) {
    const double hPad = 12;
    const double vPad = 6;
    const double spacing = 8;
    const double runSpacing = 8;
    final style = const TextStyle(fontSize: 12, color: AppColors.textPrimary);

    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth;
      double lineW = 0;
      int lines = 1;
      final shown = <String>[];
      for (final text in items) {
        final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
        final w = tp.width + hPad * 2;
        if (shown.isEmpty) {
          if (w <= maxW) {
            shown.add(text);
            lineW = w + spacing;
          } else {
            break;
          }
        } else {
          if (lineW + w > maxW) {
            lines++;
            if (lines > maxLines) break;
            lineW = w + spacing;
            shown.add(text);
          } else {
            shown.add(text);
            lineW += w + spacing;
          }
        }
      }

      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [
          for (final t in shown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
              child: Text(t, style: style),
            ),
          if (trailing != null) trailing!,
        ],
      );
    });
  }
}

class _DiscoverSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final itemsLeft = ['redmi13c 手机壳', '红米 14c 手机壳', '红米 13c 钢化膜', '弗列加特 限时加赠'];
    final itemsRight = ['苹果 iphone17', '红米 13c', '手机壳红米', '女士牛仔裤'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _List(itemsLeft)),
        const SizedBox(width: 12),
        Expanded(child: _List(itemsRight)),
      ]),
    );
  }
}

class _List extends StatelessWidget {
  final List<String> data; const _List(this.data);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final t in data)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: t, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ]),
          ),
        )
    ]);
  }
}

class _HotTodaySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hots = [
      '儿童羽绒服，轻暖不压身',
      '向日葵挂件带来好运与微笑',
      '猫山王，尽享舌尖上的奢华',
      '椰丝球，休闲茶点佳伴',
      '休闲运动鞋，步履更轻松',
      '高品质墨盒，告别打印烦恼',
      '浴巾在手，旅途轻盈无忧',
      '弹盖保温杯，喝水更方便！',
      '新鲜笋尖，一口鲜脆',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Text('今日热搜', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          SizedBox(width: 12),
          Text('数码极客', style: TextStyle(color: AppColors.textSecondary)),
          SizedBox(width: 12),
          Text('11.11热搜', style: TextStyle(color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        for (int i = 0; i < hots.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              gradient: i < 3
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        if (i == 0) const Color(0xFFFFE5E8) else if (i == 1) const Color(0xFFFFF0E0) else const Color(0xFFE9FAF0),
                        Colors.white,
                      ],
                      stops: const [0.3, 1.0],
                    )
                  : null,
              color: i >= 3 ? const Color(0xFFF8F9FA) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              if (i < 3) _TopBadge(rank: i + 1) else _NormalBadge(rank: i + 1),
              const SizedBox(width: 10),
              Expanded(child: Text(hots[i], style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
            ]),
          ),
      ]),
    );
  }
}

class _TopBadge extends StatelessWidget {
  final int rank; const _TopBadge({required this.rank});
  @override
  Widget build(BuildContext context) {
    final baseColor = rank == 1 ? Colors.redAccent : rank == 2 ? const Color(0xFFFF8F3E) : const Color(0xFF22C55E);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, baseColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _NormalBadge extends StatelessWidget {
  final int rank; const _NormalBadge({required this.rank});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFEAEAEA), borderRadius: BorderRadius.circular(6)),
      child: Text('$rank', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
