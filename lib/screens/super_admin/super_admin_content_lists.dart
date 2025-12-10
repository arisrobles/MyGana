import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SuperAdminLessonsListScreen extends StatelessWidget {
  const SuperAdminLessonsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('lessons').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final event = snapshot.data;
          if (event == null || !event.snapshot.exists) {
            return const Center(child: Text('No lessons found'));
          }
          final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          final items = map.entries.map((e) => {'id': e.key.toString(), ...Map<dynamic, dynamic>.from(e.value)}).toList();
          items.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _Header(title: 'Lessons', subtitle: 'Manage all lessons globally'),
              const SizedBox(height: 12),
              ...items.map((l) => _ContentCard(
                    leadingIcon: Icons.menu_book,
                    primaryText: l['title']?.toString() ?? '',
                    secondaryText: '${l['level'] ?? ''} • ${l['category'] ?? ''}',
                    onPreview: () => _previewLesson(context, l),
                    onRowTap: () => Navigator.pushNamed(context, '/super_admin/detail/lesson', arguments: {'lessonId': l['id']}),
                    onEdit: () => _editLesson(context, l),
                    onDelete: () => _deleteLesson(context, l),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _previewLesson(BuildContext context, Map l) async {
    int exampleCount = 0;
    try {
      final snap = await FirebaseDatabase.instance.ref().child('lessons/${l['id']}/example_sentences').get();
      if (snap.exists && snap.value is Map) exampleCount = (snap.value as Map).length;
    } catch (_) {}
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lesson Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KV('Title', l['title']?.toString() ?? ''),
            _KV('Level', l['level']?.toString() ?? ''),
            _KV('Category', l['category']?.toString() ?? ''),
            const SizedBox(height: 8),
            Text(l['description']?.toString() ?? ''),
            const SizedBox(height: 12),
            _KV('Example sentences', exampleCount.toString()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editLesson(BuildContext context, Map l) async {
    final titleController = TextEditingController(text: l['title']?.toString() ?? '');
    final descController = TextEditingController(text: l['description']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Lesson'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await FirebaseDatabase.instance.ref().child('lessons/${l['id']}').update({
            'title': titleController.text.trim(),
            'description': descController.text.trim(),
            'updatedAt': ServerValue.timestamp,
          });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson updated')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteLesson(BuildContext context, Map l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Delete "${l['title'] ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseDatabase.instance.ref().child('lessons/${l['id']}').remove();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson deleted')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }
}

class SuperAdminQuizzesListScreen extends StatelessWidget {
  const SuperAdminQuizzesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('admin_quizzes').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final event = snapshot.data;
          if (event == null || !event.snapshot.exists) {
            return const Center(child: Text('No quizzes found'));
          }
          final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          map.remove('_placeholder');
          final items = map.entries.map((e) => {'id': e.key.toString(), ...Map<dynamic, dynamic>.from(e.value)}).toList();
          items.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _Header(title: 'Quizzes', subtitle: 'Manage all quizzes globally'),
              const SizedBox(height: 12),
              ...items.map((q) => _ContentCard(
                    leadingIcon: Icons.quiz,
                    primaryText: q['title']?.toString() ?? '',
                    secondaryText: 'Active: ${q['isActive'] == true ? 'Yes' : 'No'}',
                    onRowTap: () => Navigator.pushNamed(context, '/super_admin/detail/quiz', arguments: {'quizId': q['id']}),
                    onPreview: () => _previewQuiz(context, q),
                    onEdit: () => _editQuiz(context, q),
                    onDelete: () => _deleteQuiz(context, q),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _previewQuiz(BuildContext context, Map q) async {
    int questionCount = 0;
    try {
      final snap = await FirebaseDatabase.instance.ref().child('admin_quizzes/${q['id']}/questions').get();
      if (snap.exists && snap.value is List) questionCount = (snap.value as List).length;
      if (snap.exists && snap.value is Map) questionCount = (snap.value as Map).length;
    } catch (_) {}
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KV('Title', q['title']?.toString() ?? ''),
            _KV('Active', q['isActive'] == true ? 'Yes' : 'No'),
            const SizedBox(height: 8),
            Text(q['description']?.toString() ?? ''),
            const SizedBox(height: 12),
            _KV('Questions', questionCount.toString()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editQuiz(BuildContext context, Map q) async {
    final titleController = TextEditingController(text: q['title']?.toString() ?? '');
    final descController = TextEditingController(text: q['description']?.toString() ?? '');
    bool isActive = q['isActive'] == true;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quiz'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => isActive = v,
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await FirebaseDatabase.instance.ref().child('admin_quizzes/${q['id']}').update({
            'title': titleController.text.trim(),
            'description': descController.text.trim(),
            'isActive': isActive,
            'updatedAt': DateTime.now().toIso8601String(),
          });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz updated')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteQuiz(BuildContext context, Map q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: Text('Delete "${q['title'] ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseDatabase.instance.ref().child('admin_quizzes/${q['id']}').remove();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz deleted')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }
}

class SuperAdminClassesListScreen extends StatelessWidget {
  const SuperAdminClassesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('classes').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final event = snapshot.data;
          if (event == null || !event.snapshot.exists) {
            return const Center(child: Text('No classes found'));
          }
          final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          final items = map.entries.map((e) => {'id': e.key.toString(), ...Map<dynamic, dynamic>.from(e.value)}).toList();
          items.sort((a, b) => (a['nameSection'] ?? '').toString().compareTo((b['nameSection'] ?? '').toString()));

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _Header(title: 'Classes', subtitle: 'Manage all classes globally'),
              const SizedBox(height: 12),
              ...items.map((c) => _ContentCard(
                    leadingIcon: Icons.class_,
                    primaryText: c['nameSection']?.toString() ?? '',
                    secondaryText: '${c['yearRange'] ?? ''} • Code: ${c['classCode'] ?? ''}',
                    onRowTap: () => Navigator.pushNamed(context, '/super_admin/detail/class', arguments: {'classId': c['id']}),
                    onPreview: () => _previewClass(context, c),
                    onEdit: () => _editClass(context, c),
                    onDelete: () => _deleteClass(context, c),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _previewClass(BuildContext context, Map c) async {
    int memberCount = 0;
    try {
      final snap = await FirebaseDatabase.instance.ref().child('classMembers/${c['id']}').get();
      if (snap.exists && snap.value is Map) memberCount = (snap.value as Map).length;
    } catch (_) {}
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Class Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KV('Name Section', c['nameSection']?.toString() ?? ''),
            _KV('Year Range', c['yearRange']?.toString() ?? ''),
            _KV('Class Code', c['classCode']?.toString() ?? ''),
            const SizedBox(height: 12),
            _KV('Members', memberCount.toString()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editClass(BuildContext context, Map c) async {
    final nameController = TextEditingController(text: c['nameSection']?.toString() ?? '');
    final yearController = TextEditingController(text: c['yearRange']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Class'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name Section'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: yearController,
                decoration: const InputDecoration(labelText: 'Year Range'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(context, true);
          }, child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await FirebaseDatabase.instance.ref().child('classes/${c['id']}').update({
            'nameSection': nameController.text.trim(),
            'yearRange': yearController.text.trim(),
            'updatedAt': ServerValue.timestamp,
          });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class updated')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteClass(BuildContext context, Map c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Delete "${c['nameSection'] ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final updates = <String, dynamic>{};
      updates['classes/${c['id']}'] = null;
      if ((c['classCode']?.toString().isNotEmpty ?? false)) {
        updates['classCodes/${c['classCode']}'] = null;
      }
      updates['classMembers/${c['id']}'] = null;
      await FirebaseDatabase.instance.ref().update(updates);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class deleted')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
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
          BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final IconData leadingIcon;
  final String primaryText;
  final String secondaryText;
  final VoidCallback? onRowTap;
  final VoidCallback? onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ContentCard({required this.leadingIcon, required this.primaryText, required this.secondaryText, this.onRowTap, this.onPreview, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(leadingIcon, color: Theme.of(context).primaryColor),
        ),
        title: Text(primaryText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(secondaryText, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') onEdit();
            if (val == 'delete') onDelete();
            if (val == 'preview' && onPreview != null) onPreview!();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'preview', child: Text('Preview')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: const Icon(Icons.more_vert),
        ),
        onTap: onRowTap ?? onPreview,
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}


