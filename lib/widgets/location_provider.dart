import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class LocationChangeNotifier extends ChangeNotifier {
  LatLng? _currentLocation;
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  StreamSubscription<Position>? _subscription;
  bool _isDisposed = false;

  LatLng? get currentLocation => _currentLocation;

  bool get isGpsReady =>
      _serviceEnabled &&
      (_permission == LocationPermission.always ||
          _permission == LocationPermission.whileInUse);

  LocationChangeNotifier() {
    _initLocation();
    if (!kIsWeb) {
      Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        if (_isDisposed) return;
        _serviceEnabled = (status == ServiceStatus.enabled);
        notifyListeners();
      });
    } else {
      _serviceEnabled = true;
    }
  }

  Future<void> _initLocation() async {
    try {
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _permission = await Geolocator.checkPermission();
      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();
      }
      if (isGpsReady) _startListening();
    } catch (e) {
      debugPrint("定位初始化錯誤: $e");
    }
    if (!_isDisposed) notifyListeners();
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (_isDisposed) return;
          _currentLocation = LatLng(position.latitude, position.longitude);
          notifyListeners();
        }, onError: (e) => debugPrint("定位流錯誤: $e"));
  }

  Future<void> forceRefresh() async {
    try {
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabled) return;
      _permission = await Geolocator.checkPermission();
      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();
      }
      if (isGpsReady) {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _startListening();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("重定位失敗: $e");
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

class LocationProvider extends StatelessWidget {
  final Widget Function(BuildContext context, LatLng? location) builder;

  const LocationProvider({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationChangeNotifier>(
      builder: (context, notifier, _) =>
          builder(context, notifier.currentLocation),
    );
  }
}
