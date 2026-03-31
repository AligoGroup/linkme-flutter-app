import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AboutLinkMeScreen extends StatelessWidget {
  const AboutLinkMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于LinkMe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: SizedBox(
                  height: 128,
                  width: 128,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/icons/app_icons.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.hub_outlined,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              _buildParagraph(
                'LinkMe代表“请连接我”，象征着我们对建立真诚沟通和温暖链接的渴望。',
              ),
              const SizedBox(height: 16),
              _buildParagraph(
                'LinkMe代表“我需要被Link”，提醒我们在数字世界中也需要彼此的陪伴与回应。',
              ),
              const SizedBox(height: 16),
              _buildParagraph(
                'LinkMe代表“连接世界里的你我”，让每一次对话都成为连接世界的起点。',
              ),
              const SizedBox(height: 32),
              Text(
                '版本号 v 1.0.1',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: AppTextStyles.body1.copyWith(height: 1.5),
      textAlign: TextAlign.center,
    );
  }
}
