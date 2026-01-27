import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_password_login/model/routes.dart';
import 'package:email_password_login/model/user_model.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

// ✅ FIX: correct folder case via relative imports
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _auth = FirebaseAuth.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final emailField = TextFormField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      validator: (value) =>
          (value == null || value.isEmpty) ? "Enter email" : null,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.mail),
        hintText: "Email",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final passwordField = TextFormField(
      controller: passwordController,
      obscureText: true,
      validator: (value) =>
          (value == null || value.length < 6) ? "Min 6 chars" : null,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock),
        hintText: "Password",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final signUpButton = Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(30),
      color: Colors.deepPurple,
      child: MaterialButton(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        minWidth: MediaQuery.of(context).size.width,
        onPressed: () async {
          if (_formKey.currentState?.validate() != true) return;

          try {
            final userCredential = await _auth.createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

            if (userCredential.user != null) {
              Fluttertoast.showToast(msg: "Account created!");
              if (!mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            }
          } on FirebaseAuthException catch (e) {
            Fluttertoast.showToast(msg: e.message ?? "Signup failed");
          }
        },
        child: Text(
          "Sign Up",
          style: GoogleFonts.poppins(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Lottie.asset("assets/images/sign-up.json", height: 200),
                Text("Create Account",
                    style: GoogleFonts.poppins(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                emailField,
                const SizedBox(height: 15),
                passwordField,
                const SizedBox(height: 20),
                signUpButton,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
