import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';
import 'linkme_loader.dart';
import '../../core/constants/app_constants.dart';

class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final ButtonStyle? style;
  final double? width;
  final double height;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.style,
    this.width,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style ?? ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: AppConstants.fastDuration,
          child: isLoading
              ? const SizedBox(
                  width: 26,
                  height: 18,
                  child: Center(child: LinkMeLoader(fontSize: 12, compact: true)),
                )
              : child,
        ),
      ),
    );
  }
}
