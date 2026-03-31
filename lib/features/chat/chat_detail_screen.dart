import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform; // desktop detection
import 'dart:ui' show ImageFilter; // desktop blur card
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/call_provider.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/message.dart';
import '../../shared/models/call_session.dart';
import '../../widgets/custom/user_avatar.dart';
import '../../widgets/custom/emoji_picker.dart';
import '../../widgets/custom/quick_links_widget.dart';
import '../../widgets/common/image_viewer.dart';
import '../../widgets/custom/pinned_message_bar.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/linkable_text.dart';
import 'dart:convert';
import '../subscriptions/article_detail_screen.dart' as SubscriptionArticle;
import '../hot/article_detail_screen.dart' as HotArticle;
import '../desktop/desktop_events.dart';
import '../call/call_screen.dart';
import '../../shared/providers/favorite_provider.dart';
import '../../shared/providers/pinned_message_provider.dart';
import '../../shared/models/favorite.dart';
import '../../shared/models/user.dart';
import '../../core/network/network_manager.dart';
import '../../core/network/server_health.dart';
import '../../shared/services/image_upload_service.dart';
import '../../widgets/custom/favorite_display.dart';

class ChatDetailScreen extends StatefulWidget {
  final String contactId;
  final bool isGroup;

  const ChatDetailScreen({
    super.key,
    required this.contactId,
    this.isGroup = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  // Desktop anchors for overlay emoji panel
  final GlobalKey _inputAreaKey = GlobalKey();
  final GlobalKey _emojiIconKey = GlobalKey();
  bool _desktopEmojiVisible = false;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageUploadService _imageUploadService = ImageUploadService();

  late AnimationController _inputAnimationController;
  late Animation<double> _inputScaleAnimation;

  Conversation? _currentConversation;
  List<Message> _messages = [];
  // 追踪已加载的消息ID，便于判断“新消息”数量
  final Set<int> _messageIds = <int>{};
  // 顶部以上新消息数量（当用户不在底部时累积）
  int _pendingNewCount = 0;
  // 已与界面同步的消息条数（用来计算“追加了多少条”）
  int _syncedCount = 0;
  // 第一条待加入的新消息ID（用于点击按钮后定位）
  int? _firstPendingMsgId;
  // 第一条待加入的新消息的定位Key（只绑定这一条，避免全量Key带来的重建风险）
  GlobalKey? _firstPendingKey;
  // 第一条未读消息（基于 lastReadAt 计算）
  int? _firstUnreadMsgId;
  GlobalKey? _firstUnreadKey;
  // 每条消息对应的Key（旧实现保留，不再使用）
  final Map<int, GlobalKey> _msgKeys = {};
  // 置顶栏（含展开图标）Key，用于计算阈值
  final GlobalKey _pinnedKey = GlobalKey();
  // 依据“展开置顶卡片图标”的位置计算出的触发展示按钮的阈值（像素）
  double? _indicatorTriggerPx;
  bool _isLoading = true;
  bool _showEmojiPicker = false;
  bool _showSendButton = false;
  bool _showMoreOptions = false;

  // 图片上传进度 Map<消息ID, 进度百分比>
  final Map<int, double> _uploadProgress = {};

  // 少量消息时（<=6）从顶部开始展示；消息多时采用反向列表以贴近底部
  bool get _isReversed => _messages.length > 6;

  // 回复状态与长按位置
  Message? _replyingTo;
  Offset? _lastLongPressGlobalPos;

  @override
  void initState() {
    super.initState();

    _inputAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _inputScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _inputAnimationController,
      curve: Curves.easeInOut,
    ));

    // 监听输入框焦点变化
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
          _showMoreOptions = false;
        });
      }
    });

    // 监听输入框内容变化
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      final hasFocus = _inputFocusNode.hasFocus;
      final shouldShow = hasText && hasFocus;

      if (_showSendButton != shouldShow) {
        setState(() {
          _showSendButton = shouldShow;
        });
      }
    });

    _loadChatData();

    // 监听滚动，判断是否接近底部
    _scrollController.addListener(() {
      final atBottom = _isAtBottom();
      if (atBottom && _pendingNewCount > 0) {
        _applyPendingNewMessages();
      }
    });

    // 监听 ChatProvider 变化以感知新消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<ChatProvider>().addListener(_onProviderChanged);
        
        // 注册通话结束需刷新回调
        // CallProvider 现在直接通过 _insertCallMessage 插入消息到 ChatProvider
        // 这里只需在当前会话收到通话消息时滚动到底部
        context.read<CallProvider>().onCallEndedNeedRefreshChat = 
            (conversationId, isGroup, result, duration, callType) {
          // 如果是当前会话，滚动到底部
          if (conversationId == widget.contactId && isGroup == widget.isGroup) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToBottom(animate: true);
            });
          }
        };
      } catch (_) {}
    });
  }

  // 桌面端输入工具栏的通用图标按钮
  Widget _toolbarIcon(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 离开聊天页时将该会话标记为已读（点击进入-退出即视为已读）
    try {
      final provider = context.read<ChatProvider>();
      provider.markConversationAsRead(widget.contactId);
    } catch (_) {}
    try {
      context.read<ChatProvider>().removeListener(_onProviderChanged);
      // 清理通话结束回调
      context.read<CallProvider>().onCallEndedNeedRefreshChat = null;
    } catch (_) {}
    _inputAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // 不再计算置顶图标阈值；改为更直观的规则：有新消息且不在底部就显示按钮

  // Provider 更新时计算“新增消息”
  void _onProviderChanged() {
    try {
      final provider = context.read<ChatProvider>();
      final latest =
          provider.conversations[widget.contactId] ?? const <Message>[];
      if (latest.length <= _syncedCount) return; // 没有追加
      final appendedCount = latest.length - _syncedCount;

      if (_isAtBottom()) {
        // 在底部：把追加部分同步到视图（逐条去重/替换），避免与本地待发送或API/WS重复
        final toAppend = latest.sublist(_syncedCount);
        setState(() {
          for (final m in toAppend) {
            final idx = _indexOfSameOrSimilarInView(m);
            if (idx == -1) {
              _messages.add(m);
            } else {
              _messages[idx] = m;
            }
          }
          _syncedCount = latest.length;
          _messageIds
            ..clear()
            ..addAll(_messages.map((e) => e.id));
        });
        _dedupByIdInView();
        // 不要动画，避免进入页面或实时追加时出现跳动
        _scrollToBottom(animate: false);
      } else {
        // 不在底部：仅累积数量与首条待加入ID，不立即改动视图
        setState(() {
          if (_pendingNewCount == 0) {
            _firstPendingMsgId = latest[_syncedCount].id;
            _firstPendingKey = GlobalKey();
          }
          _pendingNewCount += appendedCount;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadChatData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取会话信息
      final chatProvider = context.read<ChatProvider>();
      try {
        _currentConversation = chatProvider.conversationList
            .firstWhere((conv) => conv.id == widget.contactId);
      } catch (e) {
        debugPrint('未找到会话信息: $e');
        // 如果找不到会话，创建一个默认的会话信息
        _currentConversation = null;
      }

      // 从ChatProvider加载真实的历史消息
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        final messages = await chatProvider.getChatMessages(
          conversationId: widget.contactId,
          isGroup: widget.isGroup,
          userId: authProvider.user!.id,
        );

        if (messages.isNotEmpty) {
          // 为消息添加情绪监测信息
          _messages = await chatProvider.enrichMessagesWithEmotionData(
            messages,
            authProvider.user!.id,
          );
          _messageIds
            ..clear()
            ..addAll(_messages.map((e) => e.id));
          _syncedCount = _messages.length;
          _computeFirstUnreadAnchor();
        } else {
          // 如果没有历史消息，显示空列表而不是mock数据
          _messages = [];
          _messageIds.clear();
          _syncedCount = 0;
        }
      } else {
        _messages = [];
        _messageIds.clear();
        _syncedCount = 0;
        _firstUnreadMsgId = null;
      }

      // 加载置顶消息
      final pinnedProvider = context.read<PinnedMessageProvider>();
      await pinnedProvider.loadPinnedMessages(widget.contactId,
          isGroup: widget.isGroup);

      // 进入聊天页：稳定地定位到底部（无动画、不跳动）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messages.isNotEmpty && _isReversed) {
          _scrollToBottomStable();
        }
      });
    } catch (e) {
      debugPrint('加载聊天数据失败: $e');
      // 离线/服务器异常时，保留当前已展示的消息，不清空
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_isReversed) return;
    if (_scrollController.hasClients) {
      // 当 ListView.reverse=true 时，“底部”是 minScrollExtent(通常为0)
      final isReversed = _isReversed;
      final target = isReversed
          ? _scrollController.position.minScrollExtent
          : _scrollController.position.maxScrollExtent;
      if (animate) {
        // 两帧后再滚动，确保列表尺寸稳定
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.animateTo(
            isReversed
                ? _scrollController.position.minScrollExtent
                : _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        });
      } else {
        _scrollController.jumpTo(target);
      }
    }
  }

  // 进入页面时的“稳态”滚动到底部（无动画、最多重试几次直到真正贴底），
  // 解决首帧后列表高度变化（图片、置顶栏、字体度量等）导致的底部留白。
  void _scrollToBottomStable({int retries = 4}) {
    if (!_isReversed) return;
    if (!_scrollController.hasClients) return;
    final isReversed = _isReversed;
    _scrollController.jumpTo(
      isReversed
          ? _scrollController.position.minScrollExtent
          : _scrollController.position.maxScrollExtent,
    );
    if (retries <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // 反向列表时，贴底应当是 extentBefore 很小
      final remain = isReversed
          ? _scrollController.position.extentBefore
          : _scrollController.position.extentAfter;
      if (remain > 6) {
        _scrollToBottomStable(retries: retries - 1);
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // 发送前保留当前的回复目标快照
    final replyTarget = _replyingTo;

    // 清空输入框并收起键盘
    _messageController.clear();
    _inputFocusNode.unfocus();
    // 清除回复状态
    setState(() => _replyingTo = null);

    await _sendTextContent(
      content,
      replyTarget: replyTarget,
      triggerInputAnimation: true,
    );
  }

  Future<void> _sendTextContent(
    String content, {
    Message? replyTarget,
    bool triggerInputAnimation = false,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final network = NetworkManager();
    final serverHealth = ServerHealth();

    if (authProvider.user == null) {
      UnifiedToast.showError(context, '用户未登录');
      return;
    }
    if (!widget.isGroup &&
        chatProvider.isConversationBlocked(widget.contactId)) {
      _showCenterDark('已拉黑该好友，无法发送消息');
      return;
    }

    if (triggerInputAnimation) {
      HapticFeedback.lightImpact();
      _inputAnimationController.forward().then((_) {
        _inputAnimationController.reverse();
      });
    } else {
      HapticFeedback.selectionClick();
    }

    // 先创建“本地待发送”消息，左侧显示旋转图标
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final localPending = Message(
      id: tempId,
      senderId: authProvider.user!.id,
      senderName: authProvider.user!.nickname ?? authProvider.user!.username,
      receiverId: widget.isGroup ? null : int.tryParse(widget.contactId),
      groupId: widget.isGroup ? int.tryParse(widget.contactId) : null,
      content: trimmed,
      type: MessageType.text,
      createdAt: DateTime.now(),
      replyToMessageId: replyTarget?.id,
      replyToSenderId: replyTarget?.senderId,
      replyToSenderName: replyTarget?.senderName,
      replyToPreview: replyTarget?.type == MessageType.image
          ? '[图片]'
          : replyTarget?.content,
      replyToCreatedAt: replyTarget?.createdAt,
      sendStatus: MessageSendStatus.sending,
    );

    setState(() {
      _messages.add(localPending);
      _messageIds.add(localPending.id);
    });
    chatProvider.upsertLocalMessage(widget.contactId, localPending);
    // 发送后定位到底部，不使用弹跳动画
    _scrollToBottom(animate: false);

    // 最多等待3秒，如果尚未成功则标记失败
    bool completed = false;
    Timer? timeout;

    void markFailed(MessageSendStatus status, String centerMsg) {
      if (completed) return;
      completed = true;
      timeout?.cancel();
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(sendStatus: status);
        });
      }
      chatProvider.markLocalMessageFailed(widget.contactId, tempId, status);
      _scrollToBottom();
      _showCenterDark(centerMsg);
    }

    // 情况一：已知无网络或服务器异常，则等3秒再判失败
    final isOfflineNow = network.isOffline;
    final isServerDownNow =
        !isOfflineNow && serverHealth.status == ServerStatus.error;
    if (isOfflineNow || isServerDownNow) {
      timeout = Timer(const Duration(seconds: 3), () {
        markFailed(
          isOfflineNow
              ? MessageSendStatus.failedOffline
              : MessageSendStatus.failedServer,
          isOfflineNow ? '发送失败，请检查网络' : '服务器无响应',
        );
      });
      return; // 不尝试直连后端
    }

    // 情况二：网络正常，尝试发送；3秒兜底失败
    timeout = Timer(const Duration(seconds: 3), () {
      // 超时兜底
      final isOffline = network.isOffline;
      markFailed(
        isOffline
            ? MessageSendStatus.failedOffline
            : MessageSendStatus.failedServer,
        isOffline ? '发送失败，请检查网络' : '服务器无响应',
      );
    });

    try {
      final sentMessage = await chatProvider.sendMessage(
        senderId: authProvider.user!.id,
        content: trimmed,
        contactId: widget.contactId,
        isGroup: widget.isGroup,
        type: MessageType.text,
        replyToMessageId: replyTarget?.id,
      );

      if (sentMessage != null) {
        if (completed) return; // 已被标记失败则不再替换
        completed = true;
        timeout?.cancel();
        final patched =
            replyTarget != null && sentMessage.replyToMessageId == null
                ? sentMessage.copyWith(
                    replyToMessageId: replyTarget.id,
                    replyToSenderId: replyTarget.senderId,
                    replyToSenderName: replyTarget.senderName,
                    replyToPreview: replyTarget.type == MessageType.image
                        ? '[图片]'
                        : replyTarget.content,
                    replyToCreatedAt: replyTarget.createdAt,
                  )
                : sentMessage;
        final delivered = patched.copyWith(sendStatus: MessageSendStatus.sent);
        // 用服务端消息替换本地待发送消息
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          // 正常路径：找到本地占位（负ID）并替换
          setState(() {
            _messages[idx] = delivered;
            _messageIds.remove(tempId);
            _messageIds.add(patched.id);
          });
        } else {
          // 占位可能已被 Provider 的 WS/列表更新替换（常见于网络较快、WS先到）
          // 这里再做一次“近似匹配”（同 sender + 内容一致 + 时间接近）来替换，而不是盲目追加，避免重复显示
          final similarIdx = _indexOfSameOrSimilarInView(patched);
          if (similarIdx != -1) {
            setState(() {
              _messages[similarIdx] = delivered;
              _messageIds.add(patched.id);
            });
          } else {
            // 兜底：仍未找到，则追加
            setState(() {
              _messages.add(delivered);
              _messageIds.add(patched.id);
            });
          }
        }
        chatProvider.replaceLocalMessage(widget.contactId, tempId, delivered);
        // 成功后再去重一次（按 id），防止同一条被追加两次
        _dedupByIdInView();
        _scrollToBottom(animate: false);
      } else {
        // 立即失败
        final offline = network.isOffline;
        markFailed(
          offline
              ? MessageSendStatus.failedOffline
              : MessageSendStatus.failedServer,
          offline ? '发送失败，请检查网络' : '服务器无响应',
        );
      }
    } catch (e) {
      final offline = network.isOffline;
      final raw = e.toString();
      final friendly = raw.startsWith('Exception:')
          ? raw.replaceFirst('Exception:', '').trim()
          : raw;
      final fallback = offline ? '发送失败，请检查网络' : '服务器无响应';
      markFailed(
        offline
            ? MessageSendStatus.failedOffline
            : MessageSendStatus.failedServer,
        friendly.isNotEmpty ? friendly : fallback,
      );
    }
  }

  // 选择图片并发送
  Future<void> _pickAndSendImage(ImageSource source) async {
    // Web 端不支持
    if (kIsWeb) {
      context.showErrorToast('Web端暂不支持图片发送');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        context.showErrorToast('用户未登录');
        return;
      }

      // 触觉反馈
      HapticFeedback.lightImpact();

      // 创建本地待发送消息，使用本地文件路径作为临时内容
      final tempId = -DateTime.now().millisecondsSinceEpoch;
      final localPending = Message(
        id: tempId,
        senderId: authProvider.user!.id,
        senderName: authProvider.user!.nickname ?? authProvider.user!.username,
        receiverId: widget.isGroup ? null : int.tryParse(widget.contactId),
        groupId: widget.isGroup ? int.tryParse(widget.contactId) : null,
        content: image.path, // 临时使用本地路径
        type: MessageType.image,
        createdAt: DateTime.now(),
        sendStatus: MessageSendStatus.sending,
      );

      setState(() {
        _messages.add(localPending);
        _messageIds.add(localPending.id);
        _uploadProgress[tempId] = 0.0; // 初始化进度
      });
      _scrollToBottom(animate: false);

      // 上传图片，带进度回调
      final imageUrl = await _imageUploadService.uploadChatImage(
        File(image.path),
        onProgress: (progress) {
          print(
              '📊 上传进度: tempId=$tempId, progress=${(progress * 100).toInt()}%');
          if (mounted) {
            setState(() {
              _uploadProgress[tempId] = progress;
            });
          }
        },
      );

      // 上传完成，立即移除进度指示器
      if (mounted) {
        setState(() {
          _uploadProgress.remove(tempId);
        });
      }

      if (imageUrl == null) {
        // 上传失败，更新消息状态
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1 && mounted) {
          setState(() {
            _messages[idx] = _messages[idx]
                .copyWith(sendStatus: MessageSendStatus.failedServer);
          });
        }
        return;
      }

      // 上传成功，发送图片消息
      await _sendImageMessage(imageUrl, tempId);
    } catch (e) {
      if (mounted) {
        context.showErrorToast('选择图片失败: $e');
      }
    }
  }

  // 发送图片消息
  Future<void> _sendImageMessage(String imageUrl, int tempId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user == null) {
      return;
    }

    // 不更新消息内容，保持本地文件路径，直到发送成功
    // 这样可以确保在整个上传和发送过程中，图片都能正常显示

    try {
      final sentMessage = await chatProvider.sendMessage(
        senderId: authProvider.user!.id,
        content: imageUrl,
        contactId: widget.contactId,
        isGroup: widget.isGroup,
        type: MessageType.image,
      );

      if (sentMessage != null) {
        // 立即替换消息，不等待图片加载
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          if (mounted) {
            setState(() {
              _messages[idx] =
                  sentMessage.copyWith(sendStatus: MessageSendStatus.sent);
              _messageIds.remove(tempId);
              _messageIds.add(sentMessage.id);
              // 确保进度已被移除（双重保险）
              _uploadProgress.remove(tempId);
              _uploadProgress.remove(sentMessage.id);
            });
            _dedupByIdInView(); // 立即去重
            _scrollToBottom(animate: false);
          }
        } else {
          final similarIdx = _indexOfSameOrSimilarInView(sentMessage);
          if (similarIdx != -1) {
            if (mounted) {
              setState(() {
                _messages[similarIdx] =
                    sentMessage.copyWith(sendStatus: MessageSendStatus.sent);
                _messageIds.add(sentMessage.id);
                _uploadProgress.remove(tempId);
                _uploadProgress.remove(sentMessage.id);
              });
              _dedupByIdInView(); // 立即去重
              _scrollToBottom(animate: false);
            }
          } else {
            if (mounted) {
              setState(() {
                _messages.add(
                    sentMessage.copyWith(sendStatus: MessageSendStatus.sent));
                _messageIds.add(sentMessage.id);
                _uploadProgress.remove(tempId);
                _uploadProgress.remove(sentMessage.id);
              });
              _dedupByIdInView(); // 立即去重
              _scrollToBottom(animate: false);
            }
          }
        }
      } else {
        // 发送失败
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1 && mounted) {
          setState(() {
            _messages[idx] = _messages[idx]
                .copyWith(sendStatus: MessageSendStatus.failedServer);
          });
        }
        if (mounted) {
          context.showErrorToast('图片发送失败');
        }
      }
    } catch (e) {
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx != -1 && mounted) {
        setState(() {
          _messages[idx] = _messages[idx]
              .copyWith(sendStatus: MessageSendStatus.failedServer);
        });
      }
      if (mounted) {
        context.showErrorToast('图片发送失败');
      }
    }
  }

  // 重新加载消息列表（用于发送消息后同步）
  Future<void> _reloadMessages() async {
    try {
      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();

      if (authProvider.user != null) {
        // 直接从ChatProvider获取最新的对话消息
        final conversations = chatProvider.conversations;
        if (conversations[widget.contactId] != null) {
          final latestMessages = conversations[widget.contactId]!;

          // 为消息添加情绪监测信息
          final enrichedMessages =
              await chatProvider.enrichMessagesWithEmotionData(
            latestMessages,
            authProvider.user!.id,
          );

          setState(() {
            _messages = enrichedMessages;
          });
        }
      }
    } catch (e) {
      print('重新加载消息失败: $e');
    }
  }

  List<Message> _generateMockMessages() {
    final now = DateTime.now();
    return [
      Message(
        id: 1,
        senderId: int.tryParse(widget.contactId) ?? 2,
        senderName: _currentConversation?.displayName ?? '对方',
        receiverId: 1, // 假设当前用户ID为1
        content: '你好！最近怎么样？',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Message(
        id: 2,
        senderId: 1, // 当前用户ID
        senderName: '我',
        receiverId: int.tryParse(widget.contactId) ?? 2,
        content: '还不错，你呢？工作忙吗？',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      ),
      Message(
        id: 3,
        senderId: int.tryParse(widget.contactId) ?? 2,
        senderName: _currentConversation?.displayName ?? '对方',
        receiverId: 1, // 假设当前用户ID为1
        content: '挺忙的，不过还好。今天天气不错，想出去走走。',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // 快捷链接
            QuickLinksWidget(
              conversationId: widget.contactId,
              isGroup: widget.isGroup,
            ),

            // 置顶消息栏
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final conv = chatProvider.conversationList.firstWhere(
                  (c) => c.id == widget.contactId,
                  orElse: () => Conversation(
                    id: widget.contactId,
                    type: widget.isGroup
                        ? ConversationType.group
                        : ConversationType.private,
                    name: _currentConversation?.displayName ?? '聊天',
                    avatar: _currentConversation?.displayAvatar,
                    participants: const [],
                    lastActivity: DateTime.now(),
                  ),
                );
                return Container(
                  key: _pinnedKey,
                  child: PinnedMessageBar(
                    conversationId: widget.contactId,
                    isGroup: widget.isGroup,
                    groupName: widget.isGroup ? conv.displayName : null,
                    onTap: _onPinnedMessageChanged,
                  ),
                );
              },
            ),

            // 消息列表区域
            Expanded(
              child: _buildMessageList(),
            ),

            // 输入区域
            _buildInputArea(),

            // 表情选择器
            if (_showEmojiPicker &&
                (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS))
              Transform.translate(
                offset: const Offset(0, -13), // 向上移动减少间距
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 16),
                  child: EmojiPicker(
                    onEmojiSelected: (emoji) {
                      _messageController.text += emoji;
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _messageController.text.length),
                      );
                    },
                  ),
                ),
              ),

            // 功能选择器
            if (_showMoreOptions)
              Transform.translate(
                offset: const Offset(0, -13), // 向上移动减少间距
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 16),
                  child: _buildMoreOptionsWidget(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // 判断是否为桌面端（macOS/Windows/Linux）。
    // 仅在桌面端移除返回按钮并把头像/名称靠左对齐，
    // 避免影响移动端与 Web 的交互与布局。
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    return AppBar(
      backgroundColor: AppColors.background,
      // 桌面端不显示返回按钮；移动端显示返回按钮
      automaticallyImplyLeading: false,
      leading: isDesktop
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              splashRadius: 20,
              onPressed: () => Navigator.of(context).pop(),
            ),
      // 桌面端将标题内容左对齐显示到最左侧区域
      centerTitle: isDesktop ? false : null,
      titleSpacing: isDesktop ? 16.0 : 0.0, // 移动端间距设为0，通过内容控制
      title: Consumer2<AuthProvider, ChatProvider>(
        builder: (context, authProvider, chatProvider, _) {
          // 每次从 Provider 实时取会话，保证名称/头像更新后同步
          final conv = chatProvider.conversationList.firstWhere(
            (c) => c.id == widget.contactId,
            orElse: () =>
                _currentConversation ??
                Conversation(
                  id: widget.contactId,
                  type: widget.isGroup
                      ? ConversationType.group
                      : ConversationType.private,
                  name: _currentConversation?.displayName ?? '聊天',
                  avatar: _currentConversation?.displayAvatar,
                  participants: const [],
                  lastActivity: DateTime.now(),
                ),
          );

          final currentUserId = authProvider.user?.id ?? 1;
          
          // 桌面端和Web端保留头像
          final bool showAvatar = isDesktop || kIsWeb;
          
          Widget? leadingAvatar;
          String titleText;
          String statusText = '';
          bool isOnline = false;

          if (!widget.isGroup && conv.participants.isNotEmpty) {
            final otherUser = conv.participants.firstWhere(
              (u) => u.id != currentUserId,
              orElse: () => conv.participants.first,
            );
            isOnline = otherUser.status == UserStatus.online;
            
            if (showAvatar) {
              leadingAvatar = UserAvatar(
                imageUrl: otherUser.avatar ?? conv.displayAvatar,
                name: otherUser.nickname ?? otherUser.username ?? conv.displayName,
                size: 36,
                showOnlineStatus: true,
                isOnline: isOnline,
              );
            } else {
              if (isOnline) {
                statusText = '(在线)';
              }
            }
            titleText = otherUser.nickname ?? otherUser.username ?? conv.displayName;
          } else {
            if (showAvatar) {
              leadingAvatar = UserAvatar(
                imageUrl: conv.displayAvatar,
                name: conv.displayName,
                size: 36,
                showOnlineStatus: false,
              );
            }
            titleText = conv.displayName;
          }

          // 桌面端/Web端布局：带头像，双行显示（标题+状态）
          if (showAvatar) {
            return Row(
              children: [
                if (leadingAvatar != null) leadingAvatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: AppTextStyles.friendName.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!widget.isGroup && isOnline)
                        Text(
                          '在线',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          // 移动端布局：无头像，单行显示（标题+在线状态）
          return Row(
            children: [
              const SizedBox(width: 2), // 昵称与返回图标间距保留2像素
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: titleText,
                        style: AppTextStyles.friendName.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      if (statusText.isNotEmpty)
                        TextSpan(
                          text: ' $statusText',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone),
          onPressed: () => _startCall(CallType.voice),
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () => _startCall(CallType.video),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            _handleMenuAction(value);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Text(widget.isGroup ? '群聊信息' : '查看资料'),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Text('清空聊天记录'),
            ),
            if (!widget.isGroup)
              const PopupMenuItem(
                value: 'block',
                child: Text('拉黑用户'),
              ),
            if (widget.isGroup) ...[
              const PopupMenuItem(
                value: 'mute',
                child: Text('消息免打扰'),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: Text('退出群聊'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const LoadingState(message: '加载聊天记录...');
    }

    if (_messages.isEmpty) {
      // 兜底：若本地列表为空，尝试从 Provider 同步一次
      try {
        final latest =
            context.read<ChatProvider>().conversations[widget.contactId] ??
                const <Message>[];
        if (latest.isNotEmpty) {
          _messages = latest;
          _messageIds
            ..clear()
            ..addAll(latest.map((e) => e.id));
        }
      } catch (_) {}
      if (_messages.isEmpty) {
        return const EmptyState.noMessages();
      }
    }

    return Stack(
      children: [
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final media = MediaQuery.of(context);
            final bool isDesktop = !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux);
            final extraBottom =
                (!isDesktop ? media.viewInsets.bottom : 0.0) + 8.0;
            final currentUserId = authProvider.user?.id;
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16, 8, 16, extraBottom),
              reverse: _isReversed, // 少量消息时从顶部开始展示
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                // 反向时使用 revIndex，正常时直接 index
                final revIndex =
                    _isReversed ? (_messages.length - 1 - index) : index;
                final message = _messages[revIndex];
                final isFromMe =
                    currentUserId != null && message.senderId == currentUserId;
                // 日期分隔符判断仍基于升序索引
                final showDateSeparator = _shouldShowDateSeparator(revIndex);
                return Column(
                  children: [
                    if (showDateSeparator)
                      _buildDateSeparator(message.timestamp),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPressStart: (details) {
                        _lastLongPressGlobalPos = details.globalPosition;
                        _showMessagePopover(message, isFromMe);
                      },
                      onLongPress: () {},
                      // 桌面端：右键显示专属的竖向菜单（不影响移动端）
                      onSecondaryTapDown: (details) {
                        final bool isDesktop = !kIsWeb &&
                            (defaultTargetPlatform == TargetPlatform.macOS ||
                                defaultTargetPlatform ==
                                    TargetPlatform.windows ||
                                defaultTargetPlatform == TargetPlatform.linux);
                        if (isDesktop) {
                          _showDesktopContextMenu(
                              message, isFromMe, details.globalPosition);
                        }
                      },
                      child: (_firstPendingMsgId != null &&
                              message.id == _firstPendingMsgId &&
                              _firstPendingKey != null)
                          ? KeyedSubtree(
                              key: _firstPendingKey!,
                              child: _buildMessageBubble(message, isFromMe))
                          : (_firstUnreadMsgId != null &&
                                  message.id == _firstUnreadMsgId &&
                                  _firstUnreadKey != null)
                              ? KeyedSubtree(
                                  key: _firstUnreadKey!,
                                  child: _buildMessageBubble(message, isFromMe))
                              : _buildMessageBubble(message, isFromMe),
                    ),
                  ],
                );
              },
            );
          },
        ),
        if (_shouldShowNewMsgButton()) _buildNewMsgFloatButton(),
      ],
    );
  }

  // 是否接近底部（阈值 48px）
  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    // 反向列表：pixels<=40 视为贴底；正常列表：extentAfter<40
    return true ? pos.pixels <= 40 : pos.extentAfter < 40;
  }

  // 应用待加入的新消息
  void _applyPendingNewMessages() {
    try {
      final provider = context.read<ChatProvider>();
      final latest =
          provider.conversations[widget.contactId] ?? const <Message>[];
      // 优先：若有“未读堆叠”，不做追加，直接定位到第一条未读
      if (_firstUnreadMsgId != null) {
        final key = _firstUnreadKey;
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(key.currentContext!,
              duration: const Duration(milliseconds: 220),
              alignment: 0.1,
              curve: Curves.easeOut);
          return;
        }
      }

      // 其次：把追加部分同步到视图
      if (latest.length > _syncedCount) {
        final toAppend = latest.sublist(_syncedCount);
        setState(() {
          for (final m in toAppend) {
            final idx = _indexOfSameOrSimilarInView(m);
            if (idx == -1) {
              _messages.add(m);
            } else {
              _messages[idx] = m;
            }
          }
          _syncedCount = latest.length;
          _pendingNewCount = 0;
          _messageIds
            ..clear()
            ..addAll(_messages.map((e) => e.id));
        });
        _dedupByIdInView();
        // 定位到刚才的第一条追加
        final targetId = _firstPendingMsgId ?? toAppend.first.id;
        final key = _firstPendingKey;
        _firstPendingMsgId = null;
        _firstPendingKey = null;
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(key.currentContext!,
              duration: const Duration(milliseconds: 220),
              alignment: 0.1,
              curve: Curves.easeOut);
        } else {
          // 用户选择“查看新消息”时也尽量避免动画抖动
          _scrollToBottom(animate: false);
        }
      }
    } catch (_) {}
  }

  // 视图层的去重：按 id，或按 senderId+内容相同+时间差<=N秒
  int _indexOfSameOrSimilarInView(Message target) {
    // 视图中的消息也都是同一会话，无需再比较会话字段
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].id == target.id) return i;
    }
    final norm = target.content.trim();
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.senderId != target.senderId) continue;
      if (m.content.trim() != norm) continue;
      // 放宽阈值到10分钟，兼容服务端/客户端时区或序列化差异导致的时间偏移
      final dt = m.createdAt.difference(target.createdAt).inSeconds.abs();
      if (dt <= 600) return i;
    }
    return -1;
  }

  // 右侧居中的“以上有X条新消息”浮动按钮
  Widget _buildNewMsgFloatButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        minimum: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: _applyPendingNewMessages,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
                  Border.all(color: const Color(0xFFE5E7EB), width: 1), // 浅灰细边
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20), right: Radius.circular(0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.double_arrow_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '以上有$_pendingNewCount条新消息',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 是否显示“新消息”按钮：有待加入消息 + 不在底部（以顶部栏为节点的简化规则）
  bool _shouldShowNewMsgButton() {
    if (_pendingNewCount > 0) return true; // 有追加就显示
    // 如果没有追加，但存在“未读堆叠”，也显示按钮，点击后直达第一条未读
    try {
      if (_firstUnreadMsgId != null) return true;
    } catch (_) {}
    return false;
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;

    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];

    final currentDate = DateTime(
      currentMessage.timestamp.year,
      currentMessage.timestamp.month,
      currentMessage.timestamp.day,
    );

    final previousDate = DateTime(
      previousMessage.timestamp.year,
      previousMessage.timestamp.month,
      previousMessage.timestamp.day,
    );

    return !currentDate.isAtSameMomentAs(previousDate);
  }

  Widget _buildDateSeparator(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateSeparator(timestamp),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateSeparator(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate.isAtSameMomentAs(today)) {
      return '今天';
    } else if (messageDate
        .isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return '昨天';
    } else {
      return '${timestamp.month}月${timestamp.day}日';
    }
  }

  // 计算“第一条未读消息”的锚点（基于 lastReadAt）
  void _computeFirstUnreadAnchor() {
    try {
      final lastRead =
          context.read<ChatProvider>().lastReadAt(widget.contactId);
      if (lastRead == null) {
        _firstUnreadMsgId = null;
        _firstUnreadKey = null;
        return;
      }
      for (final m in _messages) {
        if (m.createdAt.isAfter(lastRead)) {
          _firstUnreadMsgId = m.id;
          _firstUnreadKey = GlobalKey();
          return;
        }
      }
      _firstUnreadMsgId = null;
      _firstUnreadKey = null;
    } catch (_) {}
  }

  Map<String, dynamic>? _tryParseZenNotesInvitation(String content) {
    try {
      final map = jsonDecode(content);
      if (map is Map && map['type'] == 'zennotes_invitation') {
        return map as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Widget _buildZenNotesInvitationBubble(Message message, Map<String, dynamic> data) {
    final notebookTitle = data['notebookTitle'];
    final inviterName = data['inviterName'];
    final inviterAvatar = data['inviterAvatar'];
    // final notebookId = data['notebookId']; // 暂时未使用
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    imageUrl: inviterAvatar,
                    name: inviterName,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$inviterName 邀请您协作',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ZenNotes 共享空间',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.book, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notebookTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    UnifiedToast.showSuccess(context, '已接受邀请，请前往笔记页面查看');
                    // TODO: 跳转到笔记页面
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('查看笔记本'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isFromMe) {
    // 平台判断：本轮只修复 App（iOS/Android）端的头像对齐问题
    // 移动端（iOS/Android）期望头像与消息气泡底部对齐；
    // 桌面端/Web 保持当前实现，避免影响既有布局。
    final bool _isMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    // 尝试解析 ZenNotes 邀请
    if (message.type == MessageType.system) {
      final zenNotesInvite = _tryParseZenNotesInvitation(message.content);
      if (zenNotesInvite != null) {
        return _buildZenNotesInvitationBubble(message, zenNotesInvite);
      }
    }

    // 尝试解析“文章分享”负载（JSON）
    final articleShare = _tryParseArticleShare(message.content);
    if (articleShare != null) {
      return _buildArticleShareBubble(message, isFromMe, articleShare);
    }

    // 图片消息
    if (message.type == MessageType.image) {
      print(
          '渲染图片消息: id=${message.id}, type=${message.type}, content=${message.content}');
      return _buildImageMessageBubble(message, isFromMe);
    }

    // features/chat/chat_detail_screen.dart | _buildMessageBubble | 通话卡片消息渲染
    // 作用：渲染通话卡片消息，显示通话类型、结果和时长
    if (message.type == MessageType.call) {
      return _buildCallCardBubble(message, isFromMe);
    }

    // 调试：打印所有消息的类型
    print(
        '渲染文本消息: id=${message.id}, type=${message.type}, content=${message.content.substring(0, message.content.length > 50 ? 50 : message.content.length)}');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 消息主体部分（头像 + 气泡）
          Row(
            mainAxisAlignment:
                isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            // 修复：我方长消息时头像垂直居中问题（应与气泡底部对齐）。
            // 仅在移动端调整为底对齐；其它端保持原样。
            crossAxisAlignment: isFromMe
                ? (_isMobilePlatform
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center)
                : CrossAxisAlignment.end,
            children: [
              // 对方头像
              if (!isFromMe) ...[
                // 群聊时优先显示消息发送者头像；私聊显示对方头像
                UserAvatar(
                  imageUrl: widget.isGroup
                      ? (message.senderAvatar ??
                          _currentConversation?.displayAvatar)
                      : (_currentConversation?.displayAvatar ??
                          message.senderAvatar),
                  name: message.senderName,
                  size: 32,
                ),
                const SizedBox(width: 8),
              ],

              // 我方消息：在气泡左侧放置发送状态图标（旋转/失败）
              if (isFromMe) ...[
                Align(
                  alignment: Alignment.center,
                  child: _buildSendStatusIcon(message),
                ),
                const SizedBox(width: 6),
              ],

              // 消息气泡：宽度取决于文本长度（上限为当前 Row 可用宽度的 70%），
              // App 端在此基础上再放宽 60px（不超过可用宽度）。
              Flexible(
                fit: FlexFit.loose,
                child: LayoutBuilder(
                  builder: (context, rowConstraints) {
                    // App 端增加 60px；Web/桌面端保持不变，避免影响其他端布局
                    final bool isMobile = !kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.iOS ||
                            defaultTargetPlatform == TargetPlatform.android);
                    double maxBubble = rowConstraints.maxWidth * 0.70;
                    if (isMobile) {
                      maxBubble =
                          (maxBubble + 60).clamp(0.0, rowConstraints.maxWidth);
                    }
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxBubble),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isFromMe
                              ? AppColors.primary
                              : AppColors.otherMessageBg,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                            bottomRight: Radius.circular(isFromMe ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.replyToMessageId != null &&
                                message.replyToPreview != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isFromMe
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            message.replyToSenderName ?? '引用',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: isFromMe
                                                  ? AppColors.textWhite
                                                  : AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (message.replyToCreatedAt != null)
                                          Text(
                                            _formatMessageTime(
                                                message.replyToCreatedAt!),
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: isFromMe
                                                  ? AppColors.textWhite
                                                      .withValues(alpha: 0.8)
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      // 如果回复预览是图片URL（以常见图片扩展名结尾），显示 [图片]
                                      _isImageUrl(message.replyToPreview!)
                                          ? '[图片]'
                                          : message.replyToPreview!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        color: isFromMe
                                            ? AppColors.textWhite
                                                .withValues(alpha: 0.9)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // 气泡根据文本自然决定宽度（在上限内）
                            LinkableText(
                              message.content,
                              style: AppTextStyles.messageContent.copyWith(
                                color: isFromMe
                                    ? AppColors.textWhite
                                    : AppColors.textPrimary,
                              ),
                              linkStyle: AppTextStyles.messageContent.copyWith(
                                color: isFromMe
                                    ? AppColors.textWhite.withValues(alpha: 0.9)
                                    : AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 我的头像
              if (isFromMe) ...[
                const SizedBox(width: 8),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return UserAvatar(
                      imageUrl: authProvider.user?.avatar,
                      name: authProvider.user?.nickname ??
                          authProvider.user?.username ??
                          '我',
                      size: 32,
                    );
                  },
                ),
              ],
            ],
          ),

          // 发送者昵称（群聊） + 时间戳 - 显示在气泡外部
          Container(
            margin: EdgeInsets.only(
              top: 4,
              left: isFromMe ? 0 : 40, // 对方消息：与头像对齐
              right: isFromMe ? 40 : 0, // 自己消息：与头像对齐
            ),
            child: Row(
              mainAxisAlignment:
                  isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isGroup && !isFromMe) ...[
                  Text(
                    message.senderName,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatMessageTime(message.timestamp),
                  style: AppTextStyles.messageTime.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),

          // 情绪监测提示文本 - 只有对方消息且有情绪警告时显示
          if (!isFromMe &&
              message.hasEmotionAlert &&
              message.emotionTipText != null)
            GestureDetector(
              onTap: () => _showEmotionExplanation(message),
              child: Container(
                margin: EdgeInsets.only(
                  top: 6,
                  left: 40, // 与头像对齐
                  right: 60,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      message.emotionTipText!,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 左侧发送状态图标
  // 在线正常时：使用静态时钟；
  // 无网络或后端不可达时：改为转圈圆动画（CircularProgressIndicator），3秒后由上层逻辑置为失败图标。
  Widget _buildSendStatusIcon(Message message) {
    switch (message.sendStatus) {
      case MessageSendStatus.sending:
        // 根据当前网络/后端状态决定：离线或服务异常 -> 转圈动画；否则静态时钟
        try {
          final offline = NetworkManager().isOffline;
          final serverDown = ServerHealth().status == ServerStatus.error;
          if (offline || serverDown) {
            return const SizedBox(
              width: 22,
              height: 16,
              child: Center(child: LinkMeLoader(fontSize: 10, compact: true)),
            );
          }
        } catch (_) {}
        return const Icon(Icons.schedule_rounded, size: 16, color: Colors.grey);
      case MessageSendStatus.failedOffline:
        return const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.red);
      case MessageSendStatus.failedServer:
        return const Icon(Icons.link_off_rounded, size: 16, color: Colors.red);
      case MessageSendStatus.sent:
      case null:
        return const SizedBox(width: 0, height: 16);
    }
  }

  // 解析文章分享消息（JSON字符串）
  Map<String, dynamic>? _tryParseArticleShare(String content) {
    try {
      final obj = jsonDecode(content);
      if (obj is Map<String, dynamic>) {
        final t = (obj['type'] ?? '').toString().toUpperCase();
        if (t == 'ARTICLE_SHARE' &&
            obj['articleId'] != null &&
            obj['channelId'] != null) {
          return obj;
        }
        if (t == 'HOT_ARTICLE_SHARE' && obj['articleId'] != null) {
          return obj;
        }
      }
    } catch (_) {}
    return null;
  }

  // 构建文章分享气泡（主图 + 标题 + 摘要 + 一键查看）
  Widget _buildArticleShareBubble(
      Message message, bool isFromMe, Map<String, dynamic> data) {
    final String title = (data['title'] ?? '').toString();
    final String summary = _stripHtml((data['summary'] ?? '').toString());
    final String? cover = (data['cover'] as String?);
    final String shareType =
        (data['type'] ?? 'ARTICLE_SHARE').toString().toUpperCase();
    final bool isHotShare = shareType == 'HOT_ARTICLE_SHARE';
    final String? channelId = data['channelId']?.toString();
    final String? articleId = data['articleId']?.toString();
    final Color accentColor =
        isHotShare ? AppColors.warning : AppColors.secondary;

    // 外层保持与普通消息相同的头像与布局，仅替换气泡内容
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            // 文章分享卡片较高，头像与卡片底部对齐（避免垂直居中）
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isFromMe) ...[
                UserAvatar(
                  imageUrl: widget.isGroup
                      ? (message.senderAvatar ??
                          _currentConversation?.displayAvatar)
                      : (_currentConversation?.displayAvatar ??
                          message.senderAvatar),
                  name: message.senderName,
                  size: 32,
                ),
                const SizedBox(width: 8),
              ],
              if (isFromMe) ...[
                Align(
                    alignment: Alignment.center,
                    child: _buildSendStatusIcon(message)),
                const SizedBox(width: 6),
              ],
              Flexible(
                fit: FlexFit.loose,
                child: LayoutBuilder(
                  builder: (context, rowConstraints) {
                    double maxBubble = rowConstraints.maxWidth * 0.70;
                    // 移动端：对文章分享卡片再放宽 60px（与普通气泡一致），其他端保持 70% 上限
                    final bool isMobile = !kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.iOS ||
                            defaultTargetPlatform == TargetPlatform.android);
                    if (isMobile) {
                      maxBubble =
                          (maxBubble + 60).clamp(0.0, rowConstraints.maxWidth);
                    }
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxBubble),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(isFromMe ? 12 : 4),
                            bottomRight: Radius.circular(isFromMe ? 4 : 12),
                          ),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _shareCover(cover),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: AppTextStyles.messageContent
                                          .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary)),
                                  const SizedBox(height: 6),
                                  Text(
                                    summary,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.messageContent
                                        .copyWith(
                                            color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  // 一键查看按钮：5px圆角，白底，紫色边框+文本；Hover/Pressed使用浅紫背景
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        final bool isDesktopMac = !kIsWeb &&
                                            defaultTargetPlatform ==
                                                TargetPlatform.macOS;
                                        final bool isMobilePlatform = !kIsWeb &&
                                            (defaultTargetPlatform ==
                                                    TargetPlatform.iOS ||
                                                defaultTargetPlatform ==
                                                    TargetPlatform.android);
                                        if (isHotShare) {
                                          final int? hotId = articleId != null
                                              ? int.tryParse(articleId)
                                              : null;
                                          if (hotId == null) {
                                            if (mounted)
                                              context.showErrorToast('文章已失效');
                                            return;
                                          }
                                          if (!isMobilePlatform) {
                                            if (mounted)
                                              context
                                                  .showInfoToast('请在移动端查看热榜文章');
                                            return;
                                          }
                                          final payload = {
                                            'id': hotId,
                                            'articleId': hotId,
                                            'title': title,
                                            'summary':
                                                data['summary'] ?? summary,
                                            'imageUrl':
                                                data['imageUrl'] ?? cover,
                                            'cover': cover,
                                            if (data['publishedAt'] != null)
                                              'publishedAt':
                                                  data['publishedAt'],
                                            if (data['publisher'] != null)
                                              'publisher': data['publisher'],
                                          };
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => HotArticle
                                                  .ArticleDetailScreen(
                                                      data: payload),
                                            ),
                                          );
                                          return;
                                        }
                                        if (channelId == null ||
                                            articleId == null) {
                                          if (mounted)
                                            context.showErrorToast('文章已失效');
                                          return;
                                        }
                                        if (isDesktopMac) {
                                          OpenArticleInPane(
                                                  channelId, articleId)
                                              .dispatch(context);
                                          return;
                                        }
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SubscriptionArticle
                                                .ArticleDetailScreen(
                                                    channelId: channelId,
                                                    articleId: articleId),
                                          ),
                                        );
                                      },
                                      style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStateProperty.all<Color>(
                                                Colors.white),
                                        foregroundColor:
                                            MaterialStateProperty.all<Color>(
                                                accentColor),
                                        overlayColor: MaterialStateProperty
                                            .resolveWith<Color?>((states) {
                                          if (states
                                              .contains(MaterialState.pressed))
                                            return accentColor.withValues(
                                                alpha: 0.10);
                                          if (states
                                              .contains(MaterialState.hovered))
                                            return accentColor.withValues(
                                                alpha: 0.06);
                                          return null;
                                        }),
                                        side: MaterialStateProperty.all(
                                            BorderSide(
                                                color: accentColor, width: 1)),
                                        shape: MaterialStateProperty.all(
                                            RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5))),
                                        padding: MaterialStateProperty.all(
                                            const EdgeInsets.symmetric(
                                                vertical: 10)),
                                      ),
                                      child: const Text('一键查看'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (isFromMe) ...[
                const SizedBox(width: 8),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return UserAvatar(
                      imageUrl: authProvider.user?.avatar,
                      name: authProvider.user?.nickname ??
                          authProvider.user?.username ??
                          '我',
                      size: 32,
                    );
                  },
                ),
              ],
            ],
          ),

          // 尾部时间/昵称
          Container(
            margin: EdgeInsets.only(
              top: 4,
              left: isFromMe ? 0 : 40,
              right: isFromMe ? 40 : 0,
            ),
            child: Row(
              mainAxisAlignment:
                  isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isGroup && !isFromMe) ...[
                  Text(
                    message.senderName,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatMessageTime(message.timestamp),
                  style: AppTextStyles.messageTime
                      .copyWith(color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareCover(String? url) {
    final u = (url ?? '').trim();
    if (u.isNotEmpty) {
      return Image.network(
        u,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _shareCoverPlaceholder(),
      );
    }
    return _shareCoverPlaceholder();
  }

  Widget _shareCoverPlaceholder() {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)]),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image, color: Color(0xFF93C5FD)),
    );
  }

  String _stripHtml(String s) =>
      s.replaceAll(RegExp(r"<[^>]+>"), '').replaceAll('&nbsp;', ' ').trim();

  // features/chat/chat_detail_screen.dart | _buildCallCardBubble | 构建通话卡片气泡
  // 作用：渲染通话卡片消息，显示通话类型、结果和时长，支持点击回拨
  // 关键参数：message(通话消息), isFromMe(是否为当前用户发送)
  Widget _buildCallCardBubble(Message message, bool isFromMe) {
    // 解析通话信息
    final callType = message.callType ?? 'VOICE'; // VOICE 或 VIDEO
    final callResult = message.callResult ?? 'COMPLETED'; // 通话结果
    final durationSeconds = message.callDurationSeconds ?? 0;
    
    // 判断是否为未接听（CANCELLED、REJECTED、MISSED 都算未接听）
    final isMissed = callResult == 'CANCELLED' || 
                     callResult == 'REJECTED' || 
                     callResult == 'MISSED';
    
    // 格式化通话时长
    String formatDuration(int seconds) {
      if (seconds < 60) {
        return '$seconds秒';
      } else if (seconds < 3600) {
        final minutes = seconds ~/ 60;
        final secs = seconds % 60;
        return secs > 0 ? '$minutes分${secs}秒' : '$minutes分';
      } else {
        final hours = seconds ~/ 3600;
        final minutes = (seconds % 3600) ~/ 60;
        return minutes > 0 ? '$hours小时$minutes分' : '$hours小时';
      }
    }
    
    // 获取通话类型显示文本
    final callTypeText = callType == 'VIDEO' ? '视频通话' : '语音通话';
    
    // 获取 SVG 图标路径
    final iconPath = callType == 'VIDEO' 
        ? 'assets/app_icons/svg/video.svg'
        : 'assets/app_icons/svg/call.svg';
    
    // 未接听时使用红色，已接听使用正常颜色
    final iconColor = isMissed 
        ? const Color(0xFFFF4444) // 红色
        : (isFromMe ? AppColors.textWhite : AppColors.primary);
    
    final textColor = isMissed
        ? const Color(0xFFFF4444) // 红色
        : (isFromMe ? AppColors.textWhite : AppColors.textPrimary);
    
    final statusTextColor = isMissed
        ? const Color(0xFFFF4444) // 红色
        : (isFromMe ? AppColors.textWhite.withValues(alpha: 0.8) : AppColors.textSecondary);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // features/chat/chat_detail_screen.dart | _buildCallCardBubble | 对方头像
              // 作用：显示发送者头像，群聊优先使用 senderAvatar，私聊使用会话头像
              if (!isFromMe) ...[
                UserAvatar(
                  imageUrl: widget.isGroup
                      ? (message.senderAvatar ??
                          _currentConversation?.displayAvatar)
                      : (_currentConversation?.displayAvatar ??
                          message.senderAvatar),
                  name: message.senderName,
                  size: 32,
                ),
                const SizedBox(width: 8),
              ],
              
              // 我方消息：发送状态图标（移到气泡左侧）
              if (isFromMe) ...[
                Align(
                  alignment: Alignment.center,
                  child: _buildSendStatusIcon(message),
                ),
                const SizedBox(width: 6),
              ],

              // 通话卡片
              GestureDetector(
                onTap: () {
                  // features/chat/chat_detail_screen.dart | _buildCallCardBubble | Klik卡片回拨
                  // 作用：点击通话卡片后，打开通话界面重新发起相同类型的通话
                  final isGroup = widget.isGroup;
                  final targetCallType = callType == 'VIDEO' ? CallType.video : CallType.voice;
                  
                  // 构建对方信息
                  CallUserInfo? peerUser;
                  CallGroupInfo? groupInfo;
                  
                  if (isGroup) {
                    // 群聊通话
                    if (_currentConversation != null) {
                      groupInfo = CallGroupInfo(
                        id: int.tryParse(widget.contactId) ?? 0,
                        name: _currentConversation!.displayName,
                        avatar: _currentConversation!.displayAvatar,
                      );
                    }
                  } else {
                    // 私聊通话
                    if (_currentConversation != null) {
                      peerUser = CallUserInfo(
                        id: int.tryParse(widget.contactId) ?? 0,
                        nickname: _currentConversation!.displayName,
                        avatar: _currentConversation!.displayAvatar,
                      );
                    }
                  }
                  
                  // 跳转到通话界面
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CallScreen(
                        callType: targetCallType,
                        roomType: isGroup ? CallRoomType.group : CallRoomType.private,
                        peerUser: peerUser,
                        groupInfo: groupInfo,
                        calleeId: isGroup ? null : int.tryParse(widget.contactId),
                        groupId: isGroup ? int.tryParse(widget.contactId) : null,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFromMe ? AppColors.primary : AppColors.otherMessageBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                      bottomRight: Radius.circular(isFromMe ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 通话类型和图标
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            iconPath,
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              iconColor,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            callTypeText,
                            style: AppTextStyles.messageContent.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // 通话状态和时长
                      if (isMissed)
                        Text(
                          '未接听',
                          style: AppTextStyles.caption.copyWith(
                            color: statusTextColor,
                          ),
                        )
                      else
                        Text(
                          '通话时长: ${formatDuration(durationSeconds)}',
                          style: AppTextStyles.caption.copyWith(
                            color: statusTextColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // 我方头像（显示在右侧）
              if (isFromMe) ...[
                const SizedBox(width: 8),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return UserAvatar(
                      imageUrl: authProvider.user?.avatar,
                      name: authProvider.user?.nickname ??
                          authProvider.user?.username ??
                          '我',
                      size: 32,
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // 构建图片消息气泡
  Widget _buildImageMessageBubble(Message message, bool isFromMe) {
    final bool _isMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: isFromMe
                ? (_isMobilePlatform
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center)
                : CrossAxisAlignment.end,
            children: [
              // 对方头像
              if (!isFromMe) ...[
                UserAvatar(
                  imageUrl: widget.isGroup
                      ? (message.senderAvatar ??
                          _currentConversation?.displayAvatar)
                      : (_currentConversation?.displayAvatar ??
                          message.senderAvatar),
                  name: message.senderName,
                  size: 32,
                ),
                const SizedBox(width: 8),
              ],

              // 我方消息：发送状态图标
              if (isFromMe) ...[
                Align(
                  alignment: Alignment.center,
                  child: _buildSendStatusIcon(message),
                ),
                const SizedBox(width: 6),
              ],

              // 图片气泡
              Flexible(
                fit: FlexFit.loose,
                child: GestureDetector(
                  onTap: () => _openImageViewer(message.content),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 250,
                      maxHeight: 250,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                        bottomRight: Radius.circular(isFromMe ? 4 : 16),
                      ),
                      child: Stack(
                        children: [
                          // 判断是本地文件还是网络URL
                          message.content.startsWith('http://') ||
                                  message.content.startsWith('https://')
                              ? CachedNetworkImage(
                                  imageUrl: message.content,
                                  fit: BoxFit.contain, // 保持图片比例，不拉伸
                                  // 使用本地磁盘缓存，app重启后直接从缓存加载
                                  placeholder: (context, url) {
                                    // 只有正在上传的图片才显示占位符
                                    if (_uploadProgress
                                        .containsKey(message.id)) {
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        color: AppColors.surfaceLight,
                                      );
                                    }
                                    // 历史图片不显示占位符，直接透明
                                    return const SizedBox.shrink();
                                  },
                                  errorWidget: (context, url, error) {
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      color: AppColors.surfaceLight,
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image,
                                              size: 48,
                                              color: AppColors.textLight),
                                          SizedBox(height: 8),
                                          Text('图片加载失败',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary)),
                                        ],
                                      ),
                                    );
                                  },
                                  // 设置缓存时长为30天
                                  maxWidthDiskCache: 1000,
                                  maxHeightDiskCache: 1000,
                                )
                              : Image.file(
                                  File(message.content),
                                  fit: BoxFit.contain, // 保持图片比例，不拉伸
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      color: AppColors.surfaceLight,
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image,
                                              size: 48,
                                              color: AppColors.textLight),
                                          SizedBox(height: 8),
                                          Text('图片加载失败',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary)),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                          // 上传中的进度指示器（透明球体 + 百分比）
                          // 只在有上传进度数据时显示
                          if (_uploadProgress.containsKey(message.id)) ...[
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.3),
                                child: Center(
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${((_uploadProgress[message.id] ?? 0.0) * 100).toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 我的头像
              if (isFromMe) ...[
                const SizedBox(width: 8),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return UserAvatar(
                      imageUrl: authProvider.user?.avatar,
                      name: authProvider.user?.nickname ??
                          authProvider.user?.username ??
                          '我',
                      size: 32,
                    );
                  },
                ),
              ],
            ],
          ),

          // 时间戳
          Container(
            margin: EdgeInsets.only(
              top: 4,
              left: isFromMe ? 0 : 40,
              right: isFromMe ? 40 : 0,
            ),
            child: Row(
              mainAxisAlignment:
                  isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isGroup && !isFromMe) ...[
                  Text(
                    message.senderName,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatMessageTime(message.timestamp),
                  style: AppTextStyles.messageTime.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 视图层去重：同一 message.id 仅保留一条；优先保留 sendStatus=sent 的记录
  void _dedupByIdInView() {
    final Map<int, Message> map = {};
    for (final m in _messages) {
      final existing = map[m.id];
      if (existing == null) {
        map[m.id] = m;
      } else {
        // 选取“更好”的那条
        final keep = (existing.sendStatus == MessageSendStatus.sent)
            ? existing
            : (m.sendStatus == MessageSendStatus.sent
                ? m
                : (m.createdAt.isAfter(existing.createdAt) ? m : existing));
        map[m.id] = keep;
      }
    }
    _messages = map.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _messageIds
      ..clear()
      ..addAll(_messages.map((e) => e.id));
  }

  void _showCenterDark(String text) {
    // 使用统一方法以便后续一致风格
    try {
      // ignore: use_build_context_synchronously
      context.showCenterDarkToast(text);
    } catch (_) {}
  }

  /// 判断字符串是否是图片URL
  bool _isImageUrl(String text) {
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return false;
    }
    final lowerText = text.toLowerCase();
    return lowerText.endsWith('.jpg') ||
        lowerText.endsWith('.jpeg') ||
        lowerText.endsWith('.png') ||
        lowerText.endsWith('.gif') ||
        lowerText.endsWith('.webp') ||
        lowerText.endsWith('.bmp') ||
        lowerText.contains('.jpg?') ||
        lowerText.contains('.jpeg?') ||
        lowerText.contains('.png?') ||
        lowerText.contains('.gif?') ||
        lowerText.contains('.webp?');
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildInputArea() {
    return Container(
      key: _inputAreaKey,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Desktop toolbar on top-left (QQ-like)
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 12,
                      children: [
                        _desktopToolbarIcon(
                          key: _emojiIconKey,
                          // 图标不随状态切换，始终使用表情图标
                          icon: Icons.emoji_emotions_outlined,
                          tooltip: '表情',
                          onTap: _toggleDesktopEmojiPanel,
                        ),
                        _desktopToolbarIcon(
                          icon: Icons.photo_library_outlined,
                          tooltip: '照片',
                          onTap: () => context.showInfoToast('选择照片功能开发中'),
                        ),
                        _desktopToolbarIcon(
                          icon: Icons.bookmark_border_rounded,
                          tooltip: '收藏',
                          onTap: _showFavoritesSheet,
                        ),
                        _desktopToolbarIcon(
                          icon: Icons.mic_none_outlined,
                          tooltip: '语音',
                          onTap: () => context.showInfoToast('语音功能开发中'),
                        ),
                      ],
                    ),
                  ),
                ),
              // 移除了重复的第二行桌面工具栏
              if (_replyingTo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '回复 ${_replyingTo!.senderName}',
                              style: AppTextStyles.caption
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _replyingTo!.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _replyingTo = null),
                        child: const Icon(Icons.close,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  // 输入框
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _inputScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _inputScaleAnimation.value,
                          child: Builder(builder: (context) {
                            final bool isDesktopMac = !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.macOS;
                            final row = Row(
                              children: <Widget>[
                                // Desktop: emoji handled by top toolbar; mobile keeps inside input
                                if (kIsWeb ||
                                    defaultTargetPlatform !=
                                        TargetPlatform.macOS)
                                  IconButton(
                                    icon: Icon(
                                      _showEmojiPicker
                                          ? Icons.keyboard
                                          : Icons.emoji_emotions_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showEmojiPicker = !_showEmojiPicker;
                                        _showMoreOptions = false; // 关闭功能选择器
                                      });
                                      if (_showEmojiPicker) {
                                        _inputFocusNode.unfocus();
                                      } else {
                                        _inputFocusNode.requestFocus();
                                      }
                                    },
                                  ),

                                // 文本输入框
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    focusNode: _inputFocusNode,
                                    decoration: const InputDecoration(
                                      hintText: '输入消息...',
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    style: AppTextStyles.input,
                                    maxLines: 4,
                                    minLines: 1,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),

                                // Desktop: hide more '+'; mobile keeps
                                if (kIsWeb ||
                                    defaultTargetPlatform !=
                                        TargetPlatform.macOS)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showMoreOptions = !_showMoreOptions;
                                        _showEmojiPicker = false;
                                      });
                                      _inputFocusNode.unfocus();
                                    },
                                  ),
                              ],
                            );
                            if (isDesktopMac)
                              return row; // no extra background on desktop
                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: row,
                            );
                          }),
                        );
                      },
                    ),
                  ),

                  // 发送按钮（有条件显示）
                  if (_showSendButton) const SizedBox(width: 8),
                  if (_showSendButton)
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/app_icons/svg/send.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              AppColors.textWhite,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // 结束 Column.children
            ],
          ),
        ),
      ),
    );
  }

  // 构建功能选择器组件（替代底部弹窗）
  Widget _buildMoreOptionsWidget() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1,
        children: [
          _buildMoreOption(
            icon: Icons.photo_library,
            label: '相册',
            onTap: () {
              setState(() {
                _showMoreOptions = false;
              });
              _pickAndSendImage(ImageSource.gallery);
            },
          ),
          _buildMoreOption(
            icon: Icons.camera_alt,
            label: '拍照',
            onTap: () {
              setState(() {
                _showMoreOptions = false;
              });
              _pickAndSendImage(ImageSource.camera);
            },
          ),
          _buildMoreOption(
            icon: Icons.mic,
            label: '语音',
            onTap: () {
              setState(() {
                _showMoreOptions = false;
              });
              // TODO: 语音消息
            },
          ),
          _buildMoreOption(
            icon: Icons.location_on,
            label: '位置',
            onTap: () {
              setState(() {
                _showMoreOptions = false;
              });
              final path =
                  '/send-location/${widget.contactId}${widget.isGroup ? '?type=group' : ''}';
              context.push(path);
            },
          ),
          _buildMoreOption(
            icon: Icons.favorite_border,
            label: '收藏',
            onTap: () {
              setState(() {
                _showMoreOptions = false;
              });
              _showFavoritesSheet();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Desktop toolbar icon widget
  Widget _desktopToolbarIcon(
      {Key? key,
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  void _toggleDesktopEmojiPanel() {
    final bool isMac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    if (!isMac) return;
    if (_desktopEmojiVisible) {
      Navigator.of(context, rootNavigator: true).maybePop();
      setState(() => _desktopEmojiVisible = false);
      return;
    }
    _inputFocusNode.unfocus();
    setState(() => _desktopEmojiVisible = true);

    final RenderBox iconBox =
        _emojiIconKey.currentContext!.findRenderObject() as RenderBox;
    final Offset iconTopLeft = iconBox.localToGlobal(Offset.zero);
    final RenderBox inputBox =
        _inputAreaKey.currentContext!.findRenderObject() as RenderBox;
    final Offset inputTopLeft = inputBox.localToGlobal(Offset.zero);
    final Size screen = MediaQuery.of(context).size;

    const double cardW = 420;
    const double cardH = 300;
    final double left = iconTopLeft.dx.clamp(12.0, screen.width - cardW - 12);
    final double top =
        (inputTopLeft.dy - cardH).clamp(80.0, screen.height - cardH - 80);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: 'emoji_panel',
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (_, __, ___) {
        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            child: _GlassCard(
              width: cardW,
              height: cardH,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: EmojiPicker(
                  onEmojiSelected: (emoji) {
                    _messageController.text += emoji;
                    _messageController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _messageController.text.length),
                    );
                  },
                ),
              ),
            ),
          ),
        ]);
      },
    ).then((_) => setState(() => _desktopEmojiVisible = false));
  }

  void _showFavoritesSheet() {
    // 打开弹窗前尝试加载收藏（仅在移动端触发，避免影响桌面/Web 行为）
    try {
      final bool isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);
      if (isMobile) {
        final auth = context.read<AuthProvider>();
        final uid = auth.user?.id;
        if (uid != null) {
          // 异步加载，不阻塞弹窗
          context.read<FavoriteProvider>().loadFavorites(uid);
        }
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 顶部拖拽条
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '我的收藏',
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 收藏内容列表
            Expanded(
              child: Consumer<FavoriteProvider>(
                builder: (context, provider, _) {
                  final favorites = provider.favorites;
                  if (provider.isLoading) {
                    return const Center(
                        child: SizedBox(
                            height: 28, child: LinkMeLoader(fontSize: 18)));
                  }

                  if (favorites.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无收藏内容',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final favorite = favorites[index];
                      return _buildFavoriteItem(favorite);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(Favorite favorite) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FavoriteDisplay(
        favorite: favorite,
        padding: const EdgeInsets.all(12),
        trailing: TextButton(
          onPressed: () => _sendFavoriteContent(favorite),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle:
                AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
          child: const Text('发送'),
        ),
      ),
    );
  }

  Future<void> _sendFavoriteContent(Favorite favorite) async {
    Navigator.pop(context);
    _inputFocusNode.unfocus();
    final payload = _composeFavoriteMessage(favorite);
    await _sendTextContent(payload);
    if (mounted) {
      context.showSuccessToast('收藏内容已发送', duration: const Duration(seconds: 1));
    }
  }

  String _composeFavoriteMessage(Favorite favorite) {
    final List<String> parts = [];
    switch (favorite.type) {
      case FavoriteType.link:
        final title = (favorite.title?.trim().isNotEmpty ?? false)
            ? favorite.title!.trim()
            : favorite.content.trim();
        if (title.isNotEmpty) parts.add(title);
        final link = favorite.linkUrl?.trim() ?? '';
        if (link.isNotEmpty) parts.add(link);
        final desc = favorite.description?.trim() ?? '';
        if (desc.isNotEmpty) parts.add(desc);
        break;
      case FavoriteType.text:
      case FavoriteType.message:
      default:
        parts.add(favorite.content.trim());
        break;
    }
    return parts.where((e) => e.isNotEmpty).join('\n');
  }

  void _showMessageMenu(Message message, bool isFromMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 消息操作选项
            _buildMenuOption(
              icon: Icons.content_copy,
              title: '复制',
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),

            _buildMenuOption(
              icon: Icons.star_outline,
              title: '收藏',
              onTap: () {
                Navigator.pop(context);
                _favoriteMessage(message);
              },
            ),

            _buildMenuOption(
              icon: Icons.push_pin_outlined,
              title: message.isPinned ? '取消置顶' : '置顶',
              onTap: () {
                Navigator.pop(context);
                _togglePinMessage(message);
              },
            ),

            _buildMenuOption(
              icon: Icons.delete_outline,
              title: '删除',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(
        title,
        style: TextStyle(color: color ?? AppColors.textPrimary),
      ),
      onTap: onTap,
    );
  }

  // 新UI：仿系统气泡样式的操作面板
  void _showMessagePopover(Message message, bool isFromMe) {
    final pos = _lastLongPressGlobalPos ??
        Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height - 200,
        );
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchor = overlay.globalToLocal(pos);

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black38,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, _, __) {
        return Stack(
          children: [
            Positioned(
              left: anchor.dx
                  .clamp(12, MediaQuery.of(context).size.width - 12 - 300),
              top: (anchor.dy - 90)
                  .clamp(80, MediaQuery.of(context).size.height - 160),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  // 让父容器尺寸由内容决定，仅限制最大宽度
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 20,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 14, // 子项之间的水平间距
                    runSpacing: 12, // 行与行的间距
                    children: [
                      _buildActionIcon(
                        icon: Icons.copy,
                        label: '复制',
                        onTap: () {
                          Navigator.pop(context);
                          _copyMessage(message);
                        },
                      ),
                      _buildActionIcon(
                        icon: Icons.reply,
                        label: '回复',
                        onTap: () {
                          Navigator.pop(context);
                          _startReply(message);
                        },
                      ),
                      _buildActionIcon(
                        icon: Icons.star_border,
                        label: '收藏',
                        onTap: () {
                          Navigator.pop(context);
                          _favoriteMessage(message);
                        },
                      ),
                      _buildActionIcon(
                        icon: message.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        label: message.isPinned ? '取消置顶' : '置顶',
                        onTap: () {
                          Navigator.pop(context);
                          _togglePinMessage(message);
                        },
                      ),
                      if (isFromMe)
                        _buildActionIcon(
                          icon: Icons.undo,
                          label: '撤回',
                          onTap: () {
                            Navigator.pop(context);
                            _recallMessage(message);
                          },
                        ),
                      _buildActionIcon(
                        icon: Icons.delete_outline,
                        label: '删除',
                        onTap: () {
                          Navigator.pop(context);
                          _deleteMessageForMe(message);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 桌面端专用：右键上下文菜单（竖向列表 + 浅粉背景）。
  void _showDesktopContextMenu(
      Message message, bool isFromMe, Offset globalPos) {
    final Size screen = MediaQuery.of(context).size;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset anchor = overlay.globalToLocal(globalPos);

    const double menuWidth = 132; // 更紧凑再缩小
    const double padding = 12;
    final double left =
        (anchor.dx + 8).clamp(padding, screen.width - menuWidth - padding);
    final double top = (anchor.dy - 8).clamp(80, screen.height - 280);

    final List<Map<String, dynamic>> actions = [
      {
        'icon': Icons.copy_all_rounded,
        'label': '复制',
        'onTap': () => _copyMessage(message)
      },
      {
        'icon': Icons.reply_rounded,
        'label': '回复',
        'onTap': () => _startReply(message)
      },
      {
        'icon': Icons.bookmark_border_rounded,
        'label': '收藏',
        'onTap': () => _favoriteMessage(message)
      },
      {
        'icon': message.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        'label': message.isPinned ? '取消置顶' : '置顶',
        'onTap': () => _togglePinMessage(message),
      },
      if (isFromMe)
        {
          'icon': Icons.undo_rounded,
          'label': '撤回',
          'onTap': () => _recallMessage(message)
        },
      {
        'icon': Icons.delete_outline_rounded,
        'label': '删除',
        'onTap': () => _deleteMessageForMe(message)
      },
    ];

    showGeneralDialog(
      context: context,
      barrierLabel: 'ctx',
      barrierDismissible: true,
      barrierColor: Colors.transparent, // 桌面端尽量不遮罩
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (_, __, ___) {
        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  // 更浅、更透的浅粉背景
                  color: const Color(0xCCFFF5F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE3F0)),
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.shadowMedium,
                        blurRadius: 10,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      _buildDesktopMenuItem(
                        actions[i]['icon'] as IconData,
                        actions[i]['label'] as String,
                        actions[i]['onTap'] as VoidCallback,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  // 单个菜单项（浅粉背景，悬浮高亮）
  Widget _buildDesktopMenuItem(
      IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      hoverColor: const Color(0x1F000000), // 加深的浅灰悬停背景（约12%不透明度）
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // 居中一行内容
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62, // 每个功能项固定宽度，父容器跟随内容自适应
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  void _copyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.content));
    // 改为顶部统一 Toast，避免底部 SnackBar 遮挡输入框
    context.showSuccessToast('消息已复制');
  }

  Future<void> _favoriteMessage(Message message) async {
    final favoriteProvider = context.read<FavoriteProvider>();
    final auth = context.read<AuthProvider>();
    final int? myId = auth.user?.id;
    if (myId == null) {
      if (mounted) context.showErrorToast('未登录，无法收藏');
      return;
    }
    // 私聊：目标应为对方用户；群聊：目标为群ID
    final bool isGroupMsg = (message.groupId != null);
    final int? targetUserId = isGroupMsg
        ? null
        : ((message.senderId == myId) ? message.receiverId : message.senderId);
    final int? targetGroupId = isGroupMsg ? message.groupId : null;

    final conversationName = _currentConversation?.displayName ??
        (widget.isGroup ? '群聊' : message.senderName);
    final conversationAvatar = _currentConversation?.displayAvatar ??
        (widget.isGroup ? null : message.senderAvatar);
    final metadata = {
      'senderId': message.senderId,
      'senderName': message.senderName,
      'senderAvatar': message.senderAvatar,
      'timestamp': message.createdAt.toIso8601String(),
      'conversationName': conversationName,
      'conversationAvatar': conversationAvatar,
      'conversationType': widget.isGroup ? 'GROUP' : 'PRIVATE',
      'messagePreview': message.content,
    };

    final success = await favoriteProvider.favoriteMessage(
      ownerId: myId,
      messageId: message.id,
      content: message.content,
      targetUserId: targetUserId,
      targetGroupId: targetGroupId,
      targetName: conversationName,
      targetAvatar: conversationAvatar,
      metadata: metadata,
    );

    if (mounted) {
      if (success) {
        context.showSuccessToast('消息已收藏');
      } else {
        context.showErrorToast('收藏失败');
      }
    }
  }

  Future<void> _togglePinMessage(Message message) async {
    final pinnedProvider = context.read<PinnedMessageProvider>();
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;

    if (message.isPinned) {
      // 取消置顶
      final success = await pinnedProvider.unpinMessage(
          widget.contactId, message.id.toString());
      if (success) {
        // 同步更新聊天消息列表中的状态
        final messageIndex = _messages.indexWhere((m) => m.id == message.id);
        if (messageIndex != -1) {
          setState(() {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              isPinned: false,
              pinnedAt: null,
              pinnedById: null,
            );
          });
        }

        // 也更新ChatProvider中的状态
        await chatProvider.unpinMessage(message.id);

        if (mounted) {
          context.showSuccessToast('已取消置顶');
        }
      } else if (mounted) {
        context.showErrorToast('取消置顶失败');
      }
    } else {
      // 置顶消息
      final success =
          await pinnedProvider.pinMessage(widget.contactId, message);
      if (success) {
        // 同步更新聊天消息列表中的状态
        final messageIndex = _messages.indexWhere((m) => m.id == message.id);
        if (messageIndex != -1) {
          setState(() {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              isPinned: true,
              pinnedAt: DateTime.now(),
              pinnedById: currentUserId,
            );
          });
        }

        // 也更新ChatProvider中的状态
        await chatProvider.pinMessage(message);

        if (mounted) {
          context.showSuccessToast('消息已置顶');
        }
      } else if (mounted) {
        context.showErrorToast('置顶失败');
      }
    }
  }

  // 处理置顶消息状态变化
  void _onPinnedMessageChanged() {
    // 重新加载消息列表以同步状态
    _loadChatData();
  }

  void _startReply(Message message) {
    setState(() {
      _replyingTo = message;
    });
    _inputFocusNode.requestFocus();
  }

  Future<void> _deleteMessageForMe(Message message) async {
    // 删除是“仅对自己隐藏”，允许删除好友消息
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('删除后仅对你不可见，对方仍可见。确定删除？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;

    final provider = context.read<ChatProvider>();
    final me = context.read<AuthProvider>().user?.id ?? 0;
    final ok = await provider.deleteMessageForMe(
      messageId: message.id,
      conversationId: message.conversationId,
      currentUserId: me,
    );
    if (ok) {
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
    }
    if (ok && mounted) context.showSuccessToast('已删除');
    if (!ok && mounted) context.showErrorToast('删除失败');
  }

  Future<void> _recallMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤回消息'),
        content: const Text('撤回后双方都将看不到该消息。确定撤回？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('撤回')),
        ],
      ),
    );
    if (confirmed != true) return;

    final provider = context.read<ChatProvider>();
    final ok = await provider.recallMessage(
        messageId: message.id, conversationId: message.conversationId);
    if (ok) {
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
    }
    if (ok && mounted) context.showSuccessToast('已撤回');
    if (!ok && mounted) context.showErrorToast('撤回失败');
  }

  // 打开图片查看器
  void _openImageViewer(String imageUrl) {
    final isLocalFile =
        !imageUrl.startsWith('http://') && !imageUrl.startsWith('https://');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewer(
          imageUrl: imageUrl,
          isLocalFile: isLocalFile,
        ),
      ),
    );
  }

  /// features/chat/chat_detail_screen.dart | _startCall | 发起通话
  /// 作用：从聊天页面直接发起语音或视频通话
  /// @param callType 通话类型（voice/video）
  void _startCall(CallType callType) {
    // 调试日志：记录发起通话的类型
    debugPrint('[聊天详情页] 发起通话，类型: $callType (${callType.name})');
    
    // 检查是否已在通话中
    final callProvider = context.read<CallProvider>();
    if (callProvider.isInCall) {
      UnifiedToast.showError(context, '您当前正在通话中');
      return;
    }
    
    // 获取对方信息
    CallUserInfo? peerUser;
    CallGroupInfo? groupInfo;
    
    if (widget.isGroup) {
      // 群聊通话
      if (_currentConversation != null) {
        groupInfo = CallGroupInfo(
          id: int.tryParse(widget.contactId) ?? 0,
          name: _currentConversation!.displayName,
          avatar: _currentConversation!.displayAvatar,
        );
      }
    } else {
      // 私聊通话
      if (_currentConversation != null) {
        peerUser = CallUserInfo(
          id: int.tryParse(widget.contactId) ?? 0,
          nickname: _currentConversation!.displayName,
          avatar: _currentConversation!.displayAvatar,
        );
      }
    }
    
    // 跳转到通话界面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          callType: callType,
          roomType: widget.isGroup ? CallRoomType.group : CallRoomType.private,
          peerUser: peerUser,
          groupInfo: groupInfo,
          calleeId: widget.isGroup ? null : int.tryParse(widget.contactId),
          groupId: widget.isGroup ? int.tryParse(widget.contactId) : null,
        ),
      ),
    );
  }

  // 处理菜单操作
  void _handleMenuAction(String action) {
    switch (action) {
      case 'profile':
        if (widget.isGroup) {
          // 跳转到群聊信息页面
          context.push('/group-info/${widget.contactId}');
        } else {
          // 跳转到用户资料页面
          context.push('/friend-profile/${widget.contactId}');
        }
        break;
      case 'clear':
        _clearChatHistory();
        break;
      case 'block':
        if (!widget.isGroup) {
          _blockUser();
        }
        break;
      case 'mute':
        if (widget.isGroup) {
          _toggleMute();
        }
        break;
      case 'leave':
        if (widget.isGroup) {
          _leaveGroup();
        }
        break;
    }
  }

  // 清空聊天记录
  void _clearChatHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现清空聊天记录
              context.showSuccessToast('聊天记录已清空');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  // 拉黑用户
  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拉黑用户'),
        content: const Text('确定要拉黑此用户吗？拉黑后将无法收到对方的消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现拉黑用户
              context.showSuccessToast('用户已拉黑');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('拉黑'),
          ),
        ],
      ),
    );
  }

  // 切换消息免打扰
  void _toggleMute() {
    // TODO: 实现消息免打扰功能
    context.showInfoToast('消息免打扰功能开发中');
  }

  // 退出群聊
  void _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出群聊'),
        content: const Text('确定要退出这个群聊吗？退出后将无法接收群消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = context.read<AuthProvider>();
        final chatProvider = context.read<ChatProvider>();

        if (authProvider.user != null) {
          final success = await chatProvider.leaveGroup(
            int.parse(widget.contactId),
            authProvider.user!.id,
          );

          if (success) {
            context.showSuccessToast('已退出群聊');
            if (mounted) {
              context.go('/'); // 返回主页
            }
          } else {
            context.showErrorToast(chatProvider.errorMessage ?? '退出群聊失败');
          }
        }
      } catch (e) {
        context.showErrorToast('退出群聊失败: $e');
      }
    }
  }

  // 显示情绪监测说明弹窗
  void _showEmotionExplanation(Message message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text('为什么会看到'),
            ],
          ),
          content: const Text(
            '系统监测到该好友在与多名用户聊天中提及强烈消极情绪，为避免自杀行为执行，建议及时关注和疏导！',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }
}

// Frosted glass card for desktop emoji panel
class _GlassCard extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;
  const _GlassCard(
      {required this.width, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            border: Border.all(color: const Color(0x1F000000)),
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    );
  }
}
