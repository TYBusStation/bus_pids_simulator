import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
      allowedExtensions: ['json', 'lottie'],
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        if (type == 'next')
          Static.lottieNext = result.files.first.bytes;
        else if (type == 'arrival')
          Static.lottieArrival = result.files.first.bytes;
        else
          Static.lottieSlogan = result.files.first.bytes;
      });
      await Static.saveSettings();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("儲存成功")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildTile("下一站", Static.lottieNext, () => _handleUpload('next')),
        _buildTile("到站", Static.lottieArrival, () => _handleUpload('arrival')),
        _buildTile("行進間", Static.lottieSlogan, () => _handleUpload('slogan')),
      ],
    );
  }

  Widget _buildTile(String title, Uint8List? data, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        Icons.file_present,
        color: data != null ? Colors.green : Colors.grey,
      ),
      title: Text(title),
      subtitle: Text(
        data != null
            ? "已上傳 (${(data.length / 1024).toStringAsFixed(1)} KB)"
            : "未上傳",
      ),
      trailing: ElevatedButton(onPressed: onTap, child: const Text("選擇檔案")),
    );
  }
}
