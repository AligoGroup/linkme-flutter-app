import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';

class EmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback? onBackspacePressed;

  const EmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.onBackspacePressed,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 表情符号分类
  final List<EmojiCategory> _categories = [
    EmojiCategory(
      name: '笑脸',
      icon: '😀',
      emojis: [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
        '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
        '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
        '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
        '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
        '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
        '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
      ],
    ),
    EmojiCategory(
      name: '手势',
      icon: '👋',
      emojis: [
        '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤞', '✌️',
        '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇',
        '☝️', '👍', '👎', '👊', '✊', '🤛', '🤜', '👏',
        '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💅', '🤳',
      ],
    ),
    EmojiCategory(
      name: '爱心',
      icon: '❤️',
      emojis: [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
        '💘', '💝', '💟', '♥️', '💌', '💋', '💒', '💍',
      ],
    ),
    EmojiCategory(
      name: '动物',
      icon: '🐶',
      emojis: [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
        '🐨', '🐯', '🦁', '🐮', '🐷', '🐽', '🐸', '🐵',
        '🙊', '🙉', '🙈', '🐒', '🐔', '🐧', '🐦', '🐤',
        '🐣', '🐥', '🦆', '🦅', '🦉', '🦇', '🐺', '🐗',
      ],
    ),
    EmojiCategory(
      name: '食物',
      icon: '🍎',
      emojis: [
        '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓',
        '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅',
        '🍆', '🥑', '🥦', '🥬', '🥒', '🌶️', '🌽', '🥕',
        '🧄', '🧅', '🥔', '🍠', '🥐', '🍞', '🥖', '🥨',
      ],
    ),
    EmojiCategory(
      name: '活动',
      icon: '⚽',
      emojis: [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉',
        '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍',
        '🏏', '🪃', '🥅', '⛳', '🪁', '🏹', '🎣', '🤿',
        '🥊', '🥋', '🎽', '🛹', '🛷', '⛸️', '🥌', '🎿',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      // 背景交由外层毛玻璃卡片渲染，这里保持透明
      color: Colors.transparent,
      child: Column(
        children: [
          // Tab栏
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            // 移除顶部/底部任何分割线
            dividerColor: Colors.transparent,
            tabs: _categories.map((category) {
              return Tab(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // 表情网格
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                return _buildEmojiGrid(category.emojis);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        
        return GestureDetector(
          onTap: () => widget.onEmojiSelected(emoji),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.transparent,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}

class EmojiCategory {
  final String name;
  final String icon;
  final List<String> emojis;

  EmojiCategory({
    required this.name,
    required this.icon,
    required this.emojis,
  });
}
