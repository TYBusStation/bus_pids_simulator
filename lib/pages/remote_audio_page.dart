import 'dart:convert';
import 'dart:html' as html;

import 'package:bus_pids_simulator/utils/formatter_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/static.dart';

class RemoteAudioPage extends StatefulWidget {
  const RemoteAudioPage({super.key});

  @override
  State<RemoteAudioPage> createState() => _RemoteAudioPageState();
}

class _RemoteAudioPageState extends State<RemoteAudioPage> {
  List<dynamic> _items = [];
  List<String> _pathStack = [""];
  bool _isLoading = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  String get _currentPath => _pathStack.last;

  Future<void> _fetchList() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final encodedPath = Uri.encodeComponent(_currentPath);
      final url = Uri.parse(
        "${Static.API_BASE}/internal/storage/list?path=$encodedPath",
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        setState(() => _items = json.decode(resp.body));
      }
    } catch (e) {
      if (mounted) {
        FormatterUtils.showSnackbar(context, "載入失敗: $e", color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _downloadFile(String relPath, String fileName) {
    final url =
        "${Static.API_BASE}/internal/storage/download?path=${Uri.encodeComponent(relPath)}";
    html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
  }

  Future<void> _importAction(
    String relPath,
    String fileName,
    bool asPack,
  ) async {
    String targetName = fileName;

    if (!asPack && Static.audioManager.hasLocalAudio(fileName)) {
      final result = await _showConflictDialog(fileName);
      if (result == null) return;
      if (result == "rename") {
        targetName = Static.audioManager.generateUniqueName(fileName);
      }
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        "${Static.API_BASE}/internal/storage/download?path=${Uri.encodeComponent(relPath)}",
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        bool ok = false;
        if (asPack) {
          final packName = fileName.replaceAll('.zip', '');
          ok = await Static.audioManager.importZipAsPack(
            packName,
            resp.bodyBytes,
          );
        } else {
          ok = await Static.audioManager.saveAudio(targetName, resp.bodyBytes);
        }
        if (mounted) {
          if (ok) {
            FormatterUtils.showSnackbar(
              context,
              asPack ? "匯入語音包「$targetName」成功" : "匯入「$targetName」成功",
            );
          } else {
            FormatterUtils.showSnackbar(
              context,
              asPack ? "匯入語音包「$targetName」失敗" : "匯入「$targetName」失敗",
              color: Colors.red,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        FormatterUtils.showSnackbar(context, "匯入錯誤: $e", color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showConflictDialog(String oldName) async {
    return showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("音檔已存在", style: TextStyle(fontSize: 15)),
        content: Text("「$oldName」已在本地庫中，請選擇處理方式："),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(v, "overwrite"),
            child: const Text("覆蓋"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(v, "rename"),
            child: const Text("自動重命名"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) {
      return item['name'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              if (_pathStack.length > 1)
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() => _pathStack.removeLast());
                    _fetchList();
                  },
                ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "雲端資源庫",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.refresh),
                onPressed: _fetchList,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: SizedBox(
            height: 28,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: "搜尋清單...",
                prefixIcon: const Icon(Icons.search, size: 14),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.grey.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          width: double.infinity,
          color: Colors.blue.withOpacity(0.04),
          child: Text(
            "PATH: ${_currentPath.isEmpty ? "/" : "/$_currentPath"}",
            style: const TextStyle(
              fontSize: 9,
              color: Colors.blueGrey,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filteredItems.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildListItem(filteredItems[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildListItem(dynamic item) {
    final String name = item['name'];
    final bool isDir = item['is_dir'];
    final String relPath = item['rel_path'];
    final String ext = name.split('.').last.toLowerCase();

    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        isDir ? Icons.folder : Icons.audiotrack,
        color: isDir ? Colors.amber : Colors.blueGrey,
        size: 18,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isDir ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: isDir
          ? () {
              setState(() {
                _pathStack.add(relPath);
                _searchQuery = "";
                _searchController.clear();
              });
              _fetchList();
            }
          : null,
      trailing: isDir
          ? const Icon(Icons.keyboard_arrow_right, size: 14)
          : _buildFileActions(relPath, name, ext),
    );
  }

  Widget _buildFileActions(String relPath, String name, String ext) {
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: const Size(0, 24),
      textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );

    return Wrap(
      spacing: 4,
      children: [
        FilledButton.icon(
          onPressed: () => _downloadFile(relPath, name),
          icon: const Icon(Icons.download, size: 12),
          label: const Text("下載"),
          style: style,
        ),
        if (ext != 'zip')
          FilledButton.icon(
            onPressed: () => _importAction(relPath, name, false),
            icon: const Icon(Icons.add, size: 12),
            label: const Text("匯入單獨語音"),
            style: style.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.orange.shade700),
            ),
          ),
        if (ext == 'zip')
          FilledButton.icon(
            onPressed: () => _importAction(relPath, name, true),
            icon: const Icon(Icons.unarchive, size: 12),
            label: const Text("匯入語音包"),
            style: style.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.green.shade700),
            ),
          ),
      ],
    );
  }
}
