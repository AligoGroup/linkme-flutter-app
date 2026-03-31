import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'video_player_widget.dart';

/// 视频预览组件 - 用于帖子列表和详情页
/// 显示缩略图+播放按钮，点击后打开全屏播放器
class VideoPreviewWidget extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  const VideoPreviewWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.aspectRatio = 16 / 9,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 打开全屏视频播放器
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenVideoPlayer(
              videoUrl: videoUrl,
              thumbnailUrl: thumbnailUrl,
            ),
          ),
        );
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 视频缩略图或黑色背景
            if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: borderRadius ?? BorderRadius.circular(8),
                child: Image.network(
                  thumbnailUrl!,
                  width: width ?? double.infinity,
                  height: height ?? double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.black,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: borderRadius ?? BorderRadius.circular(8),
                ),
              ),
            // 播放图标（使用SVG，无外圈）
            SvgPicture.asset(
              'assets/app_icons/svg/play.svg',
              width: 64,
              height: 64,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
