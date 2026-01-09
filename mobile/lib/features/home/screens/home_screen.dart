import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../chat/screens/chat_screen.dart'; // Pastikan import ini ada
import '../../goals/screens/goals_screen.dart';
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
  int _selectedNavIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _activeGoal;

  // Service
  final _goalsService = GoalsService();

  // Simulasi Data (Nanti diganti dengan data dari API / Database)
  // Ubah list ini jadi kosong [] untuk mengetes tampilan User Baru
  final List<Map<String, dynamic>> _tasks = [];

  // Cek apakah user punya data atau masih baru
  bool get _isNewUser => !_isLoading && _activeGoal == null;

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
        // data format: { has_active_plan: true, cycle: {...}, main_goal: {...} }
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
      setState(() => _userName = metaName.toString().split(' ').first);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // --- NAVIGATION LOGIC ---
  void _openDailyChat() {
    // Membuka Chat dengan Mode DAILY
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen(initialMode: 'DAILY')),
    );
  }

  void _openGoalSetup() {
    // Membuka Goals Screen untuk User Baru
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    ).then((_) => _loadDashboardData()); // Refresh when back
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

                    // LOGIC SWITCH: Tampilkan kartu beda buat user baru
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_isNewUser)
                      _buildNewUserHero()
                    else
                      _buildFocusHero(),

                    const SizedBox(height: 20),

                    // PORTAL KE CHAT (Klik Bar ini langsung masuk Chat Room)
                    GestureDetector(
                      onTap: _openDailyChat,
                      child: _buildAICommandBar(),
                    ),

                    const SizedBox(height: 24),

                    // LOGIC SWITCH: Timeline vs Empty State
                    if (_isNewUser || _tasks.isEmpty)
                      _buildEmptyStatePlaceholder()
                    else
                      _buildTimeline(),

                    const SizedBox(height: 24),
                    _buildHabitsSection(),
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

  // ... (Header Widget sama seperti sebelumnya) ...
  Widget _buildHeader() {
    final user = SupabaseService.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}, ${_userName ?? 'User'}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Let's conquer the day.",
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) {
              // Refresh home data in case profile settings changed (e.g. name/avatar)
              _loadUserName();
            });
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.pastelYellow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.dark, width: 2),
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null
                ? const Icon(Icons.person, color: AppColors.dark)
                : null,
          ),
        ),
      ],
    );
  }

  // === HERO CARD 1: MAIN FOCUS (Untuk User Lama) ===
  Widget _buildFocusHero() {
    final title = _activeGoal?['main_goal']?['title'] ?? 'Your Goal';
    // final progress = _activeGoal?['main_goal']?['progress'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pastelPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'MAIN FOCUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title, // [DYNAMIC DATA]
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: AppColors.dark.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'On Track',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.dark.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {}, // Nanti ke Timer Screen
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('View Plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === HERO CARD 2: NEW USER CALL TO ACTION ===
  Widget _buildNewUserHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pastelGreen, // Ganti warna jadi Hijau (Fresh)
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.dark,
          width: 1.5,
        ), // Tambah border biar tegas
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start Your Journey 🚀',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You haven't set your big goals yet. Let's define your 'North Star' to get started.",
            style: TextStyle(fontSize: 14, color: AppColors.dark),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openGoalSetup, // KE CHAT MODE GOALS
              icon: const Icon(Icons.map, size: 18),
              label: const Text('Create My First Goal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === AI COMMAND BAR (Sekarang Tappable) ===
  Widget _buildAICommandBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.dark, width: 1.5),
        boxShadow: [
          // Sedikit shadow biar kelihatan bisa diklik
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.pastelYellow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 18,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Chat with Alur...', // Teks lebih simple
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          const Icon(Icons.send_rounded, color: AppColors.dark, size: 20),
        ],
      ),
    );
  }

  // === EMPTY STATE PLACEHOLDER ===
  Widget _buildEmptyStatePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 40,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            "No tasks for today",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Chat with Alur to schedule your day!",
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Sisa fungsi Timeline & Habits sama persis, copy paste saja dari kode lamamu) ...
  // === TIMELINE TASKS ===
  Widget _buildTimeline() {
    return Column(
      children: _tasks.asMap().entries.map((entry) {
        final task = entry.value;
        return _buildTaskItem(task);
      }).toList(),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    Color bgColor;
    switch (task['color']) {
      case 'green':
        bgColor = AppColors.pastelGreen;
        break;
      case 'blue':
        bgColor = AppColors.pastelBlue;
        break;
      default:
        bgColor = Colors.white;
    }

    final isDone = task['isDone'] == true;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isDone ? AppColors.dark : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.dark, width: 1.5),
              ),
            ),
            Container(
              width: 1.5,
              height: 80,
              color: AppColors.dark.withOpacity(0.2),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Task card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: task['color'] == 'white'
                  ? Border.all(color: AppColors.dark, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.dark,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (task['tag'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task['tag'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (task['subtitle'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          task['subtitle'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task['time'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.dark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                if (task['color'] == 'blue')
                  Icon(
                    Icons.restaurant,
                    size: 28,
                    color: AppColors.dark.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // === HABITS SECTION ===
  final List<Map<String, dynamic>> _habits = [
    {'icon': Icons.water_drop, 'label': 'Water', 'isDone': true},
    {'icon': Icons.menu_book, 'label': 'Read', 'isDone': true},
    {'icon': Icons.self_improvement, 'label': 'Stretch', 'isDone': false},
    {'icon': Icons.directions_walk, 'label': 'Walk', 'isDone': false},
  ];

  Widget _buildHabitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HABITS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _habits.map((habit) {
            final isDone = habit['isDone'] == true;
            return Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.pastelGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDone
                          ? AppColors.pastelGreen
                          : AppColors.textSecondary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    habit['icon'],
                    color: isDone ? AppColors.dark : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  habit['label'],
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // === BOTTOM NAVIGATION ===
  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(24),
      ),
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
      onTap: () => setState(() => _selectedNavIndex = index),
      child: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
        size: 24,
      ),
    );
  }
}
