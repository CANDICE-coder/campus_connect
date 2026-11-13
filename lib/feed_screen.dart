import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, required this.profile});
  final Map<String, dynamic> profile;

  bool get _isOfficial => profile['role'] == 'official';

  // Tags this student receives: everyone-posts + their units + their interests.
  // Firestore allows at most 30 values in this kind of query.
  List<String> get _myTags {
    final units = List<String>.from(profile['units'] ?? []);
    final interests = List<String>.from(profile['interests'] ?? []);
    return ['ALL', ...units, ...interests].take(30).toList();
  }

  String _ago(Timestamp? t) {
    if (t == null) return 'just now';
    final d = DateTime.now().difference(t.toDate());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<void> _confirmDelete(BuildContext context,
      DocumentReference<Map<String, dynamic>> ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('tags', arrayContainsAny: _myTags)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Pinned posts first, then newest first (sorted here so no Firestore
        // index is needed).
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final pa = a.data()['pinned'] == true;
            final pb = b.data()['pinned'] == true;
            if (pa != pb) return pa ? -1 : 1;
            final ta = (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
            final tb = (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'No posts for you yet. Tap Post to share something with your units.',
                    textAlign: TextAlign.center),
              ));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final p = docs[i].data();
            final tags = List<String>.from(p['tags'] ?? []);
            final isOfficialPost = p['authorRole'] == 'official';
            final isPinned = p['pinned'] == true;
            final canDelete = p['authorId'] == myUid || _isOfficial;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPinned)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.push_pin, size: 14),
                            SizedBox(width: 4),
                            Text('Pinned', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(p['authorName'] ?? 'Student',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (isOfficialPost) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 2),
                          Text('Official',
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                  Theme.of(context).colorScheme.primary)),
                        ],
                        const Spacer(),
                        Text(_ago(p['createdAt'] as Timestamp?),
                            style: Theme.of(context).textTheme.bodySmall),
                        if (canDelete)
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'delete') {
                                _confirmDelete(context, docs[i].reference);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          )
                        else
                          const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(p['text'] ?? ''),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: tags
                          .map((t) => Chip(
                        label: Text(t == 'ALL' ? 'Everyone' : t),
                        visualDensity: VisualDensity.compact,
                      ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}