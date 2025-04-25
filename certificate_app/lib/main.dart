import 'dart:async';

import 'package:certificate_app/screens/home_screen.dart'; // Import Home Screen
import 'package:certificate_app/screens/login_screen.dart'; // Import Login Screen
import 'package:certificate_app/screens/certificates_page.dart'; // Import Certificates Page
import 'package:certificate_app/screens/profiles_page.dart'; // Import Profiles Page
import 'package:certificate_app/screens/approve_users_screen.dart'; // Import Approve Users Screen
import 'package:certificate_app/screens/view_admins_screen.dart'; // Import View Admins Screen
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:media_store_plus/media_store_plus.dart'; // Import media_store_plus

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kjqqfqzwcprytkuysbtx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqcXFmcXp3Y3ByeXRrdXlzYnR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM2NzY1NDcsImV4cCI6MjA1OTI1MjU0N30.QxZubNzNbjBBNgsav1gva3u9O9BcMKO45IpGcjemmhw',
  );

  // Initialize MediaStore (call only once)
  await MediaStore.ensureInitialized();
  MediaStore.appFolder = "PNReceiptGenerator"; // Set the app folder name

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certificate App', // Updated title
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ), // Changed seed color
        useMaterial3: true,
      ),
      home: const SplashScreen(), // Start with a Splash Screen
      routes: {
        '/login': (context) => const LoginScreen(),
        '/certificates': (context) => const CertificatesPage(),
        '/profiles': (context) => const ProfilesPage(),
        '/approve_users': (context) => const ApproveUsersScreen(),
        '/view_admins': (context) => const ViewAdminsScreen(),
        // '/forgot-password-redirect': (context) => const ForgotPasswordRedirectPage(), // Removed forgot password redirect route
      },
    );
  }
}

// Splash screen to check auth state
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    if (_navigated) return;
    _navigated = true;

    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;

    if (session != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }

    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
          if (!mounted) return;
          final AuthChangeEvent event = data.event;
          if (event == AuthChangeEvent.signedIn) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else if (event == AuthChangeEvent.signedOut) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
