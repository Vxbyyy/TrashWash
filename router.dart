// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/user_dashboard.dart';
import 'pages/admin_dashboard.dart';
import 'pages/campus_dashboard.dart';
// kalau nanti punya file supir_dashboard.dart sendiri, tinggal import:
// import 'pages/supir_dashboard.dart';

/// Router utama aplikasi
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'welcome',
      builder: (BuildContext context, GoRouterState state) =>
          const WelcomePage(),
    ),

    GoRoute(
      path: '/login',
      name: 'login',
      builder: (BuildContext context, GoRouterState state) =>
          const LoginPage(),
    ),

    GoRoute(
      path: '/register',
      name: 'register',
      builder: (BuildContext context, GoRouterState state) =>
          const RegisterPage(),
    ),

    GoRoute(
      path: '/home',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) =>
          const HomePage(),
    ),

    // ====== DASHBOARD USER PETUGAS (Trash Wash) ======
    GoRoute(
      path: '/user',
      name: 'user',
      builder: (BuildContext context, GoRouterState state) =>
          const UserDashboard(),
    ),

    // ====== DASHBOARD ADMIN ======
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (BuildContext context, GoRouterState state) =>
          const AdminDashboard(),
    ),

    // ====== DASHBOARD ORANG CAMPUS ======
    GoRoute(
      path: '/campus',
      name: 'campus',
      builder: (BuildContext context, GoRouterState state) =>
          const CampusDashboard(),
    ),

    // ====== (OPSIONAL) DASHBOARD SUPIR ======
    GoRoute(
      path: '/supir',
      name: 'supir',
      builder: (BuildContext context, GoRouterState state) =>
          const SupirDashboard(),
    ),
  ],

  // 🔒 Optional: proteksi halaman yang butuh login
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final loc = state.matchedLocation; // atau state.uri.path

    // daftar halaman yang butuh login
    const protectedPaths = {
      '/home',
      '/admin',
      '/user',
      '/campus',
      '/supir',
    };

    if (!loggedIn && protectedPaths.contains(loc)) {
      // belum login tapi mau masuk ke halaman yang dilindungi
      return '/login';
    }

    // kalau sudah login dan buka /login atau /register, bisa diarahkan ulang
    if (loggedIn && (loc == '/login' || loc == '/register')) {
      return '/home';
    }

    return null; // tidak ada redirect
  },
);

/// ====== PLACEHOLDER SUPIR (boleh dihapus kalau sudah punya halaman asli) ======
class SupirDashboard extends StatelessWidget {
  const SupirDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Supir Dashboard (placeholder)')),
    );
  }
}
