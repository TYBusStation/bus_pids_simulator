import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

import '../utils/static.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<String> _cachedNames = [];
  List<String> _filteredAudios = [];

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  void _loadNames() {
    _cachedNames = Static.audioManager.allAudioNames;
    _performSearch();
  }

  void _performSearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredAudios = List.from(_cachedNames);
      } else {
        final query = _searchQuery.toLowerCase();
        _filteredAudios = _cachedNames
            .where((n) => n.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _refresh() {
    _loadNames();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: _buildFABs(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "搜尋音檔...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                            _performSearch();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) {
                  _searchQuery = v;
                  _performSearch();
                },
              ),
            ),
          ),
          Expanded(
            child: _filteredAudios.isEmpty
                ? const Center(
                    child: Text("無音檔", style: TextStyle(color: Colors.grey)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          mainAxisExtent: 130,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _filteredAudios.length,
                    itemBuilder: (context, index) {
                      return _buildAudioCard(_filteredAudios[index], theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard(String name, ThemeData theme) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.play_circle, color: Colors.blue, size: 36),
            onPressed: () => Static.audioManager.playAudio(name),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              height: 20,
              child: _buildMarqueeOrText(name, theme),
            ),
          ),
          const Divider(height: 10, indent: 10, endIndent: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showRenameDialog(name),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.download,
                    size: 18,
                    color: Colors.green,
                  ),
                  onPressed: () => Static.audioManager.exportSingle(name),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () async {
                    await Static.audioManager.deleteAudio(name);
                    _refresh();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildMarqueeOrText(String text, ThemeData theme) {
    final style = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        if (textPainter.size.width > constraints.maxWidth) {
          return Marquee(
            text: text,
            style: style,
            scrollAxis: Axis.horizontal,
            blankSpace: 20.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 1),
          );
        }

        return Center(
          child: Text(text, style: style, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }

  Widget _buildFABs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: "import_zip",
          child: const Icon(Icons.drive_folder_upload),
          onPressed: _handleImportZip,
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "export_zip",
          child: const Icon(Icons.archive),
          onPressed: () => Static.audioManager.exportAllZip(),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "add_audio",
          child: const Icon(Icons.add),
          onPressed: _handleAddNew,
        ),
      ],
    );
  }

  Future<void> _handleImportZip() async {
    final files = await Static.audioManager.pickZipFiles();
    if (files == null || files.isEmpty) return;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (v) => AlertDialog(
            title: Text("匯入 (${files.length})"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (x, i) => Text(
                  "• ${files.keys.elementAt(i)}",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(v, false),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(v, true),
                child: const Text("確認"),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      for (var e in files.entries) {
        await Static.audioManager.saveAudio(e.key, e.value);
      }
      _refresh();
    }
  }

  Future<void> _handleAddNew() async {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("新增音檔"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: "音檔名稱"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (c.text.isNotEmpty) {
                await Static.audioManager.pickAndSave(c.text);
                Navigator.pop(v);
                _refresh();
              }
            },
            child: const Text("選擇"),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(String oldName) {
    final c = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("更名"),
        content: TextField(controller: c),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              if (c.text.isNotEmpty && c.text != oldName) {
                await Static.audioManager.renameAudio(oldName, c.text);
                Navigator.pop(v);
                _refresh();
              }
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }
}
