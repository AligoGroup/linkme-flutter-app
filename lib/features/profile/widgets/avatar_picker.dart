import 'dart:io';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/unified_toast.dart';
import '../../../shared/services/image_upload_service.dart';
import '../../../widgets/custom/user_avatar.dart';

class AvatarPicker extends StatefulWidget {
  final String? currentAvatarUrl;
  final String userName;
  final Function(String avatarUrl) onAvatarUploaded;

  const AvatarPicker({
    super.key,
    this.currentAvatarUrl,
    required this.userName,
    required this.onAvatarUploaded,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploadService = ImageUploadService();
  bool _isUploading = false;
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头像预览
        GestureDetector(
          onTap: _isUploading ? null : _showImageSourceDialog,
          child: Stack(
            children: [
              // 显示当前头像或选中的图片
              _selectedImage != null
                  ? ClipOval(
                      child: Image.file(
                        _selectedImage!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                  : UserAvatar(
                      imageUrl: widget.currentAvatarUrl,
                      name: widget.userName,
                      size: 100,
                    ),
              
              // 编辑图标
              if (!_isUploading)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
              
              // 上传中的加载指示器
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 提示文字
        Text(
          _isUploading ? '上传中...' : '点击更换头像',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // 显示图片来源选择对话框
  void _showImageSourceDialog() {
    // Web 端不支持图片选择和裁剪
    if (kIsWeb) {
      context.showErrorToast('Web端暂不支持头像上传');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (widget.currentAvatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('移除头像', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      // 裁剪图片
      final croppedFile = await _cropImage(image.path);
      if (croppedFile == null) return;

      setState(() {
        _selectedImage = File(croppedFile.path);
      });

      // 自动上传
      await _uploadImage();
    } catch (e) {
      if (mounted) {
        context.showErrorToast('选择图片失败: $e');
      }
    }
  }

  // 裁剪图片
  Future<CroppedFile?> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: AppColors.textWhite,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      return croppedFile;
    } catch (e) {
      if (mounted) {
        context.showErrorToast('裁剪图片失败: $e');
      }
      return null;
    }
  }

  // 上传图片
  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final avatarUrl = await _uploadService.uploadAvatar(_selectedImage!);

      if (avatarUrl != null) {
        widget.onAvatarUploaded(avatarUrl);
        if (mounted) {
          context.showSuccessToast('头像上传成功');
        }
      } else {
        if (mounted) {
          context.showErrorToast('头像上传失败，请重试');
        }
        setState(() {
          _selectedImage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('上传失败: $e');
      }
      setState(() {
        _selectedImage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // 移除头像
  void _removeAvatar() {
    widget.onAvatarUploaded('');
    setState(() {
      _selectedImage = null;
    });
    context.showSuccessToast('头像已移除');
  }
}
