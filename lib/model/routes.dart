// ✅ FIX: correct folder case using relative imports (model -> ../Screens)
import '../Screens/home_screen.dart';
import '../Screens/login_screen.dart';
import '../Screens/splash_screen.dart';
import '../Screens/welcome_screen.dart';

const String welcomeRoute = "/welcome";
const String homeRoute = "/home";
const String loginRoute = "/login";
const String splashRoute = "/splash";

final routes = {
  welcomeRoute: (context) => welcomeScreen(),
  homeRoute: (context) => HomeScreen(),
  loginRoute: (context) => const LoginScreen(),
  splashRoute: (context) => splashScreen(),
};
