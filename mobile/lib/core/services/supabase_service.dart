import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String _redirectUrl = 'io.supabase.alur://login-callback';

  /// Initialize Supabase - call this before runApp()
  /// Make sure to call dotenv.load() before this!
  static Future<void> initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
        'Supabase credentials not found in .env file. '
        'Please check your .env file contains SUPABASE_URL and SUPABASE_ANON_KEY',
      );
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  /// Get Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  /// Sign in with Google OAuth
  static Future<bool> signInWithGoogle() async {
    try {
      final response = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return response;
    } catch (e) {
      print('Google Sign In Error: $e');
      return false;
    }
  }

  /// Sign in with GitHub OAuth
  static Future<bool> signInWithGithub() async {
    try {
      final response = await client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: _redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return response;
    } catch (e) {
      print('GitHub Sign In Error: $e');
      return false;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;
}
