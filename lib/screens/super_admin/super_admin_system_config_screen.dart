import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class SuperAdminSystemConfigScreen extends StatefulWidget {
  const SuperAdminSystemConfigScreen({super.key});

  @override
  State<SuperAdminSystemConfigScreen> createState() => _SuperAdminSystemConfigScreenState();
}

class _SuperAdminSystemConfigScreenState extends State<SuperAdminSystemConfigScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  bool _maintenanceMode = false;
  bool _registrationEnabled = true;
  bool _guestModeEnabled = true;
  String _appVersion = '1.0.0';
  String _systemAnnouncement = '';
  int _maxUsersPerClass = 30;
  int _sessionTimeoutMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadSystemConfig();
  }

  Future<void> _loadSystemConfig() async {
    try {
      final snapshot = await _db.child('systemConfig').get();
      if (snapshot.exists) {
        final config = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _maintenanceMode = config['maintenanceMode'] ?? false;
          _registrationEnabled = config['registrationEnabled'] ?? true;
          _guestModeEnabled = config['guestModeEnabled'] ?? true;
          _appVersion = config['appVersion'] ?? '1.0.0';
          _systemAnnouncement = config['systemAnnouncement'] ?? '';
          _maxUsersPerClass = config['maxUsersPerClass'] ?? 30;
          _sessionTimeoutMinutes = config['sessionTimeoutMinutes'] ?? 30;
        });
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading system config: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSystemConfig() async {
    try {
      await _db.child('systemConfig').set({
        'maintenanceMode': _maintenanceMode,
        'registrationEnabled': _registrationEnabled,
        'guestModeEnabled': _guestModeEnabled,
        'appVersion': _appVersion,
        'systemAnnouncement': _systemAnnouncement,
        'maxUsersPerClass': _maxUsersPerClass,
        'sessionTimeoutMinutes': _sessionTimeoutMinutes,
        'lastUpdated': ServerValue.timestamp,
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildSystemStatusCard(),
                const SizedBox(height: 16),
                _buildAppSettingsCard(),
                const SizedBox(height: 16),
                _buildUserLimitsCard(),
                const SizedBox(height: 16),
                _buildAnnouncementCard(),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Configuration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          Text('Manage app-wide settings and system behavior',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              )),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'System Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Maintenance Mode'),
              subtitle: const Text('Disable app access for maintenance'),
              value: _maintenanceMode,
              onChanged: (value) {
                setState(() {
                  _maintenanceMode = value;
                });
              },
              secondary: Icon(
                _maintenanceMode ? Icons.build : Icons.build_circle_outlined,
                color: _maintenanceMode ? Colors.orange : Colors.grey,
              ),
            ),
            SwitchListTile(
              title: const Text('Registration Enabled'),
              subtitle: const Text('Allow new user registrations'),
              value: _registrationEnabled,
              onChanged: (value) {
                setState(() {
                  _registrationEnabled = value;
                });
              },
              secondary: Icon(
                _registrationEnabled ? Icons.person_add : Icons.person_add_disabled,
                color: _registrationEnabled ? Colors.green : Colors.grey,
              ),
            ),
            SwitchListTile(
              title: const Text('Guest Mode'),
              subtitle: const Text('Allow guest access to limited features'),
              value: _guestModeEnabled,
              onChanged: (value) {
                setState(() {
                  _guestModeEnabled = value;
                });
              },
              secondary: Icon(
                _guestModeEnabled ? Icons.person_outline : Icons.person_off,
                color: _guestModeEnabled ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.app_settings_alt, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 12),
                Text(
                  'App Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _appVersion,
              decoration: const InputDecoration(
                labelText: 'App Version',
                prefixIcon: Icon(Icons.tag),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _appVersion = value;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _sessionTimeoutMinutes.toString(),
              decoration: const InputDecoration(
                labelText: 'Session Timeout (minutes)',
                prefixIcon: Icon(Icons.timer),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _sessionTimeoutMinutes = int.tryParse(value) ?? 30;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserLimitsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 12),
                Text(
                  'User Limits',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _maxUsersPerClass.toString(),
              decoration: const InputDecoration(
                labelText: 'Max Users Per Class',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _maxUsersPerClass = int.tryParse(value) ?? 30;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.announcement, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  'System Announcement',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _systemAnnouncement,
              decoration: const InputDecoration(
                labelText: 'Announcement Message',
                prefixIcon: Icon(Icons.message),
                border: OutlineInputBorder(),
                hintText: 'Enter system-wide announcement...',
              ),
              maxLines: 3,
              onChanged: (value) {
                _systemAnnouncement = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loadSystemConfig,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveSystemConfig,
            icon: const Icon(Icons.save),
            label: const Text('Save Configuration'),
          ),
        ),
      ],
    );
  }
}
