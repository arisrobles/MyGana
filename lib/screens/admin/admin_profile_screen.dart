import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/class_management_service.dart';
import 'package:nihongo_japanese_app/services/profile_image_service.dart';
import 'package:nihongo_japanese_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isNewUser = true;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  final ProfileImageService _profileImageService = ProfileImageService();
  final AuthService _authService = AuthService();
  final ClassManagementService _classService = ClassManagementService();
  final ImagePicker _picker = ImagePicker();

  // User data
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String _selectedGender = 'Prefer not to say';
  String? _profileImageUrl;
  String? _userRole;
  DateTime? _createdAt;
  DateTime? _lastLoginAt;

  // Real-time data
  int _totalClasses = 0;
  int _totalStudents = 0;

  // List of preset profile images
  final List<String> _predefinedAvatars = [
    'assets/images/profile/girl.png',
    'assets/images/profile/man.png',
    'assets/images/profile/man (1).png',
    'assets/images/profile/man (2).png',
    'assets/images/profile/woman.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchRealTimeData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Load from Firebase
        final snapshot = await FirebaseDatabase.instance.ref().child('users/${user.uid}').get();

        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;

          setState(() {
            _firstNameController.text = userData['firstName'] ?? '';
            _lastNameController.text = userData['lastName'] ?? '';
            _emailController.text = userData['email'] ?? user.email ?? '';
            _bioController.text = userData['bio'] ?? '';
            _selectedGender = userData['gender'] ?? 'Prefer not to say';
            _profileImageUrl = userData['profileImageUrl'];
            _userRole = userData['role'] ?? 'teacher';
            _isNewUser = false;

            // Parse timestamps
            if (userData['createdAt'] != null) {
              _createdAt = DateTime.fromMillisecondsSinceEpoch(userData['createdAt']);
            }
            if (userData['lastLoginAt'] != null) {
              _lastLoginAt = DateTime.fromMillisecondsSinceEpoch(userData['lastLoginAt']);
            }
          });

          // Sync with SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('first_name', userData['firstName'] ?? '');
          await prefs.setString('last_name', userData['lastName'] ?? '');
          await prefs.setString('gender', userData['gender'] ?? '');
          await prefs.setString('bio', userData['bio'] ?? '');
        } else {
          // Fallback to SharedPreferences if Firebase data doesn't exist
          await _loadFromSharedPreferences();
        }
      } else {
        // No user authenticated, load from SharedPreferences
        await _loadFromSharedPreferences();
      }
    } catch (e) {
      debugPrint('Error loading user data from Firebase: $e');
      // Fallback to SharedPreferences on error
      await _loadFromSharedPreferences();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRealTimeData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Fetch classes count
        final classesSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('classes')
            .orderByChild('adminId')
            .equalTo(user.uid)
            .get();

        int classesCount = 0;
        int studentsCount = 0;

        if (classesSnapshot.exists) {
          final classesData = classesSnapshot.value as Map<dynamic, dynamic>;
          classesCount = classesData.length;

          // Count students across all classes
          for (final classId in classesData.keys) {
            final studentsSnapshot =
                await FirebaseDatabase.instance.ref().child('classMembers').child(classId).get();

            if (studentsSnapshot.exists) {
              final studentsData = studentsSnapshot.value as Map<dynamic, dynamic>;
              studentsCount += studentsData.length;
            }
          }
        }

        if (mounted) {
          setState(() {
            _totalClasses = classesCount;
            _totalStudents = studentsCount;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching real-time data: $e');
    }
  }

  Future<void> _loadFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedProfile = prefs.getBool('has_completed_profile') ?? false;

    setState(() {
      _firstNameController.text = prefs.getString('first_name') ?? '';
      _lastNameController.text = prefs.getString('last_name') ?? '';
      _selectedGender = prefs.getString('gender') ?? 'Prefer not to say';
      _bioController.text = prefs.getString('bio') ?? '';
      _isNewUser = !hasCompletedProfile;
      _isEditing = _isNewUser;
    });

    // Set email from current user if available
    final user = _authService.currentUser;
    if (user?.email != null) {
      _emailController.text = user!.email!;
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      HapticFeedback.mediumImpact();
      final user = _authService.currentUser;

      if (user != null) {
        // Save to Firebase Realtime Database
        final userData = {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'bio': _bioController.text.trim(),
          'gender': _selectedGender,
          'profileImageUrl': _profileImageUrl,
          // Do not overwrite role/isAdmin here; only user-editable fields
          'updatedAt': ServerValue.timestamp,
        };

        // If this is a new user, add createdAt timestamp
        if (_isNewUser) {
          userData['createdAt'] = ServerValue.timestamp;
        }

        await FirebaseDatabase.instance.ref().child('users/${user.uid}').update(userData);

        // Update Firebase Auth display name - wrap in try-catch to handle type casting errors
        try {
          await user.updateDisplayName(
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}');
          debugPrint('Display name updated successfully');
        } catch (displayNameError) {
          debugPrint('Display name update error (ignoring): $displayNameError');
          // Ignore display name update errors, they don't affect the core functionality
        }

        debugPrint('User data saved to Firebase successfully');
      }

      // Save to SharedPreferences for local access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('first_name', _firstNameController.text.trim());
      await prefs.setString('last_name', _lastNameController.text.trim());
      await prefs.setString('gender', _selectedGender);
      await prefs.setString('bio', _bioController.text.trim());
      await prefs.setBool('has_completed_profile', true);

      setState(() {
        _isNewUser = false;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _updateProfileImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Profile Picture',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(
                  context,
                  Icons.camera_alt,
                  'Camera',
                  () async {
                    Navigator.pop(context);
                    await _pickImage(ImageSource.camera);
                  },
                ),
                _buildImageOption(
                  context,
                  Icons.photo_library,
                  'Gallery',
                  () async {
                    Navigator.pop(context);
                    await _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Or choose from predefined avatars:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _predefinedAvatars.length,
              itemBuilder: (context, index) {
                final avatarPath = _predefinedAvatars[index];
                final isSelected = _profileImageUrl == avatarPath;

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _selectPredefinedAvatar(avatarPath);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundImage: AssetImage(avatarPath),
                      radius: 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isSaving = true;
        });

        try {
          // For now, we'll just save the local path
          // In a real implementation, you'd upload to Firebase Storage
          final String imagePath = image.path;

          setState(() {
            _profileImageUrl = imagePath;
          });

          // Save to Firebase
          await FirebaseDatabase.instance
              .ref()
              .child('users/${_authService.currentUser!.uid}')
              .update({
            'profileImageUrl': imagePath,
            'updatedAt': ServerValue.timestamp,
          });

          // Save to local storage
          await _profileImageService.saveProfileImage(imagePath, isCustom: true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile image updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error saving image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving image: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          setState(() {
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _selectPredefinedAvatar(String avatarPath) async {
    setState(() {
      _profileImageUrl = avatarPath;
    });

    // Save to Firebase
    try {
      await FirebaseDatabase.instance.ref().child('users/${_authService.currentUser!.uid}').update({
        'profileImageUrl': avatarPath,
        'updatedAt': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving predefined avatar: $e');
    }
  }

  Widget _buildProfileImage() {
    if (_profileImageUrl != null) {
      if (_profileImageUrl!.startsWith('http')) {
        return Image.network(
          _profileImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person,
              size: 50,
              color: Colors.white.withOpacity(0.8),
            );
          },
        );
      } else {
        return Image.asset(
          _profileImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person,
              size: 50,
              color: Colors.white.withOpacity(0.8),
            );
          },
        );
      }
    }
    return Icon(
      Icons.person,
      size: 50,
      color: Colors.white.withOpacity(0.8),
    );
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    // If user confirmed logout
    if (shouldLogout == true) {
      try {
        await AuthService().signOut();
        // Navigate to auth screen and remove all previous routes
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Loading profile...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(context),
                  const SizedBox(height: 24),
                  if (_isEditing || _isNewUser) _buildUserForm(context),
                  if (!_isEditing && !_isNewUser) _buildUserInfoDisplay(context),
                  const SizedBox(height: 24),
                  _buildSettingsSection(context, isDarkMode, themeProvider),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Saving changes...'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  children: [
                    // Top row with title and edit button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Teacher Profile',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Professional teaching dashboard',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                            ),
                          ],
                        ),
                        if (!_isEditing && !_isNewUser)
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit_outlined),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Profile info section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Profile image and basic info
                          Row(
                            children: [
                              // Enhanced profile image
                              GestureDetector(
                                onTap: _updateProfileImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context).shadowColor.withOpacity(0.1),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 45,
                                        backgroundColor:
                                            Theme.of(context).colorScheme.surfaceVariant,
                                        child: ClipOval(
                                          child: SizedBox(
                                            width: 90,
                                            height: 90,
                                            child: _buildProfileImage(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.surface,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).shadowColor.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Profile details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_firstNameController.text} ${_lastNameController.text}'
                                              .trim()
                                              .isEmpty
                                          ? 'Teacher Profile'
                                          : '${_firstNameController.text} ${_lastNameController.text}'
                                              .trim(),
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _emailController.text.isEmpty
                                          ? 'No email'
                                          : _emailController.text,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                            fontSize: 15,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Professional teacher badge
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.school,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'TEACHER',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Professional teacher stats
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildEnhancedStat('Classes', '$_totalClasses', Icons.class_,
                                    Theme.of(context).colorScheme.primary),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                                _buildEnhancedStat('Students', '$_totalStudents', Icons.people,
                                    Theme.of(context).colorScheme.secondary),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                                _buildEnhancedStat('Experience', '3+ Years', Icons.work_history,
                                    Theme.of(context).colorScheme.tertiary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isEditing || _isNewUser) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).shadowColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _saveUserData,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.save, size: 20),
                                label: Text(
                                  _isSaving ? 'Saving...' : 'Save Changes',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _isEditing = false);
                                _loadUserData(); // Reset to original values
                              },
                              icon: const Icon(Icons.cancel, size: 20),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                side: BorderSide(color: Colors.grey[300]!, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            // Name Fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Email Field
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Gender Dropdown
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            // Bio Field
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio (Optional)',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                hintText: 'Tell us about yourself...',
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoDisplay(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          // Info Cards
          _buildInfoCard(
            context,
            'Personal Details',
            [
              _buildInfoRow(
                  'Name', '${_firstNameController.text} ${_lastNameController.text}'.trim()),
              _buildInfoRow('Email', _emailController.text),
              _buildInfoRow('Gender', _selectedGender),
              if (_bioController.text.isNotEmpty) _buildInfoRow('Bio', _bioController.text),
            ],
            Icons.person,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            'Account Information',
            [
              _buildInfoRow('Role', _userRole?.toUpperCase() ?? 'TEACHER'),
              _buildInfoRow(
                  'Account Created',
                  _createdAt != null
                      ? '${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year}'
                      : 'Unknown'),
              _buildInfoRow(
                  'Last Login',
                  _lastLoginAt != null
                      ? '${_lastLoginAt!.day}/${_lastLoginAt!.month}/${_lastLoginAt!.year}'
                      : 'Unknown'),
            ],
            Icons.admin_panel_settings,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    List<Widget> children,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not set' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isDarkMode, ThemeProvider themeProvider) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.settings,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teaching Dashboard',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your teaching tools and preferences',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Teaching Tools Section
                  _buildEnhancedTeacherSection(
                    context,
                    'Teaching Tools',
                    Icons.school,
                    const Color(0xFF2E7D32),
                    [
                      _buildEnhancedSettingsTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.class_,
                            color: Color(0xFF2E7D32),
                            size: 26,
                          ),
                        ),
                        title: 'Class Management',
                        subtitle: const Text('Manage your classes and students'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Color(0xFF2E7D32)),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pushReplacementNamed('/admin', arguments: 2);
                        },
                        delay: 0.0,
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _buildEnhancedSettingsTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.quiz,
                            color: Color(0xFF2E7D32),
                            size: 26,
                          ),
                        ),
                        title: 'Quiz Management',
                        subtitle: const Text('Create and manage quizzes'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Color(0xFF2E7D32)),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pushReplacementNamed('/admin', arguments: 1);
                        },
                        delay: 0.1,
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _buildEnhancedSettingsTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.analytics,
                            color: Color(0xFF2E7D32),
                            size: 26,
                          ),
                        ),
                        title: 'Student Analytics',
                        subtitle: const Text('View student progress and performance'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Color(0xFF2E7D32)),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pushReplacementNamed('/admin', arguments: 3);
                        },
                        delay: 0.2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // App Settings Section
                  _buildEnhancedTeacherSection(
                    context,
                    'App Settings',
                    Icons.tune,
                    Colors.blue,
                    [
                      _buildEnhancedSettingsTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: Colors.blue,
                            size: 26,
                          ),
                        ),
                        title: 'Theme Preference',
                        subtitle: Text(isDarkMode ? 'Dark Mode Active' : 'Light Mode Active'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Switch(
                            value: isDarkMode,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              themeProvider.setAppTheme(
                                value ? AppThemeMode.dark : AppThemeMode.light,
                              );
                            },
                            activeColor: Colors.blue,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          themeProvider.setAppTheme(
                            isDarkMode ? AppThemeMode.light : AppThemeMode.dark,
                          );
                        },
                        delay: 0.0,
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _buildEnhancedSettingsTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.info,
                            color: Colors.blue,
                            size: 26,
                          ),
                        ),
                        title: 'About MyGana Educator',
                        subtitle: const Text('Version 1.0.0 • Professional Edition'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.school,
                                      color: Color(0xFF2E7D32),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'MyGana Educator',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'A comprehensive Japanese learning platform designed specifically for educators and teachers.',
                                    style: TextStyle(fontSize: 16, height: 1.4),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32).withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildInfoRow('Version', '1.0.0'),
                                        _buildInfoRow('Edition', 'Educator Professional'),
                                        _buildInfoRow(
                                            'Role', _userRole?.toUpperCase() ?? 'TEACHER'),
                                        _buildInfoRow(
                                            'Account Created',
                                            _createdAt != null
                                                ? '${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year}'
                                                : 'Unknown'),
                                        _buildInfoRow(
                                            'Last Login',
                                            _lastLoginAt != null
                                                ? '${_lastLoginAt!.day}/${_lastLoginAt!.month}/${_lastLoginAt!.year}'
                                                : 'Unknown'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2E7D32),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        delay: 0.1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Account Section
                  _buildEnhancedTeacherSection(
                    context,
                    'Account Management',
                    Icons.account_circle,
                    Colors.red,
                    [
                      _buildEnhancedSettingsTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Colors.red,
                            size: 26,
                          ),
                        ),
                        title: 'Sign Out',
                        subtitle: const Text('Sign out of your educator account'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                        ),
                        onTap: _logout,
                        delay: 0.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedTeacherSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Essential tools for effective teaching',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEnhancedSettingsTile({
    required Widget leading,
    required String title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required double delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: (800 + (delay * 200)).round()),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: leading,
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                subtitle: subtitle,
                trailing: trailing,
                onTap: onTap,
              ),
            ),
          ),
        );
      },
    );
  }
}
