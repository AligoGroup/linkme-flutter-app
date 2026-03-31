import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum NetworkIssueType {
  noNetwork,
  serverError,
}

class NetworkIssuePage extends StatelessWidget {
  final NetworkIssueType type;

  const NetworkIssuePage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final title = type == NetworkIssueType.noNetwork ? '无法连接网络' : '服务器异常';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            title: '可能的原因',
            items: type == NetworkIssueType.noNetwork 
                ? [
                    '您的设备未连接到互联网（数据流量或Wi-Fi已关闭）。',
                    '您的设备处于飞行模式。',
                    '您所在的区域网络信号覆盖较弱。',
                    'LinkMe应用的网络权限被系统禁用。',
                  ]
                : [
                    'LinkMe服务器正在进行临时维护或升级。',
                    '服务器负载过高，暂时无法处理您的请求。',
                    '中间网络节点（如DNS、CDN）出现故障。',
                    '本地数据与服务器同步时发生冲突。',
                  ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '建议解决方案',
            items: type == NetworkIssueType.noNetwork 
                ? [
                    '检查您的手机是否已开启移动数据或Wi-Fi。',
                    '尝试关闭再重新开启飞行模式，重置网络连接。',
                    '尝试切换Wi-Fi或移动数据网络。',
                    '前往系统设置 -> 应用管理 -> LinkMe -> 权限，确保“网络/无线数据”权限已开启。',
                    '如果以上均无效，请尝试重启您的设备。',
                  ]
                : [
                    '请稍后（几分钟后）再尝试刷新页面。',
                    '检查您的网络连接虽然正常，但可能会受到防火墙或VPN的影响，可以尝试切换网络环境。',
                    '尝试强制关闭LinkMe应用并重新启动。',
                    '如果问题持续较长时间，请联系客服反馈。',
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<String> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50], // Very light grey bg
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
