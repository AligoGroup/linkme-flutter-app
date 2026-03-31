import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/custom_toast.dart';
import '../../../shared/providers/auth_provider.dart';
import 'topic_search_screen.dart';
import '../services/academy_api.dart';

/// create_post_screen.dart | CreatePostScreen | 发帖页面
/// 严格按照设计稿还原：顶部自定义导航栏，九宫格模式图片在上方，底部功能按钮行
class CreatePostScreen extends StatefulWidget {
  final int? postId; // 编辑模式：传入帖子ID
  final Map<String, dynamic>? postData; // 编辑模式：传入帖子数据

  const CreatePostScreen({
    super.key,
    this.postId,
    this.postData,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _checkInContentController =
      TextEditingController();
  final TextEditingController _articleTitleController = TextEditingController();
  final TextEditingController _articleContentController =
      TextEditingController();

  // 选中的图片列表（新上传的本地文件）
  final List<XFile> _selectedMedia = [];

  // 原有的图片URL列表（编辑模式）
  final List<String> _existingImageUrls = [];

  // 原有的视频信息（编辑模式）
  String? _existingVideoUrl;
  String? _existingVideoThumbnail;

  // 视频缩略图缓存 (索引 -> 缩略图路径)
  final Map<int, String> _videoThumbnails = {};

  // 选中的标签列表 (话题 + 打卡)
  final List<Map<String, String>> _tags =
      []; // {'text': 'xxx', 'type': 'topic'|'checkin'}

  // 选中的分类
  String _selectedCategory = '分类';

  List<String> _categories = [];
  bool _isLoadingCategories = false;

  final ImagePicker _picker = ImagePicker();

  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // 监听Tab变化以更新UI选中态
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadCategories();

    // 编辑模式：加载帖子数据
    if (widget.postData != null) {
      _loadPostData();
    }
  }

  /// 加载帖子数据（编辑模式）
  void _loadPostData() {
    final data = widget.postData!;

    print('📝 [Create Post] 加载编辑数据: $data');

    // 判断是长文还是打卡模式
    final hasTitle =
        data['title'] != null && (data['title'] as String).isNotEmpty;
    if (hasTitle) {
      // 长文模式
      _tabController.index = 1;
      _articleTitleController.text = data['title'] ?? '';
      _articleContentController.text = data['content'] ?? '';
    } else {
      // 打卡模式
      _tabController.index = 0;
      _checkInContentController.text = data['content'] ?? '';
    }

    // 加载分类
    if (data['type'] != null &&
        data['type'] != 'recommend' &&
        data['type'] != 'hot') {
      _selectedCategory = data['type'];
      print('📝 [Create Post] 加载分类: $_selectedCategory');
    }

    // 加载话题
    if (data['topics'] != null) {
      final topics = data['topics'] as List;
      for (var topic in topics) {
        _tags.add({'text': topic.toString(), 'type': 'topic'});
      }
      print('📝 [Create Post] 加载话题: ${_tags.length}个');
    }

    // 加载学习打卡标签
    if (data['isStudyCheckIn'] == true) {
      _tags.add({'text': '学习打卡', 'type': 'checkin'});
      print('📝 [Create Post] 加载学习打卡标签');
    }

    // 加载原有的图片和视频URL
    if (data['images'] != null && data['images'] is List) {
      final images = data['images'] as List;
      _existingImageUrls.addAll(images.map((e) => e.toString()));
      print('📝 [Create Post] 加载原有图片: ${_existingImageUrls.length}张');
    }

    if (data['videoUrl'] != null) {
      _existingVideoUrl = data['videoUrl'].toString();
      _existingVideoThumbnail = data['videoThumbnail']?.toString();
      print('📝 [Create Post] 加载原有视频: $_existingVideoUrl');
    }
  }

  /// create_post_screen.dart | _CreatePostScreenState | _loadCategories | 加载帖子分类
  Future<void> _loadCategories() async {
    if (_isLoadingCategories) return;

    setState(() => _isLoadingCategories = true);

    try {
      final categories = await AcademyApi.getPostCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      print('加载分类失败: $e');
      // 失败时使用默认分类
      if (mounted) {
        setState(() {
          _categories = ['提问', '经验', '资料', '讨论'];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _checkInContentController.dispose();
    _articleTitleController.dispose();
    _articleContentController.dispose();
    super.dispose();
  }

  /// 选择媒体（图片或视频）- 直接打开相册
  Future<void> _pickMedia() async {
    if (_selectedMedia.length >= 9) {
      if (mounted) {
        CustomToast.showWarning(context, '最多只能选择9个媒体文件');
      }
      return;
    }

    try {
      // 直接使用 pickMultipleMedia 支持图片和视频混选
      final List<XFile> media = await _picker.pickMultipleMedia(
        limit: 9 - _selectedMedia.length,
      );

      if (media.isNotEmpty) {
        for (final file in media) {
          final fileIndex = _selectedMedia.length;
          setState(() {
            _selectedMedia.add(file);
          });

          // 判断是否为视频，如果是则生成缩略图
          final mimeType = file.mimeType ?? '';
          final path = file.path.toLowerCase();
          final isVideo = mimeType.startsWith('video/') ||
              path.endsWith('.mp4') ||
              path.endsWith('.mov') ||
              path.endsWith('.avi') ||
              path.endsWith('.mkv') ||
              path.endsWith('.webm');

          if (isVideo) {
            _generateVideoThumbnail(file.path).then((thumbnailPath) {
              if (thumbnailPath != null && mounted) {
                setState(() {
                  _videoThumbnails[fileIndex] = thumbnailPath;
                });
              }
            });
          }
        }
      }
    } catch (e) {
      print('选择媒体失败: $e');
    }
  }

  /// 生成视频缩略图
  Future<String?> _generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 300,
        quality: 75,
      );
      return thumbnailPath;
    } catch (e) {
      print('生成视频缩略图失败: $e');
      return null;
    }
  }

  /// 插入媒体到文本（长文模式）- 直接打开相册
  Future<void> _insertMediaToText() async {
    try {
      // 直接打开相册选择单个媒体（图片或视频）
      final XFile? media = await _picker.pickMedia();

      if (media != null) {
        final mediaIndex = _selectedMedia.length;

        // 判断媒体类型
        final mimeType = media.mimeType ?? '';
        final path = media.path.toLowerCase();
        final isVideo = mimeType.startsWith('video/') ||
            path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.avi') ||
            path.endsWith('.mkv') ||
            path.endsWith('.webm');

        final markerType = isVideo ? 'video' : 'img';

        setState(() {
          _selectedMedia.add(media);

          // 在光标位置插入媒体标记
          final controller = _articleContentController;
          final cursorPos = controller.selection.baseOffset;
          final text = controller.text;

          // 智能处理换行
          String prefix = '';
          String suffix = '';

          if (cursorPos > 0 &&
              !text.substring(cursorPos - 1, cursorPos).contains('\n')) {
            prefix = '\n';
          }

          if (cursorPos < text.length &&
              !text.substring(cursorPos, cursorPos + 1).contains('\n')) {
            suffix = '\n';
          }

          final mediaMarker = '$prefix[$markerType:$mediaIndex]$suffix';
          final newText = text.substring(0, cursorPos) +
              mediaMarker +
              text.substring(cursorPos);

          controller.value = controller.value.copyWith(
            text: newText,
            selection: TextSelection.collapsed(
              offset: cursorPos + mediaMarker.length,
            ),
          );
        });

        // 如果是视频，异步生成缩略图
        if (isVideo) {
          _generateVideoThumbnail(media.path).then((thumbnailPath) {
            if (thumbnailPath != null && mounted) {
              setState(() {
                _videoThumbnails[mediaIndex] = thumbnailPath;
              });
            }
          });
        }
      }
    } catch (e) {
      print('插入媒体失败: $e');
    }
  }

  /// 移除媒体（图片或视频）
  void _removeImage(int index) {
    setState(() {
      // 删除视频缩略图缓存
      if (_videoThumbnails.containsKey(index)) {
        _videoThumbnails.remove(index);
      }

      // 更新后续视频的缩略图索引
      final Map<int, String> updatedThumbnails = {};
      _videoThumbnails.forEach((key, value) {
        if (key > index) {
          updatedThumbnails[key - 1] = value;
        } else {
          updatedThumbnails[key] = value;
        }
      });
      _videoThumbnails.clear();
      _videoThumbnails.addAll(updatedThumbnails);

      _selectedMedia.removeAt(index);

      // 如果是长文模式，需要更新文本中的媒体标记
      if (_tabController.index == 1) {
        final controller = _articleContentController;
        String text = controller.text;

        // 移除对应的图片或视频标记
        text = text.replaceAll('[img:$index]', '');
        text = text.replaceAll('[video:$index]', '');

        // 更新后续媒体的索引
        for (int i = index + 1; i < _selectedMedia.length + 1; i++) {
          text = text.replaceAll('[img:$i]', '[img:${i - 1}]');
          text = text.replaceAll('[video:$i]', '[video:${i - 1}]');
        }

        controller.text = text;
      }
    });
  }

  /// 添加标签
  void _addTag(String text, String type) {
    if (_tags.length >= 3) {
      // 提示最多3个
      CustomToast.showWarning(context, '最多添加3个标签');
      return;
    }
    // 查重
    if (_tags.any((tag) => tag['text'] == text)) return;

    setState(() {
      _tags.add({'text': text, 'type': type});
    });
  }

  /// 移除标签
  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  /// 打开话题搜索
  Future<void> _openTopicSearch() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TopicSearchScreen()),
    );
    if (result != null && result is String) {
      _addTag(result, 'topic');
    }
  }

  /// 打开分类选择
  void _openCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('选择分类',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ..._categories.map((category) => ListTile(
                    title: Text(category, textAlign: TextAlign.center),
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics:
                      const NeverScrollableScrollPhysics(), // 禁止左右滑动切换，防止冲突
                  children: [
                    _buildCheckInPage(),
                    _buildArticlePage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部自定义导航栏
  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 关闭按钮 (左侧)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.close,
              size: 28,
              color: Color(0xFF333333),
            ),
          ),

          // 中间 Tab 切换
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabItem(0, '学习打卡'),
                const SizedBox(width: 24),
                _buildTabItem(1, '长文'),
              ],
            ),
          ),

          // 发布按钮 (右侧)
          GestureDetector(
            onTap: _isPublishing ? null : _publishPost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: _isPublishing
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xFFFF99B3), // 发布中显示灰色
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 40,
                      height: 18,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      widget.postId != null ? '保存' : '发布',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String text) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        if (_tabController.index != index) {
          setState(() {
            _tags.clear(); // 切换Tab清空标签
          });
          _tabController.animateTo(index);
        }
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF333333) : const Color(0xFF999999),
        ),
      ),
    );
  }

  /// 构建"学习打卡"页面
  Widget _buildCheckInPage() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        // 1. 图片选择 (九宫格，放在顶部)
        // 样式：一个大的灰色加号方块，选图后变成 Grid
        _buildMediaGrid(),

        const SizedBox(height: 16),
        // 2. 文本输入
        TextField(
          controller: _checkInContentController,
          maxLines: null,
          minLines: 3,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: '分享我的LinkMe动态',
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            hintStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
        ),

        const SizedBox(height: 8),
        const SizedBox(height: 8),
        // 3. 标签展示 (话题 + 打卡)
        if (_tags.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_tags.length, (index) {
                  final tag = _tags[index];
                  final isTopic = tag['type'] == 'topic';
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isTopic) ...[
                          SvgPicture.asset(
                            'assets/app_icons/svg/hashtag.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                                AppColors.primary, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tag['text']!,
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeTag(index),
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 12),

        // 4. 功能选项行 (Add Topic, Study Check-in, Category)
        Row(
          children: [
            // 添加话题
            _buildActionChip(
              icon: 'assets/app_icons/svg/hashtag.svg',
              label: '添加话题',
              onTap: _openTopicSearch,
            ),
            const SizedBox(width: 12),
            // 学习打卡
            _buildActionChip(
              icon: 'assets/app_icons/svg/task.svg',
              label: '学习打卡',
              onTap: () => _addTag('学习打卡', 'checkin'),
            ),
            const SizedBox(width: 12),
            // 分类
            _buildActionChip(
              icon: 'assets/app_icons/svg/category.svg',
              label: _selectedCategory,
              onTap: _openCategoryPicker,
            ),
          ],
        ),
      ],
    );
  }

  /// 构建"长文"页面
  Widget _buildArticlePage() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        // 标题
        TextField(
          controller: _articleTitleController,
          decoration: const InputDecoration(
            hintText: '好的标题更容易获得支持，选填20字',
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            hintStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 18,
                fontWeight: FontWeight.bold),
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333)),
          maxLength: 20,
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 12),

        // 内容
        TextField(
          controller: _articleContentController,
          maxLines: null,
          minLines: 8,
          decoration: const InputDecoration(
            hintText: '分享我的LinkMe动态',
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            hintStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
        ),

        // 图片预览列表 (长文模式显示已插入的图片)
        if (_selectedMedia.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '已插入的图片：',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_selectedMedia.length, (index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedMedia[index].path),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '图${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],

        const SizedBox(height: 8),
        // 标签展示 (话题 + 打卡)
        if (_tags.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_tags.length, (index) {
                  final tag = _tags[index];
                  final isTopic = tag['type'] == 'topic';
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isTopic) ...[
                          SvgPicture.asset(
                            'assets/app_icons/svg/hashtag.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                                AppColors.primary, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tag['text']!,
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeTag(index),
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 12),

        // 功能选项行
        Row(
          children: [
            // 添加话题
            _buildActionChip(
              icon: 'assets/app_icons/svg/hashtag.svg',
              label: '添加话题',
              onTap: _openTopicSearch,
            ),
            const SizedBox(width: 12),
            // 分类
            _buildActionChip(
              icon: 'assets/app_icons/svg/category.svg',
              label: _selectedCategory,
              onTap: _openCategoryPicker,
            ),
            const Spacer(),
            // 插入媒体按钮 (仅长文显示) - 支持图片和视频
            GestureDetector(
              onTap: _insertMediaToText,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(
                  'assets/app_icons/svg/gallery.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF666666), BlendMode.srcIn),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 媒体九宫格 (核心还原点)
  Widget _buildMediaGrid() {
    // 计算总媒体数量：原有图片 + 原有视频 + 新选择的媒体
    final totalExistingMedia =
        _existingImageUrls.length + (_existingVideoUrl != null ? 1 : 0);
    final totalMedia = totalExistingMedia + _selectedMedia.length;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: totalMedia + 1, // +1 是添加按钮
      itemBuilder: (context, index) {
        if (index == totalMedia) {
          // 添加按钮 - 大的灰色方块 + 号
          if (totalMedia >= 9) return const SizedBox(); // 最多9张

          return GestureDetector(
            onTap: _pickMedia,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(4), // 方形圆角
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add,
                size: 40,
                color: Color(0xFFCCCCCC),
              ),
            ),
          );
        }

        // 判断是原有图片、原有视频还是新选择的媒体
        if (index < _existingImageUrls.length) {
          // 显示原有图片
          return _buildExistingImageItem(index);
        } else if (index == _existingImageUrls.length &&
            _existingVideoUrl != null) {
          // 显示原有视频
          return _buildExistingVideoItem();
        } else {
          // 显示新选择的媒体
          final mediaIndex = index - totalExistingMedia;
          final media = _selectedMedia[mediaIndex];
          final mimeType = media.mimeType ?? '';
          final path = media.path.toLowerCase();

          // 判断是否为视频文件
          final isVideo = mimeType.startsWith('video/') ||
              path.endsWith('.mp4') ||
              path.endsWith('.mov') ||
              path.endsWith('.avi') ||
              path.endsWith('.mkv') ||
              path.endsWith('.webm');

          return _buildNewMediaItem(mediaIndex, media, isVideo);
        }
      },
    );
  }

  /// 构建原有图片项
  Widget _buildExistingImageItem(int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            _existingImageUrls[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFFF0F0F0),
                child: const Icon(
                  Icons.image,
                  size: 40,
                  color: Color(0xFFCCCCCC),
                ),
              );
            },
          ),
        ),
        // 删除按钮
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _existingImageUrls.removeAt(index);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建原有视频项
  Widget _buildExistingVideoItem() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _existingVideoThumbnail != null
              ? Image.network(
                  _existingVideoThumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF000000),
                      child: const Center(
                        child: Icon(
                          Icons.videocam,
                          size: 40,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  color: const Color(0xFF000000),
                  child: const Center(
                    child: Icon(
                      Icons.videocam,
                      size: 40,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
        ),
        // 视频播放按钮标识
        Center(
          child: SvgPicture.asset(
            'assets/app_icons/svg/play.svg',
            width: 48,
            height: 48,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
        // 删除按钮
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _existingVideoUrl = null;
                _existingVideoThumbnail = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建新选择的媒体项
  Widget _buildNewMediaItem(int mediaIndex, XFile media, bool isVideo) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: isVideo
              ? _videoThumbnails.containsKey(mediaIndex)
                  ? Image.file(
                      File(_videoThumbnails[mediaIndex]!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF000000),
                          child: const Center(
                            child: Icon(
                              Icons.videocam,
                              size: 40,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFF000000),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
              : Image.file(
                  File(media.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(
                        Icons.image,
                        size: 40,
                        color: Color(0xFFCCCCCC),
                      ),
                    );
                  },
                ),
        ),
        // 视频播放按钮标识 - 使用SVG图标
        if (isVideo)
          Center(
            child: SvgPicture.asset(
              'assets/app_icons/svg/play.svg',
              width: 48,
              height: 48,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        // 删除按钮
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(mediaIndex),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 功能按钮 (话题、打卡、分类)
  Widget _buildActionChip({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              width: 16,
              height: 16,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }

  /// 发布帖子
  Future<void> _publishPost() async {
    // 验证内容
    final isCheckIn = _tabController.index == 0;
    final content = isCheckIn
        ? _checkInContentController.text.trim()
        : _articleContentController.text.trim();

    if (content.isEmpty) {
      CustomToast.showWarning(context, '请输入内容');
      return;
    }

    if (!isCheckIn && _articleTitleController.text.trim().isEmpty) {
      CustomToast.showWarning(context, '请输入标题');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        CustomToast.showWarning(context, '请先登录');
        return;
      }

      // 1. 上传媒体文件（图片和视频）
      final List<String> imageUrls = [];
      String? videoUrl;
      String? videoThumbnail;
      int? videoDuration;

      // 编辑模式：先添加保留的原有图片和视频
      if (widget.postId != null) {
        // 添加保留的原有图片
        imageUrls.addAll(_existingImageUrls);
        print('📝 [Create Post] 编辑模式：保留原有图片 ${_existingImageUrls.length}张');

        // 添加保留的原有视频
        if (_existingVideoUrl != null) {
          videoUrl = _existingVideoUrl;
          videoThumbnail = _existingVideoThumbnail;
          print('📝 [Create Post] 编辑模式：保留原有视频');
        }
      }

      // 上传新选择的媒体文件
      for (int i = 0; i < _selectedMedia.length; i++) {
        final file = _selectedMedia[i];
        final mimeType = file.mimeType ?? '';
        final path = file.path.toLowerCase();

        // 判断是否为视频
        final isVideo = mimeType.startsWith('video/') ||
            path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.avi') ||
            path.endsWith('.mkv') ||
            path.endsWith('.webm');

        if (isVideo) {
          // 上传视频（只保留最后一个视频）
          final url = await AcademyApi.uploadVideo(File(file.path));
          videoUrl = url;

          // 上传视频缩略图
          if (_videoThumbnails.containsKey(i)) {
            final thumbnailPath = _videoThumbnails[i]!;
            final thumbnailUrl =
                await AcademyApi.uploadImage(File(thumbnailPath));
            videoThumbnail = thumbnailUrl;
            print('📤 [Create Post] 视频缩略图上传成功: $videoThumbnail');
          }

          // TODO: 获取视频时长
          videoDuration = 0;
        } else {
          // 上传图片
          final url = await AcademyApi.uploadImage(File(file.path));
          imageUrls.add(url);
        }
      }

      // 2. 提取话题
      final topics = _tags
          .where((t) => t['type'] == 'topic')
          .map((t) => t['text']!)
          .toList();

      // 3. 判断是否学习打卡
      final isStudyCheckIn =
          _tags.any((t) => t['type'] == 'checkin' && t['text'] == '学习打卡');

      // 4. 调用API
      if (widget.postId != null) {
        // 编辑模式
        print('📝 [Create Post] 编辑模式 - postId: ${widget.postId}');
        print(
            '📝 [Create Post] 标题: ${isCheckIn ? null : _articleTitleController.text.trim()}');
        print('📝 [Create Post] 内容长度: ${content.length}');
        print('📝 [Create Post] 图片: ${imageUrls.length}张');
        print('📝 [Create Post] 视频: $videoUrl');
        print('📝 [Create Post] 话题: $topics');
        print('📝 [Create Post] 分类: $_selectedCategory');
        print('📝 [Create Post] 学习打卡: $isStudyCheckIn');

        await AcademyApi.updatePost(
          postId: widget.postId!,
          userId: userId,
          title: isCheckIn ? null : _articleTitleController.text.trim(),
          content: content,
          images: imageUrls.isNotEmpty ? imageUrls : null,
          videoUrl: videoUrl,
          videoThumbnail: videoThumbnail,
          isStudyCheckIn: isStudyCheckIn,
          topics: topics.isNotEmpty ? topics : null,
          type: _selectedCategory != '分类' ? _selectedCategory : null,
        );

        if (mounted) {
          CustomToast.showSuccess(context, '保存成功');
          Navigator.pop(context, true);
        }
      } else {
        // 新建模式
        print('📤 [Create Post] 准备发布帖子');
        print('📤 [Create Post] 图片URLs: $imageUrls');
        print('📤 [Create Post] 视频URL: $videoUrl');
        print('📤 [Create Post] 内容长度: ${content.length}');

        final result = await AcademyApi.createPost(
          userId: userId,
          title: isCheckIn ? null : _articleTitleController.text.trim(),
          content: content,
          images: imageUrls.isNotEmpty ? imageUrls : null,
          videoUrl: videoUrl,
          videoThumbnail: videoThumbnail,
          isStudyCheckIn: isStudyCheckIn,
          topics: topics.isNotEmpty ? topics : null,
          type: _selectedCategory != '分类' ? _selectedCategory : null,
          nickname: authProvider.user?.nickname,
          avatar: authProvider.user?.avatar,
        );

        print('✅ [Create Post] 发布成功，返回数据: $result');

        if (mounted) {
          // 显示获得的经验值和积分
          final experienceGained = result['experienceGained'] ?? 0;
          final pointsGained = result['pointsGained'] ?? 0;
          CustomToast.showSuccess(
            context,
            '发布成功\n+ $experienceGained 经验值 + $pointsGained 积分',
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      print('发布失败: $e');
      if (mounted) {
        CustomToast.showError(context, '发布失败: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }
}
