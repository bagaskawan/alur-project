import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class GoogleCalendarSyncScreen extends StatefulWidget {
  const GoogleCalendarSyncScreen({super.key});

  @override
  State<GoogleCalendarSyncScreen> createState() =>
      _GoogleCalendarSyncScreenState();
}

class _GoogleCalendarSyncScreenState extends State<GoogleCalendarSyncScreen> {
  bool _syncEnabled = false;
  bool _syncTasks = true;
  bool _syncGoals = true;
  bool _syncReminders = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Google Calendar Sync',
          style: TextStyle(
            color: AppColors.dark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.dark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Google Calendar",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dark,
                          ),
                        ),
                        Text(
                          _syncEnabled ? "Sync is active" : "Not syncing",
                          style: TextStyle(
                            fontSize: 13,
                            color: _syncEnabled
                                ? Colors.green
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _syncEnabled,
                    onChanged: (v) => setState(() => _syncEnabled = v),
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.dark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sync Options
            if (_syncEnabled) ...[
              const Text(
                "SYNC OPTIONS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              _buildSyncOption(
                "Tasks",
                "Sync your daily tasks",
                _syncTasks,
                (v) => setState(() => _syncTasks = v),
              ),
              const SizedBox(height: 12),
              _buildSyncOption(
                "Goals",
                "Sync goal deadlines",
                _syncGoals,
                (v) => setState(() => _syncGoals = v),
              ),
              const SizedBox(height: 12),
              _buildSyncOption(
                "Reminders",
                "Sync AI reminders",
                _syncReminders,
                (v) => setState(() => _syncReminders = v),
              ),
              const SizedBox(height: 32),

              // Last Sync Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pastelBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sync,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Last synced: Just now",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.dark.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncOption(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.dark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: AppColors.dark,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
