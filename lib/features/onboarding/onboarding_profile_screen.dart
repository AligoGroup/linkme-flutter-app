import 'dart:io';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_router.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/image_upload_service.dart';
import '../../widgets/common/loading_button.dart';

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nicknameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploadService = ImageUploadService();
  late final AnimationController _loadingController;
  File? _localAvatar;
  String? _avatarUrl;
  bool _showForm = false;
  bool _isUploading = false;
  int _playCount = 0;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this);
    _loadingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playCount += 1;
        if (_playCount < 2) {
          _loadingController.forward(from: 0);
        } else {
          setState(() => _showForm = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _showForm ? _buildForm(context) : _buildLoading(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Lottie.asset(
        'assets/animations/Loading (2).json',
        controller: _loadingController,
        onLoaded: (composition) {
          _loadingController
            ..duration = composition.duration
            ..forward();
        },
        repeat: false,
        width: 220,
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 120 : 24,
        vertical: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            '快来展示你的个性风格趴！✨',
            textAlign: TextAlign.center,
            style: AppTextStyles.h6.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          Center(child: _buildAvatarSelector()),
          const SizedBox(height: 28),
          TextField(
            controller: _nicknameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '填写昵称',
              filled: true,
              fillColor: const Color(0xFFF8F9FB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const Spacer(),
          Consumer<AuthProvider>(
            builder: (context, auth, _) => LoadingButton(
              onPressed: auth.isLoading ? null : () => _handleNext(auth),
              isLoading: auth.isLoading,
              height: 46,
              child: const Text(
                '下一步',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSelector() {
    final double size = 140;
    return GestureDetector(
      onTap: _isUploading ? null : _pickAvatar,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF3F4F6),
              image: _localAvatar != null || _avatarUrl != null
                  ? DecorationImage(
                      image: _localAvatar != null
                          ? FileImage(_localAvatar!)
                          : NetworkImage(_avatarUrl!) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: (_localAvatar == null && _avatarUrl == null)
                ? Icon(Icons.person_outline,
                    size: 60, color: AppColors.textSecondary)
                : null,
          ),
          if (_localAvatar == null && _avatarUrl == null)
            Positioned(
              bottom: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '点击设置头像',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isUploading)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (file == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
          ),
          IOSUiSettings(title: '裁剪头像'),
        ],
      );

      final File target =
          cropped != null ? File(cropped.path) : File(file.path);

      setState(() {
        _isUploading = true;
      });
      final url = await _uploadService.uploadAvatar(target);
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        if (url != null) {
          _avatarUrl = url;
          _localAvatar = target;
        } else {
          context.showErrorToast('头像上传失败，请重试');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      context.showErrorToast('头像选择失败: $e');
    }
  }

  Future<void> _handleNext(AuthProvider auth) async {
    final nickname = _nicknameController.text.trim();
    if (_avatarUrl == null) {
      context.showErrorToast('请先设置头像');
      return;
    }
    if (nickname.length < 2) {
      context.showErrorToast('昵称至少需要2个字符');
      return;
    }
    final ok = await auth.completeProfileStep(
      nickname: nickname,
      avatar: _avatarUrl!,
    );
    if (!mounted) return;
    if (!ok) {
      context.showErrorToast(auth.errorMessage ?? '提交失败，请稍后再试');
      return;
    }
    context.go(AppRouter.onboardingPassword);
  }
}
