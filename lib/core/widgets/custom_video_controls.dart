import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

/// 自定义视频控制栏
/// 使用SVG图标，包括播放、暂停、重播
class CustomVideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onPlayPause;

  const CustomVideoControls({
    super.key,
    required this.controller,
    this.onPlayPause,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    widget.onPlayPause?.call();
  }

  void _replay() {
    widget.controller.seekTo(Duration.zero);
    widget.controller.play();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.controller.value.isPlaying;
    final isEnded =
        widget.controller.value.position >= widget.controller.value.duration;
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 中央重播按钮（仅在视频结束时显示）
            if (isEnded)
              Center(
                child: GestureDetector(
                  onTap: _replay,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/app_icons/svg/play.svg', // 重播图标
                        width: 40,
                        height: 40,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // 底部控制栏
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 播放/暂停按钮 + 进度条
                      Row(
                        children: [
                          // 播放/暂停按钮
                          GestureDetector(
                            onTap: isEnded ? _replay : _togglePlayPause,
                            child: SvgPicture.asset(
                              isEnded
                                  ? 'assets/app_icons/svg/play.svg'
                                  : (isPlaying
                                      ? 'assets/app_icons/svg/pause.svg'
                                      : 'assets/app_icons/svg/play.svg'),
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 进度条
                          Expanded(
                            child: VideoProgressIndicator(
                              widget.controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Color(0xFFFF4081),
                                bufferedColor: Colors.grey,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 时间显示
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
