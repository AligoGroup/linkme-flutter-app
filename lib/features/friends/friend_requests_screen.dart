import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/user.dart';
import '../../widgets/common/empty_state.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriendRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadFriendRequests() async {
    final chat = context.read<ChatProvider>();
    final me = context.read<AuthProvider>().user;
    if (me == null) { setState(() => _isLoading = false); return; }
    try {
      setState(() => _isLoading = true);
      final received = await chat.getAllReceivedRequests(me.id);
      final sent = await chat.getAllSentRequests(me.id);
      if (!mounted) return;
      setState(() {
        _receivedRequests = received.map((e) => _fromReceivedJson(e)).toList();
        _sentRequests = sent.map((e) => _fromSentJson(e)).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友请求'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('收到的'),
                  if (_getUnreadReceivedCount() > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getUnreadReceivedCount().toString(),
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: '发出的'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReceivedRequestsTab(),
                _buildSentRequestsTab(),
              ],
            ),
    );
  }

  Widget _buildReceivedRequestsTab() {
    final pendingRequests = _receivedRequests
        .where((req) => req.status == FriendRequestStatus.pending)
        .toList();
    final processedRequests = _receivedRequests
        .where((req) => req.status != FriendRequestStatus.pending)
        .toList();

    if (_receivedRequests.isEmpty) {
      return const EmptyState(
        icon: Icons.person_add_alt,
        title: '暂无好友请求',
        subtitle: '还没有人向您发送好友请求',
      );
    }

    return ListView(
      children: [
        if (pendingRequests.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              '待处理 (${pendingRequests.length})',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...pendingRequests.map((request) => _buildReceivedRequestItem(request, true)),
        ],

        if (processedRequests.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              '已处理',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...processedRequests.map((request) => _buildReceivedRequestItem(request, false)),
        ],
      ],
    );
  }

  Widget _buildSentRequestsTab() {
    if (_sentRequests.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search,
        title: '暂无发出的请求',
        subtitle: '您还没有向其他人发送好友请求',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sentRequests.length,
      separatorBuilder: (context, index) => const Divider(
        height: 32,
        color: AppColors.borderLight,
      ),
      itemBuilder: (context, index) {
        final request = _sentRequests[index];
        return _buildSentRequestItem(request);
      },
    );
  }

  Widget _buildReceivedRequestItem(FriendRequest request, bool isPending) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                backgroundImage: request.user.avatar != null ? NetworkImage(request.user.avatar!) : null,
                child: request.user.avatar == null
                    ? Text(
                        (request.user.nickname?.isNotEmpty ?? false) ? request.user.nickname![0] : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.user.nickname ?? request.user.username,
                      style: AppTextStyles.friendName,
                    ),
                    if (request.user.signature != null && request.user.signature!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        request.user.signature!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              Text(
                _formatTime(request.requestTime),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.message,
                style: AppTextStyles.body2,
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(request),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.textLight),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textWhite,
                    ),
                    child: const Text('接受'),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(request.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getStatusText(request.status),
                style: AppTextStyles.caption.copyWith(
                  color: _getStatusColor(request.status),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSentRequestItem(FriendRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                backgroundImage: request.user.avatar != null ? NetworkImage(request.user.avatar!) : null,
                child: request.user.avatar == null
                    ? Text(
                        (request.user.nickname?.isNotEmpty ?? false) ? request.user.nickname![0] : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.user.nickname ?? request.user.username,
                      style: AppTextStyles.friendName,
                    ),
                    if (request.user.signature != null && request.user.signature!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        request.user.signature!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getStatusText(request.status),
                  style: AppTextStyles.caption.copyWith(
                    color: _getStatusColor(request.status),
                  ),
                ),
              ),
            ],
          ),
          
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.message,
                style: AppTextStyles.body2,
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          Text(
            '发送时间: ${_formatTime(request.requestTime)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  void _acceptRequest(FriendRequest request) {
    final chat = context.read<ChatProvider>();
    chat.acceptFriendRequest(int.parse(request.id)).then((ok) {
      if (ok) {
        setState(() {
          final index = _receivedRequests.indexWhere((r) => r.id == request.id);
          if (index != -1) {
            _receivedRequests[index] = request.copyWith(status: FriendRequestStatus.accepted);
          }
        });
        context.showSuccessToast('已接受 ${request.user.nickname ?? request.user.username} 的好友请求');
      } else {
        context.showErrorToast('操作失败');
      }
    });
  }

  void _rejectRequest(FriendRequest request) {
    final chat = context.read<ChatProvider>();
    chat.rejectFriendRequest(int.parse(request.id)).then((ok) {
      if (ok) {
        setState(() {
          final index = _receivedRequests.indexWhere((r) => r.id == request.id);
          if (index != -1) {
            _receivedRequests[index] = request.copyWith(status: FriendRequestStatus.rejected);
          }
        });
        context.showWarningToast('已拒绝 ${request.user.nickname ?? request.user.username} 的好友请求');
      } else {
        context.showErrorToast('操作失败');
      }
    });
  }

  int _getUnreadReceivedCount() {
    return _receivedRequests
        .where((req) => req.status == FriendRequestStatus.pending)
        .length;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }

  String _getStatusText(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return '等待回复';
      case FriendRequestStatus.accepted:
        return '已接受';
      case FriendRequestStatus.rejected:
        return '已拒绝';
    }
  }

  Color _getStatusColor(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return AppColors.warning;
      case FriendRequestStatus.accepted:
        return AppColors.success;
      case FriendRequestStatus.rejected:
        return AppColors.error;
    }
  }
}

FriendRequest _fromReceivedJson(Map<String, dynamic> json) {
  final sender = json['sender'] as Map<String, dynamic>;
  return FriendRequest(
    id: json['id'].toString(),
    user: User(
      id: (sender['id'] as num).toInt(),
      username: sender['username']?.toString() ?? '',
      email: sender['email']?.toString() ?? '',
      nickname: sender['nickname']?.toString(),
      avatar: sender['avatar']?.toString(),
      status: UserStatus.online,
    ),
    message: '',
    requestTime: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    status: _mapStatus(json['status']?.toString()),
  );
}

FriendRequest _fromSentJson(Map<String, dynamic> json) {
  final target = json['target'] as Map<String, dynamic>;
  return FriendRequest(
    id: json['id'].toString(),
    user: User(
      id: (target['id'] as num).toInt(),
      username: target['username']?.toString() ?? '',
      email: target['email']?.toString() ?? '',
      nickname: target['nickname']?.toString(),
      avatar: target['avatar']?.toString(),
      status: UserStatus.online,
    ),
    message: '',
    requestTime: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    status: _mapStatus(json['status']?.toString()),
  );
}

FriendRequestStatus _mapStatus(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'ACCEPTED': return FriendRequestStatus.accepted;
    case 'REJECTED': return FriendRequestStatus.rejected;
    default: return FriendRequestStatus.pending;
  }
}

class FriendRequest {
  final String id;
  final User user;
  final String message;
  final DateTime requestTime;
  final FriendRequestStatus status;

  FriendRequest({
    required this.id,
    required this.user,
    required this.message,
    required this.requestTime,
    required this.status,
  });

  FriendRequest copyWith({
    String? id,
    User? user,
    String? message,
    DateTime? requestTime,
    FriendRequestStatus? status,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      user: user ?? this.user,
      message: message ?? this.message,
      requestTime: requestTime ?? this.requestTime,
      status: status ?? this.status,
    );
  }
}

enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}
