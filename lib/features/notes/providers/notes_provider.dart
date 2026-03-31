import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notes_api.dart';
import '../../../core/network/websocket_manager.dart';

enum NotebookVisibility { private, shared }

/// notes_provider.dart | CollaboratorInfo | 协作者详细信息 | userId,nickname,avatar,role
class CollaboratorInfo {
  const CollaboratorInfo({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.role,
  });

  final int userId;
  final String nickname;
  final String? avatar;
  final String role; // "OWNER" 或 "EDITOR"

  /// 从API响应创建CollaboratorInfo对象
  factory CollaboratorInfo.fromJson(Map<String, dynamic> json) {
    return CollaboratorInfo(
      userId: json['userId'] as int,
      nickname: json['nickname'] as String,
      avatar: json['avatar'] as String?,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'avatar': avatar,
      'role': role,
    };
  }
}

/// notes_provider.dart | Notebook | 笔记本模型 | id,title,visibility,collaborators,noteCount
class Notebook {
  const Notebook({
    required this.id,
    required this.title,
    required this.visibility,
    required this.startColor,
    required this.endColor,
    this.collaborators = const <CollaboratorInfo>[],
    this.noteCount = 0,
  });

  final String id;
  final String title;
  final NotebookVisibility visibility;
  final Color startColor;
  final Color endColor;
  final List<CollaboratorInfo> collaborators;
  final int noteCount; // 笔记数量（从后端返回）

  Notebook copyWith({
    String? title,
    NotebookVisibility? visibility,
    Color? startColor,
    Color? endColor,
    List<CollaboratorInfo>? collaborators,
    int? noteCount,
  }) {
    return Notebook(
      id: id,
      title: title ?? this.title,
      visibility: visibility ?? this.visibility,
      startColor: startColor ?? this.startColor,
      endColor: endColor ?? this.endColor,
      collaborators: collaborators ?? this.collaborators,
      noteCount: noteCount ?? this.noteCount,
    );
  }

  /// 从API响应创建Notebook对象
  factory Notebook.fromJson(Map<String, dynamic> json) {
    return Notebook(
      id: json['id'].toString(),
      title: json['title'] as String,
      visibility: json['visibility'] == 'PRIVATE'
          ? NotebookVisibility.private
          : NotebookVisibility.shared,
      startColor: _parseColor(json['startColor'] as String),
      endColor: _parseColor(json['endColor'] as String),
      collaborators: (json['collaborators'] as List<dynamic>?)
              ?.map((e) => CollaboratorInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CollaboratorInfo>[],
      noteCount: json['noteCount'] as int? ?? 0,
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}

class NoteEntry {
  NoteEntry({
    required this.id,
    required this.notebookId,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String notebookId;
  final String title;
  final String content;
  final DateTime updatedAt;

  String get formattedDate => DateFormat('M月d日').format(updatedAt);

  /// 从API响应创建NoteEntry对象
  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      id: json['id'].toString(),
      notebookId: json['notebookId'].toString(),
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// notes_provider.dart | NotesProvider | 笔记模块状态管理 | userId,notebooks,notes
class NotesProvider extends ChangeNotifier {
  NotesProvider() {
    _listenToWebSocket();
  }

  int? _userId; // 当前用户ID
  final List<Notebook> _notebooks = <Notebook>[];
  final Map<String, List<NoteEntry>> _notes = <String, List<NoteEntry>>{};
  bool _isLoading = false;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  bool get isLoading => _isLoading;

  /// 设置当前用户ID
  void setUserId(int userId) {
    _userId = userId;
    loadNotebooks(); // 加载用户的笔记本
  }

  /// 从后端加载笔记本列表
  /// notes_provider.dart | NotesProvider | loadNotebooks | 加载用户的所有笔记本（包括自己创建的和被邀请的）
  Future<void> loadNotebooks() async {
    if (_userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await NotesApi.getNotebooks(userId: _userId!);
      if (response['success'] == true) {
        final List<dynamic> data = response['data'] as List<dynamic>;
        _notebooks.clear();

        // 解析笔记本列表，确保协作者信息正确加载
        for (final json in data) {
          try {
            final notebook = Notebook.fromJson(json as Map<String, dynamic>);
            _notebooks.add(notebook);
            debugPrint(
                '[NotesProvider] 加载笔记本: ${notebook.title}, 协作者数量: ${notebook.collaborators.length}');
          } catch (e) {
            debugPrint('[NotesProvider] 解析笔记本失败: $e, JSON: $json');
          }
        }
      }
    } catch (e) {
      debugPrint('[NotesProvider] Failed to load notebooks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// notes_provider.dart | NotesProvider | notebooksByType | visibility
  List<Notebook> notebooksByType(NotebookVisibility visibility) {
    return _notebooks
        .where((Notebook notebook) => notebook.visibility == visibility)
        .toList(growable: false);
  }

  /// notes_provider.dart | NotesProvider | findNotebook | notebookId
  Notebook? findNotebook(String notebookId) {
    try {
      return _notebooks.firstWhere((Notebook nb) => nb.id == notebookId);
    } catch (_) {
      return null;
    }
  }

  /// notes_provider.dart | NotesProvider | notesOf | notebookId
  List<NoteEntry> notesOf(String notebookId) {
    return List<NoteEntry>.unmodifiable(_notes[notebookId] ?? <NoteEntry>[]);
  }

  /// 从后端加载指定笔记本的笔记列表
  Future<void> loadNotes(String notebookId) async {
    if (_userId == null) return;

    try {
      final response = await NotesApi.getNotesByNotebook(
        userId: _userId!,
        notebookId: int.parse(notebookId),
      );
      if (response['success'] == true) {
        final List<dynamic> data = response['data'] as List<dynamic>;
        _notes[notebookId] = data
            .map((json) => NoteEntry.fromJson(json as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotesProvider] Failed to load notes: $e');
    }
  }

  /// notes_provider.dart | NotesProvider | addNotebook | title,visibility
  Future<void> addNotebook(String title, NotebookVisibility visibility) async {
    if (_userId == null) return;

    final String trimmed = title.trim().isEmpty ? '未命名笔记本' : title.trim();
    final ColorPair palette = _palette[_notebooks.length % _palette.length];

    try {
      final response = await NotesApi.createNotebook(
        userId: _userId!,
        title: trimmed,
        visibility:
            visibility == NotebookVisibility.private ? 'private' : 'shared',
        startColor: Notebook._colorToHex(palette.start),
        endColor: Notebook._colorToHex(palette.end),
        collaborators: null, // 后端会自动管理协作者
      );

      if (response['success'] == true) {
        // 创建成功后重新加载笔记本列表，确保协作者信息完整
        debugPrint('[NotesProvider] 笔记本创建成功，重新加载列表');
        await loadNotebooks();
      }
    } catch (e) {
      debugPrint('[NotesProvider] Failed to add notebook: $e');
    }
  }

  /// notes_provider.dart | NotesProvider | deleteNotebook | notebookId
  Future<void> deleteNotebook(String notebookId) async {
    if (_userId == null) return;

    try {
      final response = await NotesApi.deleteNotebook(
        userId: _userId!,
        notebookId: int.parse(notebookId),
      );

      if (response['success'] == true) {
        _notebooks.removeWhere((Notebook nb) => nb.id == notebookId);
        _notes.remove(notebookId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotesProvider] Failed to delete notebook: $e');
    }
  }

  /// notes_provider.dart | NotesProvider | setNotebookVisibility | notebookId,newVisibility
  Future<void> setNotebookVisibility(
      String notebookId, NotebookVisibility target) async {
    if (_userId == null) return;

    try {
      final response = await NotesApi.updateNotebook(
        userId: _userId!,
        notebookId: int.parse(notebookId),
        visibility: target == NotebookVisibility.private ? 'private' : 'shared',
        collaborators: null, // 后端会自动管理协作者
      );

      if (response['success'] == true) {
        // 重新加载笔记本列表以获取最新的协作者信息
        await loadNotebooks();
      }
    } catch (e) {
      debugPrint('[NotesProvider] Failed to update notebook visibility: $e');
    }
  }

  /// 邀请协作者
  /// notes_provider.dart | NotesProvider | inviteCollaborator | notebookId,inviteeId
  Future<bool> inviteCollaborator(String notebookId, int inviteeId) async {
    if (_userId == null) return false;

    try {
      final response = await NotesApi.inviteCollaborator(
        userId: _userId!,
        notebookId: int.parse(notebookId),
        inviteeId: inviteeId,
      );

      if (response['success'] == true) {
        debugPrint(
            '[NotesProvider] 邀请协作者成功: notebookId=$notebookId, inviteeId=$inviteeId');
        // 重新加载笔记本列表以获取最新的协作者信息
        await loadNotebooks();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[NotesProvider] Failed to invite collaborator: $e');
      return false;
    }
  }

  /// 获取当前用户在指定笔记本中的角色
  /// notes_provider.dart | NotesProvider | getUserRole | notebookId
  String? getUserRole(String notebookId) {
    if (_userId == null) return null;

    final notebook = findNotebook(notebookId);
    if (notebook == null) return null;

    // 在协作者列表中查找当前用户
    for (final collaborator in notebook.collaborators) {
      if (collaborator.userId == _userId) {
        return collaborator.role;
      }
    }

    return null;
  }

  /// 判断当前用户是否是笔记本所有者
  /// notes_provider.dart | NotesProvider | isOwner | notebookId
  bool isOwner(String notebookId) {
    final role = getUserRole(notebookId);
    return role == 'OWNER';
  }

  /// notes_provider.dart | NotesProvider | addNote | notebookId,title,content
  Future<void> addNote({
    required String notebookId,
    required String title,
    required String content,
  }) async {
    if (_userId == null) return;

    final Notebook? notebook = findNotebook(notebookId);
    if (notebook == null) return;

    try {
      final response = await NotesApi.createNote(
        userId: _userId!,
        notebookId: int.parse(notebookId),
        title: title.trim().isEmpty ? '无标题笔记' : title.trim(),
        content: content.trim().isEmpty ? '暂无内容' : content.trim(),
      );

      if (response['success'] == true) {
        final entry =
            NoteEntry.fromJson(response['data'] as Map<String, dynamic>);
        final List<NoteEntry> allNotes = _notes.putIfAbsent(
          notebookId,
          () => <NoteEntry>[],
        );
        allNotes.insert(0, entry);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotesProvider] Failed to add note: $e');
    }
  }

  /// notes_provider.dart | NotesProvider | updateNote | notebookId,noteId,title,content
  Future<void> updateNote({
    required String notebookId,
    required String noteId,
    required String title,
    required String content,
  }) async {
    if (_userId == null) return;

    try {
      final response = await NotesApi.updateNote(
        userId: _userId!,
        noteId: int.parse(noteId),
        title: title.trim().isEmpty ? null : title.trim(),
        content: content.trim().isEmpty ? null : content.trim(),
      );

      if (response['success'] == true) {
        final List<NoteEntry>? entries = _notes[notebookId];
        if (entries == null) return;
        final int index =
            entries.indexWhere((NoteEntry note) => note.id == noteId);
        if (index == -1) return;

        final updated =
            NoteEntry.fromJson(response['data'] as Map<String, dynamic>);
        entries[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotesProvider] Failed to update note: $e');
    }
  }

  /// 监听WebSocket消息，处理笔记本邀请通知
  /// notes_provider.dart | NotesProvider | _listenToWebSocket |
  void _listenToWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketManager().messageStream.listen((event) {
      final messageType = event['type'] as String?;

      if (messageType == 'ZENNOTES_INVITATION') {
        // 收到笔记本协作邀请
        final notebookTitle = event['notebookTitle'] as String?;
        final inviterName = event['inviterName'] as String?;

        if (notebookTitle != null && inviterName != null) {
          debugPrint(
              '[NotesProvider] 收到笔记本邀请: $notebookTitle from $inviterName');

          // 重新加载笔记本列表以显示新的共享笔记本
          if (_userId != null) {
            loadNotebooks();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  static const List<ColorPair> _palette = <ColorPair>[
    ColorPair(Color(0xFF3957FF), Color(0xFF6C79FF)),
    ColorPair(Color(0xFFFF5A91), Color(0xFFFFB4C9)),
    ColorPair(Color(0xFFFFA751), Color(0xFFFFD1A3)),
    ColorPair(Color(0xFF00BFA6), Color(0xFF88E0D0)),
  ];
}

class ColorPair {
  const ColorPair(this.start, this.end);
  final Color start;
  final Color end;
}
