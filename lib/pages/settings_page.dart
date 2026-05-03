import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/contact_item.dart';
import '../utils/static.dart';
import '../widgets/searchable_list.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _refresh() => setState(() {});

  Future<bool> _showConfirmDialog(
    String title,
    String content, {
    Color? confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("確認", style: TextStyle(color: confirmColor)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _handleZipImport() async {
    final files = await Static.audioManager.pickZipFiles();
    if (files == null || files.isEmpty) return;

    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("確認匯入 (${files.length} 個檔案)"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.keys.length,
                itemBuilder: (context, i) => Text(
                  "• ${files.keys.elementAt(i)}",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("開始匯入"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      for (var entry in files.entries) {
        await Static.audioManager.saveAudio(entry.key, entry.value);
      }
      _refresh();
    }
  }

  void _showAddAudioDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("新增自定義音檔"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "輸入名稱 (如：下一站 或 站名)"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              await Static.audioManager.pickAndSave(controller.text);
              if (mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text("選擇並上傳"),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("更名"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && controller.text != oldName) {
                await Static.audioManager.renameAudio(oldName, controller.text);
                if (mounted) Navigator.pop(context);
                _refresh();
              }
            },
            child: const Text("確認"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: "一般設定"),
              Tab(text: "語音音檔管理"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGeneralSettings(theme),
                _buildAudioManagement(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: List.generate(ContactItem.contactItems.length, (
                  index,
                ) {
                  final item = ContactItem.contactItems[index];
                  return ListTile(
                    dense: true,
                    leading: FaIcon(
                      item.icon,
                      size: 26,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(item.title),
                    trailing: OutlinedButton(
                      onPressed: () async =>
                          await launchUrl(Uri.parse(item.url)),
                      child: const Text("前往"),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioManagement(ThemeData theme) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: "zip_import",
            onPressed: _handleZipImport,
            tooltip: "匯入 ZIP",
            child: const Icon(Icons.drive_folder_upload),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zip_export",
            onPressed: () async {
              if (await _showConfirmDialog("匯出 ZIP", "即將將所有自定義音檔打包為 ZIP 下載。")) {
                Static.audioManager.exportAllZip();
              }
            },
            tooltip: "匯出 ZIP",
            child: const Icon(Icons.archive),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "add_audio",
            onPressed: _showAddAudioDialog,
            tooltip: "新增音檔",
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SearchableList<String>(
          allItems: Static.audioManager.allAudioNames,
          searchHintText: "搜尋自定義音檔",
          filterCondition: (item, query) =>
              item.toLowerCase().contains(query.toLowerCase()),
          emptyStateWidget: const Center(child: Text("目前無自定義音檔")),
          sortCallback: (a, b) => a.compareTo(b),
          itemBuilder: (context, name) => Card(
            child: ListTile(
              title: Text(name),
              leading: IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.blue),
                onPressed: () => Static.audioManager.playAudio(name),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showRenameDialog(name),
                    tooltip: "更名",
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, size: 20),
                    onPressed: () async {
                      if (await _showConfirmDialog("匯出音檔", "確定要下載「$name」嗎？")) {
                        Static.audioManager.exportSingle(name);
                      }
                    },
                    tooltip: "匯出此音檔",
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () async {
                      if (await _showConfirmDialog(
                        "確認刪除",
                        "確定要刪除「$name」嗎？",
                        confirmColor: Colors.red,
                      )) {
                        await Static.audioManager.deleteAudio(name);
                        _refresh();
                      }
                    },
                    tooltip: "刪除",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
