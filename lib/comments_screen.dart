import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen(
      {super.key, required this.postRef, required this.profile});
  final DocumentReference<Map<String, dynamic>> postRef;
  final Map<String, dynamic> profile;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  bool get _isOfficial => widget.profile['role'] == 'official';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _ago(Timestamp? t) {
    if (t == null) return 'just now';
    final d = DateTime.now().difference(t.toDate());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await widget.postRef.collection('comments').add({
        'text': text,
        'authorId': user.uid,
        'authorName': widget.profile['name'],
        'authorRole': widget.profile['role'] ?? 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.postRef.snapshots(),
              builder: (context, postSnap) {
                final post = postSnap.data?.data();
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.postRef
                      .collection('comments')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    if (!snap.hasData || post == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Card(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post['authorName'] ?? 'Student',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(post['text'] ?? ''),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            '${docs.length} comment${docs.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        if (docs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: Text('No comments yet. Be the first.')),
                          ),
                        ...docs.map((d) {
                          final c = d.data();
                          final canDelete =
                              c['authorId'] == myUid || _isOfficial;
                          final official = c['authorRole'] == 'official';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(c['authorName'] ?? 'Student',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (official) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.verified,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                ],
                                const SizedBox(width: 8),
                                Text(_ago(c['createdAt'] as Timestamp?),
                                    style:
                                    Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            subtitle: Text(c['text'] ?? ''),
                            trailing: canDelete
                                ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => d.reference.delete(),
                            )
                                : null,
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLength: 300,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}