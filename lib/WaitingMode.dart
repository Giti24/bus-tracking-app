import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WaitingMode extends StatefulWidget {
  const WaitingMode({Key? key}) : super(key: key);

  @override
  _WaitingModeState createState() => _WaitingModeState();
}

class _WaitingModeState extends State<WaitingMode> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final List<Marker> _markers = [];
  GoogleMapController? _controller;
  String? _selectedDestinationName;
  List<LatLng>? _selectedRoutePoints;
  double? _selectedDestinationLat;
  double? _selectedDestinationLng;
  // optional bounds cache for zooming when map becomes ready
  LatLngBounds? _selectedRouteBounds;

  @override
  void initState() {
    super.initState();
    _listenPassengerLocations();
    _loadSelectedDestination();
  }

  void _listenPassengerLocations() {
    _databaseRef.onChildAdded.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) return;

      final data = Map<String, dynamic>.from(value);

      final lat = data['latitude'];
      final lng = data['longitude'];

      if (lat is! num || lng is! num) return;

      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId(event.snapshot.key ?? DateTime.now().toString()),
            position: LatLng(lat.toDouble(), lng.toDouble()),
          ),
        );
      });
    });
  }

  Future<void> _loadSelectedDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('selected_destination');
    if (s == null) return;
    try {
      final Map<String, dynamic> stored = json.decode(s) as Map<String, dynamic>;
      final name = stored['name'] as String?;
      final route = stored['route'] as List<dynamic>?;
      final sLat = stored['lat'];
      final sLon = stored['lon'];
      double? parsedLat = double.tryParse(sLat?.toString() ?? '');
      double? parsedLon = double.tryParse(sLon?.toString() ?? '');
      List<LatLng>? points;
      if (route != null) {
        points = route.map((p) {
          final m = p as Map<String, dynamic>;
          return LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble());
        }).toList();
      }
      setState(() {
        _selectedDestinationName = name;
        _selectedDestinationLat = parsedLat;
        _selectedDestinationLng = parsedLon;
        _selectedRoutePoints = points;
        if (points != null && points.isNotEmpty) {
          // add route markers (start and end) for visualization
          _markers.add(Marker(markerId: const MarkerId('selected_start'), position: points.first));
          _markers.add(Marker(markerId: const MarkerId('selected_end'), position: points.last));
          _selectedRouteBounds = _computeBounds(points);
        }
      });
    } catch (_) {
      // ignore parse errors
    }
  }

  // Helper: compute LatLngBounds for a list of points
  LatLngBounds _computeBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLng == null || p.longitude < minLng) minLng = p.longitude;
      if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  // Helper: zoom to route bounds if available
  Future<void> _zoomToRouteIfNeeded() async {
    if (_controller != null && _selectedRouteBounds != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(_selectedRouteBounds!, 100),
      );
    }
  }

  // Helper: clear stored destination and route
  Future<void> _clearSelectedDestination() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_destination');
    setState(() {
      _selectedDestinationName = null;
      _selectedRoutePoints = null;
      _selectedRouteBounds = null;
      _selectedDestinationLat = null;
      _selectedDestinationLng = null;
      _markers.removeWhere((m) =>
          m.markerId.value == 'selected_start' || m.markerId.value == 'selected_end');
    });
  }

  // Show confirmation dialog before clearing
  void _confirmClear() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear selected destination?'),
        content: const Text('This will remove the saved route and destination.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (res == true) {
      await _clearSelectedDestination();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F1A17);
    const muted = Color(0xFF6F665D);
    // panel color constant not needed directly; colors used inline to satisfy analyzer.

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2ED),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 3,
              ),
              onMapCreated: (controller) {
                _controller = controller;
                // if we already loaded a route earlier, zoom to it now
                _zoomToRouteIfNeeded();
              },
              markers: Set<Marker>.of(_markers),
              polylines: _selectedRoutePoints != null && _selectedRoutePoints!.length > 1
                  ? {
                      Polyline(
                        polylineId: const PolylineId('selected_route'),
                        color: Colors.blueAccent,
                        width: 5,
                        points: _selectedRoutePoints!,
                      )
                    }
                  : {},
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(252, 249, 245, 0.96),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEEE0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_pin_circle_rounded,
                            color: Color(0xFF2E6B4A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Waiting Mode",
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Listening for passenger pings",
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                              if (_selectedDestinationName != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  "Selected: $_selectedDestinationName",
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: ink,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_selectedDestinationLat != null && _selectedDestinationLng != null)
                                  Text(
                                    "Lat: ${_selectedDestinationLat!.toStringAsFixed(5)}, Lng: ${_selectedDestinationLng!.toStringAsFixed(5)}",
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                if (_selectedRoutePoints != null && _selectedRoutePoints!.isNotEmpty)
                                  Text(
                                    "Route: ${_selectedRoutePoints!.length} points",
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F2FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "LIVE",
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2B5EA3),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Clear-selection action: ask confirmation then clear stored choice
                        IconButton(
                          tooltip: 'Clear selected destination',
                          icon: const Icon(Icons.delete_outline),
                          color: const Color(0xFF6F665D),
                          onPressed: _selectedDestinationName == null ? null : _confirmClear,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(252, 249, 245, 0.98),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 12,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2D9C9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFB85A2B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${_markers.length} passengers spotted",
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Tap a marker to view pickup points",
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFB85A2B),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
