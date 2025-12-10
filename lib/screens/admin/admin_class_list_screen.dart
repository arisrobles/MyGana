import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/services/class_management_service.dart';
import 'package:nihongo_japanese_app/services/teacher_activity_service.dart';

import 'admin_class_students_screen.dart';

class AdminClassListScreen extends StatefulWidget {
  const AdminClassListScreen({super.key});

  @override
  State<AdminClassListScreen> createState() => _AdminClassListScreenState();
}

class _AdminClassListScreenState extends State<AdminClassListScreen> {
  final ClassManagementService _service = ClassManagementService();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateClassDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ClassInfo>>(
        stream: _service.watchAdminClasses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 32, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 8),
                    Text('Failed to load classes: ${snapshot.error}'),
                  ],
                ),
              ),
            );
          }
          final classes = snapshot.data ?? [];
          if (classes.isEmpty) {
            return const Center(child: Text('No classes yet. Tap + to create one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final c = classes[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.class_, color: color.primary),
                  ),
                  title: Text(c.nameSection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(c.yearRange,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.qr_code_2,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(width: 2),
                        Text(c.classCode,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminClassStudentsScreen(classId: c.classId, title: c.nameSection),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateClassDialog() async {
    final nameController = TextEditingController();
    final yearController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Class'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name Section (e.g., BSIT - A)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'Year Range (e.g., 2025 - 2026)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                if (!formKey.currentState!.validate()) return;
                try {
                  final classId = await _service.createClass(
                    nameSection: nameController.text.trim(),
                    yearRange: yearController.text.trim(),
                  );

                  // Log teacher activity
                  try {
                    await TeacherActivityService().logClassCreated(
                      classId,
                      nameController.text.trim(),
                    );
                  } catch (activityError) {
                    print('Error logging class creation activity: $activityError');
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Class created. ID: $classId')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
