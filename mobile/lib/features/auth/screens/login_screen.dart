import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/loading_dots.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await SupabaseService.signInWithGoogle();
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Google sign in failed')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGithubSignIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await SupabaseService.signInWithGithub();
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GitHub sign in failed')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Hero Image - Expands to fill available space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildHeroCard(),
              ),
            ),
            // Bottom Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Title
                  const Text(
                    'Start Your',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    'Growth Journey',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Focus on identity, not just tasks',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Auth Buttons
                  _buildGoogleButton(),
                  const SizedBox(height: 12),
                  _buildGithubButton(),
                  const SizedBox(height: 20),
                  // Terms Text
                  _buildTermsText(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/hero_illustration.png',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isLoading
            ? const SizedBox(width: 40, height: 24, child: LoadingDots(size: 6))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://www.google.com/favicon.ico',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGithubButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGithubSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 40,
                height: 24,
                child: LoadingDots(size: 6, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  FaIcon(
                    FontAwesomeIcons.github,
                    size: 24,
                    color: Colors.white,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Continue with Github',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTermsText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withOpacity(0.7),
        ),
        children: const [
          TextSpan(text: "By continuing, you agree to ALUR's "),
          TextSpan(
            text: 'Terms of\nService',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
          TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }
}
