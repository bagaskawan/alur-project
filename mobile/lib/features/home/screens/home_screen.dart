import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../goals/services/goals_service.dart';
import '../../profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State Data
  String? _userName;
  String? _avatarUrl;
  int _selectedNavIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _activeGoal;

  // Service
  final _goalsService = GoalsService();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final data = await _goalsService.getCurrentGoal();
    if (mounted) {
      setState(() {
        if (data != null && data['has_active_plan'] == true) {
          _activeGoal = data;
        } else {
          _activeGoal = null;
        }
        _isLoading = false;
      });
    }
  }

  void _loadUserName() {
    final user = SupabaseService.currentUser;
    if (user != null) {
      final metaName =
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'User';
      final avatar = user.userMetadata?['avatar_url'];
      setState(() {
        _userName = metaName.toString().split(' ').first;
        _avatarUrl = avatar;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // Green Task Summary Card
                    _buildTaskSummaryCard(),
                    const SizedBox(height: 16),

                    // Beige Webinar Card
                    _buildWebinarCard(),
                    const SizedBox(height: 16),

                    // Blue Habits Journal Card
                    _buildHabitsJournalCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Welcome Text & Username
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${_userName ?? 'David'}!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        // Notification Bell
        Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_outlined,
            size: 22,
            color: Colors.black54,
          ),
        ),
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
            border: Border.all(color: AppColors.cardGreen, width: 2),
            image: _avatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(_avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _avatarUrl == null
              ? Icon(Icons.person, size: 24, color: Colors.grey[600])
              : null,
        ),
      ],
    );
  }

  // === GREEN TASK SUMMARY CARD ===
  Widget _buildTaskSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateTime.now().day} ${_getMonthName(DateTime.now().month)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Current tasks',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'You have ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Text(
                '10',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'tasks',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'High',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 2),
                    Text(
                      '~',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'for today',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // === BEIGE WEBINAR CARD ===
  Widget _buildWebinarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBeige,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Date Badge (Circular)
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  '24',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Nov',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Webinar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Implementation of habits.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Action Icon
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.power_settings_new,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // === BLUE HABITS JOURNAL CARD ===
  Widget _buildHabitsJournalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.public, size: 18, color: Colors.black87),
                  SizedBox(width: 8),
                  Text(
                    'Habits Journal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_outward,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tag
          const Text(
            'Community',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          // Title
          const Text(
            'Productive routine.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Read Now Link
          const Text(
            'Read Now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 16),
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              'https://images.unsplash.com/photo-1495195129352-aeb325a55b65?w=800&auto=format&fit=crop',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: Colors.white.withOpacity(0.5),
                  child: const Center(
                    child: Icon(Icons.image, size: 50, color: Colors.black26),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for month name
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // === BOTTOM NAVIGATION ===
  Widget _buildBottomNav() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 32, left: 20, right: 20),
      decoration: const BoxDecoration(color: AppColors.dark),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 0),
          _buildNavItem(Icons.all_inclusive, 1),
          _buildNavItem(Icons.timer, 2, isCenter: true),
          _buildNavItem(Icons.flag, 3),
          _buildNavItem(Icons.person, 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, {bool isCenter = false}) {
    final isSelected = _selectedNavIndex == index;

    if (isCenter) {
      return GestureDetector(
        onTap: () => setState(() => _selectedNavIndex = index),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.pastelPurple,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.timer, color: AppColors.dark, size: 24),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ).then((_) {
            _loadUserName();
          });
        } else {
          setState(() => _selectedNavIndex = index);
        }
      },
      onLongPress: () {
        final labels = ['Home', 'All', 'Timer', 'Flag', 'Profile'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(labels[index]),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
        size: 24,
      ),
    );
  }
}
