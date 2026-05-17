import 'package:bus_pids_simulator/pages/main_page.dart';
import 'package:bus_pids_simulator/utils/static.dart';
import 'package:bus_pids_simulator/utils/web_interop.dart'
    if (dart.library.js_interop) 'package:bus_pids_simulator/utils/web_interop_web.dart'
    if (dart.library.html) 'package:bus_pids_simulator/utils/web_interop_web.dart'
    if (dart.library.io) 'package:bus_pids_simulator/utils/web_interop_stub.dart';
import 'package:bus_pids_simulator/widgets/gps_control_provider.dart';
import 'package:bus_pids_simulator/widgets/landscape_provider.dart';
import 'package:bus_pids_simulator/widgets/location_provider.dart';
import 'package:bus_pids_simulator/widgets/route_analysis_provider.dart';
import 'package:bus_pids_simulator/widgets/status_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppLoader());
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Static.init(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          getWebInterop().hideFlutterLoader();
          return const App();
        } else {
          return MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('資料載入中，請稍候...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _showBottomInfo = true;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LandscapeChangeNotifier(false)),
        ChangeNotifierProvider(
          create: (_) => StatusChangeNotifier(Static.currentStatus),
        ),
        ChangeNotifierProvider(create: (_) => LocationChangeNotifier()),
        ChangeNotifierProvider(create: (_) => RouteAnalysisProvider()),
        ChangeNotifierProvider(create: (_) => GpsControlProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '公車 PIDS 模擬器',
        theme: ThemeData.dark(useMaterial3: true),
        home: LandscapeWatcher(
          child: MainPage(
            showBottomInfo: _showBottomInfo,
            onToggleBottomInfo: () =>
                setState(() => _showBottomInfo = !_showBottomInfo),
          ),
        ),
      ),
    );
  }
}

class LandscapeWatcher extends StatelessWidget {
  final Widget child;

  const LandscapeWatcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final landscapeNotifier = context.read<LandscapeChangeNotifier>();
    final locationNotifier = context.watch<LocationChangeNotifier>();
    final statusNotifier = context.watch<StatusChangeNotifier>();
    final analysisProvider = context.read<RouteAnalysisProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (landscapeNotifier.landscape != isLandscape) {
        landscapeNotifier.setLandscape(isLandscape);
      }
      analysisProvider.update(
        locationNotifier.currentLocation,
        locationNotifier.currentSpeed,
        statusNotifier.currentStatus,
      );
    });

    return child;
  }
}
