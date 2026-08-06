import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../utils/setting_utils.dart';
import '../utils/static.dart';

class LottieSettingsTab extends StatefulWidget {
  const LottieSettingsTab({super.key});

  @override
  State<LottieSettingsTab> createState() => _LottieSettingsTabState();
}

class _LottieSettingsTabState extends State<LottieSettingsTab> {
  Future<void> _handleUpload(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'font' ? ['ttf', 'otf'] : ['json', 'lottie'],
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        if (type == 'next')
          Static.settings.lottieNext = result.files.first.bytes;
        else if (type == 'arrival')
          Static.settings.lottieArrival = result.files.first.bytes;
        else if (type == 'slogan')
          Static.settings.lottieSlogan = result.files.first.bytes;
        else if (type == 'font') {
          Static.settings.fontList.add(
            FontItem(
              id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
              name: result.files.first.name,
              type: 'custom',
              data: result.files.first.bytes,
            ),
          );
        }
      });
      await Static.saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildFileTile(
          "下一站 Lottie",
          Static.settings.lottieNext,
          (v) => Static.settings.lottieNext = v,
          () => _handleUpload('next'),
        ),
        _buildFileTile(
          "到站 Lottie",
          Static.settings.lottieArrival,
          (v) => Static.settings.lottieArrival = v,
          () => _handleUpload('arrival'),
        ),
        _buildFileTile(
          "行進間 Lottie",
          Static.settings.lottieSlogan,
          (v) => Static.settings.lottieSlogan = v,
          () => _handleUpload('slogan'),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text("自定義字體檔案", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...Static.settings.fontList
            .where((f) => f.type == 'custom')
            .map(
              (f) => ListTile(
                leading: const Icon(Icons.font_download),
                title: Text(f.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() => Static.settings.fontList.remove(f));
                    Static.saveSettings();
                  },
                ),
              ),
            ),
        ElevatedButton.icon(
          onPressed: () => _handleUpload('font'),
          icon: const Icon(Icons.upload),
          label: const Text("上傳字體檔案 (TTF/OTF)"),
        ),
      ],
    );
  }

  Widget _buildFileTile(
    String title,
    Uint8List? data,
    Function(Uint8List?) onRemove,
    VoidCallback onUpload,
  ) {
    return ListTile(
      leading: Icon(
        Icons.movie,
        color: data != null ? Colors.green : Colors.grey,
      ),
      title: Text(title),
      subtitle: Text(data != null ? "已上傳" : "未上傳"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() => onRemove(null));
                Static.saveSettings();
              },
            ),
          ElevatedButton(onPressed: onUpload, child: const Text("選擇")),
        ],
      ),
    );
  }
}
