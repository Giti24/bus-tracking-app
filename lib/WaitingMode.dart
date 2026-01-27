import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

class WaitingMode extends StatefulWidget {
  const WaitingMode({Key? key}) : super(key: key);

  @override
  _WaitingModeState createState() => _WaitingModeState();
}

class _WaitingModeState extends State<WaitingMode> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final List<Marker> _markers = [];
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _listenPassengerLocations();
  }

  void _listenPassengerLocations() {
    _databaseRef.onChildAdded.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) return;

      final data = Map<String, dynamic>.from(value as Map);

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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F1A17);
    const muted = Color(0xFF6F665D);
    const panel = Color(0xFFFCF9F5);

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
              onMapCreated: (controller) => _controller = controller,
              markers: Set<Marker>.of(_markers),
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
                      color: panel.withOpacity(0.96),
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
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panel.withOpacity(0.98),
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
