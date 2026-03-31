import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_response.dart';
import 'server_health.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late Dio _dio;
  String? _token;

  // 公共访问器
  Dio get dio => _dio;
  
  // Token过期回调
  VoidCallback? onTokenExpired;

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
      sendTimeout: Duration(milliseconds: ApiConfig.sendTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // 强制使用IPv4，避免DNS解析问题
      extra: {
        'resolver': 'ipv4',
      },
    ));

    // 添加拦截器
    _dio.interceptors.add(_AuthInterceptor());
    _dio.interceptors.add(_LoggingInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());

    if (kDebugMode) {
      print('🌐 ApiClient 初始化完成: base=${_dio.options.baseUrl}');
      print('🌐 WebSocket 目标: ${ApiConfig.wsUrl}');
    }

    // 尝试从本地恢复token，防止应用冷启动时在AuthProvider尚未完成初始化前发起的请求401
    _restoreTokenIfAny();
  }

  Future<void> _restoreTokenIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString('auth_token');
      if (t != null && t.isNotEmpty) {
        setToken(t);
      }
    } catch (_) {
      // 忽略本地异常，按无token处理
    }
  }

  // 设置认证Token
  void setToken(String? token) {
    if (kDebugMode) {
      print('🔐 ApiClient.setToken 被调用: ${token != null ? "${token.substring(0, 10)}..." : "null"}');
    }
    _token = token;
    if (kDebugMode) {
      print('🔐 ApiClient._token 已设置: ${_token != null ? "${_token!.substring(0, 10)}..." : "null"}');
    }
    // 同步更新全局Header，防止在部分场景下残留旧的 Authorization
    try {
      if (_dio.options.headers.containsKey('Authorization')) {
        if (token == null || token.isEmpty) {
          _dio.options.headers.remove('Authorization');
        } else {
          _dio.options.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {
      // _dio 可能尚未初始化；静默忽略
    }
  }


  String? get token => _token;

  // GET请求
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  // POST请求
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  // PUT请求
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  // DELETE请求
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(path, queryParameters: queryParameters);
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  // 处理响应
  ApiResponse<T> _handleResponse<T>(
    Response response,
    T Function(dynamic)? fromJson,
  ) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      // 后端可达，标记为健康
      ServerHealth().setHealthy();
      final responseData = response.data;
      
      if (responseData is Map<String, dynamic>) {
        final success = responseData['success'] ?? true;
        String message = responseData['message']?.toString() ?? 'Success';
        final data = responseData['data'];
        final path = response.requestOptions.path;

        // 当登录接口以 200 返回但实际为封禁/禁用等逻辑错误时，强制补足前缀
        try {
          final isLogin = path.endsWith(ApiConfig.login) || path.contains('/auth/login');
          if (isLogin) {
            bool banned = false;
            bool parseBool(dynamic v) {
              if (v is bool) return v;
              if (v is num) return v != 0;
              if (v is String) {
                final s = v.toLowerCase();
                return s == 'true' || s == '1' || s == 'yes';
              }
              return false;
            }
            final b1 = responseData['isBanned'];
            final b2 = responseData['banned'];
            final b3 = responseData['disabled'];
            final b4 = responseData['suspended'];
            final b5 = responseData['is_banned'];
            final acc = responseData['accountStatus'] ?? responseData['account_state'] ?? responseData['accountState'] ?? responseData['status'];
            banned = parseBool(b1) || parseBool(b2) || parseBool(b3) || parseBool(b4) || parseBool(b5);
            if (!banned && acc is String) {
              final s = acc.toUpperCase();
              if (s == 'BANNED' || s == 'DISABLED' || s == 'SUSPENDED' || s == 'BLOCKED') banned = true;
            }
            // 一些实现会在 JSON 内提供 code
            final jsonCode = responseData['code'];
            if (!banned && jsonCode is num) {
              if (jsonCode.toInt() == 403 || jsonCode.toInt() == 423) banned = true;
            }
            // 登录失败（无 data 或 success=false）
            if (!success || data == null) {
              if (banned) {
                final reason = responseData['reason'] ?? responseData['banReason'] ?? responseData['detail'] ?? responseData['error'];
                final reasonText = (reason is String && reason.trim().isNotEmpty) ? reason.trim() : message;
                message = '账户已封禁：$reasonText';
              } else {
                // Fallback: 若后端仅返回了简短原因（如“涉黄”），无任何封禁字段，则尽力推断并补上前缀
                final m = message.trim();
                final lm = m.toLowerCase();
                final notBanHints = <String>['密码', 'pass', 'password', '用户名', '邮箱', '无效', '格式', '验证码', '错误', '失败', 'not'];
                final looksLikeBanReason = m.isNotEmpty && !notBanHints.any((w) => lm.contains(w));
                if (looksLikeBanReason) {
                  message = '账户已封禁：$m';
                }
              }
            }
          }
        } catch (_) {}

        T? parsedData;
        if (data != null && fromJson != null) {
          parsedData = fromJson(data);
        } else if (data is T) {
          parsedData = data;
        }

        return ApiResponse<T>(
          success: success,
          message: message,
          data: parsedData,
          code: response.statusCode,
        );
      }
    }

    return ApiResponse.error(
      'Unexpected response format',
      response.statusCode,
    );
  }

  // 处理错误
  ApiResponse<T> _handleError<T>(DioException error) {
    String message;
    int? code;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        message = '连接超时，请检查网络';
        ServerHealth().setError();
        break;
      case DioExceptionType.sendTimeout:
        message = '请求超时，请重试';
        break;
      case DioExceptionType.receiveTimeout:
        message = '响应超时，请重试';
        ServerHealth().setError();
        break;
      case DioExceptionType.badResponse:
        code = error.response?.statusCode;
        final responseData = error.response?.data;
        
        if (responseData is Map<String, dynamic>) {
          // Detect banned/disabled account result from backend
          bool isBanned = false;
          try {
            final b1 = responseData['isBanned'];
            final b2 = responseData['banned'];
            final b3 = responseData['disabled'];
            final b4 = responseData['suspended'];
            final b5 = responseData['is_banned'];
            final acc = responseData['accountStatus'] ?? responseData['account_state'] ?? responseData['accountState'] ?? responseData['status'];
            bool parseBool(dynamic v) {
              if (v is bool) return v;
              if (v is num) return v != 0;
              if (v is String) {
                final s = v.toLowerCase();
                return s == 'true' || s == '1' || s == 'yes';
              }
              return false;
            }
            isBanned = parseBool(b1) || parseBool(b2) || parseBool(b3) || parseBool(b4) || parseBool(b5);
            if (!isBanned && acc is String) {
              final s = acc.toUpperCase();
              if (s == 'BANNED' || s == 'DISABLED' || s == 'SUSPENDED' || s == 'BLOCKED') {
                isBanned = true;
              }
            }
            if (!isBanned && code != null) {
              // Common locked/forbidden codes to hint account restriction
              if (code == 423) isBanned = true; // Locked
              // On login endpoint, treat 403 as banned/blocked
              final path = error.requestOptions.path;
              // Treat 403 on login as banned to ensure consistent UX across platforms
              // Many backends return only a textual reason in `message` for banned accounts.
              if (!isBanned && code == 403 && (path.endsWith(ApiConfig.login) || path.contains('/auth/login'))) {
                isBanned = true;
              }
            }
          } catch (_) {}

          // Prefer backend-provided message, but for banned account force prefix
          final baseMsgRaw = responseData['message'];
          final baseMsg = (baseMsgRaw is String && baseMsgRaw.trim().isNotEmpty)
              ? baseMsgRaw.trim()
              : '请求失败';
          final reason = responseData['reason'] ??
              responseData['banReason'] ??
              responseData['error'] ??
              responseData['detail'];
          if (isBanned) {
            final reasonText = (reason is String && reason.trim().isNotEmpty) ? reason.trim() : baseMsg;
            message = '账户已封禁：$reasonText';
          } else {
            if (reason is String && reason.trim().isNotEmpty) {
              // Avoid duplicating if reason is same as message
              message = baseMsg;
              if (!message.contains(reason)) {
                message = '$message：${reason.trim()}';
              }
            } else {
              message = baseMsg;
            }
          }
        } else {
          message = '服务器错误 (${code ?? 'Unknown'})';
        }
        if ((code ?? 500) >= 500) {
          // 5xx 通常视为后端异常
          ServerHealth().setError();
        }
        break;
      case DioExceptionType.cancel:
        message = '请求已取消';
        break;
      case DioExceptionType.connectionError:
        message = '网络连接失败，请检查网络设置';
        ServerHealth().setError();
        break;
      default:
        message = '未知错误：${error.message}';
        break;
    }

    // 处理 401 未授权错误（Token过期）
    if (code == 401) {
      if (kDebugMode) {
        print('⚠️ 检测到 401 未授权，触发 Token 过期回调');
      }
      onTokenExpired?.call();
    }

    return ApiResponse.error(message, code);
  }
}

// 认证拦截器
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ApiClient()._token;
    if (kDebugMode) {
      print('🔐 Auth拦截器: token = ${token != null ? "${token.substring(0, 10)}..." : "null"}');
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      if (kDebugMode) {
        print('🔐 添加Authorization头: Bearer ${token.substring(0, 10)}...');
      }
    } else {
      if (kDebugMode) {
        print('⚠️ 没有token，跳过Authorization头');
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

// 日志拦截器
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('🚀 ${options.method} ${options.uri}');
      print('📍 Host: ${options.uri.host}:${options.uri.port}');
      print('📂 Path: ${options.uri.path}');
      print('🌐 Headers: ${options.headers}');
      if (options.data != null) {
        print('📤 Data: ${options.data}');
      }
      if (options.queryParameters.isNotEmpty) {
        print('🔍 Query: ${options.queryParameters}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('✅ ${response.statusCode} ${response.requestOptions.uri}');
      print('📥 Response: ${response.data}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('❌ ${err.requestOptions.method} ${err.requestOptions.uri}');
      print('💥 Error: ${err.message}');
      if (err.response != null) {
        print('📥 Response: ${err.response?.data}');
      }
    }
    handler.next(err);
  }
}

// 错误处理拦截器
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 在这里可以添加全局错误处理逻辑
    // 比如网络重试、错误上报等
    handler.next(err);
  }
}
