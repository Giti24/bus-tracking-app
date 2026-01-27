import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class LocationProvider extends ChangeNotifier {
  final Location _location = Location();

  LocationData? _locationData;
  LocationData? get locationData => _locationData;

  LatLng? _currentLatLng;
  LatLng? get currentLatLng => _currentLatLng;

  Future<bool> init() async {
    var serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    var permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _location.requestPermission();
      if (permissionStatus != PermissionStatus.granted &&
          permissionStatus != PermissionStatus.grantedLimited) {
        return false;
      }
    }

    _locationData = await _location.getLocation();
    _updateLatLng(_locationData);

    _location.onLocationChanged.listen((data) {
      _locationData = data;
      _updateLatLng(data);
      notifyListeners();
    });

    notifyListeners();
    return true;
  }

  void _updateLatLng(LocationData? data) {
    final lat = data?.latitude;
    final lng = data?.longitude;
    if (lat == null || lng == null) return;
    _currentLatLng = LatLng(lat, lng);
  }
}
