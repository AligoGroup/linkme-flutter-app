// notes_api.dart | NotesApi | API service for notes module
import '../../../core/network/api_client.dart';

/// notes_api.dart
/// 笔记模块API服务
/// 提供笔记本和笔记的网络请求方法
class NotesApi {
  /// 创建笔记本
  static Future<Map<String, dynamic>> createNotebook({
    required int userId,
    required String title,
    required String visibility,
    required String startColor,
    required String endColor,
    List<String>? collaborators,
  }) async {
    final response = await ApiClient().post(
      '/notebooks',
      queryParameters: {'userId': userId},
      data: {
        'title': title,
        'visibility': visibility.toUpperCase(),
        'startColor': startColor,
        'endColor': endColor,
        if (collaborators != null) 'collaborators': collaborators,
      },
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('创建笔记本失败: ${response.message}');
    }
  }

  /// 获取笔记本列表
  static Future<Map<String, dynamic>> getNotebooks({
    required int userId,
    String? visibility,
  }) async {
    final Map<String, dynamic> query = {'userId': userId};
    if (visibility != null) {
      query['visibility'] = visibility.toUpperCase();
    }

    final response = await ApiClient().get(
      '/notebooks',
      queryParameters: query,
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('获取笔记本列表失败: ${response.message}');
    }
  }

  /// 获取单个笔记本
  static Future<Map<String, dynamic>> getNotebook({
    required int userId,
    required int notebookId,
  }) async {
    final response = await ApiClient().get(
      '/notebooks/$notebookId',
      queryParameters: {'userId': userId},
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('获取笔记本失败: ${response.message}');
    }
  }

  /// 更新笔记本
  static Future<Map<String, dynamic>> updateNotebook({
    required int userId,
    required int notebookId,
    String? title,
    String? visibility,
    List<String>? collaborators,
  }) async {
    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (visibility != null) body['visibility'] = visibility.toUpperCase();
    if (collaborators != null) body['collaborators'] = collaborators;

    final response = await ApiClient().put(
      '/notebooks/$notebookId',
      queryParameters: {'userId': userId},
      data: body,
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('更新笔记本失败: ${response.message}');
    }
  }

  /// 邀请协作者
  static Future<Map<String, dynamic>> inviteCollaborator({
    required int userId,
    required int notebookId,
    required int inviteeId,
  }) async {
    final response = await ApiClient().post(
      '/notebooks/$notebookId/invite',
      queryParameters: {
        'userId': userId,
        'inviteeId': inviteeId,
      },
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('邀请协作者失败: ${response.message}');
    }
  }

  /// 删除笔记本
  static Future<Map<String, dynamic>> deleteNotebook({
    required int userId,
    required int notebookId,
  }) async {
    final response = await ApiClient().delete(
      '/notebooks/$notebookId',
      queryParameters: {'userId': userId},
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('删除笔记本失败: ${response.message}');
    }
  }

  /// 创建笔记
  static Future<Map<String, dynamic>> createNote({
    required int userId,
    required int notebookId,
    required String title,
    required String content,
  }) async {
    final response = await ApiClient().post(
      '/notes',
      queryParameters: {'userId': userId},
      data: {
        'notebookId': notebookId,
        'title': title,
        'content': content,
      },
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('创建笔记失败: ${response.message}');
    }
  }

  /// 获取笔记本下的笔记列表
  static Future<Map<String, dynamic>> getNotesByNotebook({
    required int userId,
    required int notebookId,
  }) async {
    final response = await ApiClient().get(
      '/notes/notebook/$notebookId',
      queryParameters: {'userId': userId},
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('获取笔记列表失败: ${response.message}');
    }
  }

  /// 获取单个笔记
  static Future<Map<String, dynamic>> getNote({
    required int userId,
    required int noteId,
  }) async {
    final response = await ApiClient().get(
      '/notes/$noteId',
      queryParameters: {'userId': userId},
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('获取笔记失败: ${response.message}');
    }
  }

  /// 更新笔记
  static Future<Map<String, dynamic>> updateNote({
    required int userId,
    required int noteId,
    String? title,
    String? content,
  }) async {
    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;

    final response = await ApiClient().put(
      '/notes/$noteId',
      queryParameters: {'userId': userId},
      data: body,
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('更新笔记失败: ${response.message}');
    }
  }

  /// 删除笔记
  static Future<Map<String, dynamic>> deleteNote({
    required int userId,
    required int noteId,
  }) async {
    final response = await ApiClient().delete(
      '/notes/$noteId',
      queryParameters: {'userId': userId},
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('删除笔记失败: ${response.message}');
    }
  }

  /// 获取用户收到的邀请列表
  /// notes_api.dart | NotesApi | getInvitations | userId
  static Future<Map<String, dynamic>> getInvitations({
    required int userId,
  }) async {
    final response = await ApiClient().get(
      '/notebooks/invitations',
      queryParameters: {'userId': userId},
    );

    if (response.success) {
      return {
        'success': true,
        'data': response.data,
        'message': response.message,
      };
    } else {
      throw Exception('获取邀请列表失败: ${response.message}');
    }
  }
}
