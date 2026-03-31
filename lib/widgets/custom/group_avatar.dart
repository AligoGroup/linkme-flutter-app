import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';
import 'user_avatar.dart';

class GroupAvatar extends StatelessWidget {
  final List<String> memberAvatars;
  final String groupName;
  final double size;
  final String? groupAvatar; // 可选的群头像URL

  const GroupAvatar({
    super.key,
    required this.memberAvatars,
    required this.groupName,
    required this.size,
    this.groupAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // 如果有群头像且不是后端的占位配置，则直接使用
    if (groupAvatar != null &&
        groupAvatar!.isNotEmpty &&
        !groupAvatar!.startsWith('GROUP_AVATAR:')) {
      return UserAvatar(
        imageUrl: groupAvatar,
        name: groupName,
        size: size,
      );
    }

    // 使用成员头像拼接
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: _buildGroupAvatarContent(),
      ),
    );
  }

  Widget _buildGroupAvatarContent() {
    if (memberAvatars.isEmpty) {
      // 如果没有成员头像，显示群名称首字符
      return Container(
        color: _generateColorFromName(groupName),
        child: Center(
          child: Text(
            groupName.isNotEmpty ? groupName.substring(0, 1).toUpperCase() : '群',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final displayAvatars = memberAvatars.take(4).toList();
    
    if (displayAvatars.length == 1) {
      // 单个头像
      return UserAvatar(
        imageUrl: displayAvatars[0],
        name: groupName,
        size: size,
      );
    } else if (displayAvatars.length == 2) {
      // 两个头像左右布局
      return Row(
        children: [
          Expanded(
            child: UserAvatar(
              imageUrl: displayAvatars[0],
              name: groupName,
              size: size,
            ),
          ),
          Expanded(
            child: UserAvatar(
              imageUrl: displayAvatars[1],
              name: groupName,
              size: size,
            ),
          ),
        ],
      );
    } else if (displayAvatars.length == 3) {
      // 三个头像：左边一个，右边上下两个
      return Row(
        children: [
          Expanded(
            child: UserAvatar(
              imageUrl: displayAvatars[0],
              name: groupName,
              size: size,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: UserAvatar(
                    imageUrl: displayAvatars[1],
                    name: groupName,
                    size: size / 2,
                  ),
                ),
                Expanded(
                  child: UserAvatar(
                    imageUrl: displayAvatars[2],
                    name: groupName,
                    size: size / 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // 四个头像：2x2网格
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: UserAvatar(
                    imageUrl: displayAvatars[0],
                    name: groupName,
                    size: size / 2,
                  ),
                ),
                Expanded(
                  child: UserAvatar(
                    imageUrl: displayAvatars[1],
                    name: groupName,
                    size: size / 2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: UserAvatar(
                    imageUrl: displayAvatars[2],
                    name: groupName,
                    size: size / 2,
                  ),
                ),
                Expanded(
                  child: UserAvatar(
                    imageUrl: displayAvatars[3],
                    name: groupName,
                    size: size / 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Color _generateColorFromName(String name) {
    // 根据群名称生成颜色
    final colors = [
      AppColors.primary,
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF00BCD4),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFF8BC34A),
      const Color(0xFFCDDC39),
      const Color(0xFFFFEB3B),
      const Color(0xFFFFC107),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
      const Color(0xFF795548),
      const Color(0xFF607D8B),
    ];
    
    int hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }
}
