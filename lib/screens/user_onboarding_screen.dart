import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nihongo_japanese_app/screens/main_screen.dart'; // Changed to MainScreen
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/class_management_service.dart';
import 'package:nihongo_japanese_app/services/profile_image_service.dart';
import 'package:nihongo_japanese_app/services/system_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserOnboardingScreen extends StatefulWidget {
  final String? email;
  final String? password;
  final String? classCode;

  const UserOnboardingScreen({super.key, this.email, this.password, this.classCode});

  @override
  State<UserOnboardingScreen> createState() => _UserOnboardingScreenState();
}

class _UserOnboardingScreenState extends State<UserOnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  final ProfileImageService _profileImageService = ProfileImageService();
  final AuthService _authService = AuthService();
  final SystemConfigService _systemConfig = SystemConfigService();
  final ImagePicker _picker = ImagePicker();
  ClassManagementService? _classService;

  // User data
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String _selectedGender = 'Prefer not to say';
  String? _selectedImagePath;

  // List of preset profile images
  final List<String> _predefinedAvatars = [
    'assets/images/profile/female.png',
    'assets/images/profile/girl.png',
    'assets/images/profile/man.png',
    'assets/images/profile/man (1).png',
    'assets/images/profile/man (2).png',
    'assets/images/profile/woman.png',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animationController.forward();
    debugPrint(
        'UserOnboardingScreen init: email=${widget.email}, user=${_authService.currentUser?.uid}');
  }

  Future<ClassManagementService> _ensureClassService() async {
    _classService ??= ClassManagementService();
    return _classService!;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveUserData() async {
    if (_formKey.currentState!.validate()) {
      // Check if registration is enabled before proceeding
      final isRegistrationEnabled = await _systemConfig.isRegistrationEnabled();
      if (!isRegistrationEnabled) {
        if (mounted) {
          _showRegistrationDisabledDialog();
        }
        return;
      }

      HapticFeedback.mediumImpact();
      final prefs = await SharedPreferences.getInstance();

      try {
        debugPrint(
            'Saving user data: email=${widget.email}, currentUser=${_authService.currentUser?.uid}');
        User? user = _authService.currentUser;
        String? profileImageUrl;

        // Upload profile image if selected
        if (_selectedImagePath != null && !_selectedImagePath!.startsWith('assets/')) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images/${user?.uid ?? DateTime.now().millisecondsSinceEpoch}');
          debugPrint('Uploading profile image: $_selectedImagePath');
          await storageRef.putFile(File(_selectedImagePath!));
          profileImageUrl = await storageRef.getDownloadURL();
          debugPrint('Profile image uploaded: $profileImageUrl');
        } else if (_selectedImagePath != null) {
          profileImageUrl = _selectedImagePath;
          debugPrint('Using preset image: $profileImageUrl');
        }

        if (user == null && widget.email != null && widget.password != null) {
          // User not authenticated, proceed with registration
          debugPrint('Registering new user with email: ${widget.email}');
          await _authService.register(
            email: widget.email!,
            password: widget.password!,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            gender: _selectedGender,
            profileImagePath: _selectedImagePath,
          );
          user = _authService.currentUser;
          debugPrint('Registration complete: user=${user?.uid}');
        } else if (user == null) {
          throw Exception('No user authenticated and no email/password provided');
        }

        // Store user data in Realtime Database
        debugPrint('Saving user data to Realtime Database for user: ${user?.uid}');
        await FirebaseDatabase.instance.ref().child('users/${user?.uid}').set({
          'email': widget.email ?? user?.email,
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'gender': _selectedGender,
          'profileImageUrl': profileImageUrl,
          'isAdmin': false,
          'role': 'student',
          'createdAt': ServerValue.timestamp,
        });

        // Enroll to class if classCode provided
        try {
          if (widget.classCode != null && widget.classCode!.isNotEmpty) {
            debugPrint('Attempting class enrollment with code: ${widget.classCode}');
            // lazy import to avoid heavy coupling
            // ignore: avoid_dynamic_calls
            final service = await _ensureClassService();
            await service.enrollCurrentUserWithCode(widget.classCode!.trim());
            debugPrint('Enrollment successful');
          }
        } catch (e) {
          debugPrint('Class enrollment failed: $e');
          // Continue without blocking onboarding
        }

        // Save to SharedPreferences for local use
        debugPrint('Saving user data to SharedPreferences');
        await prefs.setString('first_name', _firstNameController.text);
        await prefs.setString('last_name', _lastNameController.text);
        await prefs.setString('gender', _selectedGender);
        await prefs.setBool('has_completed_profile', true);

        if (mounted) {
          debugPrint('Navigating to MainScreen');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Profile setup completed!'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } catch (e, stackTrace) {
        debugPrint('Error in _saveUserData: $e');
        debugPrint('Stack trace: $stackTrace');
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        if (errorMessage.contains('email-already-in-use')) {
          errorMessage = 'This email is already in use. Please log in or use a different email.';
        } else if (errorMessage.contains('network-request-failed')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (errorMessage.contains('permission-denied')) {
          errorMessage = 'Permission denied. Please contact support.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
      });
      await _profileImageService.saveProfileImage(image.path, isCustom: true);
    }
  }

  void _showPresetImagesDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose a Profile Image',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: _predefinedAvatars.length,
                  itemBuilder: (context, index) {
                    final avatar = _predefinedAvatars[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImagePath = avatar;
                        });
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage(avatar),
                        backgroundColor: Colors.grey.shade200,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRegistrationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.block,
              color: Colors.red.shade400,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Registration Disabled',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sorry, you cannot register at this time.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New registrations are currently disabled by the administrator.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate back to auth screen
              Navigator.of(context).pop();
            },
            child: Text(
              'Go Back',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Let’s Get Started!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us a bit about yourself',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          child: _selectedImagePath != null
                              ? ClipOval(
                                  child: _selectedImagePath!.startsWith('assets/')
                                      ? Image.asset(
                                          _selectedImagePath!,
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                        )
                                      : Image.file(
                                          File(_selectedImagePath!),
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                        ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: ElevatedButton.icon(
                                onPressed: _pickImageFromGallery,
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text(
                                  'Gallery',
                                  style: TextStyle(fontSize: 14),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: ElevatedButton.icon(
                                onPressed: _showPresetImagesDialog,
                                icon: const Icon(Icons.image, size: 18),
                                label: const Text(
                                  'Preset',
                                  style: TextStyle(fontSize: 14),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildAnimatedTextField(
                    controller: _firstNameController,
                    labelText: 'First Name',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                    delay: 0.0,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedTextField(
                    controller: _lastNameController,
                    labelText: 'Last Name',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                    delay: 0.1,
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.people_outline),
                            ),
                            items: ['Male', 'Female', 'Non-binary', 'Prefer not to say']
                                .map((gender) => DropdownMenuItem(
                                      value: gender,
                                      child: Text(gender),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _saveUserData,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                              ),
                              child: const Text(
                                'Complete Setup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required double delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(icon),
              ),
              keyboardType: keyboardType,
              validator: validator,
            ),
          ),
        );
      },
    );
  }
}
