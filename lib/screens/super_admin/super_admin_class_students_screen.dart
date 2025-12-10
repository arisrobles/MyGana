import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/services/class_management_service.dart';

class SuperAdminClassStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String? yearRange;
  final String? classCode;

  const SuperAdminClassStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
    this.yearRange,
    this.classCode,
  });

  @override
  State<SuperAdminClassStudentsScreen> createState() => _SuperAdminClassStudentsScreenState();
}

class _SuperAdminClassStudentsScreenState extends State<SuperAdminClassStudentsScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final ClassManagementService _classService = ClassManagementService();

  bool _loading = true;
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _classInfo;
  Map<String, dynamic>? _capacityInfo;

  @override
  void initState() {
    super.initState();
    _loadClassStudents();
  }

  Future<void> _loadClassStudents() async {
    setState(() => _loading = true);

    try {
      // Load class information
      final classSnapshot = await _db.child('classes/${widget.classId}').get();
      if (classSnapshot.exists) {
        _classInfo = Map<String, dynamic>.from(classSnapshot.value as Map);
      }

      // Load capacity information
      _capacityInfo = await _classService.getClassCapacityInfo(widget.classId);

      // Load class members
      final membersSnapshot = await _db.child('classMembers/${widget.classId}').get();
      if (membersSnapshot.exists) {
        final members = Map<String, dynamic>.from(membersSnapshot.value as Map);
        _students = [];

        for (final entry in members.entries) {
          final studentId = entry.key;
          final enrollmentData = Map<String, dynamic>.from(entry.value);

          // Load student profile data
          final studentSnapshot = await _db.child('users/$studentId').get();
          if (studentSnapshot.exists) {
            final studentData = Map<String, dynamic>.from(studentSnapshot.value as Map);

            _students.add({
              'studentId': studentId,
              'firstName': studentData['firstName'] ?? '',
              'lastName': studentData['lastName'] ?? '',
              'email': studentData['email'] ?? '',
              'profileImageUrl': studentData['profileImageUrl'],
              'enrolledAt': enrollmentData['enrolledAt'],
              'totalXp': studentData['totalXp'] ?? 0,
              'mojiCoins': studentData['mojiCoins'] ?? 0,
              'level': studentData['level'] ?? 1,
            });
          }
        }

        // Sort students by XP (highest first)
        _students.sort((a, b) => (b['totalXp'] as int).compareTo(a['totalXp'] as int));
      }
    } catch (e) {
      debugPrint('Error loading class students: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _getDisplayName(Map<String, dynamic> student) {
    final firstName = student['firstName'] ?? '';
    final lastName = student['lastName'] ?? '';

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    } else {
      return 'Student';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Class Info Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.className,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.yearRange != null || widget.classCode != null)
                        Text(
                          '${widget.yearRange ?? ''}${widget.yearRange != null && widget.classCode != null ? ' • ' : ''}${widget.classCode != null ? 'Code: ${widget.classCode}' : ''}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '${_students.length} Students Enrolled',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                        ),
                      ),
                      if (_capacityInfo != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Capacity: ${_capacityInfo!['currentCount']}/${_capacityInfo!['maxCount']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 60,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    (_capacityInfo!['capacityPercentage'] / 100).clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _capacityInfo!['isFull']
                                        ? Colors.red
                                        : _capacityInfo!['capacityPercentage'] > 80
                                            ? Colors.orange
                                            : Colors.green,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_capacityInfo!['isFull'])
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 12,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Class is full',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                // Students List
                Expanded(
                  child: _students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No students enrolled',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            return _buildStudentCard(student, index + 1);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            backgroundImage: student['profileImageUrl'] != null
                ? NetworkImage(student['profileImageUrl'])
                : null,
            child: student['profileImageUrl'] == null
                ? Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayName(student),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  student['email'] ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${student['totalXp']} XP',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.monetization_on,
                      size: 14,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${student['mojiCoins']}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Level and Navigation Arrow
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Level ${student['level']}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(student['enrolledAt']),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}
