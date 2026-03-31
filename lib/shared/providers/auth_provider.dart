import 'dart:async';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/dto/login_response.dart';
import '../services/auth_service.dart';
import 'chat_provider.dart';
import '../../features/notes/providers/notes_provider.dart';
import 'zennotes_invitation_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/desktop/window_control.dart';
import '../../core/network/api_response.dart';

enum OnboardingStage { profile, password, done }

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  // 区分“初始化阶段”的加载状态，避免普通更新触发整个App重建
  bool _isInitializing = false;
  String? _errorMessage;
  bool _passwordStepAcknowledged = false;
  bool _navigationLocked = false;
  // 仅用于路由守卫监听的登录状态变更（登录/退出/自动恢复），避免普通资料更新触发路由重建
  final ValueNotifier<int> _authStateTick = ValueNotifier<int>(0);
  // One-shot banner/notice message to display right after routing (e.g., banned account reason)
  String? _pendingBannerMessage;

  final AuthService _authService = AuthService();
  ChatProvider? _chatProvider;
  NotesProvider? _notesProvider;
  ZenNotesInvitationProvider? _zenNotesInvitationProvider;

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null && _token != null;
  bool get isProfileCompleted => _user?.profileCompleted ?? false;
  bool get isPasswordSet => _user?.passwordSet ?? false;
  bool get isEmailVerified => _user?.emailVerified ?? false;
  bool get passwordStepAcknowledged => _passwordStepAcknowledged;
  bool get navigationLocked => _navigationLocked;
  OnboardingStage get onboardingStage {
    if (!isLoggedIn) return OnboardingStage.done;
    if (!isProfileCompleted) return OnboardingStage.profile;
    if (!isPasswordSet && !_passwordStepAcknowledged) {
      return OnboardingStage.password;
    }
    return OnboardingStage.done;
  }

  Listenable get authStateListenable => _authStateTick;

  // Take and clear one-time pending banner message
  String? takePendingBanner() {
    final m = _pendingBannerMessage;
    _pendingBannerMessage = null;
    return m;
  }

  void _bumpAuthState() {
    _authStateTick.value++;
  }

  // 提供更新用户对象的简便方法（仅本地内存，不触持久化），用于小范围 UI 即时反馈
  void setUser(User newUser) {
    _user = newUser;
    notifyListeners();
  }

  void setNavigationLock(bool value) {
    if (_navigationLocked == value) return;
    _navigationLocked = value;
    notifyListeners();
  }

  // 设置ChatProvider引用
  void setChatProvider(ChatProvider chatProvider) {
    _chatProvider = chatProvider;
  }

  // 设置NotesProvider引用
  void setNotesProvider(NotesProvider notesProvider) {
    _notesProvider = notesProvider;
  }

  // 设置ZenNotesInvitationProvider引用
  void setZenNotesInvitationProvider(ZenNotesInvitationProvider provider) {
    _zenNotesInvitationProvider = provider;
  }

  // 延迟初始化聊天功能 - 添加详细日志
  void _scheduleChatInitialization() {
    print('🔗 _scheduleChatInitialization 被调用');
    print('🔍 检查条件: _chatProvider != null = ${_chatProvider != null}');
    print('🔍 检查条件: _user != null = ${_user != null}');
    print('🔍 检查条件: _token != null = ${_token != null}');

    if (_chatProvider != null && _user != null && _token != null) {
      print('✅ 聊天初始化条件满足，用户ID: ${_user!.id}');
      print('🔗 调度聊天功能初始化...');

      // 确保只初始化一次，避免重复加载导致会话重复
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          print('🔗 ChatProvider.initializeIfNeeded 开始');
          await _chatProvider!.initializeIfNeeded(_user!.id, _token!);
          print('✅ ChatProvider.initializeIfNeeded 完成');
          // 登录成功后（桌面端）启用可缩放主页窗口与最小尺寸
          await WindowControl.enableHomeWindow();
        } catch (e) {
          print('❌ 聊天功能初始化失败: $e');
        }
      });
    } else {
      print('❌ 聊天功能初始化条件不满足');
    }
    // if (_chatProvider != null && _user != null && _token != null) {
    //   print('🔗 调度聊天功能初始化...');

    //   // 更长的延迟，确保UI完全加载完成
    //   Future.delayed(const Duration(seconds: 2), () async {
    //     try {
    //       print('🔗 开始初始化聊天功能...');

    //       // 分步骤初始化，每步之间有间隔
    //       await _chatProvider!.fetchFriends(_user!.id);
    //       await Future.delayed(const Duration(milliseconds: 200));

    //       await _chatProvider!.fetchMessages(_user!.id);
    //       await Future.delayed(const Duration(milliseconds: 200));

    //       await _chatProvider!.getPendingRequests(_user!.id);
    //       await Future.delayed(const Duration(milliseconds: 200));

    //       // 最后连接WebSocket
    //       await _chatProvider!.connectWebSocket(_user!.id, _token!);

    //       print('✅ 聊天功能初始化完成');
    //     } catch (e) {
    //       print('⚠️ 聊天功能初始化失败: $e');
    //       // 初始化失败不影响登录状态
    //     }
    //   });
    // }
  }

  // Initialize from storage
  Future<void> initialize() async {
    // 仅用于冷启动读取本地存储时的全局等待，不影响路由状态
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authData = await _authService.loadAuthData();
      if (authData != null) {
        _user = authData.user;
        _token = authData.token;

        // 确保ApiClient的token被正确设置
        ApiClient().setToken(_token);

        print('📱 从本地存储成功加载用户数据: ${_user?.username}');
        print('🔐 已重新设置ApiClient token: ${_token != null}');

        // 自动登录后也需要初始化聊天功能
        _scheduleChatInitialization();

        // 初始化笔记Provider（从本地存储恢复登录状态时）
        if (_notesProvider != null && _user != null) {
          _notesProvider!.setUserId(_user!.id);
        }

        // 初始化ZenNotes邀请Provider（从本地存储恢复登录状态时）
        if (_zenNotesInvitationProvider != null && _user != null) {
          _zenNotesInvitationProvider!.setUserId(_user!.id);
        }

        await _syncPasswordStepAck();

        // 通知路由：认证状态已可用
        _bumpAuthState();
      } else {
        print('📱 本地存储中没有找到用户数据');
        _bumpAuthState();
      }
    } catch (e) {
      _errorMessage = '初始化失败: $e';
      print('❌ initialize() 异常: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _syncPasswordStepAck() async {
    final currentUser = _user;
    if (currentUser == null) {
      _passwordStepAcknowledged = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final ack = prefs.getBool(_passwordAckKey(currentUser.id)) ?? false;
    _passwordStepAcknowledged = ack;
  }

  Future<void> _setPasswordAck(bool value) async {
    final currentUser = _user;
    if (currentUser == null) {
      _passwordStepAcknowledged = value;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_passwordAckKey(currentUser.id), value);
    _passwordStepAcknowledged = value;
  }

  String _passwordAckKey(int userId) => 'password_step_ack_$userId';

  // Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 开始登录流程，用户名: $username');
      final response = await _authService.login(username, password);
      final ok = await _handleLoginResponse(response);
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _errorMessage = '登录失败: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ 登录异常: $e');
      print('❌ 登录异常详细信息: ${e.runtimeType} - $e');
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? nickname,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        username: username,
        email: email,
        password: password,
        nickname: nickname,
        phone: phone,
      );
      if (response.isSuccess && response.data != null) {
        final ok = await _handleLoginResponse(response);
        _isLoading = false;
        notifyListeners();
        return ok;
      }
      if (response.isSuccess) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '注册失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<EmailCodeSendResult> requestEmailCode(
    String email, {
    EmailCodeScene scene = EmailCodeScene.register,
  }) async {
    try {
      final response = await _authService.requestEmailCode(email, scene: scene);
      if (response.isSuccess) {
        final debugCode =
            response.data != null && response.data!['debugCode'] is String
                ? response.data!['debugCode'] as String
                : null;
        return EmailCodeSendResult(
          success: true,
          message: response.message,
          debugCode: debugCode,
        );
      }
      _errorMessage = response.message;
      notifyListeners();
      return EmailCodeSendResult(success: false, message: response.message);
    } catch (e) {
      final msg = '发送验证码失败: $e';
      _errorMessage = msg;
      notifyListeners();
      return EmailCodeSendResult(success: false, message: msg);
    }
  }

  Future<EmailCodeSendResult> requestAccountDeletionCode() async {
    final email = _user?.email;
    final sanitized = email?.trim();
    if (sanitized == null || sanitized.isEmpty) {
      const msg = '当前账号未绑定邮箱，无法发送验证码';
      _errorMessage = msg;
      notifyListeners();
      return const EmailCodeSendResult(success: false, message: msg);
    }
    return requestEmailCode(sanitized, scene: EmailCodeScene.accountDelete);
  }

  Future<bool> registerWithEmailCode({
    required String email,
    required String code,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _authService.registerByEmail(
        email: email,
        code: code,
      );
      final ok = await _handleLoginResponse(response);
      _isLoading = false;
      notifyListeners();
      if (ok) {
        await _setPasswordAck(false);
      }
      return ok;
    } catch (e) {
      _errorMessage = '注册失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithEmailCode({
    required String email,
    required String code,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _authService.loginByEmail(
        email: email,
        loginType: EmailLoginType.code,
        code: code,
      );
      final ok = await _handleLoginResponse(response);
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _errorMessage = '登录失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _authService.loginByEmail(
        email: email,
        loginType: EmailLoginType.password,
        password: password,
      );
      final ok = await _handleLoginResponse(response);
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _errorMessage = '登录失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🔄 开始登出...');

      // 断开WebSocket连接
      if (_chatProvider != null) {
        await _chatProvider!.disconnect();
        _chatProvider!.reset();
        print('🔌 WebSocket已断开');
      }

      await _authService.logout();

      // 清理内存状态
      _user = null;
      _token = null;
      _errorMessage = null;
      _passwordStepAcknowledged = false;

      // 清理ApiClient的token
      ApiClient().setToken(null);

      // 桌面端：恢复登录/注册窗口的固定大小与不可缩放
      await WindowControl.enforceAuthWindow();

      print('✅ 登出完成');
      // 通知路由登录状态已变更
      _bumpAuthState();
    } catch (e) {
      print('❌ 登出失败: $e');
      _errorMessage = '登出失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount({
    required String code,
    String? reason,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response =
          await _authService.deleteAccount(code: code.trim(), reason: reason);
      if (!response.isSuccess) {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      await logout();
      return true;
    } catch (e) {
      _errorMessage = '账号注销失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
    String? phone,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.updateProfile(
        nickname: nickname,
        signature: signature,
        avatar: avatar,
        phone: phone,
      );

      if (response.isSuccess && response.data != null) {
        _user = response.data!;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = '更新资料失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeProfileStep({
    required String nickname,
    required String avatar,
  }) async {
    if (_user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _authService.completeProfile(
        nickname: nickname,
        avatar: avatar,
      );
      if (response.isSuccess && response.data != null) {
        _user = response.data;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '更新资料失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setupPasswordStep(String password) async {
    if (_user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _authService.setupPassword(password);
      if (response.isSuccess && response.data != null) {
        _user = response.data;
        await _setPasswordAck(true);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '设置密码失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> skipPasswordStep() async {
    await _setPasswordAck(true);
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _handleLoginResponse(ApiResponse<LoginResponse> response) async {
    if (response.isSuccess && response.data != null) {
      await _applyLoginState(response.data!);
      return true;
    }
    _errorMessage = response.message;
    return false;
  }

  Future<void> _applyLoginState(LoginResponse data) async {
    _user = data.user;
    _token = data.token;
    ApiClient().setToken(_token);
    _prepareBanBanner(_user);
    _scheduleChatInitialization();
    // 初始化笔记Provider
    if (_notesProvider != null && _user != null) {
      _notesProvider!.setUserId(_user!.id);
    }
    // 初始化ZenNotes邀请Provider
    if (_zenNotesInvitationProvider != null && _user != null) {
      _zenNotesInvitationProvider!.setUserId(_user!.id);
    }
    await _syncPasswordStepAck();
    _bumpAuthState();
  }

  void _prepareBanBanner(User? user) {
    if (user == null) {
      _pendingBannerMessage = null;
      return;
    }
    try {
      final state = user.accountState?.toUpperCase();
      final isBanned = (user.isBanned == true) ||
          (state != null &&
              ['BANNED', 'DISABLED', 'SUSPENDED', 'BLOCKED'].contains(state));
      if (isBanned) {
        final reason = (user.banReason?.trim().isNotEmpty == true)
            ? user.banReason!.trim()
            : '管理员未填写原因';
        _pendingBannerMessage = '账户已封禁：$reason';
      } else {
        _pendingBannerMessage = null;
      }
    } catch (_) {}
  }
}

class EmailCodeSendResult {
  final bool success;
  final String message;
  final String? debugCode;

  const EmailCodeSendResult({
    required this.success,
    required this.message,
    this.debugCode,
  });
}
