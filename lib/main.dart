import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visionvolcan_site_app/screens/login_screen.dart';
import 'package:visionvolcan_site_app/screens/site_list_screen.dart';
import 'package:visionvolcan_site_app/services/cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nxxrobftgkkqybbvilub.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im54eHJvYmZ0Z2trcXliYnZpbHViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzNTk4ODMsImV4cCI6MjA3NzkzNTg4M30.B_DUDrllZTkUL6_y_XhkrW2QWmCfUelLPUHH7vc0Bno',
  );

  // Initialize cache service for offline-first architecture (only on non-web platforms)
  if (!kIsWeb) {
    try {
      await CacheService.instance.init();
    } catch (e) {
      print('Cache service initialization failed: $e');
      // Continue without cache if initialization fails
    }
  }

  runApp(const MyBuilderApp());
}

class MyBuilderApp extends StatelessWidget {
  const MyBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _checkAuthState(),  //check
    );
  }

  Widget _checkAuthState() {

    final session = supabase.auth.currentSession;

    if (session != null) {

      return const SiteListScreen();
    } else {

      return const LoginScreen();
    }
  }
}

// easy access to our database
final supabase = Supabase.instance.client;