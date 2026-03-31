import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import '../../shared/services/hot_service.dart';
import '../../core/theme/app_colors.dart';

class HotSearchResultScreen extends StatefulWidget {
  final int labelId;
  final String keyword;
  const HotSearchResultScreen({super.key, required this.labelId, required this.keyword});

  @override
  State<HotSearchResultScreen> createState() => _HotSearchResultScreenState();
}

class _HotSearchResultScreenState extends State<HotSearchResultScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(()=> _loading = true);
    final res = await HotService().search(labelId: widget.labelId, keyword: widget.keyword, page: 0, size: 30);
    if (!mounted) return;
    setState((){
      _loading = false;
      if (res.success && res.data != null) {
        _items = ((res.data!['articles'] as List?) ?? []).cast<Map>().map((e)=> Map<String, dynamic>.from(e as Map)).toList();
      } else { _items = const []; }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('搜索：${widget.keyword}')),
      body: _loading
          ? const Center(child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)))
          : _items.isEmpty
              ? const Center(child: Text('未找到相关内容', style: TextStyle(color: AppColors.textLight)))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = _items[i];
                    return ListTile(
                      leading: m['coverImage'] != null && m['coverImage'].toString().isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(m['coverImage'], width: 64, height: 40, fit: BoxFit.cover))
                          : const SizedBox(width: 64, height: 40),
                      title: Text(m['title']?.toString() ?? ''),
                      subtitle: Text(m['summary']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
    );
  }
}
