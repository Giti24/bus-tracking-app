import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'location_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};

  static const CameraPosition _initial = CameraPosition(
    target: LatLng(0, 0),
    zoom: 3,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<LocationProvider>();
      await provider.init();
      _moveToUserIfAvailable();
    });
  }

  void _moveToUserIfAvailable() {
    final provider = context.read<LocationProvider>();
    final pos = provider.currentLatLng;
    if (pos == null || _controller == null) return;

    _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 16),
      ),
    );

    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'me')
        ..add(
          Marker(
            markerId: const MarkerId('me'),
            position: pos,
            infoWindow: const InfoWindow(title: 'You'),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider(),
      child: Consumer<LocationProvider>(
        builder: (context, provider, _) {
          final userPos = provider.currentLatLng;

          if (userPos != null) {
            _markers
              ..removeWhere((m) => m.markerId.value == 'me')
              ..add(
                Marker(
                  markerId: const MarkerId('me'),
                  position: userPos,
                  infoWindow: const InfoWindow(title: 'You'),
                ),
              );
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Map')),
            body: GoogleMap(
              initialCameraPosition: _initial,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
              onMapCreated: (c) {
                _controller = c;
                _moveToUserIfAvailable();
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _moveToUserIfAvailable,
              child: const Icon(Icons.my_location),
            ),
          );
        },
      ),
    );
  }
}
