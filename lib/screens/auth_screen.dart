import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nihongo_japanese_app/screens/forgot_password_screen.dart';
import 'package:nihongo_japanese_app/screens/main_screen.dart';
import 'package:nihongo_japanese_app/screens/user_onboarding_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/system_config_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _systemConfig = SystemConfigService();
  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _registrationEnabled = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  // Class code for registration
  final TextEditingController _classCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Reduced animation duration
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _checkRegistrationStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _classCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkRegistrationStatus() async {
    try {
      final isEnabled = await _systemConfig.isRegistrationEnabled();

      if (mounted) {
        setState(() {
          _registrationEnabled = isEnabled;
          if (!isEnabled) {
            _isLoginMode = true; // Force login mode if registration is disabled
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking registration status: $e');
      if (mounted) {
        setState(() {
          _registrationEnabled = true; // Default to enabled on error
        });
      }
    }
  }

  Future<bool> _hasUserProfile(String uid) async {
    try {
      debugPrint('Checking user profile for UID: $uid');
      final snapshot = await FirebaseDatabase.instance.ref().child('users/$uid').get();
      final exists = snapshot.exists;
      debugPrint('User profile exists: $exists');
      return exists;
    } catch (e) {
      debugPrint('Error checking user profile: $e');
      return false;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid email and password.'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Submitting: isLoginMode=$_isLoginMode, email=${_emailController.text.trim()}');
      if (_isLoginMode) {
        await _authService.login(_emailController.text.trim(), _passwordController.text);
        debugPrint('Login completed, checking user state');
        if (!mounted) {
          debugPrint('Widget not mounted after login, aborting navigation');
          return;
        }

        final user = _authService.currentUser;
        if (user == null) {
          debugPrint('No user found after login');
          throw Exception('Authentication failed: No user found');
        }

        debugPrint('Resolving role for user: ${user.uid}');
        debugPrint('User email: ${user.email}');
        final role = await _authService.getUserRole();
        debugPrint('Resolved role: $role');

        // Additional debugging - check the actual profile data
        try {
          final profileSnapshot =
              await FirebaseDatabase.instance.ref().child('users/${user.uid}').get();
          if (profileSnapshot.exists) {
            final profileData = profileSnapshot.value as Map<dynamic, dynamic>;
            debugPrint('Full profile data: $profileData');
            debugPrint('Profile role field: ${profileData['role']}');
            debugPrint('Profile isAdmin field: ${profileData['isAdmin']}');
          } else {
            debugPrint('ERROR: No profile found for user ${user.uid}');
          }
        } catch (e) {
          debugPrint('Error fetching profile data: $e');
        }

        if (mounted) {
          // Check for maintenance mode (but allow super admin to bypass)
          final isMaintenanceMode = await _systemConfig.isMaintenanceMode();
          if (isMaintenanceMode) {
            final isSuperAdmin =
                role == 'super_admin' && user.email?.toLowerCase() == 'superadmin01@gmail.com';
            if (!isSuperAdmin) {
              debugPrint('Maintenance mode active, blocking non-super-admin user');
              await _authService.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'The app is currently under maintenance. Please try again later.'),
                    backgroundColor: Colors.orange.shade400,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
              return;
            }
          }

          // Check for super admin first - but only if email matches super admin email
          if (role == 'super_admin' && user.email?.toLowerCase() == 'superadmin01@gmail.com') {
            debugPrint('Navigating to super admin');
            Navigator.pushReplacementNamed(context, '/super_admin');
            return;
          }

          // If role is super_admin but email doesn't match, treat as teacher
          if (role == 'super_admin' && user.email?.toLowerCase() != 'superadmin01@gmail.com') {
            debugPrint(
                'WARNING: Role is super_admin but email doesn\'t match, treating as teacher');
            // Continue to teacher check below
          }

          // Check for teacher access with retry mechanism
          debugPrint('Checking teacher access...');
          bool isTeacher = false;
          for (int attempt = 1; attempt <= 3; attempt++) {
            try {
              isTeacher = await _authService.isTeacher();
              debugPrint('Teacher check attempt $attempt: $isTeacher');
              if (isTeacher) break;
              if (attempt < 3) {
                debugPrint('Waiting 1 second before retry...');
                await Future.delayed(const Duration(seconds: 1));
              }
            } catch (e) {
              debugPrint('Error checking teacher access on attempt $attempt: $e');
              if (attempt < 3) {
                await Future.delayed(const Duration(seconds: 1));
              }
            }
          }

          if (isTeacher) {
            debugPrint('Navigating to admin');
            Navigator.pushReplacementNamed(context, '/admin');
            return;
          }
        }

        debugPrint('Checking profile existence for user: ${user.uid}');
        final hasProfile = await _hasUserProfile(user.uid);
        debugPrint('hasProfile: $hasProfile');

        if (mounted) {
          debugPrint('Navigating to ${hasProfile ? 'MainScreen' : 'UserOnboardingScreen'}');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => hasProfile ? const MainScreen() : const UserOnboardingScreen(),
            ),
          );
        }
      } else {
        // Check if registration is enabled before proceeding
        if (!_registrationEnabled) {
          if (mounted) {
            _showRegistrationDisabledDialog();
          }
          return;
        }

        debugPrint('Attempting to sign out before registration');
        await _authService.signOut();
        debugPrint('Navigating to UserOnboardingScreen for registration');
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserOnboardingScreen(
                email: _emailController.text.trim(),
                password: _passwordController.text,
                classCode: _classCodeController.text.trim().isEmpty
                    ? null
                    : _classCodeController.text.trim(),
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _submit: $e\nStack trace: $stackTrace');
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.contains('email-already-in-use')) {
        errorMessage = 'This email is already in use. Please log in or use a different email.';
      } else if (errorMessage.contains('network-request-failed')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else if (errorMessage.contains('reCAPTCHA')) {
        errorMessage = 'reCAPTCHA verification failed. Please try again.';
      } else if (errorMessage.contains('permission-denied')) {
        errorMessage = 'Permission denied. Please contact support.';
      } else if (errorMessage.contains('wrong-password')) {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (errorMessage.contains('user-not-found')) {
        errorMessage = 'No account found with this email. Please register.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Submit completed, isLoading: $_isLoading');
    }
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _emailController.clear();
      _passwordController.clear();
    });
    HapticFeedback.lightImpact();
    debugPrint('Toggled mode to: ${_isLoginMode ? 'Login' : 'Register'}');
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
              // Switch to login mode
              setState(() {
                _isLoginMode = true;
                _emailController.clear();
                _passwordController.clear();
              });
            },
            child: Text(
              'Go to Login',
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

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    required IconData icon,
    bool obscureText = false,
    required String? Function(String?) validator,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    required double delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: hintText,
                    prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.8)),
                    suffixIcon: suffixIcon,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.8)),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade900.withOpacity(0.2),
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                  obscureText: obscureText,
                  validator: validator,
                  keyboardType: keyboardType,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (_) => _formKey.currentState?.validate(),
                ),
                if (hintText != null) const SizedBox(height: 4),
                if (hintText != null)
                  Text(
                    'e.g., $hintText',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.7), // Softer gradient
                  primaryColor.withOpacity(0.4),
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100.withOpacity(0.9), // Softer color
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '日本語',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: primaryColor.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'MyGana',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'TheLastShuriken',
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isLoginMode
                              ? 'Welcome back to your Japanese journey!'
                              : 'Start your Japanese adventure today!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900.withOpacity(0.1), // Softer background
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildAnimatedTextField(
                                  controller: _emailController,
                                  labelText: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                  delay: 0.0,
                                ),
                                const SizedBox(height: 24),
                                _buildAnimatedTextField(
                                  controller: _passwordController,
                                  labelText: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                      HapticFeedback.lightImpact();
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  delay: 0.1,
                                ),
                                const SizedBox(height: 24),
                                if (!_isLoginMode)
                                  _buildAnimatedTextField(
                                    controller: _classCodeController,
                                    labelText: 'Class Code (optional)',
                                    hintText: 'CLS-12345',
                                    icon: Icons.group_add_outlined,
                                    keyboardType: TextInputType.text,
                                    validator: (_) => null,
                                    delay: 0.15,
                                  ),
                                const SizedBox(height: 32),
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 600),
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
                                            onPressed: _isLoading
                                                ? null
                                                : () {
                                                    HapticFeedback.mediumImpact();
                                                    _submit();
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor.withOpacity(0.7),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                              shadowColor: primaryColor.withOpacity(0.1),
                                            ),
                                            child: Text(
                                              _isLoginMode ? 'Login' : 'Continue to Register',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Forgot Password Link (only show in login mode)
                                if (_isLoginMode) ...[
                                  Center(
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ForgotPasswordScreen(),
                                            settings: const RouteSettings(name: '/forgot-password'),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isLoginMode ? 'Need an account?' : 'Have an account?',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _toggleMode,
                                      child: Text(
                                        _isLoginMode ? 'Register' : 'Login',
                                        style: TextStyle(
                                          color: primaryColor.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!_registrationEnabled && !_isLoginMode)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'New registrations are currently disabled by the administrator.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.2), // Softer overlay
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor.withOpacity(0.7)),
              ),
            ),
          ),
      ],
    );
  }
}
