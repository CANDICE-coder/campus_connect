import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CampusConnectApp());
}

class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final user = snapshot.data;
          if (user == null) return const AuthScreen();
          return ProfileGate(uid: user.uid);
        },
      ),
    );
  }
}

/// Sends new users to profile setup, and returning users to the home screen.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.uid});
  final String uid;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Firestore error:\n${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Loading your profile...'),
                    if (_slow) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Taking too long: the phone cannot reach Firestore.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Log out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return snap.data!.exists
            ? const HomeScreen()
            : const ProfileSetupScreen();
      },
    );
  }
}