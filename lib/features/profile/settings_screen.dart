import 'package:linkme_flutter/core/theme/linkme_material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _messageNotification = true;
  bool _soundReminder = true;
  bool _vibrationReminder = false;
  bool _friendVerify = true;
  bool _allowStrangerView = false;
  bool _displayOnlineStatus = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.background,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildSectionTitle('通知与提醒'),
          _buildManualToggle(
            icon: Icons.notifications_outlined,
            title: '消息通知',
            subtitle: '开启后将在有新消息时推送提醒',
            value: _messageNotification,
            onChanged: (value) {
              setState(() => _messageNotification = value);
              context.showInfoToast(value ? '已开启消息通知' : '已关闭消息通知');
            },
          ),
          _buildManualToggle(
            icon: Icons.volume_up_outlined,
            title: '声音提醒',
            subtitle: '在收到消息时播放提示音',
            value: _soundReminder,
            onChanged: (value) {
              setState(() => _soundReminder = value);
              context.showInfoToast(value ? '已开启声音提醒' : '已关闭声音提醒');
            },
          ),
          _buildManualToggle(
            icon: Icons.vibration,
            title: '振动提醒',
            subtitle: '静音模式下仍然通过振动提示',
            value: _vibrationReminder,
            onChanged: (value) {
              setState(() => _vibrationReminder = value);
              context.showInfoToast(value ? '已开启振动提醒' : '已关闭振动提醒');
            },
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('隐私'),
          _buildManualToggle(
            icon: Icons.verified_user_outlined,
            title: '好友验证',
            subtitle: '开启后，添加您为好友需要验证',
            value: _friendVerify,
            onChanged: (value) {
              setState(() => _friendVerify = value);
              context.showInfoToast(value ? '已开启好友验证' : '已关闭好友验证');
            },
          ),
          _buildManualToggle(
            icon: Icons.visibility_outlined,
            title: '允许陌生人查看资料',
            subtitle: '关闭后，仅好友可查看您的头像和签名',
            value: _allowStrangerView,
            onChanged: (value) {
              setState(() => _allowStrangerView = value);
              context.showInfoToast(value ? '已允许陌生人查看资料' : '已禁止陌生人查看资料');
            },
          ),
          _buildManualToggle(
            icon: Icons.circle,
            title: '显示我的在线状态',
            subtitle: '关闭后，好友将无法看到您的在线状态',
            value: _displayOnlineStatus,
            onChanged: (value) {
              setState(() => _displayOnlineStatus = value);
              context.showInfoToast(value ? '已显示在线状态' : '已隐藏在线状态');
            },
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('通用'),
          _buildActionCard(
            icon: Icons.language,
            title: '语言',
            subtitle: '简体中文',
            onTap: () => context.showInfoToast('当前只支持简体中文'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.storage,
            title: '清理缓存',
            subtitle: '释放存储空间',
            onTap: () => _showClearCacheDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: AppTextStyles.body1.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildManualToggle({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _ManualToggleButtons(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: AppColors.shadowLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('清理缓存将删除本地缓存的图片、文件等数据，但不会影响聊天记录。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.showSuccessToast('缓存清理完成，释放了 25.6 MB 空间');
            },
            child: const Text('确定清理'),
          ),
        ],
      ),
    );
  }
}

class _ManualToggleButtons extends StatelessWidget {
  const _ManualToggleButtons({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        color: AppColors.surfaceLight,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: '开启',
            selected: value,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 6),
          _ToggleChip(
            label: '关闭',
            selected: !value,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.textWhite : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
