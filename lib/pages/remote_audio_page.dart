import 'dart:typed_data';
import 'dart:ui';

import 'package:bus_pids_simulator/utils/formatter_utils.dart';
import 'package:bus_pids_simulator/utils/utils_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../utils/static.dart';

class ActionStatus {
  final double? progress;
  final String message;

  ActionStatus(this.progress, this.message);
}

class RemoteAudioPage extends StatefulWidget {
  const RemoteAudioPage({super.key});

  @override
  State<RemoteAudioPage> createState() => _RemoteAudioPageState();
}

class _RemoteAudioPageState extends State<RemoteAudioPage> {
  List<dynamic> _items = [];
  List<String> _pathStack = [""];
  bool _isLoadingList = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  String get _currentPath => _pathStack.last;

  Future<void> _fetchList() async {
    if (!mounted) return;
    setState(() => _isLoadingList = true);
    try {
      final encodedPath = Uri.encodeComponent(_currentPath);
      final url = "${Static.API_BASE}/internal/storage/list?path=$encodedPath";
      final resp = await Static.dio.get(url);
      if (resp.statusCode == 200) setState(() => _items = resp.data);
    } catch (e) {
      if (mounted) {
        FormatterUtils.showSnackbar(context, "載入清單失敗", color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _executeAction({
    required String relPath,
    required String fileName,
    required String title,
    required Future<bool> Function(
      Uint8List bytes,
      ValueNotifier<ActionStatus> notifier,
    )
    onDownloaded,
  }) async {
    _cancelToken = CancelToken();
    final ValueNotifier<ActionStatus> statusNotifier = ValueNotifier(
      ActionStatus(0.0, "正在下載"),
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      useRootNavigator: true,
      pageBuilder: (context, anim1, anim2) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Material(
            type: MaterialType.transparency,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Center(
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<ActionStatus>(
                        valueListenable: statusNotifier,
                        builder: (context, state, child) {
                          return Text(
                            state.message,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ValueListenableBuilder<ActionStatus>(
                        valueListenable: statusNotifier,
                        builder: (context, state, child) {
                          bool isIndeterminate = (state.progress == null);
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: isIndeterminate
                                      ? null
                                      : state.progress,
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isIndeterminate
                                    ? "請稍候..."
                                    : "${(state.progress! * 100).toInt()}%",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () {
                            _cancelToken?.cancel();
                            Navigator.of(context, rootNavigator: true).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text(
                            "取消",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final url =
          "${Static.API_BASE}/internal/storage/download?path=${Uri.encodeComponent(relPath)}";
      final response = await Static.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            statusNotifier.value = ActionStatus(received / total, "正在下載");
          } else {
            statusNotifier.value = ActionStatus(null, "正在下載");
          }
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final success = await onDownloaded(
          Uint8List.fromList(response.data!),
          statusNotifier,
        );
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (mounted && success) {
          FormatterUtils.showSnackbar(context, "「$fileName」$title成功");
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!CancelToken.isCancel(e as DioException)) {
        if (mounted) {
          FormatterUtils.showSnackbar(
            context,
            "$title失敗: $e",
            color: Colors.red,
          );
        }
      }
    }
  }

  void _downloadFile(String relPath, String fileName) {
    _executeAction(
      relPath: relPath,
      fileName: fileName,
      title: "下載",
      onDownloaded: (bytes, notifier) async {
        notifier.value = ActionStatus(null, "正在儲存檔案");
        downloadFile(bytes, fileName);
        return true;
      },
    );
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
    _executeAction(
      relPath: relPath,
      fileName: fileName,
      title: asPack ? "匯入語音包" : "匯入單獨語音",
      onDownloaded: (bytes, notifier) async {
        if (asPack) {
          notifier.value = ActionStatus(null, "正在解壓縮語音包");
          final packName = fileName.replaceAll('.zip', '');
          return await Static.audioManager.importZipAsPack(packName, bytes);
        } else {
          notifier.value = ActionStatus(null, "正在匯入語音");
          return await Static.audioManager.saveAudio(targetName, bytes);
        }
      },
    );
  }

  Future<String?> _showConflictDialog(String oldName) async {
    return showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("音檔已存在", style: TextStyle(fontSize: 14)),
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
            child: const Text("重命名"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items
        .where(
          (item) => item['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      children: [
        _buildHeader(),
        _buildPathBanner(),
        Expanded(
          child: _isLoadingList
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

  Widget _buildHeader() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (_pathStack.length > 1)
            IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() => _pathStack.removeLast());
                _fetchList();
              },
            ),
          const SizedBox(width: 4),
          const Text(
            "強烈建議使用非計量網路下載",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 22,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText: "搜尋...",
                  prefixIcon: const Icon(Icons.search, size: 12),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          IconButton(
            iconSize: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.refresh),
            onPressed: _fetchList,
          ),
        ],
      ),
    );
  }

  Widget _buildPathBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      width: double.infinity,
      color: Colors.blue.withOpacity(0.04),
      child: Text(
        "PATH: ${_currentPath.isEmpty ? "/" : "/$_currentPath"}",
        style: const TextStyle(
          fontSize: 8,
          color: Colors.blueGrey,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildListItem(dynamic item) {
    final String name = item['name'];
    final bool isDir = item['is_dir'];
    final String relPath = item['rel_path'];
    final String updatedAt = item['updated_at'] ?? "";
    final String ext = name.split('.').last.toLowerCase();
    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        isDir ? Icons.folder : Icons.audiotrack,
        color: isDir ? Colors.amber : Colors.blueGrey,
        size: 16,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isDir ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: isDir
          ? null
          : Text(
              "更新於: $updatedAt",
              style: const TextStyle(fontSize: 9, color: Colors.grey),
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(0, 22),
      textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
    return Wrap(
      spacing: 3,
      children: [
        FilledButton.icon(
          onPressed: () => _downloadFile(relPath, name),
          icon: const Icon(Icons.download, size: 10),
          label: const Text("下載"),
          style: style,
        ),
        if (ext != 'zip')
          FilledButton.icon(
            onPressed: () => _importAction(relPath, name, false),
            icon: const Icon(Icons.add, size: 10),
            label: const Text("匯入單獨語音"),
            style: style.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.orange.shade700),
            ),
          ),
        if (ext == 'zip')
          FilledButton.icon(
            onPressed: () => _importAction(relPath, name, true),
            icon: const Icon(Icons.unarchive, size: 10),
            label: const Text("匯入語音包"),
            style: style.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.green.shade700),
            ),
          ),
      ],
    );
  }
}
