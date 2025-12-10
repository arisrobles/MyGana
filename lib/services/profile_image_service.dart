import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageService {
  static const String _profileImageKey = 'profile_image_path';
  static const String _isCustomImageKey = 'is_custom_image';

  // Reset service (useful when user changes)
  void reset() {
    print('ProfileImageService reset for user change');
  }

  // Save the profile image path
  Future<void> saveProfileImage(String path, {bool isCustom = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImageKey, path);
    await prefs.setBool(_isCustomImageKey, isCustom);
  }

  // Get the profile image path
  Future<String?> getProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileImageKey);
  }

  // Check if the image is custom (uploaded)
  Future<bool> isCustomImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isCustomImageKey) ?? false;
  }

  // Clear the profile image
  Future<void> clearProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileImageKey);
    await prefs.remove(_isCustomImageKey);
  }

  Future<void> removeProfileImage() async {}
}
