import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final userName =
        user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'User';
    final userEmail = user?.email ?? '';
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'ALUR',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.accent,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        userName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 24),

              // Welcome text
              const Text(
                'Welcome!',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),

              // User name
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // Email
              if (userEmail.isNotEmpty)
                Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withOpacity(0.8),
                  ),
                ),

              const SizedBox(height: 48),

              // Chat placeholder
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chat feature coming soon!',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Logout button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await SupabaseService.signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
