import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';
import '../models/message.dart';

class MessageService {
  final ApiClient _apiClient = ApiClient();

  /// 发送私聊消息
  Future<Message?> sendPrivateMessage(
    int senderId,
    int receiverId,
    String content, {
    int? replyToMessageId,
    MessageType type = MessageType.text,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConfig.messages}/send',
        data: {
          'senderId': senderId,
          'receiverId': receiverId,
          'content': content,
          'type': type.name.toUpperCase(),
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        },
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return Message.fromJson(apiResponse.data!);
      }
      // Propagate server message so UI can display a clearer reason
      throw Exception(apiResponse.message ?? '发送消息失败');
    } catch (e) {
      print('发送消息失败: $e');
      rethrow; // Let caller set a friendly error message/toast
    }
  }

  /// 获取私聊消息记录
  Future<List<Message>> getPrivateMessages(int userId1, int userId2,
      {int page = 0, int size = 50}) async {
    print(
        '📨 MessageService.getPrivateMessages 开始执行，userId1=$userId1, userId2=$userId2');
    try {
      final url = '${ApiConfig.messages}/private/$userId1/$userId2';
      print('📨 请求URL: $url');
      print('📨 查询参数: page=$page, size=$size');

      final response = await _apiClient.dio.get(
        url,
        queryParameters: {
          'page': page,
          'size': size,
        },
      );

      print('📨 收到HTTP响应，状态码: ${response.statusCode}');
      print('📨 响应数据: ${response.data}');

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      print(
          '📨 ApiResponse解析结果: success=${apiResponse.success}, message=${apiResponse.message}');

      if (apiResponse.success && apiResponse.data != null) {
        print('📨 开始转换消息数据，原始数据长度: ${apiResponse.data!.length}');
        final messageList = <Message>[];
        for (int i = 0; i < apiResponse.data!.length; i++) {
          try {
            final json = apiResponse.data![i] as Map<String, dynamic>;
            print('📨 转换消息数据[$i]: $json');
            final message = Message.fromJson(json);
            messageList.add(message);
            print('📨 消息[$i]转换成功: ${message.content}');
          } catch (e) {
            print('❌ 消息[$i]转换失败: $e');
            print('❌ 原始数据: ${apiResponse.data![i]}');
          }
        }
        print(
            '📨 消息列表转换完成，成功转换: ${messageList.length}/${apiResponse.data!.length}');
        return messageList;
      }
      return [];
    } catch (e) {
      print('❌ 获取私聊消息失败: $e');
      print('❌ 异常类型: ${e.runtimeType}');
      return [];
    }
  }

  /// 获取用户的所有消息
  Future<List<Message>> getUserMessages(int userId,
      {int page = 0, int size = 50}) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.messages}/$userId',
        queryParameters: {
          'page': page,
          'size': size,
        },
      );

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('获取用户消息失败: $e');
      return [];
    }
  }

  /// 获取未读消息
  Future<List<Message>> getUnreadMessages(int userId) async {
    try {
      final response =
          await _apiClient.dio.get('${ApiConfig.messages}/unread/$userId');

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('获取未读消息失败: $e');
      return [];
    }
  }

  /// 标记消息为已读
  Future<bool> markAsRead(int messageId) async {
    try {
      final response =
          await _apiClient.dio.put('${ApiConfig.messages}/$messageId/read');

      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      return apiResponse.success;
    } catch (e) {
      print('标记已读失败: $e');
      return false;
    }
  }

  /// 获取聊天联系人（最近聊天列表）
  Future<List<Map<String, dynamic>>> getChatContacts(int userId) async {
    print('🌐 MessageService.getChatContacts 开始执行，用户ID: $userId');
    try {
      final url = '${ApiConfig.messages}/contacts/$userId';
      print('🌐 请求URL: $url');
      print('🌐 当前ApiConfig.messages: ${ApiConfig.messages}');

      print('🌐 发送GET请求...');
      final response = await _apiClient.dio.get(url);
      print('🌐 收到HTTP响应，状态码: ${response.statusCode}');
      print('🌐 响应数据: ${response.data}');

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      print(
          '🌐 ApiResponse解析结果: success=${apiResponse.success}, message=${apiResponse.message}');

      if (apiResponse.success && apiResponse.data != null) {
        print('🌐 开始转换聊天联系人数据，原始数据长度: ${apiResponse.data!.length}');
        final contactList = apiResponse.data!.map((json) {
          print('🌐 转换联系人数据: $json');
          return json as Map<String, dynamic>;
        }).toList();
        print('🌐 聊天联系人列表转换完成，最终联系人数: ${contactList.length}');
        return contactList;
      } else {
        print('🌐 API响应失败: ${apiResponse.message}');
        return [];
      }
    } catch (e) {
      print('❌ 获取聊天联系人失败: $e');
      print('❌ 异常类型: ${e.runtimeType}');
      if (e is DioException) {
        print('❌ DioException详情: ${e.response?.data}');
        print('❌ 状态码: ${e.response?.statusCode}');
      }
      return [];
    }
  }

  /// 置顶消息
  Future<Message?> pinMessage(int messageId) async {
    try {
      final response =
          await _apiClient.dio.post('${ApiConfig.messages}/$messageId/pin');

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return Message.fromJson(apiResponse.data!);
      }
      return null;
    } catch (e) {
      print('置顶消息失败: $e');
      return null;
    }
  }

  /// 取消置顶消息
  Future<Message?> unpinMessage(int messageId) async {
    try {
      final response =
          await _apiClient.dio.post('${ApiConfig.messages}/$messageId/unpin');

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return Message.fromJson(apiResponse.data!);
      }
      return null;
    } catch (e) {
      print('取消置顶失败: $e');
      return null;
    }
  }

  /// 获取置顶消息
  Future<List<Message>> getPinnedMessages(
      int userId, int chatId, bool isGroup) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.messages}/pinned',
        queryParameters: {
          'chatId': chatId,
          'isGroup': isGroup,
        },
      );

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('获取置顶消息失败: $e');
      return [];
    }
  }

  /// 发送群聊消息
  Future<Message?> sendGroupMessage(
    int senderId,
    int groupId,
    String content, {
    int? replyToMessageId,
    MessageType type = MessageType.text,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConfig.messages}/group',
        data: {
          'senderId': senderId,
          'groupId': groupId,
          'content': content,
          'type': type.name.toUpperCase(),
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        },
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return Message.fromJson(apiResponse.data!);
      }
      // Propagate server message so UI can display a clearer reason
      throw Exception(apiResponse.message ?? '发送消息失败');
    } catch (e) {
      print('发送群聊消息失败: $e');
      rethrow; // Let caller set a friendly error message/toast
    }
  }

  /// 获取群聊消息
  Future<List<Message>> getGroupMessages(int groupId,
      {int page = 0, int size = 50}) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConfig.messages}/group/$groupId',
        queryParameters: {
          'page': page,
          'size': size,
        },
      );

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('获取群聊消息失败: $e');
      return [];
    }
  }

  /// 删除消息（仅自己可见的删除）
  Future<bool> deleteMessageForMe(int messageId) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConfig.messages}/$messageId/hide',
      );
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      return apiResponse.success;
    } catch (e) {
      print('删除消息失败: $e');
      return false;
    }
  }

  /// 撤回消息（对所有人删除）
  Future<bool> recallMessage(int messageId) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConfig.messages}/$messageId/recall',
      );
      final apiResponse = ApiResponse<String>.fromJson(
        response.data,
        (data) => data.toString(),
      );
      return apiResponse.success;
    } catch (e) {
      print('撤回消息失败: $e');
      return false;
    }
  }
}
