import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';

class ProfileService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>?> getProfile() async {
    final response = await _apiService.get('/api/v1/users/profile');
    if (response.isSuccess) {
      return response.data;
    }
    return null;
  }

  Future<bool> updateProfile({
    String? workStartTime,
    String? workEndTime,
    String? aiPersona,
    String? preferredLanguage,
    Map<String, dynamic>? personalizationData,
  }) async {
    final body = <String, dynamic>{};
    if (workStartTime != null) body['work_start_time'] = workStartTime;
    if (workEndTime != null) body['work_end_time'] = workEndTime;
    if (aiPersona != null) body['ai_persona'] = aiPersona;
    if (preferredLanguage != null)
      body['preferred_language'] = preferredLanguage;
    if (personalizationData != null)
      body['personalization_data'] = personalizationData;

    final response = await _apiService.put('/api/v1/users/profile', body: body);
    return response.isSuccess;
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
  }
}
