import '../../../core/services/api_service.dart';
import 'dart:convert';

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

  /// Check relationship with existing goals
  /// Returns a Map with 'is_related', 'reasoning', etc.
  Future<Map<String, dynamic>> checkGoalRelationship(String goal) async {
    try {
      // We pass the goal as 'current_stage' because the prompt uses it that way
      // Message can be just a placeholder or the same goal
      final response = await _apiService.post(
        '/api/v1/chat/send',
        body: {
          'message': goal,
          'mode': 'GOAL_RELATIONSHIP_CHECK',
          'current_stage': goal,
        },
      );

      if (response.isSuccess &&
          response.data != null &&
          response.data['reply'] != null) {
        // The backend might return the JSON in 'reply' field as string if it wasn't parsed by 'ONBOARDING' logic,
        // BUT wait, service.py returns 'final_response_dict' which is the raw JSON if it was parsed.
        // However, in service.py, non-ONBOARDING modes return { 'reply': ai_reply, 'mode': mode }.
        // And the prompt asks for JSON ONLY.
        // The service.py logic for 'ONBOARDING' parses JSON.
        // My new modes are NOT 'ONBOARDING', so they fall into the 'else' block (lines 242+).
        // And that block just puts response.content into 'reply'.

        // So I need to parse the JSON string here in frontend.
        // Or better, I should probably have updated service.py to parse JSON for these modes too,
        // but arguably the frontend can parse it.

        // Let's assume 'reply' contains the JSON string.
        // I will parse it here.
        String jsonStr = response.data['reply'] as String;
        // Clean markdown code blocks if any
        jsonStr = jsonStr
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        // Use a simple JSON decoder if available, but I need to import dart:convert
        // ApiService usually handles JSON response, but here the specific field 'reply' IS a JSON string.

        return _parseJsonLoose(jsonStr);
      }
      throw Exception('Failed to check relationship');
    } catch (e) {
      print('Goal Check Error: $e');
      // Fallback: Assume unrelated
      return {'is_related': false};
    }
  }

  /// Get strategy advice
  Future<Map<String, dynamic>> getStrategyAdvice(String goal) async {
    try {
      final response = await _apiService.post(
        '/api/v1/chat/send',
        body: {'message': goal, 'mode': 'STRATEGY_ADVISOR'},
      );

      if (response.isSuccess &&
          response.data != null &&
          response.data['reply'] != null) {
        String jsonStr = response.data['reply'] as String;
        jsonStr = jsonStr
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return _parseJsonLoose(jsonStr);
      }
      throw Exception('Failed to get strategy');
    } catch (e) {
      print('Strategy Error: $e');
      // Fallback
      return {
        'recommended_method': 'Sprint Mode',
        'why': 'Default fallback due to error',
      };
    }
  }

  Map<String, dynamic> _parseJsonLoose(String str) {
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (e) {
      print("JSON Parse Error: $str");
      return {};
    }
  }

  /// Generate Blueprint with detailed phases
  Future<Map<String, dynamic>> generateBlueprint(
    String goal,
    String timeHorizon,
  ) async {
    try {
      final response = await _apiService.post(
        '/api/v1/chat/send',
        body: {
          'message': goal,
          'mode': 'BLUEPRINT_GENERATOR',
          'current_stage': timeHorizon,
        },
      );

      if (response.isSuccess &&
          response.data != null &&
          response.data['reply'] != null) {
        String jsonStr = response.data['reply'] as String;
        jsonStr = jsonStr
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return _parseJsonLoose(jsonStr);
      }
      throw Exception('Failed to generate blueprint');
    } catch (e) {
      print('Blueprint Generation Error: $e');
      return {
        'action': 'SHOW_BLUEPRINT',
        'goal_title': goal,
        'time_horizon': timeHorizon,
        'blueprint_data': [
          {'phase_name': 'Phase 1', 'focus': 'Getting Started', 'tasks': []},
        ],
      };
    }
  }
}
