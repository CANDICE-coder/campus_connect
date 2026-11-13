import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'feed_screen.dart';
import 'create_post_screen.dart';
import 'edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final profile = snap.data?.data();
        if (profile == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(_index == 0 ? 'Your feed' : 'Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: _index == 0
              ? FeedScreen(profile: profile)
              : ProfileTab(profile: profile),
          floatingActionButton: _index == 0
              ? FloatingActionButton.extended(
            icon: const Icon(Icons.edit),
            label: const Text('Post'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CreatePostScreen(profile: profile)),
            ),
          )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dynamic_feed), label: 'Feed'),
              NavigationDestination(
                  icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final isOfficial = profile['role'] == 'official';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Flexible(
              child: Text('Hi, ${profile['name']}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            if (isOfficial) ...[
              const SizedBox(width: 8),
              Icon(Icons.verified,
                  color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text('${profile['course']} · Year ${profile['year']}'),
        const SizedBox(height: 16),
        Text('Units: ${(profile['units'] as List).join(', ')}'),
        const SizedBox(height: 8),
        Text('Interests: ${(profile['interests'] as List).join(', ')}'),
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.edit),
          label: const Text('Edit profile'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EditProfileScreen(profile: profile)),
          ),
        ),
      ],
    );
  }
}