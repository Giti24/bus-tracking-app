import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class PassengerMode extends StatefulWidget {
  const PassengerMode({Key? key}) : super(key: key);

  @override
  State<PassengerMode> createState() => _PassengerModeState();
}

class _PassengerModeState extends State<PassengerMode> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  Position? _currentPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // 1) Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = "Location services are disabled.");
        return;
      }

      // 2) Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() => _error = "Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _error =
            "Location permission permanently denied. Enable it in Settings.");
        return;
      }

      // 3) Get location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _error = null;
      });

      await _uploadLocationToDatabase(position.latitude, position.longitude);
    } catch (e) {
      setState(() => _error = "Failed to get location: $e");
    }
  }

  Future<void> _uploadLocationToDatabase(
      double latitude, double longitude) async {
    await _databaseRef.push().set({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': ServerValue.timestamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    final pos = _currentPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Mode'),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, textAlign: TextAlign.center)
            : pos == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Latitude: ${pos.latitude}'),
                      Text('Longitude: ${pos.longitude}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: const Text("Refresh Location"),
                      ),
                    ],
                  ),
      ),
    );
  }
}
