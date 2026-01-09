import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/goals_service.dart';
import '../../home/screens/home_screen.dart';

class BlueprintPreviewScreen extends StatefulWidget {
  final String goalTitle;
  final String timeHorizon;
  final List<dynamic> blueprintData;

  const BlueprintPreviewScreen({
    super.key,
    required this.goalTitle,
    required this.timeHorizon,
    required this.blueprintData,
  });

  @override
  State<BlueprintPreviewScreen> createState() => _BlueprintPreviewScreenState();
}

class _BlueprintPreviewScreenState extends State<BlueprintPreviewScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 16),

            // Timeline indicator
            _buildTimelineIndicator(),
            const SizedBox(height: 8),

            // Goal Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.goalTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Swipeable Cards
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.blueprintData.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final phase = widget.blueprintData[index];
                  return _buildPhaseCard(phase, index);
                },
              ),
            ),

            // Page Indicator
            _buildPageIndicator(),
            const SizedBox(height: 16),

            // Swipe hint
            if (widget.blueprintData.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Swipe for next pillar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dark.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.dark.withOpacity(0.5),
                    ),
                  ],
                ),
              ),

            // Bottom Button
            _buildApproveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                color: Colors.transparent, // Hit testable area
                // Icon removed as requested
              ),
            ),
          ),
          const Text(
            'Blueprint Preview',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pastelYellow.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '1 - ${widget.timeHorizon}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.dark.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildPhaseCard(dynamic phase, int index) {
    // phaseName removed as requested
    final focus = phase['focus'] ?? 'Focus area';
    final tasks = phase['tasks'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 32), // Added margin for spacing
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Centered alignment
            children: [
              // Phase Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.pastelYellow.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppColors.dark,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              // Focus (Styled larger and bold)
              Text(
                focus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 24),

              // Tasks
              ...tasks.map((task) => _buildTaskItem(task)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(dynamic task) {
    final title = task['title'] ?? 'Task';
    final duration = task['duration'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.pastelYellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.dark,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
                if (duration.isNotEmpty)
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.dark.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.blueprintData.length,
        (index) => Container(
          width: index == _currentPage ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: index == _currentPage
                ? AppColors.pastelYellow
                : AppColors.dark.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildApproveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _onApprove,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pastelYellow,
            foregroundColor: AppColors.dark,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Approve & Generate Full Plan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 8),
              Icon(Icons.auto_awesome, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onApprove() async {
    // 1. Show Loading Indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menyimpan Blueprint...'),
        duration: Duration(seconds: 1),
      ),
    );

    // 2. Call Service to Save
    final goalsService = GoalsService();

    // Estimate dates (simple logic for MVP: Start today, End based on TimeHorizon)
    final now = DateTime.now();
    DateTime endDate = now.add(const Duration(days: 90)); // Default 3 months

    // Simple parser for "3 Bulan" / "6 Bulan"
    if (widget.timeHorizon.toLowerCase().contains("bulan")) {
      final parts = widget.timeHorizon.trim().split(" ");
      if (parts.isNotEmpty) {
        final months = int.tryParse(parts[0]) ?? 3;
        endDate = now.add(Duration(days: months * 30));
      }
    }

    final success = await goalsService.saveFinalBlueprint(
      mainGoalTitle: widget.goalTitle,
      strategyMethod:
          "PROJECT_180", // Default for now, or pass from previous screen
      startDate: now,
      endDate: endDate,
      phasesData: widget.blueprintData,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blueprint Berhasil Disimpan! 🚀'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate to Home and clear stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan blueprint. Coba lagi.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
