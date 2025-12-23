import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

const _primaryColor = Color(0xFF143B6E);

// ✅ hanya pakai biru muda polos (tanpa biru gelap & putih)
const _loginBg = Color(0xFFBFEFF1);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _lihatSandi = false;
  bool _loading = false;

  FirebaseDatabase get _rtdb => FirebaseDatabase.instance;

  void _showSnack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  bool _isValidEmail(String s) {
    final v = s.trim();
    return v.isNotEmpty && v.contains('@') && v.contains('.');
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      final uid = cred.user!.uid;

      // ✅ Ambil data user lengkap (role + type + approved + rejected)
      final userSnap = await _rtdb.ref('users/$uid').get();
      if (!userSnap.exists || userSnap.value == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _pass.clear();
        _showSnack('Data akun belum lengkap. Hubungi admin.');
        return;
      }

      final raw = userSnap.value;

      // normalize ke Map<String, dynamic>
      final Map<String, dynamic> u = <String, dynamic>{};
      if (raw is Map) {
        raw.forEach((k, v) => u[k.toString()] = v);
      }

      final role = (u['role'] ?? 'user').toString(); // admin / campus / user
      final type = (u['type'] ?? '').toString();     // warga / petugas (sesuai register)

      // Petugas = type petugas atau role user (sesuai struktur app kamu)
      final bool isPetugas = (type == 'petugas') || (role == 'user');

      // ✅ default aman:
      // - kalau field approved belum ada:
      //    - petugas dianggap belum disetujui (false)
      //    - non-petugas dianggap disetujui (true)
      final bool hasApprovedKey = u.containsKey('approved');
      final bool approved = hasApprovedKey ? (u['approved'] == true) : !isPetugas;

      final bool rejected = (u['rejected'] == true);

      // ✅ BLOK LOGIN PETUGAS jika belum disetujui / ditolak
      if (isPetugas) {
        if (rejected) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _pass.clear();
          _showSnack('Akun petugas kamu ditolak oleh admin.');
          return;
        }
        if (!approved) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _pass.clear();
          _showSnack('Akun petugas kamu masih menunggu persetujuan admin.');
          return;
        }
      }

      if (!mounted) return;

      // ✅ Redirect sesuai role
      if (role == 'admin') {
        context.go('/admin');
      } else if (role == 'campus') {
        context.go('/campus');
      } else {
        context.go('/user');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'Email belum terdaftar.';
          break;
        case 'wrong-password':
          msg = 'Password yang kamu masukkan salah.';
          break;
        case 'invalid-credential':
          msg = 'Email atau password tidak sesuai. Silakan periksa lagi.';
          break;
        case 'invalid-email':
          msg = 'Format email tidak valid.';
          break;
        case 'user-disabled':
          msg = 'Akun ini telah dinonaktifkan. Hubungi admin.';
          break;
        case 'network-request-failed':
          msg = 'Koneksi internet bermasalah. Coba lagi.';
          break;
        case 'too-many-requests':
          msg = 'Terlalu banyak percobaan. Coba lagi beberapa saat.';
          break;
        default:
          msg = 'Login gagal (${e.code}). Coba lagi.';
      }

      _pass.clear();
      _showSnack(msg);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Terjadi kesalahan tak terduga: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(text: _email.text.trim());
    bool sending = false;

    await showDialog(
      context: context,
      barrierDismissible: !sending,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> send() async {
              final email = emailController.text.trim();

              if (!_isValidEmail(email)) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Masukkan email yang valid.')),
                );
                return;
              }

              setDialogState(() => sending = true);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                if (mounted) {
                  Navigator.of(dialogCtx).pop();
                  _showSnack(
                    'Link reset password sudah dikirim ke $email. Cek Inbox/Spam.',
                  );
                }
              } on FirebaseAuthException catch (e) {
                String msg;
                switch (e.code) {
                  case 'invalid-email':
                    msg = 'Format email tidak valid.';
                    break;
                  case 'user-not-found':
                    msg = 'Email belum terdaftar.';
                    break;
                  case 'too-many-requests':
                    msg = 'Terlalu banyak permintaan. Coba lagi nanti.';
                    break;
                  default:
                    msg = 'Gagal mengirim reset password (${e.code}).';
                }
                ScaffoldMessenger.of(dialogCtx)
                    .showSnackBar(SnackBar(content: Text(msg)));
              } catch (e) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(content: Text('Terjadi error: $e')),
                );
              } finally {
                if (dialogCtx.mounted) setDialogState(() => sending = false);
              }
            }

            return AlertDialog(
              title: const Text(
                'Lupa Kata Sandi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Masukkan email akun Anda. Sistem akan mengirim link untuk mengganti kata sandi.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'contoh@gmail.com',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !sending,
                    onSubmitted: (_) => sending ? null : send(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: sending ? null : send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Kirim'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ pastikan tidak ada background putih dari Scaffold
      backgroundColor: _loginBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),

      // ✅ background halaman = biru muda polos
      body: Container(
        color: _loginBg,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 32),

                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _fieldDecoration('Masukkan Gmail'),
                        validator: (v) => (v == null || !_isValidEmail(v))
                            ? 'Email tidak valid'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _pass,
                        obscureText: !_lihatSandi,
                        decoration: _fieldDecoration(
                          'Masukkan Kata Sandi',
                          suffix: IconButton(
                            icon: Icon(
                              _lihatSandi
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey.shade700,
                            ),
                            onPressed: () =>
                                setState(() => _lihatSandi = !_lihatSandi),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Minimal 6 karakter'
                            : null,
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text(
                            'Lupa kata sandi?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'MASUK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Belum memiliki akun? ',
                            style: TextStyle(fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text(
                              'DAFTAR',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
