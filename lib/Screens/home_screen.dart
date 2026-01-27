import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // TODO: replace with your real user data / auth
  final String userName = "";
  final String userEmail = "";

  // TODO: replace with your real logout logic
  Future<void> _logout(BuildContext context) async {
    // Example: Navigator.pushReplacementNamed(context, '/login');
    Navigator.pop(context);
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    // TODO: add your navigation logic here if you switch pages
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: ink,
            size: 30,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Home",
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
      body: SafeArea(
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
                  child: _QuickActionTile(
                    title: "Passenger",
                    subtitle: "Share your location",
                    icon: Icons.directions_bus_filled_rounded,
                    accent: accent,
                    onTap: () => _onNavTap(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionTile(
                    title: "Waiting",
                    subtitle: "Watch live pickups",
                    icon: Icons.person_pin_circle_rounded,
                    accent: const Color(0xFF3B6D4E),
                    onTap: () => _onNavTap(2),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Active riders",
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

            // Active riders list card
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('passengers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Something went wrong.',
                      style: GoogleFonts.dmSans(color: muted),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: [
                        const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading riders...',
                          style: GoogleFonts.dmSans(color: muted),
                        ),
                      ],
                    );
                  }

                  final data = snapshot.data;
                  if (data == null || data.size == 0) {
                    return Text(
                      'No active riders yet.',
                      style: GoogleFonts.dmSans(color: muted),
                    );
                  }

                  final count = data.size > 5 ? 5 : data.size;

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: count,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (context, index) {
                      final raw = data.docs[index].data();
                      final doc = raw is Map<String, dynamic>
                          ? raw
                          : <String, dynamic>{};

                      final fullName =
                          (doc['fullname'] ?? 'Unknown').toString();
                      final email = (doc['email'] ?? '').toString();

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFF4E0D0),
                            child: Text(
                              _initials(fullName),
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: ink,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.radio_button_checked,
                            color: Color(0xFF4D9F63),
                            size: 14,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F1A17),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFF6F665D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
