import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'custom_video_controls.dart';

/// 自定义视频播放器组件
/// 支持全屏播放、自定义控制栏样式
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final double aspectRatio;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = true,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // 初始化视频播放器
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoPlayerController.initialize();

      if (widget.autoPlay) {
        _videoPlayerController.play();
      }

      if (widget.looping) {
        _videoPlayerController.setLooping(true);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ [VideoPlayer] 初始化失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  '视频加载失败',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 缩略图占位符
              if (widget.thumbnailUrl != null)
                Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.black,
                  ),
                ),
              // 加载指示器
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4081)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 使用视频的真实宽高比，而不是固定的aspectRatio
    final videoAspectRatio = _videoPlayerController.value.aspectRatio;

    return AspectRatio(
      aspectRatio: videoAspectRatio > 0 ? videoAspectRatio : widget.aspectRatio,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // 视频播放器
            Center(
              child: AspectRatio(
                aspectRatio: videoAspectRatio > 0
                    ? videoAspectRatio
                    : widget.aspectRatio,
                child: VideoPlayer(_videoPlayerController),
              ),
            ),
            // 自定义控制栏
            if (widget.showControls)
              CustomVideoControls(controller: _videoPlayerController),
          ],
        ),
      ),
    );
  }
}

/// 全屏视频播放器页面
class FullScreenVideoPlayer extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 视频播放器（自动适应宽高比）
            Center(
              child: VideoPlayerWidget(
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                autoPlay: true,
                showControls: true,
                aspectRatio: 16 / 9, // 初始值，会被视频真实宽高比覆盖
              ),
            ),
            // 关闭按钮
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
