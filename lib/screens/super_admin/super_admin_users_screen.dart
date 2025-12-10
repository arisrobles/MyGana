import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/super_admin/super_admin_user_detail_screen.dart';
import 'package:nihongo_japanese_app/services/admin_user_management_service.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';

class SuperAdminUsersScreen extends StatefulWidget {
  const SuperAdminUsersScreen({super.key});

  @override
  State<SuperAdminUsersScreen> createState() => _SuperAdminUsersScreenState();
}

class _SuperAdminUsersScreenState extends State<SuperAdminUsersScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final AuthService _auth = AuthService();
  bool _loading = true;
  List<_UserItem> _users = [];
  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  final TextEditingController _regFirstNameController = TextEditingController();
  final TextEditingController _regLastNameController = TextEditingController();
  String _regGender = 'Prefer not to say';
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedFilter = 'all'; // all, teachers, students, super_admins
  String _sortBy = 'role'; // role, name, email, created

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await _db.child('users').get();
      final List<_UserItem> items = [];
      if (snap.exists && snap.value is Map) {
        final map = Map<dynamic, dynamic>.from(snap.value as Map);
        map.forEach((key, value) {
          final data = Map<dynamic, dynamic>.from(value);
          items.add(_UserItem(
            uid: key.toString(),
            email: data['email']?.toString() ?? '',
            name: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            role: data['role']?.toString() ?? ((data['isAdmin'] == true) ? 'teacher' : 'student'),
          ));
        });
      }
      items.sort((a, b) => a.role.compareTo(b.role));
      if (mounted)
        setState(() {
          _users = items;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Invite flow removed in favor of direct registration

  Future<void> _registerTeacherAccount() async {
    // Debug: Check super admin permissions before attempting to create teacher
    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('Super admin must be logged in to create teachers');
      }

      final role = await authService.getUserRole();
      debugPrint('Super admin role: $role');
      debugPrint('Super admin UID: ${currentUser.uid}');
      debugPrint('Super admin email: ${currentUser.email}');

      if (role != 'super_admin') {
        throw Exception('Current user is not a super admin. Role: $role');
      }
    } catch (e) {
      debugPrint('Permission check failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
      return;
    }

    final formKey = GlobalKey<FormState>();
    _regEmailController.clear();
    _regPasswordController.clear();
    _regFirstNameController.clear();
    _regLastNameController.clear();
    _regGender = 'Prefer not to say';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Register Teacher',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _regEmailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _regPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _regFirstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name (optional)',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _regLastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name (optional)',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _regGender,
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary')),
                      DropdownMenuItem(
                          value: 'Prefer not to say', child: Text('Prefer not to say')),
                    ],
                    onChanged: (v) => _regGender = v ?? 'Prefer not to say',
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.people_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Register', style: TextStyle(fontSize: 16)),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
    );
    if (saved != true) return;
    try {
      await AdminUserManagementService().createTeacherAccount(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
        firstName: _regFirstNameController.text.trim().isEmpty
            ? null
            : _regFirstNameController.text.trim(),
        lastName:
            _regLastNameController.text.trim().isEmpty ? null : _regLastNameController.text.trim(),
        gender: _regGender,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teacher account created'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateRole(_UserItem user, String newRole) async {
    try {
      await _db.child('users/${user.uid}').update({
        'role': newRole,
        'isAdmin': (newRole == 'teacher' || newRole == 'super_admin'),
        'updatedAt': ServerValue.timestamp,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role updated successfully')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update role: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _deleteUser(_UserItem user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${user.name.isEmpty ? user.email : user.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.child('users/${user.uid}').remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _navigateToUserDetail(_UserItem user) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SuperAdminUserDetailScreen(
          userId: user.uid,
          userEmail: user.email,
          userName: user.name,
          userRole: user.role,
        ),
      ),
    );

    // Refresh the list if user was updated or deleted
    if (result == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calculate statistics
    final totalUsers = _users.length;
    final teachers = _users.where((u) => u.role == 'teacher').length;
    final students = _users.where((u) => u.role == 'student').length;
    final superAdmins = _users.where((u) => u.role == 'super_admin').length;

    // Filter and sort users
    List<_UserItem> filteredUsers = _users.where((u) {
      // Apply role filter
      if (_selectedFilter != 'all' && u.role != _selectedFilter) return false;

      // Apply search filter
      if (_query.isNotEmpty) {
        return u.email.toLowerCase().contains(_query) || u.name.toLowerCase().contains(_query);
      }
      return true;
    }).toList();

    // Sort users
    filteredUsers.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.name.compareTo(b.name);
        case 'email':
          return a.email.compareTo(b.email);
        case 'role':
          return a.role.compareTo(b.role);
        default:
          return a.role.compareTo(b.role);
      }
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // Header with gradient and search
          Container(
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
              boxShadow: [
                BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
              ],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Users',
                    style:
                        TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Manage teachers and students',
                    style: TextStyle(color: Colors.white.withOpacity(0.9))),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name or email...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statistics Cards
          _buildStatisticsCards(totalUsers, teachers, students, superAdmins),
          const SizedBox(height: 16),

          // Register teacher card
          _buildRegisterTeacherCard(),
          const SizedBox(height: 16),

          // Filter and Sort Controls
          _buildFilterAndSortControls(),
          const SizedBox(height: 16),

          // Users List
          _buildUsersList(filteredUsers),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(int totalUsers, int teachers, int students, int superAdmins) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Users',
              totalUsers.toString(),
              Icons.people,
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Teachers',
              teachers.toString(),
              Icons.workspaces_outline,
              Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Students',
              students.toString(),
              Icons.school_outlined,
              Theme.of(context).colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Super Admins',
              superAdmins.toString(),
              Icons.admin_panel_settings,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTeacherCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6))
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Register Teacher', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Create a new teacher account (email & password)'),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _registerTeacherAccount,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Register'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Filter & Sort',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: InputDecoration(
                    labelText: 'Filter by Role',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                    DropdownMenuItem(value: 'student', child: Text('Students')),
                    DropdownMenuItem(value: 'super_admin', child: Text('Super Admins')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'role', child: Text('Role')),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'email', child: Text('Email')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value ?? 'role';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<_UserItem> users) {
    if (users.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter criteria',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Group users by role for better organization
    final Map<String, List<_UserItem>> groupedUsers = {};
    for (final user in users) {
      groupedUsers.putIfAbsent(user.role, () => []).add(user);
    }

    return Column(
      children: [
        // Show results count
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'Showing ${users.length} user${users.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Display users grouped by role
        ...groupedUsers.entries.map((entry) {
          final role = entry.key;
          final roleUsers = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role header
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getRoleColor(role).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getRoleIcon(role),
                      size: 18,
                      color: _getRoleColor(role),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_getRoleDisplayName(role)} (${roleUsers.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _getRoleColor(role),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Users in this role
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: roleUsers.map((u) => _buildUserTile(u)).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Theme.of(context).colorScheme.primary;
      case 'teacher':
        return Theme.of(context).colorScheme.secondary;
      case 'student':
        return Theme.of(context).colorScheme.tertiary;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'super_admin':
        return Icons.admin_panel_settings;
      case 'teacher':
        return Icons.workspaces_outline;
      case 'student':
        return Icons.school_outlined;
      default:
        return Icons.person;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admins';
      case 'teacher':
        return 'Teachers';
      case 'student':
        return 'Students';
      default:
        return 'Users';
    }
  }

  Widget _buildUserTile(_UserItem u, {bool? isSelfOverride}) {
    final isSelf = isSelfOverride ?? (_auth.currentUser?.uid == u.uid);
    final roleColor = u.role == 'super_admin'
        ? Theme.of(context).colorScheme.primary
        : u.role == 'teacher'
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.tertiary;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: u.role == 'student' ? null : () => _navigateToUserDetail(u),
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.12),
          child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
              style: TextStyle(color: roleColor, fontWeight: FontWeight.w700)),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(u.name.isEmpty ? u.email : u.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            _RoleBadge(role: u.role),
          ],
        ),
        subtitle: Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (role) => _updateRole(u, role),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'student', child: Text('Make Student')),
                PopupMenuItem(value: 'teacher', child: Text('Make Teacher')),
                PopupMenuItem(value: 'super_admin', child: Text('Make Super Admin')),
              ],
              child: const Icon(Icons.more_vert),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              onPressed: isSelf ? null : () => _deleteUser(u),
              tooltip: isSelf ? 'Cannot delete current account' : 'Delete user',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inviteEmailController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regFirstNameController.dispose();
    _regLastNameController.dispose();
    super.dispose();
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});
  @override
  Widget build(BuildContext context) {
    Color color = role == 'super_admin'
        ? Theme.of(context).colorScheme.primary
        : role == 'teacher'
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.tertiary;
    String label = role == 'super_admin'
        ? 'Super Admin'
        : role == 'teacher'
            ? 'Teacher'
            : 'Student';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _UserItem {
  final String uid;
  final String email;
  final String name;
  final String role;
  _UserItem({required this.uid, required this.email, required this.name, required this.role});
}
