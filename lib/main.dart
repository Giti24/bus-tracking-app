import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'Screens/welcome_screen.dart'; // <-- make sure this file exists

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init (important if you use firebase_auth/firestore/database)
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Tracking',
      home: const welcomeScreen(), // <-- this must match your class name
    );
  }
}
