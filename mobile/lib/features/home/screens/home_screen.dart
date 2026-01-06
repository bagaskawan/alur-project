import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

/// Home/Dashboard screen that displays user profile and personalization data
/// Shown after onboarding is completed
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic>? _personalizationData;
  String? _userName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
  }

  Future<void> _loadUserData() async {
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        // Get user name from metadata
        final metaName =
            user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            user.email?.split('@').first ??
            'User';

        // Fetch personalization data from Supabase
        final response = await SupabaseService.client
            .from('profiles')
            .select('personalization_data, full_name')
            .eq('id', user.id)
            .single();

        setState(() {
          _userName =
              response['full_name'] ?? metaName.toString().split(' ').first;
          _personalizationData =
              response['personalization_data'] as Map<String, dynamic>?;
          _isLoading = false;
        });

        _animationController.forward();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _animationController.forward();
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Yakin mau logout?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.signOut();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with greeting and logout
                  _buildHeader(),
                  const SizedBox(height: 32),

                  // Welcome card
                  _buildWelcomeCard(),
                  const SizedBox(height: 24),

                  // Personalization data cards
                  _buildSectionTitle('Profil Personalisasi'),
                  const SizedBox(height: 16),
                  _buildPersonalizationCards(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 4) {
      greeting = "Halo pejuang malam";
    } else if (hour < 11) {
      greeting = "Selamat pagi";
    } else if (hour < 15) {
      greeting = "Selamat siang";
    } else if (hour < 18) {
      greeting = "Selamat sore";
    } else {
      greeting = "Selamat malam";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _userName ?? 'User',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        // Logout button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.9),
            AppColors.accent.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'ALUR',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Onboarding selesai! 🎉',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kamu sudah siap memulai perjalanan produktivitasmu bersama ALUR.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPersonalizationCards() {
    final data = _personalizationData ?? {};

    final items = [
      _PersonalizationItem(
        icon: Icons.wb_sunny_rounded,
        title: 'Waktu Produktif',
        key: 'energy_profile',
        color: Colors.orange,
      ),
      _PersonalizationItem(
        icon: Icons.flag_rounded,
        title: 'Motivasi',
        key: 'motivation_drivers',
        color: Colors.green,
      ),
      _PersonalizationItem(
        icon: Icons.psychology_rounded,
        title: 'Response Tantangan',
        key: 'challenge_response',
        color: Colors.blue,
      ),
      _PersonalizationItem(
        icon: Icons.school_rounded,
        title: 'Gaya Belajar',
        key: 'learning_style',
        color: Colors.purple,
      ),
      _PersonalizationItem(
        icon: Icons.person_rounded,
        title: 'Tipe Kepribadian',
        key: 'behavior_type',
        color: Colors.teal,
      ),
    ];

    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final value = data[item.key];
        final displayValue = value is List && value.isNotEmpty
            ? value.first.toString().replaceAll('_', ' ')
            : (value?.toString() ?? 'Belum diisi');

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayValue,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PersonalizationItem {
  final IconData icon;
  final String title;
  final String key;
  final Color color;

  _PersonalizationItem({
    required this.icon,
    required this.title,
    required this.key,
    required this.color,
  });
}
