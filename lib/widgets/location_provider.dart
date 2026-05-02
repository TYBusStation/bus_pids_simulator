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

  LatLng? get currentLocation => _currentLocation;

  bool get serviceEnabled => _serviceEnabled;

  LocationPermission get permission => _permission;

  bool get isGpsReady =>
      _serviceEnabled &&
      (_permission == LocationPermission.always ||
          _permission == LocationPermission.whileInUse);

  LocationChangeNotifier() {
    _initLocation();
    if (!kIsWeb) {
      Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
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

      if (isGpsReady) {
        _startListening();
      }
    } catch (e) {
      debugPrint("定位初始化錯誤: $e");
    }
    notifyListeners();
  }

  void _startListening() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        notifyListeners();
      },
      onError: (e) {
        debugPrint("定位流錯誤: $e");
      },
    );
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
