import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationChangeNotifier extends ChangeNotifier {
  LatLng? _currentLocation;
  double _currentSpeed = 0;
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  StreamSubscription<Position>? _subscription;
  bool _isDisposed = false;

  LatLng? get currentLocation => _currentLocation;

  double get currentSpeed => _currentSpeed;

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
      debugPrint(e.toString());
    }
    if (!_isDisposed) notifyListeners();
  }

  void _startListening() {
    _subscription?.cancel();
    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "正在背景運行定位服務",
          notificationTitle: "公車模擬器執行中",
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _subscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (_isDisposed) return;
            _currentLocation = LatLng(position.latitude, position.longitude);
            _currentSpeed = position.speed > 0 ? position.speed * 3.6 : 0;
            notifyListeners();
          },
          onError: (e) => debugPrint(e.toString()),
        );
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
        _currentSpeed = pos.speed > 0 ? pos.speed * 3.6 : 0;
        _startListening();
        notifyListeners();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
