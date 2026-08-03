import 'dart:ui';

import 'package:bus_pids_simulator/utils/formatter_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../utils/static.dart';
import 'audio_detail_page.dart';

class AudioPackPage extends StatefulWidget {
  const AudioPackPage({super.key});

  @override
  State<AudioPackPage> createState() => _AudioPackPageState();
}

class _AudioPackPageState extends State<AudioPackPage> {
  bool _loading = false;
  String _loadingText = "處理中...";

  void _importLocalZip() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.first.bytes == null) return;
    final defaultName = result.files.first.name.replaceAll('.zip', '');
    final nameController = TextEditingController(text: defaultName);
    final packName = await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("匯入語音包"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "請輸入語音包名稱"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(v, nameController.text),
            child: const Text("匯入"),
          ),
        ],
      ),
    );
    if (packName != null && packName.isNotEmpty) {
      setState(() {
        _loading = true;
        _loadingText = "正在解壓並儲存語音包...";
      });
      final ok = await Static.audioManager.importZipAsPack(
        packName,
        result.files.first.bytes!,
      );
      if (mounted) {
        setState(() => _loading = false);
        if (!ok)
          FormatterUtils.showSnackbar(context, "匯入失敗", color: Colors.red);
      }
    }
  }

  void _replacePack(int index) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.first.bytes == null) return;
    setState(() {
      _loading = true;
      _loadingText = "正在替換語音包內容...";
    });
    final ok = await Static.audioManager.replacePack(
      index,
      result.files.first.bytes!,
    );
    if (mounted) {
      setState(() => _loading = false);
      if (!ok)
        FormatterUtils.showSnackbar(context, "替換失敗", color: Colors.red);
      else
        FormatterUtils.showSnackbar(context, "替換成功");
    }
  }

  void _confirmDelete(int index, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("確認刪除"),
        content: Text("確定要刪除語音包「$name」嗎？\n此動作無法還原。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(v, true),
            child: const Text("刪除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Static.audioManager.removePack(index);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = Static.audioManager.voicePacks;
    return Stack(
      children: [
        Scaffold(
          floatingActionButton: FloatingActionButton(
            mini: true,
            onPressed: _loading ? null : _importLocalZip,
            child: const Icon(Icons.add_to_photos),
          ),
          body: packs.isEmpty
              ? const Center(
                  child: Text(
                    "尚未加入任何語音包",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ReorderableListView.builder(
                  onReorder: (oldIndex, newIndex) async {
                    await Static.audioManager.reorderPack(oldIndex, newIndex);
                    setState(() {});
                  },
                  itemCount: packs.length,
                  itemBuilder: (context, index) {
                    final pack = packs[index];
                    return Card(
                      key: ValueKey(pack.name),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Opacity(
                        opacity: pack.isEnabled ? 1.0 : 0.6,
                        child: ListTile(
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.drag_handle, color: Colors.grey),
                              Text(
                                "${index + 1}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            pack.name,
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              decoration: pack.isEnabled
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("檔案數: ${pack.fileNames.length}"),
                              Text(
                                "更新於: ${pack.updatedAt.toString().substring(0, 16)}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: pack.isEnabled,
                                onChanged: (val) async {
                                  await Static.audioManager.togglePackStatus(
                                    index,
                                    val,
                                  );
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.sync,
                                  color: Colors.orange,
                                ),
                                onPressed: () => _replacePack(index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _confirmDelete(index, pack.name),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => AudioPackDetailPage(pack: pack),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_loading)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                            _loadingText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "這可能需要幾秒鐘，請勿關閉視窗",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
