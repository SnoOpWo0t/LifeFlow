import 'package:flutter/material.dart';

/// Preset popular categories for wishlist items with curated styling.
class WishlistCategoryUtils {
  static const List<String> popularCategories = [
    'Tech',
    'Perfume',
    'Fashion',
    'Gaming',
    'Books',
    'Home',
    'Beauty',
    'Fitness',
    'Travel',
  ];

  static IconData getIcon(String? category) {
    if (category == null || category.trim().isEmpty) {
      return Icons.label_outline;
    }
    final lower = category.trim().toLowerCase();

    if (lower.contains('tech') ||
        lower.contains('gadget') ||
        lower.contains('electronic') ||
        lower.contains('phone') ||
        lower.contains('laptop') ||
        lower.contains('pc')) {
      return Icons.devices;
    }
    if (lower.contains('perfume') ||
        lower.contains('fragrance') ||
        lower.contains('cologne') ||
        lower.contains('scent')) {
      return Icons.spa;
    }
    if (lower.contains('fashion') ||
        lower.contains('cloth') ||
        lower.contains('dress') ||
        lower.contains('shoe') ||
        lower.contains('wear')) {
      return Icons.checkroom;
    }
    if (lower.contains('game') ||
        lower.contains('gaming') ||
        lower.contains('playstation') ||
        lower.contains('xbox') ||
        lower.contains('nintendo')) {
      return Icons.sports_esports;
    }
    if (lower.contains('book') ||
        lower.contains('read') ||
        lower.contains('novel')) {
      return Icons.menu_book;
    }
    if (lower.contains('home') ||
        lower.contains('furnitur') ||
        lower.contains('decor') ||
        lower.contains('kitchen')) {
      return Icons.home_outlined;
    }
    if (lower.contains('beauty') ||
        lower.contains('skin') ||
        lower.contains('care') ||
        lower.contains('makeup')) {
      return Icons.auto_awesome;
    }
    if (lower.contains('fit') ||
        lower.contains('gym') ||
        lower.contains('sport') ||
        lower.contains('workout')) {
      return Icons.fitness_center;
    }
    if (lower.contains('travel') ||
        lower.contains('trip') ||
        lower.contains('flight') ||
        lower.contains('hotel')) {
      return Icons.flight_takeoff;
    }
    if (lower.contains('car') ||
        lower.contains('bike') ||
        lower.contains('vehicle')) {
      return Icons.directions_car;
    }
    if (lower.contains('music') ||
        lower.contains('audio') ||
        lower.contains('sound')) {
      return Icons.headphones;
    }
    if (lower.contains('camera') || lower.contains('photo')) {
      return Icons.camera_alt;
    }

    return Icons.sell_outlined;
  }

  static Color getColor(String? category) {
    if (category == null || category.trim().isEmpty) {
      return const Color(0xFF64748B); // Slate
    }
    final lower = category.trim().toLowerCase();

    if (lower.contains('tech') ||
        lower.contains('gadget') ||
        lower.contains('electronic') ||
        lower.contains('phone')) {
      return const Color(0xFF0284C7); // Sky blue
    }
    if (lower.contains('perfume') ||
        lower.contains('fragrance') ||
        lower.contains('cologne')) {
      return const Color(0xFFD946EF); // Fuchsia
    }
    if (lower.contains('fashion') || lower.contains('cloth')) {
      return const Color(0xFFEC4899); // Pink
    }
    if (lower.contains('game') || lower.contains('gaming')) {
      return const Color(0xFF8B5CF6); // Violet
    }
    if (lower.contains('book') || lower.contains('read')) {
      return const Color(0xFFF59E0B); // Amber
    }
    if (lower.contains('home') || lower.contains('furnitur')) {
      return const Color(0xFF10B981); // Emerald
    }
    if (lower.contains('beauty') || lower.contains('skin')) {
      return const Color(0xFFF43F5E); // Rose
    }
    if (lower.contains('fit') || lower.contains('gym')) {
      return const Color(0xFFEF4444); // Red
    }
    if (lower.contains('travel') || lower.contains('trip')) {
      return const Color(0xFF06B6D4); // Cyan
    }

    // Deterministic palette generation for custom user categories
    const palette = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF14B8A6), // Teal
      Color(0xFFF97316), // Orange
      Color(0xFFA855F7), // Purple
      Color(0xFF06B6D4), // Cyan
      Color(0xFF84CC16), // Lime
      Color(0xFFE11D48), // Rose
      Color(0xFF3B82F6), // Blue
    ];

    final hash = lower.codeUnits.fold(0, (acc, val) => acc + val);
    return palette[hash % palette.length];
  }
}
