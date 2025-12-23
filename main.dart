import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/user_dashboard.dart';
import 'pages/admin_dashboard.dart';
import 'pages/campus_dashboard.dart'; // 👈 IMPORT CAMPUS DASHBOARD

/// Notifier untuk me-refresh router saat status auth berubah.
class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable(Stream<User?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ========================= FIX (WEB MULTI TAB LOGIN) =========================
  // Default FirebaseAuth (WEB) = LOCAL persistence (shared di semua tab).
  // SESSION persistence = per-tab, jadi tab admin/petugas/campus bisa login beda akun
  // tanpa saling “mengubah” tab lain.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }
  // ============================================================================

  final authListenable =
      AuthStateListenable(FirebaseAuth.instance.authStateChanges());

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/user',
        name: 'user',
        builder: (context, state) => const UserDashboard(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/campus', // 👈 ROUTE BARU
        name: 'campus',
        builder: (context, state) => const CampusDashboard(),
      ),

      // (opsional) placeholder supir
      GoRoute(
        path: '/supir',
        name: 'supir',
        builder: (context, state) => const SupirDashboard(),
      ),
    ],
    refreshListenable: authListenable,
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final loc = state.matchedLocation;

      // halaman yang butuh login
      final protected = const {
        '/home',
        '/admin',
        '/supir',
        '/user',
        '/campus',
      }.contains(loc);

      if (!loggedIn && protected) return '/login';

      // role diarahkan di LoginPage setelah login
      return null;
    },
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('404: ${state.uri}'))),
  );

  runApp(TrashWashApp(router: router));
}

class TrashWashApp extends StatelessWidget {
  final GoRouter router;
  const TrashWashApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TrashWash',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(useMaterial3: true),
    );
  }
}

// (opsional) placeholder SUPIR
class SupirDashboard extends StatelessWidget {
  const SupirDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Supir Dashboard (placeholder)')),
    );
  }
}
