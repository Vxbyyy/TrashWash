import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  FirebaseDatabase _db() => FirebaseDatabase.instance;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Belum login → redirect aman setelah frame
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final email = user.email ?? '';
    final uid = user.uid;
    final userRef = _db().ref('users/$uid');

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrashWash'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: Center(
        child: StreamBuilder<DatabaseEvent>(
          stream: userRef.onValue,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Error: ${snap.error}');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final raw = snap.data?.snapshot.value;
            final data = (raw is Map) ? raw : <dynamic, dynamic>{};

            final name = data['name'] ?? '(tanpa nama)';
            final phone = data['phone'] ?? '-';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Halo, $name',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('Email: $email'),
                Text('No HP: $phone'),
              ],
            );
          },
        ),
      ),
    );
  }
}
