import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/widgets/unified_toast.dart' as _toast show ToastExtension;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InAppBrowser extends StatefulWidget {
  final String url;
  final String? title;

  const InAppBrowser({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<InAppBrowser> createState() => _InAppBrowserState();
}

class _InAppBrowserState extends State<InAppBrowser> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkFirstTimeUsage();
  }

  Future<void> _checkFirstTimeUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuidance = prefs.getBool('has_seen_browser_guidance') ?? false;

    if (!hasSeenGuidance) {
      // 延迟显示引导，让页面先加载
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _showBrowserGuidance();
        }
      });
    }
  }

  Future<void> _showBrowserGuidance() async {
    if (!mounted) return;

    // 显示覆盖层引导
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildGuidanceOverlay();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildGuidanceOverlay() {
    return Stack(
      children: [
        // 半透明背景
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              Navigator.of(context).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_seen_browser_guidance', true);
            },
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),

        // 引导提示卡片
        Positioned(
          top: kToolbarHeight + MediaQuery.of(context).padding.top + 10,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 指向图标的箭头
                  Container(
                    margin: const EdgeInsets.only(right: 20),
                    child: CustomPaint(
                      size: const Size(20, 15),
                      painter: _ArrowPainter(),
                    ),
                  ),

                  // 提示卡片
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '使用提示',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '点击右上角的 🔗 图标，\n可以在系统浏览器中打开网页',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                  'has_seen_browser_guidance', true);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              '知道了',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            _updateNavigationState();
            _updateTitle();
          },
          onHttpError: (HttpResponseError error) {
            _showErrorSnackBar('HTTP错误: ${error.response?.statusCode}');
          },
          onWebResourceError: (WebResourceError error) {
            _showErrorSnackBar('加载错误: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _updateTitle() async {
    final title = await _controller.getTitle();
    if (title != null && title.isNotEmpty) {
      setState(() {
        _currentTitle = title;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    // 统一顶部提示
    // ignore: use_build_context_synchronously
    context.showErrorToast(message);
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });
    await _controller.reload();
  }

  Future<void> _openInExternalBrowser() async {
    final currentUrl = await _controller.currentUrl();
    if (currentUrl != null) {
      final uri = Uri.parse(currentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 30,
        centerTitle: true,
        title: Text(
          widget.title ?? (_currentTitle.isNotEmpty ? _currentTitle : '网页浏览'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: TextButton(
              onPressed: () async {
                final can = await _controller.canGoBack();
                if (can) {
                  await _controller.goBack();
                } else {
                  if (mounted) Navigator.of(context).maybePop();
                }
              },
              style: ButtonStyle(
                padding: const MaterialStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                minimumSize: const MaterialStatePropertyAll(Size(0, 0)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor:
                    const MaterialStatePropertyAll(Colors.transparent),
                backgroundColor:
                    const MaterialStatePropertyAll(Colors.transparent),
                foregroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.hovered)) {
                    return Colors.pinkAccent.shade100; // 浅粉
                  }
                  return Colors.pink; // 默认粉
                }),
              ),
              child: const Text('返回',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4.0),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 30),
        child: WebViewWidget(controller: _controller),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _canGoBack
                    ? () async {
                        await _controller.goBack();
                        _updateNavigationState();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _canGoForward
                    ? () async {
                        await _controller.goForward();
                        _updateNavigationState();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: () {
                  _controller.loadRequest(Uri.parse(widget.url));
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 自定义箭头绘制器
class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path();

    // 绘制指向上方的箭头
    path.moveTo(size.width / 2, 0); // 箭头顶点
    path.lineTo(0, size.height); // 左下角
    path.lineTo(size.width, size.height); // 右下角
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
