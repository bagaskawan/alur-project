import '../../../core/services/api_service.dart';

/// Service for handling goal-related AI operations
class GoalsService {
  final ApiService _apiService = ApiService();

  /// Enhance a goal statement using AI
  /// Uses GOALS_SETUP mode with a specific prompt for enhancement
  /// Returns the enhanced goal text or throws an error
  Future<String> enhanceGoal(String goalText) async {
    if (goalText.trim().isEmpty) {
      throw Exception('Goal text cannot be empty');
    }

    try {
      // Send to backend with GOALS_SETUP mode
      // The message includes instruction for AI to enhance the goal
      final response = await _apiService.post(
        '/api/v1/chat/send',
        body: {
          'message': goalText, // Backend prompt handles the enhancement logic
          'mode': 'GOAL_ENHANCE',
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data;
        final reply = data['reply'] as String?;

        if (reply != null && reply.isNotEmpty) {
          // Clean up the response - remove quotes if present
          String enhanced = reply.trim();
          if (enhanced.startsWith('"') && enhanced.endsWith('"')) {
            enhanced = enhanced.substring(1, enhanced.length - 1);
          }
          return enhanced;
        }

        throw Exception('AI tidak memberikan respons');
      }

      throw Exception(response.message ?? 'Gagal menghubungi AI');
    } catch (e) {
      print('GoalsService Error: $e');
      rethrow;
    }
  }

  /// Send a message in the GOALS_SETUP mode
  Future<String> sendGoalSetupMessage(String message) async {
    try {
      final response = await _apiService.post(
        '/api/v1/chat/send', // Verify endpoint, previously used /api/v1/chat/send
        body: {'message': message, 'mode': 'GOALS_SETUP'},
      );

      if (response.isSuccess && response.data != null) {
        return response.data['reply'] ?? '';
      }
      throw Exception(response.message ?? 'Failed to send message');
    } catch (e) {
      rethrow;
    }
  }
}
