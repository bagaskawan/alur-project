import '../../../core/services/api_service.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  /// Returns a Map with 'reply' and 'intent' (AGREEMENT/DISCUSSION)
  Future<Map<String, dynamic>> sendGoalSetupMessage(String message) async {
    try {
      final response = await _apiService.post(
        '/api/v1/chat/send', // Verify endpoint, previously used /api/v1/chat/send
        body: {'message': message, 'mode': 'GOALS_SETUP'},
      );

      if (response.isSuccess && response.data != null) {
        // Backend now returns JSON string in 'reply' field
        String jsonStr = response.data['reply'] as String;

        // Clean markdown if present
        jsonStr = jsonStr
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        try {
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (parseError) {
          // Fallback for types or legacy responses
          return {'reply': jsonStr, 'intent': 'DISCUSSION'};
        }
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

  /// Get strategy advice with negotiation capabilities
  Future<Map<String, dynamic>> getStrategyAdvice(
    String goal,
    String constraints,
  ) async {
    try {
      // Gabungkan goal dan constraints agar dikirim ke prompt AI
      // Contoh input: "Jadi AI Engineer. Saya cuma punya waktu 2 jam sehari setelah ngojek."
      final fullMessage = "$goal. Kondisi/Batasan: $constraints";

      final response = await _apiService.post(
        '/api/v1/chat/send',
        body: {'message': fullMessage, 'mode': 'STRATEGY_ADVISOR'},
      );

      if (response.isSuccess && response.data != null) {
        // Ambil string reply yang berisi JSON dari service.py
        String jsonStr = response.data['reply'] as String;

        // Bersihkan markdown jika ada
        jsonStr = jsonStr
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        // Decode menjadi Map lengkap
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
      throw Exception('Gagal mengambil strategi');
    } catch (e) {
      print('Strategy Error: $e');
      // Return fallback error yang aman
      return {
        'analysis': {'feasibility_status': 'ERROR'},
        'recommendation': {
          'strategy_name': 'Manual Setup',
          'reasoning': 'Maaf, AI sedang sibuk. Silakan buat plan manual.',
        },
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

  Future<bool> saveFinalBlueprint({
    required String mainGoalTitle,
    required String strategyMethod,
    required DateTime startDate,
    required DateTime endDate,
    required List<dynamic> phasesData, // List of phases dari JSON AI
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in");

      // Format Tanggal ke String (YYYY-MM-DD)
      String formatDate(DateTime dt) =>
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

      final body = {
        "user_id": userId,
        "main_goal_title": mainGoalTitle,
        "strategy_method": strategyMethod,
        "start_date": formatDate(startDate),
        "end_date": formatDate(endDate),
        "phases": phasesData.map((phase) {
          // Mapping data dari AI format ke Backend Schema format
          return {
            "phase_name": phase['phase_name'] ?? "Phase",
            "focus": phase['focus'] ?? "",
            "tasks": (phase['tasks'] as List? ?? []).map((t) {
              return {
                "title": t['title'] ?? "Untitled Task",
                "estimated_duration": 60,
                "energy_required": "MEDIUM",
              };
            }).toList(),
          };
        }).toList(),
      };

      final response = await _apiService.post(
        '/api/v1/goals/blueprint/save',
        body: body,
      );

      return response.isSuccess;
    } catch (e) {
      print("Save Blueprint Error: $e");
      return false;
    }
  }

  /// Fetch the current active goal/blueprint
  Future<Map<String, dynamic>?> getCurrentGoal() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _apiService.get(
        '/api/v1/goals/current?user_id=$userId',
      );

      if (response.isSuccess && response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      print("Fetch Current Goal Error: $e");
      return null;
    }
  }
}
