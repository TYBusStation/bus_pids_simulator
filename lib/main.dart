import 'package:bus_pids_simulator/pages/main_page.dart';
import 'package:bus_pids_simulator/utils/static.dart';
import 'package:bus_pids_simulator/utils/web_interop.dart'
    if (dart.library.html) 'package:bus_pids_simulator/utils/web_interop_web.dart'
    if (dart.library.io) 'package:bus_pids_simulator/utils/web_interop_stub.dart';
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

class App extends StatelessWidget {
  const App({super.key});

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
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '公車 PIDS 模擬器',
        theme: ThemeData.dark(useMaterial3: true),
        home: const LandscapeWatcher(child: MainPage()),
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
    final notifier = context.read<LandscapeChangeNotifier>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notifier.landscape != isLandscape) {
        notifier.setLandscape(isLandscape);
      }
    });

    return child;
  }
}
