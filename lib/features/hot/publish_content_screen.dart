import 'dart:io';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/hot_service.dart';
import '../../core/widgets/unified_toast.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/community_notification_provider.dart';
import '../../shared/services/image_upload_service.dart';

/// 发布内容（热点榜单）- 仅前端表单
/// 功能：
/// - 输入网络图片 URL（实时预览）
/// - 标题、概要
/// - 选择分类、选择渠道
/// - 正文内容
/// - 不接后端，点击发布仅做字段校验并提示
class PublishContentScreen extends StatefulWidget {
  final Map<String, dynamic>? initialArticle;
  const PublishContentScreen({super.key, this.initialArticle});

  @override
  State<PublishContentScreen> createState() => _PublishContentScreenState();
}

class _PublishContentScreenState extends State<PublishContentScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _imageUrlCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _summaryCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();

  String? _category;
  String? _channel;
  int? _labelId; // 资源类型（来自搜索下拉菜单）
  List<Map<String, dynamic>> _menus = const [];
  List<String> _categories = const [];
  String? _localCoverPath;
  bool _uploadingCover = false;
  final ImagePicker _imagePicker = ImagePicker();
  int? _articleId;
  String? _initialResourceLabel;

  static const List<String> channels = <String>['热度榜单', '附近门店', '订阅号'];

  bool get _isMobileApp =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
  bool get _isEditing => _articleId != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initialArticle;
    if (init != null && init.isNotEmpty) {
      _articleId = (init['id'] as num?)?.toInt() ?? (init['articleId'] as num?)?.toInt();
      _imageUrlCtrl.text = (init['coverImage'] ?? init['imageUrl'] ?? '').toString();
      _titleCtrl.text = (init['title'] ?? '').toString();
      _summaryCtrl.text = (init['summary'] ?? '').toString();
      _bodyCtrl.text = (init['content'] ?? '').toString();
      _category = (init['category'] ?? '').toString().isEmpty ? null : (init['category'] ?? '').toString();
      _channel = (init['channel'] ?? '').toString().isEmpty ? null : (init['channel'] ?? '').toString();
      _labelId = (init['labelId'] as num?)?.toInt();
      if (_labelId == null) {
        final label = (init['resourceType'] ?? init['label'])?.toString();
        if (label != null && label.isNotEmpty) {
          _initialResourceLabel = label;
        }
      }
    }
  }

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenusOnce() async {
    if (_menus.isNotEmpty) return;
    final res = await HotService().fetchMenus();
    if (res.success && res.data != null) {
      setState(() {
        _menus = res.data!;
        if (_labelId == null && _initialResourceLabel != null) {
          final match = _menus.firstWhere(
            (e) => (e['label'] ?? '').toString() == _initialResourceLabel,
            orElse: () => const {'id': null},
          );
          final mid = (match['id'] as num?)?.toInt();
          if (mid != null) _labelId = mid;
        }
      });
    }
  }

  Future<void> _loadCategoriesOnce() async {
    if (_categories.isNotEmpty) return;
    final res = await HotService().fetchCategories();
    if (res.success && res.data != null) {
      setState(() { _categories = (res.data ?? const []).map((e)=> e['name'].toString()).toList(); });
    }
  }

  Future<void> _pickCoverImage() async {
    if (_uploadingCover) return;
    if (!_isMobileApp) {
      context.showInfoToast('桌面端请直接粘贴图片链接');
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() {
        _localCoverPath = picked.path;
        _uploadingCover = true;
      });
      final url = await ImageUploadService().uploadChatImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        setState(() => _uploadingCover = false);
        context.showErrorToast('图片上传失败，请稍后重试');
        return;
      }
      setState(() {
        _uploadingCover = false;
        _imageUrlCtrl.text = url;
      });
      context.showSuccessToast('图片上传成功');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingCover = false);
      context.showErrorToast('选择图片失败');
    }
  }

  void _clearCoverImage() {
    if (_uploadingCover) return;
    setState(() {
      _localCoverPath = null;
      _imageUrlCtrl.clear();
    });
  }

  void _submit() {
    // 顶部弹窗提示：不使用表单自带的错误样式
    final url = _imageUrlCtrl.text.trim();
    if (url.isEmpty) {
      context.showErrorToast('请先上传封面图');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      context.showErrorToast('请输入标题');
      return;
    }
    if (_summaryCtrl.text.trim().isEmpty) {
      context.showErrorToast('请输入概要');
      return;
    }
    if ((_category ?? '').isEmpty) {
      context.showErrorToast('请选择分类');
      return;
    }
    if ((_channel ?? '').isEmpty) {
      context.showErrorToast('请选择渠道');
      return;
    }
    if (_bodyCtrl.text.trim().isEmpty) {
      context.showErrorToast('请输入正文内容');
      return;
    }
    // 发布到后端
    final selectedMenu = _menus.firstWhere((e)=> e['id']==_labelId, orElse: ()=> const {'label': null});
    final resourceLabel = (selectedMenu['label'] ?? _initialResourceLabel) as String?;
    final editing = _isEditing;
    if (editing && _articleId == null) {
      context.showErrorToast('文章信息未加载完成，请稍后重试');
      return;
    }
    final future = editing
        ? HotService().updateArticle(
            articleId: _articleId!,
            title: _titleCtrl.text.trim(),
            summary: _summaryCtrl.text.trim(),
            coverImage: _imageUrlCtrl.text.trim(),
            content: _bodyCtrl.text.trim(),
            category: _category!,
            channel: _channel,
            resourceType: resourceLabel,
            labelId: _labelId,
          )
        : HotService().publishArticle(
            title: _titleCtrl.text.trim(),
            summary: _summaryCtrl.text.trim(),
            coverImage: _imageUrlCtrl.text.trim(),
            content: _bodyCtrl.text.trim(),
            category: _category!,
            channel: _channel,
            resourceType: resourceLabel,
            labelId: _labelId,
          );
    future
        .then((res) {
      if (res.success) {
        context.showSuccessToast(editing ? '更新成功' : '发布成功');
        if (!editing) {
          try {
            final data = res.data ?? const <String, dynamic>{};
            final articleId = (data['id'] as num?)?.toInt() ?? (data['articleId'] as num?)?.toInt();
            if (articleId != null) {
              context.read<CommunityNotificationProvider>().addPublishNotification(
                articleId: articleId,
                title: _titleCtrl.text.trim(),
                imageUrl: _imageUrlCtrl.text.trim(),
              );
            }
          } catch (_) {}
        }
        Navigator.of(context).pop(true);
      } else {
        context.showErrorToast(res.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑内容' : '发布内容'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(_isEditing ? '保存' : '发布'),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              const _SectionTitle('封面图'),
              if (_isMobileApp)
                _CoverPicker(
                  localPath: _localCoverPath,
                  remoteUrl: _imageUrlCtrl.text.trim(),
                  uploading: _uploadingCover,
                  onPick: _pickCoverImage,
                  onClear: _clearCoverImage,
                )
              else ...[
                _ImageUrlInput(
                  controller: _imageUrlCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _ImagePreview(urlGetter: () => _imageUrlCtrl.text.trim()),
              ],

              const SizedBox(height: 18),
              const _SectionTitle('标题'),
              _BorderlessField(
                controller: _titleCtrl,
                hintText: '请输入标题',
              ),

              const SizedBox(height: 18),
              const _SectionTitle('概要'),
              _BorderlessField(
                controller: _summaryCtrl,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                hintText: '一句话或一小段介绍',
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: 18),
              const _SectionTitle('选择分类'),
              FutureBuilder(
                future: _loadCategoriesOnce(),
                builder: (context, snapshot) {
                  final loading = snapshot.connectionState == ConnectionState.waiting && _categories.isEmpty;
                  return _TagSelector(
                    options: _categories,
                    selected: _category,
                    placeholder: loading ? '正在加载分类...' : '暂无分类',
                    isLoading: loading,
                    onSelect: (v) => setState(() => _category = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              const _SectionTitle('选择渠道'),
              _TagSelector(
                options: channels,
                selected: _channel,
                placeholder: '请选择渠道',
                onSelect: (v) => setState(() => _channel = v),
              ),

              const SizedBox(height: 12),
              const _SectionTitle('资源类型'),
              FutureBuilder(
                future: _loadMenusOnce(),
                builder: (context, snap) {
                  final labels = _menus.map((e) => e['label']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
                  final loading = snap.connectionState == ConnectionState.waiting && labels.isEmpty;
                  final selectedLabel = _menus.firstWhere((e)=>e['id']==_labelId, orElse: ()=> const {'label': null})['label'] as String?;
                  return _TagSelector(
                    options: labels,
                    selected: selectedLabel ?? _initialResourceLabel,
                    placeholder: loading ? '正在加载资源类型...' : '暂无资源类型',
                    isLoading: loading,
                    onSelect: (label) {
                      final m = _menus.firstWhere((e)=> e['label']==label, orElse: ()=> const {'id': null});
                      setState(() {
                        _labelId = (m['id'] as num?)?.toInt();
                        _initialResourceLabel = label;
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 18),
              const _SectionTitle('正文内容'),
              _BorderlessField(
                controller: _bodyCtrl,
                minLines: 6,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                hintText: '请输入正文内容',
              ),

              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.showSuccessToast('已保存为草稿（前端演示）');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF7A00)),
                        foregroundColor: const Color(0xFFFF7A00),
                      ),
                      child: const Text('保存草稿'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A00)),
                      child: Text(_isEditing ? '保存修改' : '发布', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  final String? localPath;
  final String remoteUrl;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _CoverPicker({
    required this.localPath,
    required this.remoteUrl,
    required this.uploading,
    required this.onPick,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLocal = localPath != null && localPath!.isNotEmpty;
    final bool hasRemote = remoteUrl.isNotEmpty;
    Widget preview;
    final bool showClear = (hasLocal || hasRemote) && onClear != null;
    if (hasLocal) {
      preview = Image.file(
        File(localPath!),
        fit: BoxFit.cover,
      );
    } else if (hasRemote) {
      preview = Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('图片加载失败', style: TextStyle(color: AppColors.textLight)),
        ),
      );
    } else {
      preview = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.image_outlined, color: AppColors.textLight, size: 40),
          SizedBox(height: 8),
          Text('点击下方按钮选择本地图片', style: TextStyle(color: AppColors.textLight)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFFF9FAFB), child: preview),
                if (uploading)
                  Container(
                    color: Colors.black.withOpacity(0.25),
                    child: const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 2.6, color: Color(0xFFFF7A00)),
                      ),
                    ),
                  ),
                if (showClear)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: uploading ? null : onClear,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0x99B0B0B0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(hasLocal || hasRemote ? '重新选择图片' : '选择本地图片'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF7A00),
                side: const BorderSide(color: Color(0xFFFFB680)),
              ),
            ),
          ),
        ],
        ),
        const SizedBox(height: 4),
        const Text(
          '目前支持从相册选择图片，上传后将自动生成链接用于发布。',
          style: TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
    );
  }
}

/// 统一的“无边框、无背景”的输入域
class _BorderlessField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator; // 保留参数但不显示错误
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  const _BorderlessField({
    super.key,
    required this.controller,
    this.hintText,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.onChanged,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorStyle: const TextStyle(height: 0, color: Colors.transparent),
        filled: false,
        prefixIcon: prefixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
      // 为兼容 Form 结构，返回 null，避免出现错误提示元素
      validator: (_) => null,
      style: const TextStyle(fontSize: 15),
    );
  }
}

class _TagSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final String placeholder;
  final ValueChanged<String> onSelect;
  final bool isLoading;
  const _TagSelector({
    required this.options,
    required this.selected,
    required this.placeholder,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if ((options.isEmpty) && !isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(placeholder, style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
      );
    }

    if (isLoading && options.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('数据加载中...', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final opt in options)
          _TagChip(
            text: opt,
            selected: opt == selected,
            onTap: () => onSelect(opt),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _TagChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = selected ? const Color(0xFFFFF3E0) : const Color(0xFFF6F7FB);
    final Color border = selected ? const Color(0xFFFFB680) : const Color(0xFFE5E7EB);
    final Color fg = selected ? const Color(0xFFFF7A00) : AppColors.textSecondary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
      ),
    );
  }
}

class _ImageUrlInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _ImageUrlInput({required this.controller, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return _BorderlessField(
      controller: controller,
      hintText: '粘贴网络图片 URL',
      keyboardType: TextInputType.url,
      prefixIcon: const Icon(Icons.link_outlined),
      onChanged: onChanged,
      validator: (_) => null,
    );
  }
}

class _ImagePreview extends StatefulWidget {
  final String Function() urlGetter;
  const _ImagePreview({required this.urlGetter});
  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  @override
  Widget build(BuildContext context) {
    final url = widget.urlGetter();
    final hasUrl = url.isNotEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: hasUrl
          ? ClipRRect(
              key: const ValueKey('preview'),
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF3F4F6),
                    alignment: Alignment.center,
                    child: const Text('图片加载失败', style: TextStyle(color: AppColors.textLight)),
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('placeholder'),
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              alignment: Alignment.center,
              child: const Text('输入图片 URL 后预览', style: TextStyle(color: AppColors.textLight)),
            ),
    );
  }
}
