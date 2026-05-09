import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

import '../utils/audio_manager.dart';
import '../utils/static.dart';
import '../utils/utils.dart'
    if (dart.library.js_interop) '../utils/utils_web.dart'
    if (dart.library.io) '../utils/utils_stub.dart';

class AudioPackDetailPage extends StatefulWidget {
  final VoicePack pack;

  const AudioPackDetailPage({super.key, required this.pack});

  @override
  State<AudioPackDetailPage> createState() => _AudioPackDetailPageState();
}

class _AudioPackDetailPageState extends State<AudioPackDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  late List<String> _allKeys;
  List<String> _filteredKeys = [];

  @override
  void initState() {
    super.initState();
    _allKeys = widget.pack.files.keys.toList()..sort();
    _filteredKeys = _allKeys;
  }

  void _onSearch(String v) {
    setState(() {
      _searchQuery = v;
      _filteredKeys = _allKeys
          .where((k) => k.toLowerCase().contains(v.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pack.name),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                "${widget.pack.files.length} 個檔案",
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "搜尋語音包內檔案...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch("");
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredKeys.isEmpty
                ? const Center(
                    child: Text(
                      "找不到相關檔案",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          mainAxisExtent: 160,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _filteredKeys.length,
                    itemBuilder: (context, index) {
                      final name = _filteredKeys[index];
                      return _buildAudioCard(name, theme);
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
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.play_circle, color: Colors.blue, size: 32),
            onPressed: () =>
                Static.audioManager.playRawBytes(widget.pack.files[name]!),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              height: 18,
              child: _buildMarqueeOrText(name, theme),
            ),
          ),
          const SizedBox(height: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.download, size: 18, color: Colors.green),
            onPressed: () =>
                downloadFile(widget.pack.files[name]!, "$name.mp3"),
          ),
        ],
      ),
    );
  }

  Widget _buildMarqueeOrText(String text, ThemeData theme) {
    final style = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 11,
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
}
