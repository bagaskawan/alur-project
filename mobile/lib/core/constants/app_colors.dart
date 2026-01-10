import 'package:flutter/material.dart';

class AppColors {
  // === MONOCHROME (Primary) ===
  static const Color dark = Color(0xFF1D1C21); // Almost Black - Primary
  static const Color textPrimary = Color(0xFF1D1C21); // Same as dark
  static const Color textSecondary = Color(0xFF6B6B6B); // Mid gray
  static const Color background = Color(0xFFF8FAFC); // Off-white
  static const Color surface = Colors.white;

  // === PASTEL ACCENTS ===
  static const Color pastelGreen = Color(0xFFE0F3CC);
  static const Color pastelPurple = Color(0xFFC4A3FD);
  static const Color pastelYellow = Color(0xFFFFDD9D);
  static const Color pastelBlue = Color(0xFFC2E2FA);

  // === CARD COLORS (for redesigned home screen) ===
  static const Color cardGreen = Color(0xFFC8E6A0); // Light green for task card
  static const Color cardBeige = Color(
    0xFFF5E6D3,
  ); // Beige/cream for webinar card
  static const Color cardBlue = Color(0xFFA3D5F5); // Light blue for habits card

  // === SEMANTIC ALIASES ===
  static const Color primary = dark; // Main brand color
  static const Color accent = pastelPurple; // Accent/highlight
  static const Color success = pastelGreen; // Success states
  static const Color warning = pastelYellow; // Warning states
  static const Color info = pastelBlue; // Info/neutral states
}
