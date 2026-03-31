import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/user.dart';
import '../../../shared/providers/chat_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../widgets/common/empty_state.dart';
import '../../../core/widgets/unified_toast.dart';

class FriendRequestsView extends StatefulWidget {
  const FriendRequestsView({super.key});

  @override
  State<FriendRequestsView> createState() => _FriendRequestsViewState();
}

class _FriendRequestsViewState extends State<FriendRequestsView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<_FR> _received = [];
  List<_FR> _sent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final chat = context.read<ChatProvider>();
    final me = context.read<AuthProvider>().user;
    if (me == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final received = await chat.getAllReceivedRequests(me.id);
      final sent = await chat.getAllSentRequests(me.id);
      if (!mounted) return;
      setState(() {
        _received = received.map(_fromReceived).toList();
        _sent = sent.map(_fromSent).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(message: '加载中...');
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: _tab,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: '收到的'), Tab(text: '我发出的')],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildReceived(),
              _buildSent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceived() {
    if (_received.isEmpty)
      return const EmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: '暂无收到的申请',
          subtitle: '别人向你发起的好友申请会显示在这里');
    return ListView.builder(
      itemCount: _received.length,
      itemBuilder: (_, i) => _receivedTile(_received[i]),
    );
  }

  Widget _buildSent() {
    if (_sent.isEmpty)
      return const EmptyState(
          icon: Icons.send_outlined,
          title: '暂无发出的申请',
          subtitle: '你向别人发起的好友申请会显示在这里');
    return ListView.builder(
      itemCount: _sent.length,
      itemBuilder: (_, i) => _sentTile(_sent[i]),
    );
  }

  Widget _receivedTile(_FR r) {
    final isPending = r.status == _FRStatus.pending;
    return ListTile(
      leading: CircleAvatar(
          backgroundImage: r.avatar != null ? NetworkImage(r.avatar!) : null,
          child: r.avatar == null
              ? Text(r.name.isNotEmpty ? r.name[0] : 'U')
              : null),
      title: Text(r.name, style: AppTextStyles.friendName),
      subtitle: Text(_fmt(r.time),
          style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
      trailing: isPending
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () => _reject(r), child: const Text('拒绝')),
              const SizedBox(width: 6),
              ElevatedButton(
                  onPressed: () => _accept(r), child: const Text('同意')),
            ])
          : _statusChip(r.status),
    );
  }

  Widget _sentTile(_FR r) {
    return ListTile(
      leading: CircleAvatar(
          backgroundImage: r.avatar != null ? NetworkImage(r.avatar!) : null,
          child: r.avatar == null
              ? Text(r.name.isNotEmpty ? r.name[0] : 'U')
              : null),
      title: Text(r.name, style: AppTextStyles.friendName),
      subtitle: Text(_fmt(r.time),
          style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
      trailing: _statusChip(r.status),
    );
  }

  Widget _statusChip(_FRStatus s) {
    final text = s == _FRStatus.pending
        ? '等待回复'
        : s == _FRStatus.accepted
            ? '已接受'
            : '已拒绝';
    final color = s == _FRStatus.pending
        ? AppColors.warning
        : s == _FRStatus.accepted
            ? AppColors.success
            : AppColors.error;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(14)),
        child: Text(text,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)));
  }

  void _accept(_FR r) {
    final chat = context.read<ChatProvider>();
    chat.acceptFriendRequest(r.id).then((ok) {
      if (ok) {
        setState(() => r.status = _FRStatus.accepted);
        final displayName = r.name.trim();
        final snapshot = User(
          id: r.userId,
          username: displayName.isNotEmpty ? displayName : 'user${r.userId}',
          email: 'user${r.userId}@placeholder.local',
          nickname: displayName.isNotEmpty ? displayName : null,
          avatar: r.avatar,
          status: UserStatus.offline,
        );
        chat.ensureConversationForFriend(r.userId, friendData: snapshot);
        context.showSuccessToast('已接受 ${r.name} 的好友请求');
      }
    });
  }

  void _reject(_FR r) {
    final chat = context.read<ChatProvider>();
    chat.rejectFriendRequest(r.id).then((ok) {
      if (ok) {
        setState(() => r.status = _FRStatus.rejected);
        context.showWarningToast('已拒绝 ${r.name} 的好友请求');
      }
    });
  }

  String _fmt(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inHours < 1) return '${d.inMinutes}分钟前';
    if (d.inDays < 1) return '${d.inHours}小时前';
    if (d.inDays < 7) return '${d.inDays}天前';
    return '${t.month}月${t.day}日';
  }

  _FR _fromReceived(Map<String, dynamic> j) {
    final s = j['sender'] as Map<String, dynamic>;
    return _FR(
        id: (j['id'] as num).toInt(),
        userId: (s['id'] as num).toInt(),
        name: (s['nickname'] ?? s['username'] ?? '').toString(),
        avatar: s['avatar']?.toString(),
        time: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        status: _map(j['status']?.toString()));
  }

  _FR _fromSent(Map<String, dynamic> j) {
    final s = j['target'] as Map<String, dynamic>;
    return _FR(
        id: (j['id'] as num).toInt(),
        userId: (s['id'] as num).toInt(),
        name: (s['nickname'] ?? s['username'] ?? '').toString(),
        avatar: s['avatar']?.toString(),
        time: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        status: _map(j['status']?.toString()));
  }

  _FRStatus _map(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'ACCEPTED':
        return _FRStatus.accepted;
      case 'REJECTED':
        return _FRStatus.rejected;
      default:
        return _FRStatus.pending;
    }
  }
}

class _FR {
  int id;
  int userId;
  String name;
  String? avatar;
  DateTime time;
  _FRStatus status;
  _FR(
      {required this.id,
      required this.userId,
      required this.name,
      this.avatar,
      required this.time,
      required this.status});
}

enum _FRStatus { pending, accepted, rejected }
