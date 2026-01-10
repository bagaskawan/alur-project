import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/loading_dots.dart';

/// Language selection screen shown before onboarding
/// Allows user to choose their preferred language
class LanguageSelectionScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const LanguageSelectionScreen({super.key, required this.onComplete});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;
  bool _isLoading = false;

  // Language options
  static const List<Map<String, String>> _languages = [
    {'code': 'id', 'name': 'Bahasa Indonesia', 'flag': '🇮🇩'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
  ];

  @override
  void initState() {
    super.initState();
    _detectDeviceLocale();
  }

  void _detectDeviceLocale() {
    // Get device locale and pre-select
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'id') {
      setState(() => _selectedLanguage = 'id');
    } else {
      setState(() => _selectedLanguage = 'en');
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedLanguage == null) return;

    setState(() => _isLoading = true);

    try {
      // Save to Supabase profile
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        await SupabaseService.client
            .from('profiles')
            .update({'preferred_language': _selectedLanguage})
            .eq('id', userId);
      }

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Title
              const Text(
                'Pilih Bahasa',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your language',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Language options
              ..._languages.map((lang) => _buildLanguageOption(lang)),

              const Spacer(flex: 2),

              // Continue button
              ElevatedButton(
                onPressed: _selectedLanguage != null && !_isLoading
                    ? _saveAndContinue
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 40,
                        child: LoadingDots(size: 4, color: Colors.white),
                      )
                    : const Text(
                        'Lanjutkan / Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(Map<String, String> lang) {
    final isSelected = _selectedLanguage == lang['code'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedLanguage = lang['code']),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(lang['flag']!, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lang['name']!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
