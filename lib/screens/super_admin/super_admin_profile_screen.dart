import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/profile_image_service.dart';

class SuperAdminProfileScreen extends StatefulWidget {
  const SuperAdminProfileScreen({super.key});

  @override
  State<SuperAdminProfileScreen> createState() => _SuperAdminProfileScreenState();
}

class _SuperAdminProfileScreenState extends State<SuperAdminProfileScreen> {
  final AuthService _authService = AuthService();
  final ProfileImageService _profileImageService = ProfileImageService();
  String? _profileImageUrl;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _gender = 'Prefer not to say';
  String _displayName = '';
  int _totalUsers = 0;
  int _totalTeachers = 0;
  int _totalStudents = 0;
  int _totalLessons = 0;
  int _totalQuizzes = 0;
  int _totalClasses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadStats();
  }

  Future<void> _loadProfileData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final snapshot =
            await FirebaseDatabase.instance.ref().child('users/${currentUser.uid}').get();
        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _firstName = userData['firstName']?.toString() ?? '';
            _lastName = userData['lastName']?.toString() ?? '';
            _email = userData['email']?.toString() ?? currentUser.email ?? '';
            _gender = userData['gender']?.toString() ?? 'Prefer not to say';
            _displayName = '$_firstName $_lastName'.trim();
            if (_displayName.isEmpty) {
              _displayName = _email;
            }
          });
        }

        // Load profile image
        final imageUrl = await _profileImageService.getProfileImage();
        if (mounted) {
          setState(() {
            _profileImageUrl = imageUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    }
  }

  // Count only teachers (exclude super_admin from count)
  Future<int> _countTeachers() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      int teacherCount = 0;

      // Get all users
      final usersSnapshot = await db.child('users').get();
      if (usersSnapshot.exists) {
        final users = usersSnapshot.value as Map<dynamic, dynamic>;

        for (final userData in users.values) {
          if (userData is Map) {
            // Only count users with role 'teacher' (exclude super_admin)
            final role = userData['role']?.toString();
            if (role == 'teacher') {
              teacherCount++;
              continue;
            }

            // Fallback to legacy isAdmin flag but only if role is not super_admin
            if (role != 'super_admin') {
              final isAdmin = userData['isAdmin'];
              if (isAdmin == true) {
                teacherCount++;
              }
            }
          }
        }
      }

      debugPrint('Total teachers counted: $teacherCount');
      return teacherCount;
    } catch (e) {
      debugPrint('Error counting teachers: $e');
      return 0;
    }
  }

  // Count students who are actually enrolled in classes
  Future<int> _countEnrolledStudents() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      final Set<String> enrolledStudentIds = <String>{};

      // Get all classes
      final classesSnapshot = await db.child('classes').get();
      if (classesSnapshot.exists) {
        final classes = classesSnapshot.value as Map<dynamic, dynamic>;

        // For each class, count enrolled students
        for (final classId in classes.keys) {
          final classMembersSnapshot = await db.child('classMembers').child(classId).get();
          if (classMembersSnapshot.exists) {
            final members = classMembersSnapshot.value as Map<dynamic, dynamic>;
            enrolledStudentIds.addAll(members.keys.cast<String>());
          }
        }
      }

      return enrolledStudentIds.length;
    } catch (e) {
      debugPrint('Error counting enrolled students: $e');
      return 0;
    }
  }

  Future<void> _loadStats() async {
    try {
      final db = FirebaseDatabase.instance.ref();

      // Load user counts with proper filtering
      final usersSnapshot = await db.child('users').get();
      if (usersSnapshot.exists) {
        final users = usersSnapshot.value as Map<dynamic, dynamic>;

        // Filter out any null or invalid entries
        final validUsers = users.values
            .where((user) => user != null && user is Map && user.containsKey('role'))
            .toList();

        _totalUsers = validUsers.length;
        // Count only teachers (exclude super_admin from count)
        _totalTeachers = await _countTeachers();
        // Count students who are actually enrolled in classes (more accurate)
        _totalStudents = await _countEnrolledStudents();
      }

      // Load content counts with proper filtering
      final lessonsSnapshot = await db.child('lessons').get();
      if (lessonsSnapshot.exists) {
        final lessons = lessonsSnapshot.value as Map<dynamic, dynamic>;
        // Filter out any null entries or system entries
        _totalLessons = lessons.values.where((lesson) => lesson != null && lesson is Map).length;
      }

      // Load quizzes from admin_quizzes (teacher-created quizzes)
      final quizzesSnapshot = await db.child('admin_quizzes').get();
      if (quizzesSnapshot.exists) {
        final quizzes = quizzesSnapshot.value as Map<dynamic, dynamic>;
        // Filter out placeholder and null entries
        _totalQuizzes = quizzes.values
            .where((quiz) =>
                quiz != null &&
                quiz is Map &&
                quiz.containsKey('title') &&
                quiz['title'] != '_placeholder')
            .length;
      }

      // Load classes count
      final classesSnapshot = await db.child('classes').get();
      if (classesSnapshot.exists) {
        final classes = classesSnapshot.value as Map<dynamic, dynamic>;
        // Filter out any null entries
        _totalClasses =
            classes.values.where((classData) => classData != null && classData is Map).length;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading super admin profile stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildStatsSection(),
                const SizedBox(height: 24),
                _buildSettingsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = _authService.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Super Admin';
    final email = user?.email ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                ),
                child: ClipOval(
                  child: _buildProfileImage(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Super Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
      ),
      child: const Icon(
        Icons.admin_panel_settings,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              'Total Users',
              _isLoading ? '...' : '$_totalUsers',
              Icons.people,
              Theme.of(context).colorScheme.primary,
            ),
            _buildStatCard(
              'Teachers',
              _isLoading ? '...' : '$_totalTeachers',
              Icons.school,
              Theme.of(context).colorScheme.secondary,
            ),
            _buildStatCard(
              'Students',
              _isLoading ? '...' : '$_totalStudents',
              Icons.person,
              Theme.of(context).colorScheme.tertiary,
            ),
            _buildStatCard(
              'Classes',
              _isLoading ? '...' : '$_totalClasses',
              Icons.class_,
              Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                    width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildSettingsCard(
          'Account',
          Icons.person,
          [
            _buildSettingsTile(
              'Profile Settings',
              'Update your profile',
              Icons.edit,
              () {
                _showProfileEditDialog();
              },
            ),
            _buildSettingsTile(
              'Change Password',
              'Update your password',
              Icons.lock,
              () {
                _showChangePasswordDialog();
              },
            ),
            _buildSettingsTile(
              'Logout',
              'Sign out of your account',
              Icons.logout,
              () {
                _showLogoutDialog();
              },
              isDestructive: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
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

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Theme.of(context).colorScheme.error.withOpacity(0.1)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      ),
      onTap: onTap,
    );
  }

  void _showProfileEditDialog() {
    final firstNameController = TextEditingController(text: _firstName);
    final lastNameController = TextEditingController(text: _lastName);
    final emailController = TextEditingController(text: _email);
    String selectedGender = _gender;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  enabled: false, // Email cannot be changed
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.people_outline),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary')),
                    DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedGender = value ?? 'Prefer not to say';
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateProfile(
                  firstNameController.text.trim(),
                  lastNameController.text.trim(),
                  selectedGender,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile(String firstName, String lastName, String gender) async {
    try {
      final db = FirebaseDatabase.instance.ref();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) return;

      await db.child('users/${currentUser.uid}').update({
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'lastUpdated': ServerValue.timestamp,
      });

      setState(() {
        _firstName = firstName;
        _lastName = lastName;
        _gender = gender;
        _displayName = '$firstName $lastName'.trim();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() {
                          isLoading = true;
                        });

                        try {
                          await _changePassword(
                            currentPasswordController.text,
                            newPasswordController.text,
                          );

                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to change password: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setDialogState(() {
                              isLoading = false;
                            });
                          }
                        }
                      }
                    },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(String currentPassword, String newPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_profileImageUrl == null) {
      return _buildDefaultAvatar();
    }

    // Check if it's an asset path
    if (_profileImageUrl!.startsWith('assets/')) {
      return Image.asset(
        _profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    }

    // Otherwise treat as network URL
    return Image.network(
      _profileImageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
    );
  }
}
