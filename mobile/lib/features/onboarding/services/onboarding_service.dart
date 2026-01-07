import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/chat_message.dart';

/// Service for handling onboarding chat logic with Backend AI integration
/// Now uses ApiService to communicate with FastAPI backend
class OnboardingService {
  final ApiService _apiService = ApiService();

  // Onboarding question stages (for tracking completion)
  static const List<String> _stages = [
    'greeting',
    'energy_profile',
    'motivation_drivers',
    'challenge_response',
    'learning_style',
    'behavior_type',
    'completion',
  ];

  // Choice chips for each stage (friendly labels)
  static const Map<String, List<String>> stageChips = {
    'energy_profile': ['Pagi ☀️', 'Malam 🌙', 'Fleksibel ⚡'],
    'motivation_drivers': ['Target 🎯', 'Hadiah 🎁', 'Teman 👥', 'Belajar 📈'],
    'challenge_response': [
      'Langsung 💪',
      'Strategi 🧠',
      'Kolaborasi 🤝',
      'Adaptif 🔄',
    ],
    'learning_style': ['Visual 👀', 'Audio 🎧', 'Praktek ✋', 'Baca/Tulis 📖'],
    'behavior_type': ['Sendiri 🧘', 'Ramai 🎉', 'Tergantung ⚖️'],
  };

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

  /// Returns true only when ALL 5 personalization data fields have been filled
  bool get isComplete {
    final requiredFields = [
      'energy_profile',
      'motivation_drivers',
      'challenge_response',
      'learning_style',
      'behavior_type',
    ];
    for (final field in requiredFields) {
      if (_collectedData[field] == null || _collectedData[field]!.isEmpty) {
        return false;
      }
    }
    return true;
  }

  Map<String, List<String>> get collectedData =>
      Map.unmodifiable(_collectedData);

  /// Get choice chips for the current stage (returns null if no chips)
  List<String>? getOptionsForCurrentStage() {
    return stageChips[currentStage];
  }

  /// Get the smart initial greeting message
  String getInitialMessage() {
    // 1. Cek Waktu (Time Awareness)
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour < 4) {
      timeGreeting = "Halo pejuang malam"; // Lembur/Begadang
    } else if (hour < 11) {
      timeGreeting = "Pagi";
    } else if (hour < 15) {
      timeGreeting = "Siang";
    } else if (hour < 18) {
      timeGreeting = "Sore";
    } else {
      timeGreeting = "Malam";
    }

    // 2. Cek Metadata User dari Supabase (Auth Awareness)
    final user = SupabaseService.currentUser;
    // Metadata biasanya menyimpan 'full_name', 'name', atau 'preferred_username'
    final metaName =
        user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];

    if (metaName != null && metaName.toString().isNotEmpty) {
      // KASUS A: Nama User SUDAH ADA (misal login Google)
      _userName = metaName.toString().split(' ').first; // Ambil nama depan

      // PENTING: Kita harus majukan stage secara manual karena stage 'greeting'
      // tujuannya cuma cari nama. Kalau nama sudah ada, kita loncat ke 'energy_profile'.
      if (currentStage == 'greeting') {
        _advanceStage(); // Loncat dari index 0 ke 1
      }

      return "$timeGreeting, $_userName! 👋\n\nAku Alur, asisten produktivitasmu. Biar aku bisa bantu lebih optimal, kapan biasanya kamu paling **produktif**? **Pagi**, **siang**, atau **malam**?";
    } else {
      // KASUS B: Nama User BELUM ADA (misal login Email biasa)
      // Tetap di stage 0 ('greeting') untuk menunggu input nama
      return "$timeGreeting! 👋\n\nAku Alur, asisten produktivitasmu. Btw, aku boleh panggil kamu siapa nih?";
    }
  }

  /// Process user message and generate AI response using Backend API
  /// Falls back to mock responses if backend is unavailable
  /// Process user message and generate AI response using Backend API
  Future<String> processUserMessage(String userMessage) async {
    // 1. Special Local Handling for Greeting (Name Extraction)
    if (currentStage == 'greeting') {
      final name = _extractName(userMessage);
      if (name != null && name.isNotEmpty) {
        _userName = name;
        // We still send to backend to get a nice reply
      }
    }

    try {
      // 2. Call Backend API with Context
      final response = await _apiService.post(
        '/api/v1/chat/send',
        body: {
          'message': userMessage,
          'mode': 'ONBOARDING',
          'current_stage': currentStage, // 🧠 Send Context to Brain
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data;

        // 3. Check AI Decision (JSON Logic)
        // Explicit boolean check for null safety
        bool isValid = data['is_valid_answer'] == true;

        if (isValid) {
          // AI says answer is valid!

          if (currentStage == 'greeting') {
            // For greeting, we just advance
            _advanceStage();
          } else {
            // For data stages, backend extracts the data
            List<String> extractedValues = [];
            final rawData = data['extracted_data'];

            if (rawData is String) {
              extractedValues = [rawData];
            } else if (rawData is List) {
              extractedValues = List<String>.from(rawData);
            }

            if (extractedValues.isNotEmpty) {
              // Update local state with data from Brain
              _collectedData[currentStage] = extractedValues;

              // Advance to next stage
              _advanceStage();
            }
          }
        }

        // 4. Return AI Reply (Explanation or Next Question)
        final reply = data['reply'] as String?;
        return reply ?? "Maaf, ada kesalahan sistem.";
      }

      return _getMockResponse(userMessage);
    } catch (e) {
      print('Backend API Error: $e');
      return _getMockResponse(userMessage);
    }
  }

  String? _extractName(String message) {
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

  /// Fallback mock responses when backend is unavailable
  String _getMockResponse(String userMessage) {
    switch (currentStage) {
      case 'greeting':
        final name = _extractName(userMessage) ?? 'kamu';
        _userName = name;
        _advanceStage();
        return 'Hai $name! 👋\n\nOke, jadi kapan biasanya kamu paling **produktif**? **Pagi**, **siang**, atau **malam**?';
      case 'energy_profile':
        _advanceStage();
        return 'Sip! Terus nih, apa **tantangan produktivitas** terbesar yang lagi kamu hadapi sekarang?';
      case 'motivation_drivers':
        _advanceStage();
        return 'I see! Kalo soal pengingat, kamu lebih suka cara yang **lembut** atau **tegas** nih?';
      case 'challenge_response':
        _advanceStage();
        return 'Noted! Last question - kamu lebih suka belajar hal baru lewat **visual**, **dengerin**, **praktek langsung**, atau **baca**?';
      case 'learning_style':
        _advanceStage();
        return 'Satu lagi! Kamu recharge-nya lebih enak **sendirian**, **sama orang lain**, atau **tergantung mood**?';
      case 'behavior_type':
        _advanceStage();
        return 'Mantap, ${_userName ?? 'kamu'}! 🎉\n\nAku udah personalisasi pengalaman ALUR-mu. Yuk mulai perjalanan produktifmu!\n\nTap **"Get Started"** di bawah ya.';
      default:
        return 'Thanks udah sharing! Yuk langsung gas! 🚀';
    }
  }

  /// Save personalization data to Supabase profiles table
  Future<void> savePersonalizationData() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // Debug print: Show ALL collected persona data before saving
    print('\n' + '=' * 60);
    print('🔄 SAVING PERSONALIZATION DATA TO SUPABASE');
    print('=' * 60);
    print('User ID: $userId');
    print('User Name: $_userName');
    print('');
    print('📊 PERSONA DATA:');
    _collectedData.forEach((key, value) {
      print('   $key: $value');
    });
    print('=' * 60 + '\n');

    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'personalization_data': _collectedData,
            'full_name': _userName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      print('✅ Personalization data saved successfully!');
    } catch (e) {
      print('❌ Error saving personalization data: $e');
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
