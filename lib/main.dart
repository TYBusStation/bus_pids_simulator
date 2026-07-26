import 'package:bus_pids_simulator/pages/main_page.dart';
import 'package:bus_pids_simulator/utils/static.dart';
import 'package:bus_pids_simulator/utils/version_check_service.dart';
import 'package:bus_pids_simulator/utils/web_interop_helper.dart';
import 'package:bus_pids_simulator/widgets/gps_control_provider.dart';
import 'package:bus_pids_simulator/widgets/landscape_provider.dart';
import 'package:bus_pids_simulator/widgets/location_provider.dart';
import 'package:bus_pids_simulator/widgets/route_analysis_provider.dart';
import 'package:bus_pids_simulator/widgets/status_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LandscapeChangeNotifier(false)),
        ChangeNotifierProvider(
          create: (_) => StatusChangeNotifier(Static.currentStatus),
        ),
        ChangeNotifierProvider(create: (_) => LocationChangeNotifier()),
        ChangeNotifierProxyProvider2<
          LocationChangeNotifier,
          StatusChangeNotifier,
          RouteAnalysisProvider
        >(
          create: (_) => RouteAnalysisProvider(),
          update: (_, loc, status, analysis) => analysis!
            ..update(
              loc.currentLocation,
              loc.currentSpeed,
              status.currentStatus,
            ),
        ),
        ChangeNotifierProvider(create: (_) => GpsControlProvider()),
      ],
      child: const AppLoader(),
    ),
  );
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _isInitialized = false;
  Map<String, dynamic>? _updateInfo;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    try {
      await Static.init();
      if (kIsWeb) {
        getWebInterop().hideFlutterLoader();
      }
      if (!kIsWeb) {
        final versionService = VersionCheckService();
        if (await versionService.isUpdateRequired()) {
          _updateInfo = await versionService.getLatestVersionInfo();
        }
      }
      setState(() {
        _isInitialized = true;
        _error = null;
      });
    } catch (e) {
      if (kIsWeb) {
        getWebInterop().hideFlutterLoader();
      }
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '公車 PIDS 模擬器',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        dialogTheme: DialogThemeData(
          titleTextStyle: ThemeData.dark().textTheme.titleSmall,
          contentTextStyle: ThemeData.dark().textTheme.bodySmall,
          insetPadding: const EdgeInsets.all(4),
          actionsPadding: const EdgeInsets.all(4),
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text("載入失敗: $_error"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startInitialization,
                child: const Text("重試"),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text('系統初始化中...'),
            ],
          ),
        ),
      );
    }

    return AppContent(
      updateInfo: _updateInfo,
      onSkipUpdate: () => setState(() => _updateInfo = null),
    );
  }
}

class AppContent extends StatefulWidget {
  final Map<String, dynamic>? updateInfo;
  final VoidCallback onSkipUpdate;

  const AppContent({super.key, this.updateInfo, required this.onSkipUpdate});

  @override
  State<AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<AppContent> {
  bool _showBottomInfo = true;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final landscapeNotifier = context.read<LandscapeChangeNotifier>();

    if (landscapeNotifier.landscape != isLandscape) {
      Future.microtask(() => landscapeNotifier.setLandscape(isLandscape));
    }

    return Stack(
      children: [
        MainPage(
          showBottomInfo: _showBottomInfo,
          onToggleBottomInfo: () =>
              setState(() => _showBottomInfo = !_showBottomInfo),
        ),
        if (widget.updateInfo != null)
          UpdatePage(
            updateInfo: widget.updateInfo!,
            onSkip: widget.onSkipUpdate,
          ),
      ],
    );
  }
}

class UpdatePage extends StatefulWidget {
  final Map<String, dynamic> updateInfo;
  final VoidCallback onSkip;

  const UpdatePage({super.key, required this.updateInfo, required this.onSkip});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool _isDownloading = false;
  double _progress = 0.0;

  Future<void> _startUpdate() async {
    setState(() => _isDownloading = true);
    try {
      await VersionCheckService().downloadAndInstall(
        widget.updateInfo['url'],
        (p) => setState(() => _progress = p),
      );
    } catch (e) {
      setState(() => _isDownloading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, size: 40, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                '發現新版本 v${widget.updateInfo['version']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              if (_isDownloading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text('${(_progress * 100).toStringAsFixed(1)}%'),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: widget.onSkip,
                      child: const Text('略過'),
                    ),
                    ElevatedButton(
                      onPressed: _startUpdate,
                      child: const Text('更新'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
