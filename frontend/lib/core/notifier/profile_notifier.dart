import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileNotifier {
  static final ValueNotifier<Map<String, dynamic>?> currentUserProfile = ValueNotifier(null);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_user_profile');
      if (raw != null && raw.isNotEmpty) {
        currentUserProfile.value = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[ProfileNotifier] Error loading cached profile: $e');
    }
  }

  static Future<void> setProfile(Map<String, dynamic> profile) async {
    currentUserProfile.value = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', jsonEncode(profile));
    } catch (e) {
      debugPrint('[ProfileNotifier] Error caching profile: $e');
    }
  }

  static Future<void> updateAvatar(String newAvatarUrl) async {
    if (currentUserProfile.value != null) {
      final updated = Map<String, dynamic>.from(currentUserProfile.value!);
      final profileObj = updated['profile'] != null ? Map<String, dynamic>.from(updated['profile']) : <String, dynamic>{};
      profileObj['avatarUrl'] = newAvatarUrl;
      updated['profile'] = profileObj;
      updated['avatarUrl'] = newAvatarUrl;
      currentUserProfile.value = updated;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_profile', jsonEncode(updated));
      } catch (e) {
        debugPrint('[ProfileNotifier] Error updating cached avatar: $e');
      }
    }
  }

  static Future<void> clear() async {
    currentUserProfile.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_profile');
    } catch (_) {}
  }
}
