import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import 'providers/notes_provider.dart';

/// linkme_flutter/lib/features/notes/note_editor_screen.dart
/// NoteEditorScreen
/// 笔记编辑页面，包含标题、内容输入及底部工具栏
class NoteEditorScreen extends StatefulWidget {
  /// 构造函数
  /// @param notebook 所属笔记本
  /// @param note 现有笔记对象（可选，为空则为新建）
  const NoteEditorScreen({super.key, required this.notebook, this.note});

  final Notebook notebook;
  final NoteEntry? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();
  
  // 滚动控制器，用于监听滚动并动态显示 AppBar 标题
  final ScrollController _scrollController = ScrollController();
  
  // 状态变量：是否显示 AppBar 上的标题
  bool _showAppBarTitle = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
    }
    
    // 监听滚动事件
    _scrollController.addListener(_handleScroll);
    
    // 监听标题变化，实时更新 AppBar 标题（如果在显示状态）
    _titleController.addListener(() {
      if (_showAppBarTitle) setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }
  
  /// 滚动监听处理
  /// 当标题输入框的大部分滚动出屏幕时，显示 AppBar 标题
  void _handleScroll() {
    // 阈值设为 50，大约是标题行的一半高度
    final bool shouldShow = _scrollController.hasClients && _scrollController.offset > 50;
    if (shouldShow != _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = shouldShow;
      });
    }
  }

  /// 保存笔记
  /// linkme_flutter/lib/features/notes/note_editor_screen.dart
  /// _NoteEditorScreenState
  /// _saveNote
  /// 无参数
  void _saveNote() {
    final NotesProvider provider = context.read<NotesProvider>();
    // 如果标题和内容都为空，直接返回
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    
    // 更新或新建笔记
    if (_isEditing) {
      provider.updateNote(
        notebookId: widget.notebook.id,
        noteId: widget.note!.id,
        title: _titleController.text,
        content: _contentController.text,
      );
    } else {
      provider.addNote(
        notebookId: widget.notebook.id,
        title: _titleController.text,
        content: _contentController.text,
      );
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // 检测键盘是否弹起
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    // AppBar 标题文本，取自输入框，若空则显示默认文案
    final String appBarTitleText = _titleController.text.trim().isEmpty 
        ? '未命名笔记' 
        : _titleController.text.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      // 允许 Scaffold 自动调整大小以避让键盘
      // 这样 Positioned(bottom: 0) 会自动跟随键盘顶部
      resizeToAvoidBottomInset: true,
      // 关键修改：允许 body 延伸到 AppBar 后面，实现沉浸式/穿透效果
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // 当滚动发生时，背景色变为淡白色/半透明效果
        backgroundColor: _showAppBarTitle ? Colors.white : Colors.transparent,
        // 滚动时显示轻微阴影或分隔线
        elevation: _showAppBarTitle ? 0.5 : 0,
        shadowColor: Colors.black.withOpacity(0.1),
        scrolledUnderElevation: 0,
        centerTitle: true,
        // 动态标题：渐入渐出效果
        title: AnimatedOpacity(
          opacity: _showAppBarTitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            appBarTitleText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        leadingWidth: 100, // 稍微增加宽度以确保容纳下 Row
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.only(left: 16),
            alignment: Alignment.centerLeft, // 确保整体靠左
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
              children: const [
                Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Colors.black87,
                ),
                SizedBox(width: 2), // 稍微减小间距，更紧凑
                Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.0, // 消除文字默认行高带来的垂直偏移
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF1A1A1A), // 深黑色
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // 胶囊形状
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                minimumSize: const Size(60, 36),
              ),
              onPressed: _saveNote,
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        // 点击空白处收起键盘
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          // SafeArea 仅负责顶部，底部由我们在 Toolbar 中手动处理（为了更精细的控制）
          // 这里必须把 top 设为 false，因为我们在 ListView 里手动加了 padding.top 来实现沉浸式
          top: false,
          bottom: false,
          child: Stack(
            children: [
              // 内容区域
              Positioned.fill(
                child: ListView(
                  controller: _scrollController,
                  // 增加顶部 Padding 以避让 AppBar (StatusBarHeight + AppBarHeight)
                  // 底部增加 Padding 以避让 Toolbar
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                    bottom: 80,
                  ),
                  children: [
                    // const SizedBox(height: 16), // 已合并到 padding.top 中
                    // 标题输入框
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      cursorColor: AppColors.primary,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111215),
                        height: 1.3,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '起个标题趴',
                        hintStyle: TextStyle(
                          color: Color(0xFFD0D3D9),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: false,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_contentFocus);
                      },
                    ),
                    const SizedBox(height: 24),
                    // 内容输入框
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocus,
                      maxLines: null,
                      cursorColor: AppColors.primary,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '记录点什么呢？',
                        hintStyle: TextStyle(
                          color: Color(0xFF9EA3AE),
                          fontSize: 16,
                          height: 1.5,
                        ),
                        filled: false,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF111215),
                        height: 1.5,
                      ),
                    ),
                    // 底部留白，防止内容被Toolbar遮挡
                    // Toolbar 高度 ~52 + Padding ~16 = 68，多留一点
                    const SizedBox(height: 80), 
                  ],
                ),
              ),
              
              // 底部悬浮工具栏
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildToolbar(context, isKeyboardVisible),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部工具栏
  Widget _buildToolbar(BuildContext context, bool isKeyboardVisible) {
    // 如果键盘弹起，padding 为 12（紧凑）；如果没弹起，padding 为 SafeArea.bottom + 16
    final double bottomPadding = isKeyboardVisible 
        ? 12.0 
        : MediaQuery.of(context).padding.bottom + 16.0;

    return Container(
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        bottom: bottomPadding,
        top: 8
      ),
      // 可以添加渐变背景遮罩，防止文字与Toolbar重叠时看不清
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.8),
            Colors.white,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2125), // 接近黑色的深灰
          borderRadius: BorderRadius.circular(26), // 圆角胶囊
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // AI 魔法图标
            _ToolbarButton(
              icon: Icons.auto_awesome, // 使用闪烁/魔法图标
              color: const Color(0xFF7B90FF), // 亮蓝色
              onTap: () {
                // TODO: 接入AI辅助写作功能
              },
            ),
            // 分割线
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white.withOpacity(0.2),
            ),
            // 其他格式化图标
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ToolbarButton(
                    icon: Icons.format_bold,
                    onTap: () {},
                  ),
                  _ToolbarButton(
                    icon: Icons.format_italic,
                    onTap: () {},
                  ),
                  _ToolbarButton(
                    icon: Icons.title, 
                    onTap: () {},
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_bulleted,
                    onTap: () {},
                  ),
                  _ToolbarButton(
                    icon: Icons.check_box_outlined,
                    onTap: () {},
                  ),
                  _ToolbarButton(
                    icon: Icons.code,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具栏按钮组件
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: color ?? const Color(0xFFE0E0E0), // 默认为浅灰色
        ),
      ),
    );
  }
}
