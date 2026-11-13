import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textCtrl = TextEditingController();
  final Set<String> _tags = {};
  bool _pinned = false;
  bool _posting = false;
  String? _error;

  bool get _isOfficial => widget.profile['role'] == 'official';

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _toggle(String tag, bool selected) {
    setState(() {
      if (selected) {
        _tags.add(tag);
      } else {
        _tags.remove(tag);
      }
    });
  }

  Future<void> _post() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write something first.');
      return;
    }
    if (_tags.isEmpty) {
      setState(() => _error = 'Pick who should see this post.');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('posts').add({
        'text': text,
        'authorId': user.uid,
        'authorName': widget.profile['name'],
        'authorRole': widget.profile['role'] ?? 'student',
        'tags': _tags.toList(),
        'pinned': _isOfficial && _pinned,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Could not post. Check your connection and try again.';
        _posting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = List<String>.from(widget.profile['units'] ?? []);
    final interests = List<String>.from(widget.profile['interests'] ?? []);
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
                hintText: "What's happening?", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const Text('Who should see this?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Everyone'),
                selected: _tags.contains('ALL'),
                onSelected: (s) => _toggle('ALL', s),
              ),
              ...units.map((u) => FilterChip(
                label: Text(u),
                selected: _tags.contains(u),
                onSelected: (s) => _toggle(u, s),
              )),
              ...interests.map((i) => FilterChip(
                label: Text(i),
                selected: _tags.contains(i),
                onSelected: (s) => _toggle(i, s),
              )),
            ],
          ),
          if (_isOfficial)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pin to top of feeds'),
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _posting ? null : _post,
            child: _posting
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}