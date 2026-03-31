import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:typed_data';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../../core/widgets/unified_toast.dart';

/// 图片查看器
class ImageViewer extends StatelessWidget {
  final String imageUrl;
  final bool isLocalFile;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.isLocalFile = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return GestureDetector(
      // 支持单击和下滑关闭
      onTap: () => Navigator.of(context).pop(),
      onVerticalDragEnd: (details) {
        // 向下滑动关闭
        if (details.primaryVelocity! > 300) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 图片查看器 - 垂直居中，高度90%
            Center(
              child: SizedBox(
                height: screenHeight * 0.9,
                child: PhotoView(
                  imageProvider: isLocalFile
                      ? FileImage(File(imageUrl))
                      : NetworkImage(imageUrl) as ImageProvider,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  loadingBuilder: (context, event) => Center(
                    child: CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                      color: Colors.white,
                    ),
                  ),
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  // 禁用手势，让外层的 GestureDetector 处理
                  gestureDetectorBehavior: HitTestBehavior.translucent,
                ),
              ),
            ),

          // 顶部工具栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (!isLocalFile)
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () => _saveImage(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  /// 保存图片到相册
  Future<void> _saveImage(BuildContext context) async {
    try {
      HapticFeedback.mediumImpact();
      context.showLoadingToast('正在保存图片...');

      // 下载图片
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final result = await SaverGallery.saveImage(
          Uint8List.fromList(response.bodyBytes),
          quality: 100,
          fileName: 'linkme_${DateTime.now().millisecondsSinceEpoch}.jpg',
          androidRelativePath: 'Pictures/LinkMe',
          skipIfExists: false,
        );

        if (result.isSuccess) {
          if (context.mounted) {
            context.showSuccessToast('图片已保存到相册');
          }
        } else {
          if (context.mounted) {
            context.showErrorToast('保存失败');
          }
        }
      } else {
        if (context.mounted) {
          context.showErrorToast('下载图片失败');
        }
      }
    } catch (e) {
      print('保存图片失败: $e');
      if (context.mounted) {
        context.showErrorToast('保存图片失败');
      }
    }
  }
}
