import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'Simulator.dart';

class PassengerMode extends StatefulWidget {
  const PassengerMode({Key? key}) : super(key: key);

  @override
  _PassengerModeState createState() => _PassengerModeState();
}


class _PassengerModeState extends State<PassengerMode> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

    // Using OpenStreetMap Nominatim for search/geocoding and OSRM for routing.
    // No API key required for basic usage. Note: respect Nominatim usage policy and set a proper User-Agent.

      GoogleMapController? _controller;
      final TextEditingController _destController = TextEditingController();
      final List<Polyline> _polylines = [];
      Marker? _originMarker;
      Marker? _destMarker;
      // --- Mock destinations (Tirana) ---
      final List<Map<String, dynamic>> _mockDestinations = [
        {
          'name': 'Skanderbeg Square',
          'lat': 41.3275,
          'lon': 19.8187,
          // longer mock route with many intermediate points and stops at 4 indices
          'route': [
            {'lat': 41.3350, 'lon': 19.8240},
            {'lat': 41.3335, 'lon': 19.8230},
            {'lat': 41.3320, 'lon': 19.8215},
            {'lat': 41.3305, 'lon': 19.8205},
            {'lat': 41.3290, 'lon': 19.8195},
            {'lat': 41.3280, 'lon': 19.8190},
            {'lat': 41.3275, 'lon': 19.8187},
            {'lat': 41.3265, 'lon': 19.8180},
            {'lat': 41.3250, 'lon': 19.8170},
            {'lat': 41.3235, 'lon': 19.8160},
            {'lat': 41.3220, 'lon': 19.8150},
            {'lat': 41.3205, 'lon': 19.8140},
          ],
          // stops indices (4 stops)
          'stops': [2, 5, 8, 11],
        },
        {
          'name': 'Grand Park (Parku i Madh)',
          'lat': 41.3151,
          'lon': 19.8314,
          'route': [
            {'lat': 41.3320, 'lon': 19.8270},
            {'lat': 41.3300, 'lon': 19.8280},
            {'lat': 41.3280, 'lon': 19.8290},
            {'lat': 41.3260, 'lon': 19.8300},
            {'lat': 41.3240, 'lon': 19.8305},
            {'lat': 41.3220, 'lon': 19.8310},
            {'lat': 41.3200, 'lon': 19.8314},
            {'lat': 41.3180, 'lon': 19.8316},
            {'lat': 41.3160, 'lon': 19.8315},
            {'lat': 41.3151, 'lon': 19.8314},
            {'lat': 41.3140, 'lon': 19.8313},
            {'lat': 41.3130, 'lon': 19.8310},
          ],
          'stops': [1, 4, 7, 10],
        },
        {
          'name': 'Tirana International Airport',
          'lat': 41.4141,
          'lon': 19.7201,
          'route': [
            {'lat': 41.3800, 'lon': 19.7700},
            {'lat': 41.3850, 'lon': 19.7600},
            {'lat': 41.3900, 'lon': 19.7500},
            {'lat': 41.3950, 'lon': 19.7400},
            {'lat': 41.4000, 'lon': 19.7300},
            {'lat': 41.4050, 'lon': 19.7250},
            {'lat': 41.4100, 'lon': 19.7220},
            {'lat': 41.4141, 'lon': 19.7201},
            {'lat': 41.4170, 'lon': 19.7180},
            {'lat': 41.4200, 'lon': 19.7160},
            {'lat': 41.4230, 'lon': 19.7140},
            {'lat': 41.4250, 'lon': 19.7120},
          ],
          'stops': [0, 4, 7, 11],
        },
      ];
      String? _selectedMockName;
          // Autocomplete suggestions state
          List<Map<String, String>> _suggestions = []; // { 'description': ..., 'place_id': ... }
          Timer? _debounce;
          bool _loadingSuggestions = false;
          String? _placesStatus;
          String? _lastApiError;
          // lightweight in-memory cache to avoid repeated identical requests
          final Map<String, List<Map<String, String>>> _suggestionsCache = {};

      // Helper to perform HTTP GET with retries and exponential backoff
      Future<http.Response> _httpGetWithRetries(Uri url, {Map<String,String>? headers, int retries = 2, Duration timeout = const Duration(seconds:15)}) async {
        int attempt = 0;
        while (true) {
          try {
            attempt++;
            final resp = await http.get(url, headers: headers).timeout(timeout);
            return resp;
          } on TimeoutException catch (_) {
            if (attempt > retries) rethrow;
            // short exponential backoff
            final backoff = Duration(milliseconds: 300 * (1 << (attempt - 1)));
            // ignore: avoid_print
            print('Request timeout (attempt $attempt) to $url, retrying after $backoff');
            await Future.delayed(backoff);
            continue;
          } catch (e) {
            // other network errors: if no retries left, rethrow to be handled by caller
            if (attempt > retries) rethrow;
            final backoff = Duration(milliseconds: 300 * (1 << (attempt - 1)));
            // ignore: avoid_print
            print('Request failed (attempt $attempt) to $url: $e, retrying after $backoff');
            await Future.delayed(backoff);
          }
        }
      }

  Position? _currentPosition;
  String? _error;
  final Set<Marker> _markers = {};
  DateTime? _lastUpdated;

    @override
    void initState() {
    super.initState();
    _getCurrentLocation();
    _destController.addListener(() {
      _onDestChanged(_destController.text);
    });
    }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = "Location services are disabled.");
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() => _error = "Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _error = "Location permission permanently denied.");
        return;
      }

      // ✅ New API (no deprecated desiredAccuracy)
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      setState(() {
        _currentPosition = position;
        _error = null;
        _lastUpdated = DateTime.now();
        _markers
          ..clear()
          ..add(
            Marker(
              markerId: const MarkerId("me"),
              position: LatLng(position.latitude, position.longitude),
            ),
          );
        _originMarker = Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(position.latitude, position.longitude),
        );
      });

      await _uploadLocationToDatabase(position.latitude, position.longitude);
    } catch (e) {
      setState(() => _error = "Failed to get location.");
    }
  }

    Future<void> _uploadLocationToDatabase(
      double latitude, double longitude) async {
    await _databaseRef.push().set({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
    }

    // --- Autocomplete & routing helpers ---
    void _onDestChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(text.trim());
    });
    }

    // Apply a chosen mock destination: draw its route, markers and store locally.
     Future<void> _applyMockDestination(Map<String, dynamic> dest) async {
       final name = dest['name'] as String? ?? 'Unknown';
       final lat = (dest['lat'] as num).toDouble();
       final lon = (dest['lon'] as num).toDouble();

       // build polyline points from mock route
       final List<LatLng> points = [];
       final route = dest['route'] as List<dynamic>? ?? [];
       for (final p in route) {
         final m = p as Map<String, dynamic>;
         final rlat = (m['lat'] as num).toDouble();
         final rlon = (m['lon'] as num).toDouble();
         points.add(LatLng(rlat, rlon));
       }

       final poly = Polyline(
         polylineId: PolylineId('mock_${name}'),
         color: Colors.deepPurple,
         width: 5,
         points: points,
       );

       setState(() {
         _polylines
           ..clear()
           ..add(poly);
         _destMarker = Marker(
           markerId: const MarkerId('dest'),
           position: LatLng(lat, lon),
           infoWindow: InfoWindow(title: name),
         );
         if (_originMarker != null) {
           _markers.removeWhere((m) => m.markerId == _originMarker!.markerId);
         }
         _originMarker = Marker(
           markerId: const MarkerId('origin'),
           position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
         );
         _markers
           ..removeWhere((m) => m.markerId == const MarkerId('dest') || m.markerId == const MarkerId('origin'))
           ..addAll([_originMarker!, _destMarker!]);
         _selectedMockName = name;
         _destController.text = name;
       });

       // Save to shared preferences for Waiting page to pick up
       final prefs = await SharedPreferences.getInstance();
       final stored = {
         'name': name,
         'lat': lat,
         'lon': lon,
         'route': route,
         'stops': dest['stops'] ?? [],
       };
       await prefs.setString('selected_destination', json.encode(stored));
       // Auto-start simulation for this selected route (single route list)
       try {
         BusSimManager.startForRoutes(FirebaseDatabase.instance.ref(), [dest], tickMs: 1000, stepFraction: 0.005, stopSeconds: 30);
       } catch (_) {}
       // show small confirmation
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected $name')));
     }

    Future<void> _fetchSuggestions(String input) async {
    // Use Nominatim search API for suggestions (no key required). Observe fair-use policy.
    setState(() => _loadingSuggestions = true);
    // Serve from cache for exact queries
    if (_suggestionsCache.containsKey(input)) {
      setState(() {
        _suggestions = _suggestionsCache[input]!;
        _placesStatus = 'OK_CACHED';
        _lastApiError = null;
        _loadingSuggestions = false;
      });
      return;
    }
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent(input)}&addressdetails=1&limit=6');
      final resp = await _httpGetWithRetries(url, headers: {'User-Agent': 'bus-tracking-app/1.0 (you@example.com)'}, retries: 2, timeout: const Duration(seconds: 15));
      // debug log
      // ignore: avoid_print
      print('Nominatim search response: ${resp.statusCode} ${resp.body}');
      if (resp.statusCode != 200) {
        setState(() {
          _suggestions = [];
          _placesStatus = 'NOMINATIM_ERROR';
          _lastApiError = 'HTTP ${resp.statusCode}';
        });
        return;
      }
      final List<dynamic> items = json.decode(resp.body) as List<dynamic>;
      if (items.isEmpty) {
        setState(() {
          _suggestions = [];
          _placesStatus = 'ZERO_RESULTS';
          _lastApiError = null;
        });
        return;
      }
      setState(() {
        _suggestions = items.map((it) {
          final m = it as Map<String, dynamic>;
          return <String, String>{
            'description': (m['display_name'] ?? '').toString(),
            'lat': (m['lat'] ?? '').toString(),
            'lon': (m['lon'] ?? '').toString(),
          };
        }).toList();
        // cache the results for this input
        _suggestionsCache[input] = List<Map<String,String>>.from(_suggestions);
        _placesStatus = 'OK_NOMINATIM';
        _lastApiError = null;
      });
    } catch (e) {
      // network or parse error
      // ignore: avoid_print
      print('Nominatim fetch error: $e');
      // surface friendly message for timeout-like errors
      final msg = e is TimeoutException ? 'Timeout waiting for search service' : e.toString();
      setState(() {
        _suggestions = [];
        _placesStatus = 'ERROR';
        _lastApiError = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => _loadingSuggestions = false);
    }
    }

      Future<void> _selectSuggestion(Map<String, String> s) async {
        final desc = s['description'] ?? '';
        final lat = double.tryParse(s['lat'] ?? '');
        final lon = double.tryParse(s['lon'] ?? '');
        _destController.text = desc;
        setState(() => _suggestions = []);
        if (lat != null && lon != null) {
          await _routeToCoordinates(lat, lon, desc);
        } else {
          await _searchAndRoute();
        }
      }

    Future<void> _routeToCoordinates(double destLat, double destLng, String destLabel) async {
    final origin = _currentPosition;
    if (origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current location not available')));
      return;
    }
    try {
      // Use OSRM public routing server for free routing (profile: driving)
      final coords = '${origin.longitude},${origin.latitude};$destLng,$destLat';
      final osrmUrl = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=polyline');
      final dirResp = await _httpGetWithRetries(osrmUrl, retries: 2, timeout: const Duration(seconds: 15));
      // debug
      // ignore: avoid_print
      print('OSRM route response: ${dirResp.statusCode} ${dirResp.body}');
      if (dirResp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routing service unavailable')));
        return;
      }
      final dirJson = json.decode(dirResp.body) as Map<String, dynamic>;
      final routes = (dirJson['routes'] as List?) ?? [];
      if (routes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No route found')));
        return;
      }
      final overviewPolyline = (routes[0]['geometry'] ?? '') as String;
      final points = _decodePolyline(overviewPolyline);
      final poly = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blue,
        width: 5,
        points: points,
      );
      setState(() {
        _polylines
          ..clear()
          ..add(poly);
        _destMarker = Marker(
          markerId: const MarkerId('dest'),
          position: LatLng(destLat, destLng),
          infoWindow: InfoWindow(title: destLabel),
        );
        _originMarker = Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(origin.latitude, origin.longitude),
        );
        _markers
          ..removeWhere((m) => m.markerId == const MarkerId('dest') || m.markerId == const MarkerId('origin'))
          ..addAll([_originMarker!, _destMarker!]);
      });
      if (_controller != null && points.isNotEmpty) {
        final swLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
        final swLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
        final neLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
        final neLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
        final bounds = LatLngBounds(southwest: LatLng(swLat, swLng), northeast: LatLng(neLat, neLng));
        final camUpdate = CameraUpdate.newLatLngBounds(bounds, 60);
        _controller!.moveCamera(camUpdate);
      }
    } catch (e) {
      final msg = e is TimeoutException ? 'Timeout waiting for routing service' : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Routing failed: $msg')));
      setState(() => _lastApiError = msg);
    }
    }

  @override
  Widget build(BuildContext context) {
    final position = _currentPosition;
    const ink = Color(0xFF1F1A17);
    const muted = Color(0xFF6F665D);

    if (_error != null) {
      return _StatusScaffold(
        title: "Location issue",
        message: _error!,
        onRetry: _getCurrentLocation,
      );
    }

    if (position == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F2ED),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                "Finding your location...",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2ED),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 16,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              polylines: Set<Polyline>.of(_polylines),
              onMapCreated: (c) => _controller = c,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Make top content scrollable so the overlay never overflows
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Destination search + suggestions dropdown
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String?>(
                                      value: _selectedMockName,
                                      hint: const Text('Select destination'),
                                      items: _mockDestinations.map((d) => DropdownMenuItem<String?>(
                                        value: d['name'] as String,
                                        child: Text(d['name'] as String),
                                      )).toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedMockName = v;
                                          _destController.text = v ?? '';
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_selectedMockName != null) {
                                        final dest = _mockDestinations.firstWhere((d) => d['name'] == _selectedMockName);
                                        _applyMockDestination(dest);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination')));
                                      }
                                    },
                                    child: const Text('Go'),
                                  ),
                                ],
                              ),
                              // Suggestions list
                              if (_suggestions.isNotEmpty || _loadingSuggestions) ...[
                                const SizedBox(height: 8),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0,4))],
                                  ),
                                  child: _loadingSuggestions
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: Center(child: SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2))),
                                        )
                                      : ListView.separated(
                                          shrinkWrap: true,
                                          padding: const EdgeInsets.all(8),
                                          itemCount: _suggestions.length,
                                          separatorBuilder: (_, __) => const Divider(height: 8),
                                          itemBuilder: (context, i) {
                                            final s = _suggestions[i];
                                            return ListTile(
                                              dense: true,
                                              title: Text(s['description'] ?? ''),
                                              onTap: () => _selectSuggestion(s),
                                            );
                                          },
                                        ),
                                ),
                              ],
                              // If no suggestions and not loading, show status to help debugging
                              if (!_loadingSuggestions && _suggestions.isEmpty && _destController.text.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _placesStatus != null
                                        ? 'Places: ${_placesStatus}'
                                        : (_lastApiError != null ? 'Error: $_lastApiError' : 'No suggestions'),
                                    style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF6F665D)),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Mock destinations dropdown (Tirana) and select button
                              // (Removed: now handled by the main destination dropdown above)
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(252, 249, 245, 0.96),
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
                                    color: const Color(0xFFF2D9C9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.directions_bus_filled_rounded,
                                    color: Color(0xFFB85A2B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Passenger Mode",
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Sharing your live position",
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          color: muted,
                                        ),
                                      ),
                                      // Coordinates display in header
                                      if (position != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}",
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
                                    "ACTIVE",
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
                        ],
                      ),
                    ),
                  ),
                  // Bottom info panel (fixed below scroll area)
                  Container(
                    margin: const EdgeInsets.only(bottom: 68),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(252, 249, 245, 0.98),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 12,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current coordinates",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _CoordTile(
                                label: "Latitude",
                                value: position.latitude.toStringAsFixed(5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CoordTile(
                                label: "Longitude",
                                value: position.longitude.toStringAsFixed(5),
                              ),
                            ),
                          ],
                        ),
                        if (_lastUpdated != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            "Updated ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}",
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ],
                        // Show API error message if present to help debugging
                        if (_lastApiError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'API: $_lastApiError',
                            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.redAccent),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _getCurrentLocation,
        backgroundColor: ink,
        icon: const Icon(Icons.gps_fixed_rounded),
        label: Text(
          "Refresh",
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

      Future<void> _searchAndRoute() async {
        final destText = _destController.text.trim();
        if (destText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a destination')));
          return;
        }

        final origin = _currentPosition;
        if (origin == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current location not available')));
          return;
        }

        setState(() => _loadingSuggestions = true);
        try {
          // Use Nominatim to geocode the typed destination
          final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent(destText)}&limit=1');
          final resp = await _httpGetWithRetries(url, headers: {'User-Agent': 'bus-tracking-app/1.0 (you@example.com)'}, retries: 2, timeout: const Duration(seconds: 15));
          if (resp.statusCode != 200) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search service unavailable')));
            return;
          }
          final List<dynamic> results = json.decode(resp.body) as List<dynamic>;
          if (results.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination not found')));
            return;
          }
          final place = results[0] as Map<String, dynamic>;
          final destLat = double.tryParse((place['lat'] ?? '').toString());
          final destLng = double.tryParse((place['lon'] ?? '').toString());
          if (destLat == null || destLng == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid place coordinates')));
            return;
          }
          await _routeToCoordinates(destLat, destLng, place['display_name'] ?? destText);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Routing failed: ${e.toString()}')));
        } finally {
          setState(() => _loadingSuggestions = false);
        }
      }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final point = LatLng(lat / 1e5, lng / 1e5);
      poly.add(point);
    }
    return poly;
  }

    @override
    void dispose() {
    _controller?.dispose();
    _destController.dispose();
    _debounce?.cancel();
    super.dispose();
    }
}

class _CoordTile extends StatelessWidget {
  const _CoordTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: const Color(0xFF6F665D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F1A17),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2ED),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2D9C9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.gps_off_rounded,
                  color: Color(0xFFB85A2B),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F1A17),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF6F665D),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F1A17),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      // optional small feedback while retrying
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Retrying...')),
                      );
                      await onRetry();
                    } catch (e) {
                      // show error if retry fails
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Retry failed: ${e.toString()}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    "Try again",
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
