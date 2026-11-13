import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _courseCtrl;
  final _unitCtrl = TextEditingController();
  late int _year;
  late List<String> _units;
  late Set<String> _interests;
  bool _saving = false;
  String? _error;

  static const interestOptions = [
    'Programming',
    'Mathematics',
    'Business',
    'Sports',
    'Music',
    'Art & Design',
    'Research',
    'Entrepreneurship',
    'Volunteering',
    'Gaming',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p['name'] ?? '');
    _courseCtrl = TextEditingController(text: p['course'] ?? '');
    _year = (p['year'] ?? 1) as int;
    _units = List<String>.from(p['units'] ?? []);
    _interests = Set<String>.from(p['interests'] ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _courseCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _addUnit() {
    final code =
    _unitCtrl.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (code.isNotEmpty && !_units.contains(code)) {
      setState(() => _units.add(code));
    }
    _unitCtrl.clear();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_units.isEmpty) {
      setState(() => _error = 'Add at least one unit.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      // update() changes only these fields, so the role is never overwritten.
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameCtrl.text.trim(),
        'course': _courseCtrl.text.trim(),
        'year': _year,
        'units': _units,
        'interests': _interests.toList(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Could not save. Check your connection and try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Full name', border: OutlineInputBorder()),
              validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _courseCtrl,
              decoration: const InputDecoration(
                  labelText: 'Course', border: OutlineInputBorder()),
              validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter your course' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(
                  labelText: 'Year of study', border: OutlineInputBorder()),
              items: [1, 2, 3, 4, 5, 6]
                  .map((y) =>
                  DropdownMenuItem(value: y, child: Text('Year $y')))
                  .toList(),
              onChanged: (v) => setState(() => _year = v ?? 1),
            ),
            const SizedBox(height: 24),
            const Text('Your units',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _addUnit(),
                    decoration: const InputDecoration(
                        labelText: 'Unit code (e.g. BIT2101)',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _addUnit, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _units
                  .map((u) => InputChip(
                label: Text(u),
                onDeleted: () => setState(() => _units.remove(u)),
              ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text('Your interests',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: interestOptions
                  .map((i) => FilterChip(
                label: Text(i),
                selected: _interests.contains(i),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _interests.add(i);
                  } else {
                    _interests.remove(i);
                  }
                }),
              ))
                  .toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                  TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}