import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/services/supabase_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/onboarding/screens/onboarding_chat_screen.dart';
import 'features/onboarding/screens/language_selection_screen.dart';
import 'features/onboarding/services/onboarding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(const AlurApp());
}

class AlurApp extends StatelessWidget {
  const AlurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALUR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        useMaterial3: true,
        // Smooth page transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper widget that listens to auth state and shows appropriate screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _hasSelectedLanguage = false;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    if (SupabaseService.isLoggedIn) {
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        try {
          // Check profile for language preference
          final profile = await SupabaseService.client
              .from('profiles')
              .select('preferred_language')
              .eq('id', userId)
              .single();

          final hasLang =
              profile['preferred_language'] != null &&
              profile['preferred_language'].toString().isNotEmpty;

          // Check onboarding status
          final completed = await OnboardingService.hasCompletedOnboarding();

          if (mounted) {
            setState(() {
              _hasSelectedLanguage = hasLang;
              _hasCompletedOnboarding = completed;
              _isLoading = false;
            });
          }
        } catch (e) {
          // Profile might not exist yet
          if (mounted) {
            setState(() {
              _hasSelectedLanguage = false;
              _hasCompletedOnboarding = false;
              _isLoading = false;
            });
          }
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _handleLanguageComplete() {
    setState(() => _hasSelectedLanguage = true);
  }

  void _handleOnboardingComplete() {
    setState(() => _hasCompletedOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        // Check if user is logged in
        if (SupabaseService.isLoggedIn) {
          // Show loading
          if (_isLoading) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Animated transition between screens
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _getScreen(),
          );
        }

        // Recalculate status when auth changes
        if (snapshot.hasData &&
            snapshot.data?.event == AuthChangeEvent.signedIn) {
          _isLoading = true;
          _checkUserStatus();
        }

        return const LoginScreen();
      },
    );
  }

  Widget _getScreen() {
    if (_hasCompletedOnboarding) {
      return const HomeScreen(key: ValueKey('home'));
    }

    if (!_hasSelectedLanguage) {
      return LanguageSelectionScreen(
        key: const ValueKey('language'),
        onComplete: _handleLanguageComplete,
      );
    }

    return OnboardingChatScreen(
      key: const ValueKey('onboarding'),
      onComplete: _handleOnboardingComplete,
    );
  }
}
