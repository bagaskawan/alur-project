import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/api_service.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _user = SupabaseService.currentUser;
  final _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Personality profile state
  Map<String, dynamic> _personalityData = {};
  bool _isLoading = true;

  // Personality options configuration
  static const Map<String, List<String>> _personalityOptions = {
    'energy_profile': ['MORNING_LARK', 'NIGHT_OWL', 'FLEXIBLE'],
    'motivation_drivers': [
      'GOAL_ORIENTED',
      'REWARD_DRIVEN',
      'SOCIAL_DRIVEN',
      'GROWTH_FOCUSED',
    ],
    'challenge_response': ['FIGHTER', 'STRATEGIC', 'COLLABORATOR', 'ADAPTIVE'],
    'learning_style': ['VISUAL', 'AUDITORY', 'KINESTHETIC', 'READING_WRITING'],
    'behavior_type': ['INTROVERT', 'EXTROVERT', 'AMBIVERT'],
  };

  // Display names for fields
  static const Map<String, String> _fieldDisplayNames = {
    'energy_profile': 'Energy Profile',
    'motivation_drivers': 'Motivation Driver',
    'challenge_response': 'Challenge Response',
    'learning_style': 'Learning Style',
    'behavior_type': 'Behavior Type',
  };

  @override
  void initState() {
    super.initState();
    final meta = _user?.userMetadata ?? {};
    _nameController = TextEditingController(
      text: meta['full_name'] ?? meta['name'] ?? '',
    );
    _emailController = TextEditingController(text: _user?.email ?? '');
    _loadPersonalityData();
  }

  Future<void> _loadPersonalityData() async {
    try {
      final response = await _apiService.get('/api/v1/users/profile');
      if (response.isSuccess && response.data != null) {
        setState(() {
          _personalityData = response.data['personalization_data'] ?? {};
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getDisplayValue(String field) {
    final values = _personalityData[field];
    if (values == null || (values is List && values.isEmpty)) {
      return 'Not Set';
    }
    final value = values is List ? values.first : values;
    return _formatOptionName(value.toString());
  }

  String _formatOptionName(String option) {
    // Convert SNAKE_CASE to Title Case
    return option
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _showSelectionModal(String field) async {
    final options = _personalityOptions[field] ?? [];
    final currentValues = _personalityData[field];
    final currentValue = currentValues is List && currentValues.isNotEmpty
        ? currentValues.first
        : null;

    debugPrint('📋 Opening modal for $field');
    debugPrint('📋 Current value: $currentValue');
    debugPrint('📋 Current personalityData: $_personalityData');

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSelectionSheet(
        title: 'Select ${_fieldDisplayNames[field]}',
        options: options,
        selectedValue: currentValue,
      ),
    );

    debugPrint('📋 Selected: $selected');

    if (selected != null && selected != currentValue) {
      debugPrint('✅ Calling _updatePersonalityField with $field = $selected');
      await _updatePersonalityField(field, selected);
      debugPrint('✅ After update, personalityData: $_personalityData');
    } else {
      debugPrint(
        '⏭️ No change needed (selected=$selected, current=$currentValue)',
      );
    }
  }

  Widget _buildSelectionSheet({
    required String title,
    required List<String> options,
    String? selectedValue,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
          ),
          // Options list
          ...options.map(
            (option) => _buildOptionItem(
              option: option,
              isSelected: option == selectedValue,
              onTap: () => Navigator.pop(context, option),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required String option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatOptionName(option),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.dark,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.pastelYellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: AppColors.dark),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePersonalityField(String field, String value) async {
    // Save old value for rollback on error
    final oldValue = _personalityData[field];

    // Optimistic update - update UI immediately
    setState(() {
      _personalityData[field] = [value];
    });

    debugPrint('🔄 Updating $field to $value');
    debugPrint('📦 Request body: {"field": "$field", "value": ["$value"]}');

    try {
      final response = await _apiService.patch(
        '/api/v1/users/profile/personality',
        body: {
          'field': field,
          'value': [value],
        },
      );

      debugPrint('📬 Response: ${response.isSuccess} - ${response.message}');
      debugPrint('📬 Data: ${response.data}');

      if (!response.isSuccess) {
        // Rollback on failure
        setState(() {
          _personalityData[field] = oldValue;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: ${response.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_fieldDisplayNames[field]} updated successfully',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      // Rollback on error
      setState(() {
        _personalityData[field] = oldValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _user?.userMetadata ?? {};
    final avatarUrl = meta['avatar_url'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Personal Information',
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
      body: _isLoading
          ? _buildSkeletonUI()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // === AVATAR ===
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFE4C9),
                              width: 4,
                            ),
                            image: avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(avatarUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: const Color(0xFFFFE4C9),
                          ),
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.textSecondary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.pastelYellow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // === FULL NAME ===
                  _buildLabel("Full Name"),
                  _buildTextField(
                    controller: _nameController,
                    hintText: "Enter your name",
                  ),
                  const SizedBox(height: 24),

                  // === EMAIL ===
                  _buildLabel("Email Address"),
                  _buildTextField(
                    controller: _emailController,
                    hintText: "Enter your email",
                    readOnly: true,
                    suffixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Linked to Google Account",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // === PERSONALITY PROFILE ===
                  _buildSectionLabel("PERSONALITY PROFILE", Icons.psychology),
                  _buildMenuCard([
                    _buildProfileItem(
                      icon: Icons.bolt,
                      iconColor: Colors.amber,
                      title: "Energy Profile",
                      value: _getDisplayValue('energy_profile'),
                      onTap: () => _showSelectionModal('energy_profile'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileItem(
                      icon: Icons.flag,
                      iconColor: Colors.green,
                      title: "Motivation Driver",
                      value: _getDisplayValue('motivation_drivers'),
                      onTap: () => _showSelectionModal('motivation_drivers'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileItem(
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      title: "Challenge Response",
                      value: _getDisplayValue('challenge_response'),
                      onTap: () => _showSelectionModal('challenge_response'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileItem(
                      icon: Icons.school,
                      iconColor: Colors.blue,
                      title: "Learning Style",
                      value: _getDisplayValue('learning_style'),
                      onTap: () => _showSelectionModal('learning_style'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileItem(
                      icon: Icons.people,
                      iconColor: Colors.orange,
                      title: "Behavior Type",
                      value: _getDisplayValue('behavior_type'),
                      onTap: () => _showSelectionModal('behavior_type'),
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.dark,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.5),
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: suffixIcon,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
        style: const TextStyle(fontSize: 15, color: AppColors.dark),
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.dark,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // AVATAR SKELETON
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // FORM FIELDS SKELETON
          _buildFieldSkeleton(),
          const SizedBox(height: 24),
          _buildFieldSkeleton(),
          const SizedBox(height: 32),

          // PERSONALITY PROFILE SKELETON
          Container(
            width: 150,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 300,
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
          ),
        ],
      ),
    );
  }

  Widget _buildFieldSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ],
    );
  }
}
