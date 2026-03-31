import 'package:provider/provider.dart';

import '../../core/theme/linkme_material.dart';
import 'note_editor_screen.dart';
import 'providers/notes_provider.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key, required this.notebook});

  final Notebook notebook;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 页面加载时从后端获取最新笔记列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotesProvider>().loadNotes(widget.notebook.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// note_list_screen.dart | _NoteListScreenState | _openEditor | entry
  Future<void> _openEditor({NoteEntry? entry}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          notebook: widget.notebook,
          note: entry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider provider = context.watch<NotesProvider>();
    final List<NoteEntry> notes = provider.notesOf(widget.notebook.id);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.notebook.title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openEditor,
              child: const CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildSearchField(),
            const SizedBox(height: 24),
            Expanded(
              child:
                  notes.isEmpty ? _buildEmptyState() : _buildNotesList(notes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, color: Colors.black38, size: 18),
          ),
          hintText: '搜索笔记...',
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.manage_search, color: Colors.black26, size: 46),
        const SizedBox(height: 20),
        const Text(
          '未找到笔记',
          style: TextStyle(color: Colors.black45),
        ),
      ],
    );
  }

  Widget _buildNotesList(List<NoteEntry> notes) {
    return ListView.separated(
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (BuildContext context, int index) {
        final NoteEntry entry = notes[index];
        return GestureDetector(
          onTap: () => _openEditor(entry: entry),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.black38),
                    const SizedBox(width: 6),
                    Text(
                      entry.formattedDate,
                      style: const TextStyle(color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
