import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_response.dart';

/// Group API service
/// 完整的群聊管理服务，包含创建、管理、解散群聊等功能
class GroupService {
  final ApiClient _apiClient = ApiClient();

  /// 获取当前用户加入的群聊列表
  /// 后端路径: GET /api/groups/list
  Future<List<Map<String, dynamic>>> getMyGroups() async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.groups}/list');
      final api = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (d) => d as List<dynamic>,
      );
      if (api.success && api.data != null) {
        // 后端返回 ChatGroup 实体，直接按 Map 透传即可
        // 返回可增长的 List，避免在客户端对列表执行 remove/clear 时抛出
        // "Cannot clear a fixed-length list" 的错误
        return api.data!
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      print('❌ 获取群聊列表失败: ${e.response?.statusCode} ${e.response?.data}');
      return [];
    } catch (e) {
      print('❌ 获取群聊列表失败: $e');
      return [];
    }
  }

  /// 创建群聊
  /// 后端路径: POST /api/groups/create
  Future<Map<String, dynamic>?> createGroup({
    required String groupName,
    required String description,
    required List<int> memberIds,
    String? avatar,
  }) async {
    try {
      print('🔄 创建群聊: $groupName, 成员: $memberIds');
      final payload = <String, dynamic>{
        'name': groupName,
        'description': description,
        'memberIds': memberIds,
      };
      if (avatar != null && avatar.trim().isNotEmpty) {
        payload['avatar'] = avatar.trim();
      }
      final response = await _apiClient.dio.post(
        '${ApiConfig.groups}/create',
        data: payload,
      );
      
      final api = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      
      if (api.success && api.data != null) {
        print('✅ 群聊创建成功: ${api.data!['name'] ?? api.data!['groupName'] ?? ''}');
        return api.data;
      } else {
        print('❌ 群聊创建失败: ${api.message}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ 创建群聊失败: ${e.response?.statusCode} ${e.response?.data}');
      return null;
    } catch (e) {
      print('❌ 创建群聊失败: $e');
      return null;
    }
  }

  /// 解散群聊
  /// 后端路径: DELETE /api/groups/{groupId}
  Future<bool> dissolveGroup(int groupId, int userId) async {
    try {
      print('🔄 解散群聊: $groupId');
      final response = await _apiClient.dio.delete('${ApiConfig.groups}/$groupId');
      
      final api = ApiResponse<String>.fromJson(
        response.data,
        (d) => d.toString(),
      );
      
      if (api.success) {
        print('✅ 群聊解散成功');
        return true;
      } else {
        print('❌ 群聊解散失败: ${api.message}');
        return false;
      }
    } on DioException catch (e) {
      print('❌ 解散群聊失败: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('❌ 解散群聊失败: $e');
      return false;
    }
  }

  /// 退出群聊
  /// 后端路径: POST /api/groups/{groupId}/leave
  Future<bool> leaveGroup(int groupId, int userId) async {
    try {
      print('🔄 退出群聊: $groupId');
      // 后端根据JWT中的当前用户识别，无需传userId
      final response = await _apiClient.dio.post('${ApiConfig.groups}/$groupId/leave');
      
      final api = ApiResponse<String>.fromJson(
        response.data,
        (d) => d.toString(),
      );
      
      if (api.success) {
        print('✅ 退出群聊成功');
        return true;
      } else {
        print('❌ 退出群聊失败: ${api.message}');
        return false;
      }
    } on DioException catch (e) {
      print('❌ 退出群聊失败: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('❌ 退出群聊失败: $e');
      return false;
    }
  }

  /// 添加群成员（批量封装）
  /// 后端路径: POST /api/groups/{groupId}/members （单个）
  Future<bool> addGroupMembers(int groupId, List<int> memberIds, int operatorId) async {
    try {
      print('🔄 添加群成员: $groupId, 新成员: $memberIds');
      for (final id in memberIds) {
        final response = await _apiClient.dio.post(
          '${ApiConfig.groups}/$groupId/members',
          data: {'userId': id},
        );
        final api = ApiResponse<Map<String, dynamic>>.fromJson(
          response.data,
          (d) => d as Map<String, dynamic>,
        );
        if (!api.success) {
          print('❌ 添加成员失败: ${api.message} (memberId=$id)');
          return false;
        }
      }
      print('✅ 添加群成员成功');
      return true;
    } on DioException catch (e) {
      print('❌ 添加群成员失败: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('❌ 添加群成员失败: $e');
      return false;
    }
  }

  /// 移除群成员
  /// 后端路径: DELETE /api/groups/{groupId}/members/{memberId}
  Future<bool> removeGroupMember(int groupId, int memberId, int operatorId) async {
    try {
      print('🔄 移除群成员: $groupId, 成员: $memberId');
      final response = await _apiClient.dio.delete(
        '${ApiConfig.groups}/$groupId/members/$memberId',
      );
      final api = ApiResponse<String>.fromJson(
        response.data,
        (d) => d.toString(),
      );
      if (api.success) {
        print('✅ 移除群成员成功');
        return true;
      } else {
        print('❌ 移除群成员失败: ${api.message}');
        return false;
      }
    } on DioException catch (e) {
      print('❌ 移除群成员失败: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('❌ 移除群成员失败: $e');
      return false;
    }
  }

  /// 更新群信息（根据字段分别调用后端对应接口）
  Future<Map<String, dynamic>?> updateGroupInfo({
    required int groupId,
    String? groupName,
    String? description,
    String? avatar,
  }) async {
    try {
      print('🔄 更新群信息: $groupId');
      Map<String, dynamic>? result;

      Future<Map<String, dynamic>?> _parseUpdate(Response resp) async {
        try {
          final raw = resp.data;
          if (raw is Map) {
            final ok = raw['success'] == true;
            final data = raw['data'];
            if (ok && data is Map) {
              // 宽松转换：逐个 key 转成字符串，避免 Map<String,dynamic>.from 的泛型限制
              final out = <String, dynamic>{};
              (data as Map).forEach((k, v) {
                out[k.toString()] = v;
              });
              return out;
            }
          }
        } catch (e) {
          print('⚠️ _parseUpdate 宽松解析失败: $e');
        }
        return null;
      }

      if (groupName != null) {
        final resp = await _apiClient.dio.put(
          '${ApiConfig.groups}/$groupId/name',
          data: {'name': groupName},
        );
        if (resp.statusCode == 200) {
          final raw = resp.data;
          final ok = (raw is Map) && (raw['success'] == true);
          if (ok) {
            final parsed = await _parseUpdate(resp);
            result = {...?result, ...?parsed, 'name': groupName};
          } else {
            print('❌ 更新群名称失败: ${raw is Map ? raw['message'] : raw}');
          }
        }
      }
      if (avatar != null) {
        final resp = await _apiClient.dio.put(
          '${ApiConfig.groups}/$groupId/avatar',
          data: {'avatar': avatar},
        );
        if (resp.statusCode == 200) {
          final raw = resp.data;
          final ok = (raw is Map) && (raw['success'] == true);
          if (ok) {
            final parsed = await _parseUpdate(resp);
            result = {...?result, ...?parsed, 'avatar': avatar};
          } else {
            print('❌ 更新群头像失败: ${raw is Map ? raw['message'] : raw}');
          }
        }
      }
      if (description != null) {
        final resp = await _apiClient.dio.put(
          '${ApiConfig.groups}/$groupId/announcement',
          data: {'announcement': description},
        );
        if (resp.statusCode == 200) {
          final raw = resp.data;
          final ok = (raw is Map) && (raw['success'] == true);
          if (ok) {
            final parsed = await _parseUpdate(resp);
            result = {...?result, ...?parsed, 'description': description, 'announcement': description};
          } else {
            print('❌ 更新群公告失败: ${raw is Map ? raw['message'] : raw}');
          }
        }
      }
      return result;
    } on DioException catch (e) {
      print('❌ 更新群信息失败: ${e.response?.statusCode} ${e.response?.data}');
      return null;
    } catch (e) {
      print('❌ 更新群信息失败: $e');
      return null;
    }
  }

  /// 获取群详情（当前不强依赖，只在后续扩展时使用）
  Future<Map<String, dynamic>?> getGroupDetail(int groupId) async {
    try {
      final resp = await _apiClient.dio.get('${ApiConfig.groups}/$groupId');
      final raw = resp.data;
      if (raw is Map) {
        final ok = raw['success'] == true;
        final data = raw['data'];
        if (ok && data is Map) {
          try {
            return Map<String, dynamic>.from(data as Map);
          } catch (_) {
            // 容忍后端返回的泛型不完全匹配
            final out = <String, dynamic>{};
            (data as Map).forEach((k, v) {
              out[String.fromCharCodes(k.toString().codeUnits)] = v;
            });
            return out;
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ 获取群详情失败: $e');
      return null;
    }
  }

  /// 获取群成员（后端返回 GroupMember，其中包含嵌套的 user 对象）
  /// 这里做一次“扁平化”，将常用字段（id/nickname/username/avatar/role）提升到顶层，
  /// 以兼容现有前端展示逻辑，避免出现“未知用户”。
  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    try {
      final response = await _apiClient.dio.get('${ApiConfig.groups}/$groupId/members');
      final api = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (d) => d as List<dynamic>,
      );
      if (api.success && api.data != null) {
        final List<Map<String, dynamic>> out = [];
        for (final raw in api.data!) {
          final m = raw as Map<String, dynamic>;
          final user = (m['user'] as Map<String, dynamic>?) ?? const {};
          out.add({
            // 使用用户ID作为成员ID，便于前端直接使用
            'id': (user['id'] ?? m['userId'] ?? m['id']),
            'username': user['username'] ?? m['username'],
            'nickname': user['nickname'] ?? m['nickname'],
            'avatar': user['avatar'] ?? m['avatar'],
            'role': m['role'] ?? m['memberRole'] ?? 'MEMBER',
            // 额外保留原始结构，必要时可取更多字段
            'raw': m,
          });
        }
        return out;
      }
      return [];
    } catch (e) {
      print('❌ 获取群成员失败: $e');
      return [];
    }
  }
}
