import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// Simple bus simulator: iterates over provided routes and periodically
/// pushes location pings to the Realtime Database using `databaseRef.push()`.
///
/// Usage:
/// final sim = BusSimulator(FirebaseDatabase.instance.ref(), mockRoutes, intervalMs: 1200);
/// sim.start();
/// sim.stop();
class BusSimulator {
  BusSimulator(this._dbRef, this.routes, {this.tickMs = 1000, this.stepFraction = 0.02, this.stopSeconds = 30});

  final DatabaseReference _dbRef;
  final List<Map<String, dynamic>> routes;
  // tick interval in milliseconds
  final int tickMs;
  // fraction of segment to travel per tick (0..1): smaller => slower
  final double stepFraction;
  // duration to pause at stops in seconds
  final int stopSeconds;

  final List<Timer> _timers = [];

  bool get isRunning => _timers.isNotEmpty;

  void start() {
    if (isRunning) return;

    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      final name = route['name']?.toString() ?? 'sim_bus_$i';
      final points = (route['route'] as List<dynamic>? ?? [])
          .map<Map<String, double>>((p) => {'lat': (p['lat'] as num).toDouble(), 'lon': (p['lon'] as num).toDouble()})
          .toList();
      final stopsList = (route['stops'] as List<dynamic>?)?.map<int>((v) => v as int).toList() ?? [];

      if (points.length < 2) continue;

      // per-vehicle state
      int segIndex = 0; // current segment start index
      double t = 0.0; // interpolation 0..1 along current segment
      int pauseTicks = 0; // ticks to wait at a stop

      // stagger start slightly so buses don't all move at the same instant
      final initialDelay = Duration(milliseconds: i * (tickMs ~/ 2));

      // periodic timer moves the vehicle smoothly along segments
      final timer = Timer.periodic(Duration(milliseconds: tickMs), (_) async {
        try {
          if (pauseTicks > 0) {
            // still waiting at stop: decrement counter and re-write same position timestamp
            pauseTicks--;
            final cur = points[segIndex % points.length];
            await _dbRef.child('simulator').child(name).set({
              'latitude': cur['lat'],
              'longitude': cur['lon'],
              'timestamp': DateTime.now().toIso8601String(),
              'vehicle': name,
              'sim': true,
            });
            return;
          }


          // advance along segment
          t += stepFraction;
          if (t >= 1.0) {
            // move to next segment
            t = t - 1.0;
            segIndex = (segIndex + 1) % points.length;
          }

          // linear interpolate lat/lon
          final curA = points[segIndex % points.length];
          final curB = points[(segIndex + 1) % points.length];
          final lat = curA['lat']! + (curB['lat']! - curA['lat']!) * t;
          final lon = curA['lon']! + (curB['lon']! - curA['lon']!) * t;

          // Check whether we're effectively at a stop index (arrived to curB when t close to 0)
          // Consider arrival when t < stepFraction/2 and segIndex+1 is a stop index
          final arrivedIndex = (segIndex + 1) % points.length;
          if (stopsList.contains(arrivedIndex) && t < (stepFraction / 2.0)) {
            // set pause for stopSeconds (convert to ticks)
            pauseTicks = (stopSeconds * 1000 ~/ tickMs);
          }

          await _dbRef.child('simulator').child(name).set({
            'latitude': lat,
            'longitude': lon,
            'timestamp': DateTime.now().toIso8601String(),
            'vehicle': name,
            'sim': true,
          });
        } catch (e) {
          // best-effort: ignore write errors
        }
      });

      // initial immediate write at the route start
      _timers.add(Timer(initialDelay, () async {
        final start = points[0];
        try {
          await _dbRef.child('simulator').child(name).set({
            'latitude': start['lat'],
            'longitude': start['lon'],
            'timestamp': DateTime.now().toIso8601String(),
            'vehicle': name,
            'sim': true,
          });
        } catch (_) {}
      }));

      _timers.add(timer);
    }
  }

  Future<void> stop() async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

// Global manager to ensure only one simulator runs at a time.
class BusSimManager {
  static BusSimulator? _active;

  /// Stop currently active simulator (if any).
  static Future<void> stopActive() async {
    if (_active != null) {
      await _active!.stop();
      _active = null;
    }
  }

  /// Start a single simulator for the provided [routes]. This will stop any previously running simulator.
  static Future<void> startForRoutes(DatabaseReference dbRef, List<Map<String, dynamic>> routes,
      {int tickMs = 1000, double stepFraction = 0.005, int stopSeconds = 30}) async {
    await stopActive();
    _active = BusSimulator(dbRef, routes, tickMs: tickMs, stepFraction: stepFraction, stopSeconds: stopSeconds);
    _active!.start();
  }
}
