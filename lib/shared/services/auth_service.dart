import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/dto/login_request.dart';
import '../models/dto/register_request.dart';
import '../models/dto/login_response.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';

enum EmailCodeScene {
  register('REGISTER'),
  login('LOGIN'),
  passwordReset('PASSWORD_RESET'),
  accountDelete('ACCOUNT_DELETE');

  final String apiValue;
  const EmailCodeScene(this.apiValue);
}

enum EmailLoginType { code, password }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _apiClient = ApiClient();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // 登录
  Future<ApiResponse<LoginResponse>> login(
      String username, String password) async {
    final request = LoginRequest(
      username: username,
      password: password,
    );

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.login,
      data: request.toJson(),
    );
    return _handleLoginLikeResponse(response, '登录');
  }

  // 注册
  Future<ApiResponse<LoginResponse>> register({
    required String username,
    required String email,
    required String password,
    String? nickname,
    String? phone,
  }) async {
    final request = RegisterRequest(
      username: username,
      email: email,
      password: password,
      nickname: nickname,
      phone: phone,
    );

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.register,
      data: request.toJson(),
    );

    if (response.isSuccess && response.data == null) {
      return ApiResponse.success(response.message);
    }
    return _handleLoginLikeResponse(response, '注册');
  }

  // 更新用户资料
  Future<ApiResponse<User>> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
    String? phone,
  }) async {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (signature != null) data['signature'] = signature;
    if (avatar != null) data['avatar'] = avatar;
    if (phone != null) data['phone'] = phone;

    final response = await _apiClient.put<Map<String, dynamic>>(
      ApiConfig.userProfile,
      data: data,
    );

    if (response.isSuccess && response.data != null) {
      try {
        final userData = response.data!;
        var user = User.fromJson(userData);

        // 有些后端实现可能不会在更新资料接口中返回 status 字段，
        // 或者返回为 null/空串，导致前端解析为离线。
        // 这里做一次兜底：若返回缺失，则沿用本地已登录用户的状态。
        final rawStatus = userData['status'];
        if (rawStatus == null || rawStatus.toString().isEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final cached = prefs.getString(_userKey);
            if (cached != null && cached.isNotEmpty) {
              final prev =
                  User.fromJson(json.decode(cached) as Map<String, dynamic>);
              user = user.copyWith(status: prev.status);
            }
          } catch (_) {
            // 忽略本地读取失败
          }
        }

        // 更新本地存储的用户信息
        await _saveUserData(user);

        return ApiResponse.success(response.message, user);
      } catch (e) {
        return ApiResponse.error('用户资料解析失败: $e');
      }
    }

    return ApiResponse.error(response.message);
  }

  // 登出
  Future<void> logout() async {
    // 尽量彻底地清理本地登录态，兼容历史/其他端可能写入的键名
    final prefs = await SharedPreferences.getInstance();

    // 当前Flutter端使用的键
    const currentKeys = <String>{_tokenKey, _userKey};
    // 早期或其他实现可能使用过的键（例如早期Flutter/web共用约定）
    const legacyKeys = <String>{'token', 'user'};

    for (final k in {...currentKeys, ...legacyKeys}) {
      try {
        await prefs.remove(k);
      } catch (_) {
        // 忽略单个键清理失败，继续其他键
      }
    }

    // 同步清理内存中的认证头
    _apiClient.setToken(null);
  }

  // 从本地存储加载认证信息
  Future<LoginResponse?> loadAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);

      if (token != null && userJson != null) {
        final userData = json.decode(userJson);
        final user = User.fromJson(userData);

        // 设置API客户端的token
        _apiClient.setToken(token);

        return LoginResponse(
          token: token,
          user: user,
          message: '从本地加载成功',
        );
      }
    } catch (e) {
      // 如果加载失败，清除可能损坏的数据
      await logout();
    }

    return null;
  }

  // 检查是否已登录
  Future<bool> isLoggedIn() async {
    final authData = await loadAuthData();
    return authData != null;
  }

  // 保存认证数据到本地
  Future<void> _saveAuthData(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await _saveUserData(user);
  }

  // 保存用户数据到本地
  Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
  }

  // 获取当前token
  String? getCurrentToken() {
    return _apiClient.token;
  }

  Future<ApiResponse<LoginResponse>> _handleLoginLikeResponse(
    ApiResponse<Map<String, dynamic>> response,
    String label,
  ) async {
    print("打印数据");
    print(response);
    if (response.isSuccess && response.data != null) {
      try {
        final loginResponse = _mapToLoginResponse(response.data!);
        if (loginResponse == null) {
          return ApiResponse.error('$label数据解析失败');
        }
        await _saveAuthData(loginResponse.token, loginResponse.user);
        _apiClient.setToken(loginResponse.token);
        return ApiResponse.success(response.message, loginResponse);
      } catch (e) {
        return ApiResponse.error('$label数据解析失败: $e');
      }
    }
    return ApiResponse.error(response.message);
  }

  LoginResponse? _mapToLoginResponse(Map<String, dynamic> payload) {
    final token = payload['token'];
    final userData = payload['user'];
    if (token is String && userData is Map<String, dynamic>) {
      return LoginResponse(
        token: token,
        user: User.fromJson(userData),
        message: payload['message']?.toString(),
      );
    }
    return null;
  }

  Future<ApiResponse<Map<String, dynamic>>> requestEmailCode(
    String email, {
    EmailCodeScene scene = EmailCodeScene.register,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailRequestCode,
      data: {
        'email': email,
        'scene': scene.apiValue,
      },
    );
  }

  Future<ApiResponse<LoginResponse>> registerByEmail({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailRegister,
      data: {'email': email, 'code': code},
    );
    return _handleLoginLikeResponse(response, '注册');
  }

  Future<ApiResponse<LoginResponse>> loginByEmail({
    required String email,
    EmailLoginType loginType = EmailLoginType.password,
    String? code,
    String? password,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'loginType': loginType.name.toUpperCase(),
    };
    if (loginType == EmailLoginType.code) {
      payload['code'] = code;
    } else {
      payload['password'] = password;
    }
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.emailLogin,
      data: payload,
    );
    return _handleLoginLikeResponse(response, '登录');
  }

  Future<ApiResponse<User>> completeProfile({
    required String nickname,
    required String avatar,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.completeProfile,
      data: {
        'nickname': nickname,
        'avatar': avatar,
      },
    );
    if (response.isSuccess && response.data != null) {
      try {
        final user = User.fromJson(response.data!);
        await _saveUserData(user);
        return ApiResponse.success(response.message, user);
      } catch (e) {
        return ApiResponse.error('资料更新解析失败: $e');
      }
    }
    return ApiResponse.error(response.message);
  }

  Future<ApiResponse<User>> setupPassword(String password) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.passwordSetup,
      data: {'password': password},
    );
    if (response.isSuccess && response.data != null) {
      try {
        final user = User.fromJson(response.data!);
        await _saveUserData(user);
        return ApiResponse.success(response.message, user);
      } catch (e) {
        return ApiResponse.error('密码设置结果解析失败: $e');
      }
    }
    return ApiResponse.error(response.message);
  }

  Future<ApiResponse<void>> deleteAccount({
    required String code,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'code': code,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    return _apiClient.post<void>(
      ApiConfig.accountDeletion,
      data: payload,
    );
  }


  // 获取当前用户ID (从本地存储)
  Future<int?> getCurrentUserId() async {
    final authData = await loadAuthData();
    return authData?.user.id;
  }
}
