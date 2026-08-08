import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/setting_utils.dart';
import '../../utils/static.dart';

class LottieSettingsTab extends StatefulWidget {
  const LottieSettingsTab({super.key});

  @override
  State<LottieSettingsTab> createState() => _LottieSettingsTabState();
}

class _LottieSettingsTabState extends State<LottieSettingsTab> {
  FontWeight _resolveFontWeight(String style, String weight) {
    final String s = (style + weight).toLowerCase().trim();
    if (s.contains('900') || s.contains('black')) return FontWeight.w900;
    if (s.contains('800') || (s.contains('extra') && s.contains('bold')))
      return FontWeight.w800;
    if (s.contains('700') || s.contains('bold')) return FontWeight.w700;
    if (s.contains('600') || s.contains('semi')) return FontWeight.w600;
    if (s.contains('500') || s.contains('medium')) return FontWeight.w500;
    if (s.contains('400') || s.contains('regular')) return FontWeight.w400;
    if (s.contains('300') || s.contains('light')) return FontWeight.w300;
    if (s.contains('100') || s.contains('thin')) return FontWeight.w100;
    return FontWeight.normal;
  }

  Future<void> _preCacheLottieFonts(Uint8List data) async {
    try {
      final json = jsonDecode(utf8.decode(data));
      if (json['fonts'] == null || json['fonts']['list'] == null) return;
      final googleMap = GoogleFonts.asMap();
      for (var f in (json['fonts']['list'] as List)) {
        final family = (f['fFamily']?.toString() ?? "").trim();
        final style = (f['fStyle']?.toString() ?? "").trim();
        final weight = (f['fWeight']?.toString() ?? "").trim();
        final normalized = family
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('-', '');
        String? matchKey;
        for (var key in googleMap.keys) {
          if (key.toLowerCase().replaceAll(' ', '').replaceAll('-', '') ==
              normalized) {
            matchKey = key;
            break;
          }
        }
        if (matchKey != null) {
          await GoogleFonts.pendingFonts([
            GoogleFonts.getFont(
              matchKey,
              fontWeight: _resolveFontWeight(style, weight),
            ),
          ]);
        }
      }
    } catch (_) {}
  }

  Future<void> _handleUpload(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'font' ? ['ttf', 'otf'] : ['json', 'lottie'],
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      final bytes = result.files.first.bytes!;
      final fileName = result.files.first.name;
      if (type == 'font') {
        final fontName = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;
        await Static.registerFont(fontName, bytes);
        setState(
          () => Static.settings.fontList.add(
            FontItem(id: fontName, name: fontName, type: 'custom', data: bytes),
          ),
        );
      } else {
        await _preCacheLottieFonts(bytes);
        setState(() {
          if (type == 'next')
            Static.settings.lottieNext = bytes;
          else if (type == 'arrival')
            Static.settings.lottieArrival = bytes;
          else if (type == 'slogan')
            Static.settings.lottieSlogan = bytes;
        });
      }
      await Static.saveSettings();
      await Static.loadAllFonts();
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
