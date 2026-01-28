import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

import '../PassengerMode.dart';
import '../WaitingMode.dart';
import '../Simulator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
    int _selectedIndex = 0;
    late final PageController _pageController;

    // Small mock routes (Tirana) reused in Home for Active rides
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
      'stops': [2,5,8,11],
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
      'stops': [1,4,7,10],
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
      'stops': [0,4,7,11],
    },
    ];

  // TODO: replace with your real user data / auth
  final String userName = "";
  final String userEmail = "";

    @override
    void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    }

  // TODO: replace with your real logout logic
  Future<void> _logout(BuildContext context) async {
    // Example: Navigator.pushReplacementNamed(context, '/login');
    Navigator.pop(context);
  }

  void _onNavTap(int index) {
    // animate PageView to the tapped page; onPageChanged will update _selectedIndex
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "NA";
    final first = parts.first.isNotEmpty ? parts.first[0] : "";
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : "";
    final initials = (first + last).trim();
    return initials.isEmpty ? "NA" : initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const pageBackground = Color(0xFFF7F2ED);
    const ink = Color(0xFF1F1A17);
    const accent = Color(0xFFB85A2B);
    const muted = Color(0xFF6F665D);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _pageTitle(),
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        actions: _appBarActions(),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _selectedIndex = i),
        children: [
          _homeContent(),
          const PassengerMode(),
          const WaitingMode(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: accent,
        unselectedItemColor: muted,
        backgroundColor: const Color(0xFFFCF9F5),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus), label: "Passenger"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_pin_circle), label: "Waiting"),
        ],
      ),
    );
  }

  Widget _homeContent() {
    const ink = Color(0xFF1F1A17);
    const muted = Color(0xFF6F665D);
    const accent = Color(0xFFB85A2B);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFE6CF),
                  Color(0xFFF7C4A3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A1F1A17),
                  blurRadius: 16,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome back",
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        userName.isNotEmpty
                            ? userName
                            : "Ready to track your ride?",
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      if (userEmail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 72,
                  width: 72,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF6EF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text(
            "Quick actions",
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _onNavTap(1),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 6))],
                    ),
                    child: FutureBuilder<Position?>(
                      future: _fetchCurrentPosition(),
                      builder: (context, snap) {
                        final pos = snap.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: Color.lerp(accent, Colors.white, 0.85)!,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.directions_bus_filled_rounded, color: accent),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Passenger',
                              style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1F1A17)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pos != null
                                  ? 'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}'
                                  : 'Share your location',
                              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF6F665D)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _onNavTap(2),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 6))],
                    ),
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: _loadSelectedDestinationInfo(),
                      builder: (context, snap) {
                        final info = snap.data;
                        final name = info?['name'] as String?;
                        final lat = info?['lat'] as double?;
                        final lon = info?['lon'] as double?;
                        final stops = info?['stops'] as int?;
                        final subtitle = name != null
                            ? (stops != null ? '$name • $stops stops' : name)
                            : 'Watch live pickups';
                        final sub2 = (lat != null && lon != null) ? 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lon.toStringAsFixed(5)}' : null;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: Color.lerp(const Color(0xFF3B6D4E), Colors.white, 0.85)!,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF3B6D4E)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Waiting',
                              style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1F1A17)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF6F665D)),
                            ),
                            if (sub2 != null) ...[
                              const SizedBox(height: 2),
                              Text(sub2, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF6F665D))),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Simulation is started automatically when a route is selected from Active rides.

          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Active rides",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              Text(
                "Live feed",
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Active rides list (using onboard mock routes)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 8),
                )
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mockDestinations.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, index) {
                final m = _mockDestinations[index];
                final name = (m['name'] ?? '').toString();
                final lat = m['lat'] is num ? (m['lat'] as num).toDouble() : null;
                final lon = m['lon'] is num ? (m['lon'] as num).toDouble() : null;
                final route = m['route'] as List<dynamic>? ?? [];
                return InkWell(
                  onTap: () async {
                    // Save selection to SharedPreferences so Waiting/Passenger pick it up
                    final prefs = await SharedPreferences.getInstance();
                    final stored = {
                      'name': name,
                      'lat': lat,
                      'lon': lon,
                      'route': route,
                    };
                    await prefs.setString('selected_destination', json.encode(stored));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected $name')));
                    // Auto-start simulator for the selected route (single route list)
                    BusSimManager.startForRoutes(
                      FirebaseDatabase.instance.ref(),
                      [m],
                      tickMs: 1000,
                      stepFraction: 0.005, // smooth, slow movement
                      stopSeconds: 30, // 30s pause at scheduled stops
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFF4E0D0),
                        child: Text(
                          name.isNotEmpty ? name[0] : '?',
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: accent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lat != null && lon != null ? 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lon.toStringAsFixed(5)}' : '${route.length} stops',
                              style: GoogleFonts.dmSans(fontSize: 12, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.directions_bus, color: Color(0xFFB85A2B)),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ...removed duplicate Mock routes section per user request...

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: Text(
                "Logout",
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }

  String _pageTitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Passenger';
      case 2:
        return 'Waiting';
      case 0:
      default:
        return 'Home';
    }
  }

  List<Widget> _appBarActions() {
    // Return different actions depending on current tab
    switch (_selectedIndex) {
      case 1: // Passenger
        return [
          IconButton(
            tooltip: 'Refresh location',
            icon: const Icon(Icons.gps_fixed_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tap the refresh button in Passenger mode to update location.')),
              );
            },
          ),
        ];
      case 2: // Waiting
        return [
          IconButton(
            tooltip: 'Refresh map',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing waiting mode...')),
              );
            },
          ),
        ];
      case 0: // Home
      default:
        return [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: _showProfileDialog,
          ),
        ];
    }
  }

  void _showProfileDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${userName.isNotEmpty ? userName : 'Guest'}'),
            const SizedBox(height: 6),
            Text('Email: ${userEmail.isNotEmpty ? userEmail : 'Not signed in'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _logout(context);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

    @override
    void dispose() {
    // stop BusSimManager if running
    BusSimManager.stopActive();
    _pageController.dispose();
    super.dispose();
    }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // This widget is no longer used, but kept for reference.
    return const SizedBox.shrink();
  }
}

// Helper methods for geolocator and shared_preferences
extension _HomeScreenHelpers on _HomeScreenState {
  Future<Position?> _fetchCurrentPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _loadSelectedDestinationName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('selected_destination');
      if (jsonStr == null) return null;
      final decoded = json.decode(jsonStr);
      if (decoded is Map && decoded['name'] is String) {
        return decoded['name'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadSelectedDestinationInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('selected_destination');
      if (jsonStr == null) return null;
      final decoded = json.decode(jsonStr);
      if (decoded is Map) {
        final name = decoded['name'] as String?;
        final lat = decoded['lat'] is num ? (decoded['lat'] as num).toDouble() : null;
        final lon = decoded['lon'] is num ? (decoded['lon'] as num).toDouble() : null;
        final route = decoded['route'] as List<dynamic>? ?? [];
        return {
          'name': name,
          'lat': lat,
          'lon': lon,
          'stops': route.length,
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
