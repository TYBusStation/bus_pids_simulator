import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _launchDownloadUrl() async {
    final Uri url = Uri.parse(
      'https://github.com/TYBusStation/bus_pids_simulator/releases/latest',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("無法開啟連結")));
      }
    }
  }

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

      // 重要：延遲一小段時間讓 UI 先渲染出 Loading 動畫，避免同步運算直接卡死第一幀
      await Future.delayed(const Duration(milliseconds: 300));

      final ok = await Static.audioManager.importZipAsPack(
        packName,
        result.files.first.bytes!,
      );

      if (mounted) {
        setState(() => _loading = false);
        if (!ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("匯入失敗")));
        }
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

    await Future.delayed(const Duration(milliseconds: 300));

    final ok = await Static.audioManager.replacePack(
      index,
      result.files.first.bytes!,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (!ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("替換失敗")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("替換成功")));
      }
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
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: _loading ? null : _importLocalZip,
            child: const Icon(Icons.add_to_photos),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "前往 Release 頁面下載語音包(不定期更新，請留意是否更新)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _launchDownloadUrl,
                      icon: const Icon(Icons.open_in_new, size: 12),
                      label: const Text("前往"),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: packs.isEmpty
                    ? Center(
                        child: const Text(
                          "尚未加入任何語音包",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: packs.length,
                        itemBuilder: (context, index) {
                          final pack = packs[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.folder_zip,
                                color: Colors.blue,
                              ),
                              title: Text(pack.name),
                              subtitle: Text("檔案數: ${pack.files.length}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                  builder: (c) =>
                                      AudioPackDetailPage(pack: pack),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        // 加強版的加載動畫
        if (_loading)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // 背景模糊
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
