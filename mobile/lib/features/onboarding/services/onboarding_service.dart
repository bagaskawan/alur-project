import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/supabase_service.dart';
import '../models/chat_message.dart';

/// Service for handling onboarding chat logic with GROQ AI integration
class OnboardingService {
  static const String _groqApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // Onboarding question stages
  static const List<String> _stages = [
    'greeting',
    'energy_profile',
    'motivation_drivers',
    'challenge_response',
    'learning_style',
    'behavior_type',
    'completion',
  ];

  // Valid tags for each personalization category
  static const Map<String, List<String>> validTags = {
    'behavior_type': ['INTROVERT', 'EXTROVERT', 'AMBIVERT'],
    'energy_profile': ['MORNING_LARK', 'NIGHT_OWL', 'FLEXIBLE'],
    'motivation_drivers': [
      'GOAL_ORIENTED',
      'REWARD_DRIVEN',
      'SOCIAL_DRIVEN',
      'GROWTH_FOCUSED',
    ],
    'challenge_response': ['FIGHTER', 'STRATEGIC', 'COLLABORATOR', 'ADAPTIVE'],
    'learning_style': ['VISUAL', 'AUDITORY', 'KINESTHETIC', 'READING_WRITING'],
  };

  int _currentStageIndex = 0;
  String? _userName;
  final Map<String, List<String>> _collectedData = {
    'behavior_type': [],
    'energy_profile': [],
    'motivation_drivers': [],
    'challenge_response': [],
    'learning_style': [],
  };

  String get currentStage => _stages[_currentStageIndex];
  bool get isComplete => _currentStageIndex >= _stages.length - 1;
  Map<String, List<String>> get collectedData =>
      Map.unmodifiable(_collectedData);

  /// Get the initial greeting message
  String getInitialMessage() {
    return "Halo! Saya Alur. Mari kita sesuaikan aplikasi ini dengan gaya kerjamu. Kapan biasanya energi fokusmu paling tinggi?";
  }

  /// Process user message and generate AI response using GROQ
  Future<String> processUserMessage(String userMessage) async {
    final groqApiKey = dotenv.env['GROQ_API_KEY'];

    if (groqApiKey == null || groqApiKey.isEmpty) {
      // Fallback to mock responses if no API key
      return _getMockResponse(userMessage);
    }

    try {
      final response = await _callGroqApi(userMessage, groqApiKey);
      _extractAndStoreData(userMessage);
      _advanceStage();
      return response;
    } catch (e) {
      print('GROQ API Error: $e');
      // Fallback to mock response on error
      return _getMockResponse(userMessage);
    }
  }

  /// Call GROQ API for AI response
  Future<String> _callGroqApi(String userMessage, String apiKey) async {
    final systemPrompt = _buildSystemPrompt();
    final contextPrompt = _buildContextPrompt(userMessage);

    final response = await http.post(
      Uri.parse(_groqApiUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': contextPrompt},
        ],
        'max_tokens': 200,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ??
          _getMockResponse(userMessage);
    } else {
      throw Exception('GROQ API error: ${response.statusCode}');
    }
  }

  String _buildSystemPrompt() {
    return '''You are a friendly Growth Guide AI assistant helping a new user set up their profile in the ALUR productivity app. 
Your role is to ask questions conversationally to understand the user's:
- Work preferences and energy patterns
- Motivation style
- How they handle challenges
- Learning preferences
- Personality type (introvert/extrovert/ambivert)

Keep responses SHORT (1-3 sentences max), warm, and conversational. Use emojis sparingly.
Ask ONE question at a time. Don't explain the categories, just ask naturally.''';
  }

  String _buildContextPrompt(String userMessage) {
    String context = 'Current stage: ${_stages[_currentStageIndex]}\n';
    if (_userName != null) {
      context += 'User\'s name: $_userName\n';
    }
    context += 'User just said: "$userMessage"\n\n';

    switch (currentStage) {
      case 'greeting':
        context +=
            'Extract their name and ask about what time of day they feel most energized and productive.';
        break;
      case 'energy_profile':
        context +=
            'Ask what motivates them most - achieving goals, earning rewards, social connection, or personal growth?';
        break;
      case 'motivation_drivers':
        context +=
            'Ask how they typically respond when facing a difficult challenge.';
        break;
      case 'challenge_response':
        context +=
            'Ask how they prefer to learn new things - through visuals, listening, hands-on practice, or reading?';
        break;
      case 'learning_style':
        context +=
            'Ask if they recharge better alone (introvert), with others (extrovert), or it depends (ambivert).';
        break;
      case 'behavior_type':
        context +=
            'Thank them warmly and let them know you\'ve personalized their experience. End with enthusiasm about their growth journey ahead!';
        break;
      default:
        context += 'Wrap up the conversation and welcome them to the app.';
    }

    return context;
  }

  /// Extract data from user message and store with valid tags
  void _extractAndStoreData(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    switch (currentStage) {
      case 'greeting':
        // Extract name - simple extraction from greeting response
        _userName = _extractName(userMessage);
        break;
      case 'energy_profile':
        if (lowerMessage.contains('morning') ||
            lowerMessage.contains('early') ||
            lowerMessage.contains('pagi')) {
          _collectedData['energy_profile'] = ['MORNING_LARK'];
        } else if (lowerMessage.contains('night') ||
            lowerMessage.contains('late') ||
            lowerMessage.contains('malam')) {
          _collectedData['energy_profile'] = ['NIGHT_OWL'];
        } else {
          _collectedData['energy_profile'] = ['FLEXIBLE'];
        }
        break;
      case 'motivation_drivers':
        if (lowerMessage.contains('goal') ||
            lowerMessage.contains('achieve') ||
            lowerMessage.contains('tujuan')) {
          _collectedData['motivation_drivers'] = ['GOAL_ORIENTED'];
        } else if (lowerMessage.contains('reward') ||
            lowerMessage.contains('bonus') ||
            lowerMessage.contains('hadiah')) {
          _collectedData['motivation_drivers'] = ['REWARD_DRIVEN'];
        } else if (lowerMessage.contains('team') ||
            lowerMessage.contains('social') ||
            lowerMessage.contains('teman')) {
          _collectedData['motivation_drivers'] = ['SOCIAL_DRIVEN'];
        } else {
          _collectedData['motivation_drivers'] = ['GROWTH_FOCUSED'];
        }
        break;
      case 'challenge_response':
        if (lowerMessage.contains('fight') ||
            lowerMessage.contains('head on') ||
            lowerMessage.contains('langsung')) {
          _collectedData['challenge_response'] = ['FIGHTER'];
        } else if (lowerMessage.contains('plan') ||
            lowerMessage.contains('think') ||
            lowerMessage.contains('strategi')) {
          _collectedData['challenge_response'] = ['STRATEGIC'];
        } else if (lowerMessage.contains('team') ||
            lowerMessage.contains('help') ||
            lowerMessage.contains('kolaborasi')) {
          _collectedData['challenge_response'] = ['COLLABORATOR'];
        } else {
          _collectedData['challenge_response'] = ['ADAPTIVE'];
        }
        break;
      case 'learning_style':
        if (lowerMessage.contains('visual') ||
            lowerMessage.contains('see') ||
            lowerMessage.contains('lihat')) {
          _collectedData['learning_style'] = ['VISUAL'];
        } else if (lowerMessage.contains('listen') ||
            lowerMessage.contains('hear') ||
            lowerMessage.contains('dengar')) {
          _collectedData['learning_style'] = ['AUDITORY'];
        } else if (lowerMessage.contains('hands') ||
            lowerMessage.contains('practice') ||
            lowerMessage.contains('praktek')) {
          _collectedData['learning_style'] = ['KINESTHETIC'];
        } else {
          _collectedData['learning_style'] = ['READING_WRITING'];
        }
        break;
      case 'behavior_type':
        if (lowerMessage.contains('alone') ||
            lowerMessage.contains('introvert') ||
            lowerMessage.contains('sendiri')) {
          _collectedData['behavior_type'] = ['INTROVERT'];
        } else if (lowerMessage.contains('people') ||
            lowerMessage.contains('extrovert') ||
            lowerMessage.contains('orang')) {
          _collectedData['behavior_type'] = ['EXTROVERT'];
        } else {
          _collectedData['behavior_type'] = ['AMBIVERT'];
        }
        break;
    }
  }

  String? _extractName(String message) {
    // Simple name extraction - get first capitalized word or word after common patterns
    final patterns = [
      RegExp(
        r"(?:name is|call me|i'm|nama saya|panggil saya)\s+(\w+)",
        caseSensitive: false,
      ),
      RegExp(r'^(\w+)$'), // Single word response
      RegExp(
        r"(?:hi|hello|hey)[,!]?\s*(?:i'm|i am)?\s*(\w+)",
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }

    // Fallback: get first word that looks like a name (capitalized)
    final words = message.split(' ');
    for (final word in words) {
      final cleaned = word.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (cleaned.isNotEmpty && cleaned[0] == cleaned[0].toUpperCase()) {
        return cleaned;
      }
    }

    return message.split(' ').first.replaceAll(RegExp(r'[^a-zA-Z]'), '');
  }

  void _advanceStage() {
    if (_currentStageIndex < _stages.length - 1) {
      _currentStageIndex++;
    }
  }

  /// Fallback mock responses when GROQ is unavailable
  String _getMockResponse(String userMessage) {
    _extractAndStoreData(userMessage);

    switch (currentStage) {
      case 'greeting':
        final name = _extractName(userMessage) ?? 'there';
        _userName = name;
        _advanceStage();
        return 'Nice to meet you, $name! 🌟\n\nWhat time of day do you feel most energized and productive?';
      case 'energy_profile':
        _advanceStage();
        return 'Interesting! What motivates you most to get things done - achieving goals, earning rewards, connecting with others, or personal growth?';
      case 'motivation_drivers':
        _advanceStage();
        return 'When you face a tough challenge, how do you usually respond? Do you tackle it head-on, strategize first, seek help, or adapt as you go?';
      case 'challenge_response':
        _advanceStage();
        return 'How do you prefer to learn new things? Through visuals, listening, hands-on practice, or reading?';
      case 'learning_style':
        _advanceStage();
        return 'Last question! Do you recharge better by spending time alone, with others, or does it depend on the situation?';
      case 'behavior_type':
        _advanceStage();
        return 'Awesome, ${_userName ?? 'friend'}! 🎉\n\nI\'ve personalized your ALUR experience based on what you shared. You\'re all set to start your growth journey!\n\nTap "Get Started" below to continue.';
      default:
        return 'Thanks for sharing! Let\'s get you started on your growth journey! 🚀';
    }
  }

  /// Save personalization data to Supabase profiles table
  Future<void> savePersonalizationData() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'personalization_data': _collectedData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      print('Error saving personalization data: $e');
      rethrow;
    }
  }

  /// Save chat messages to Supabase chat_messages table
  Future<void> saveChatMessages(List<ChatMessage> messages) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final records = messages.map((m) => m.toMap(userId)).toList();
      await SupabaseService.client.from('chat_messages').insert(records);
    } catch (e) {
      print('Error saving chat messages: $e');
      rethrow;
    }
  }

  /// Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('personalization_data')
          .eq('id', userId)
          .single();

      final data = response['personalization_data'] as Map<String, dynamic>?;
      if (data == null) return false;

      // Check if any category has been filled
      return (data['behavior_type'] as List?)?.isNotEmpty == true ||
          (data['energy_profile'] as List?)?.isNotEmpty == true ||
          (data['motivation_drivers'] as List?)?.isNotEmpty == true;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }
}
