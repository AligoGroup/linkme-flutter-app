import 'dart:math' as math;

import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

/// 统一的下拉刷新组件：使用 loading.json 作为动画，保持原有交互体验。
class LottieRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final ScrollNotificationPredicate? notificationPredicate;
  final double triggerOffset;
  final double maxPulldownExtent;
  final String lottieAsset;
  final String? semanticsLabel;
  final String? semanticsValue;

  const LottieRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.notificationPredicate,
    this.triggerOffset = 80,
    this.maxPulldownExtent = 140,
    this.lottieAsset = 'assets/animations/Loading.json',
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  State<LottieRefreshIndicator> createState() => _LottieRefreshIndicatorState();
}

class _LottieRefreshIndicatorState extends State<LottieRefreshIndicator>
    with SingleTickerProviderStateMixin {
  double _pullExtent = 0;
  bool _refreshing = false;
  AnimationController? _reboundController;

  ScrollNotificationPredicate get _predicate =>
      widget.notificationPredicate ?? defaultScrollNotificationPredicate;

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    final holdExtent = _pullExtent;
    setState(() {
      _refreshing = true;
      _pullExtent = holdExtent;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      _animateTo(0, onCompleted: () {
        if (!mounted) return;
        setState(() {
          _refreshing = false;
        });
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_predicate(notification)) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _stopRebound();
    }

    if (_reboundController != null) {
      return false;
    }

    final metrics = notification.metrics;
    final atTop = metrics.pixels <= metrics.minScrollExtent + 0.5;
    if (!atTop) {
      if (_pullExtent != 0) {
        _animateTo(0);
      }
      return false;
    }

    if (notification is OverscrollNotification && notification.overscroll < 0) {
      _stopRebound();
      _updateExtent(_pullExtent - notification.overscroll);
    } else if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta < 0 && metrics.pixels <= metrics.minScrollExtent) {
        _stopRebound();
        _updateExtent(_pullExtent - delta);
      } else if (delta > 0 && _pullExtent > 0) {
        _updateExtent(math.max(0, _pullExtent - delta));
      }
    } else if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      final bool shouldTrigger =
          !_refreshing && _pullExtent >= widget.triggerOffset - 0.5;
      if (shouldTrigger) {
        _handleRefresh();
      } else if (!_refreshing && _pullExtent > 0) {
        _animateTo(0);
      }
    }
    return false;
  }

  void _updateExtent(double value) {
    final clamped = value.clamp(0.0, widget.maxPulldownExtent.toDouble());
    if ((_pullExtent - clamped).abs() < 0.01) return;
    setState(() => _pullExtent = clamped);
  }

  void _stopRebound() {
    if (_reboundController != null) {
      _reboundController!.stop();
      _reboundController!.dispose();
      _reboundController = null;
    }
  }

  void _animateTo(double target, {VoidCallback? onCompleted}) {
    _stopRebound();
    if ((_pullExtent - target).abs() < 0.5) {
      setState(() => _pullExtent = target);
      onCompleted?.call();
      return;
    }
    final controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    final animation = Tween<double>(begin: _pullExtent, end: target).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
    animation.addListener(() {
      if (mounted) setState(() => _pullExtent = animation.value);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
        if (identical(_reboundController, controller)) {
          _reboundController = null;
        }
        if (status == AnimationStatus.completed) {
          onCompleted?.call();
        }
      }
    });
    _reboundController = controller;
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: widget.child,
        ),
        _buildLottieOverlay(),
      ],
    );
  }

  @override
  void dispose() {
    _reboundController?.dispose();
    super.dispose();
  }

  Widget _buildLottieOverlay() {
    final show = _refreshing || _pullExtent > 4;
    final progress = (_pullExtent / widget.triggerOffset).clamp(0.0, 1.0);
    final topPadding = 10.0 + math.min(50.0, _pullExtent * 0.5);
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 130),
        opacity: show ? 1 : 0,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: SizedBox(
              height: 96,
              width: 96,
              child: Lottie.asset(
                widget.lottieAsset,
                repeat: true,
                animate: true,
                frameRate: FrameRate.max,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
