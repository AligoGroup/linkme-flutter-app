import 'dart:async';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_router.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  bool _earScaleIn = false;
  bool _earAtTop = false;
  bool _showFirstTypewriter = false;
  bool _firstTextDone = false;
  bool _showSecondAnimation = false;
  bool _secondScaleIn = false;
  bool _secondAtTop = false;
  bool _showSecondTypewriter = false;
  bool _secondTextDone = false;
  bool _showGoButton = false;
  bool _showFirstStage = true;
  bool _showSecondStage = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() => _earScaleIn = true);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _earAtTop = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _showFirstTypewriter = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildEarAnimation(),
                    if (_showSecondAnimation) _buildAboutAnimation(),
                    _buildTypingArea(),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              AnimatedOpacity(
                opacity: _showGoButton ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: GestureDetector(
                  onTap: _showGoButton ? _goHome : null,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF6DAF),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33FF6DAF),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Go',
                      style: AppTextStyles.body1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarAnimation() {
    return AnimatedOpacity(
      opacity: _showFirstStage ? 1 : 0,
      duration: const Duration(milliseconds: 320),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        alignment: _earAtTop ? const Alignment(-0.05, -0.85) : Alignment.center,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 800),
          scale: _earScaleIn ? 1.0 : 0.65,
          curve: Curves.easeOutBack,
          child: Lottie.asset(
            'assets/animations/ear.json',
            width: 160,
            repeat: true,
          ),
        ),
      ),
    );
  }

  Widget _buildAboutAnimation() {
    return AnimatedOpacity(
      opacity: _showSecondStage ? 1 : 0,
      duration: const Duration(milliseconds: 320),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        alignment: _secondAtTop ? const Alignment(0, -0.25) : Alignment.center,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 700),
          scale: _secondScaleIn ? 1.0 : 0.7,
          curve: Curves.easeOutBack,
          child: Lottie.asset(
            'assets/animations/about-us.json',
            width: 140,
            repeat: true,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: _showFirstStage ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: _showFirstTypewriter
              ? TypewriterText(
                  lines: const [
                    'LinkMe 连接每一次真诚的情绪',
                    '在这里遇见同频的灵魂伙伴',
                    '一起探索生活的更多可能',
                  ],
                  onCompleted: _handleFirstTextDone,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        AnimatedOpacity(
          opacity: _showSecondStage ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: _showSecondTypewriter
              ? TypewriterText(
                  lines: const [
                    '期待与你在 LinkMe 的相遇！',
                    '你准备好了嘛？',
                  ],
                  onCompleted: _handleSecondTextDone,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _handleFirstTextDone() {
    if (_firstTextDone) return;
    _firstTextDone = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showFirstStage = false);
      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        setState(() {
          _showSecondAnimation = true;
          _secondScaleIn = true;
          _showSecondStage = true;
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() => _secondAtTop = true);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            setState(() => _showSecondTypewriter = true);
          });
        });
      });
    });
  }

  void _handleSecondTextDone() {
    if (_secondTextDone) return;
    _secondTextDone = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _showGoButton = true);
    });
  }

  void _goHome() {
    context.go(AppRouter.main, extra: const {'entry': 'onboarding'});
  }
}

class TypewriterText extends StatefulWidget {
  final List<String> lines;
  final Duration charDelay;
  final VoidCallback? onCompleted;

  const TypewriterText({
    super.key,
    required this.lines,
    this.charDelay = const Duration(milliseconds: 60),
    this.onCompleted,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  late final List<String> _lines;
  late final List<String> _rendered;
  int _lineIndex = 0;
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lines = widget.lines;
    _rendered = List.filled(_lines.length, '');
    _timer = Timer.periodic(widget.charDelay, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (_lineIndex >= _lines.length) {
        _timer?.cancel();
        widget.onCompleted?.call();
        return;
      }
      final currentLine = _lines[_lineIndex];
      if (_charIndex < currentLine.length) {
        _charIndex += 1;
        _rendered[_lineIndex] = currentLine.substring(0, _charIndex);
      } else {
        _lineIndex += 1;
        _charIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.body1.copyWith(
      fontSize: 18,
      height: 1.5,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i <= _lineIndex && i < _rendered.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: style,
                children: [
                  TextSpan(text: _rendered[i]),
                  if (i == _lineIndex && _lineIndex < _lines.length)
                    const TextSpan(
                      text: '▉',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
