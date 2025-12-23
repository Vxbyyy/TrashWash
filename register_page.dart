import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

const _primaryColor = Color(0xFF143B6E);

// ✅ biru muda polos (tanpa layer biru gelap)
const _pageBg = Color(0xFFBFEFF1);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _hp = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _idPetugas = TextEditingController();

  bool _loading = false;

  bool _showPass = false;
  bool _showPass2 = false;

  String _roleType = 'warga';
  bool get _isPetugas => _roleType == 'petugas';

  FirebaseDatabase get _rtdb => FirebaseDatabase.instance;

  Future<void> _daftar() async {
    if (!_form.currentState!.validate()) return;
    if (_pass.text != _pass2.text) {
      _show('Konfirmasi sandi tidak sama');
      return;
    }

    if (_isPetugas && _idPetugas.text.trim().isEmpty) {
      _show('Nomor identitas petugas wajib diisi.');
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      final uid = cred.user!.uid;

      // cek apakah ini user admin pertama
      bool isAdmin = false;
      try {
        final snap = await _rtdb
            .ref('users')
            .orderByChild('role')
            .equalTo('admin')
            .limitToFirst(1)
            .get();
        if (!snap.exists) isAdmin = true;
      } catch (_) {}

      // mapping role sesuai struktur aplikasi
      String role;
      if (isAdmin) {
        role = 'admin';
      } else if (_roleType == 'warga') {
        role = 'campus';
      } else {
        role = 'user'; // petugas kebersihan
      }

      // aturan approval:
      // - admin & warga/campus: langsung aktif
      // - petugas: menunggu persetujuan admin
      final bool needsApproval = (!isAdmin && _isPetugas);
      final bool approved = !needsApproval;

      await _rtdb.ref('users/$uid').set({
        'name': _nama.text.trim(),
        'email': _email.text.trim(),
        'phone': _hp.text.trim(),
        'role': role,
        'type': _roleType, // warga / petugas
        if (_idPetugas.text.trim().isNotEmpty)
          'idPetugas': _idPetugas.text.trim(),

        // approval fields
        'approved': approved,
        'rejected': false,
        if (approved) 'approvedAt': ServerValue.timestamp,

        'createdAt': ServerValue.timestamp,
      });

      await cred.user!.updateDisplayName(_nama.text.trim());
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      if (needsApproval) {
        _show('Akun petugas berhasil dibuat dan menunggu persetujuan admin.');
      } else {
        _show('Akun berhasil dibuat. Silakan masuk.');
      }

      context.go('/login');
    } on FirebaseAuthException catch (e) {
      _show('[${e.code}] ${e.message ?? "Gagal daftar"}');
    } catch (e) {
      _show('Terjadi kesalahan tak terduga: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }

  Widget _buildRoleChip(String key, String label) {
    final selected = _roleType == key;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _roleType = key),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primaryColor, width: 1.2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    _hp.dispose();
    _pass.dispose();
    _pass2.dispose();
    _idPetugas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
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
              context.go('/login');
            }
          },
        ),
      ),

      // ✅ background = biru muda polos, tanpa TrashBackground
      body: Container(
        color: _pageBg,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'BUAT AKUN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 28),

                      TextFormField(
                        controller: _nama,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration('Nama'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _email,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _fieldDecoration('Gmail'),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Email tidak valid'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _hp,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        decoration: _fieldDecoration('No. Hp'),
                        validator: (v) => (v == null || v.trim().length < 6)
                            ? 'No HP tidak valid'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Daftar sebagai:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRoleChip('warga', 'Mahasiswa/Warga Kampus'),
                          const SizedBox(width: 8),
                          _buildRoleChip('petugas', 'Petugas Kebersihan'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_isPetugas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _idPetugas,
                            textInputAction: TextInputAction.next,
                            decoration:
                                _fieldDecoration('Nomor Identitas Petugas'),
                            validator: (v) {
                              if (_isPetugas &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Nomor identitas petugas wajib diisi';
                              }
                              return null;
                            },
                          ),
                        ),

                      TextFormField(
                        controller: _pass,
                        textInputAction: TextInputAction.next,
                        obscureText: !_showPass,
                        decoration: _fieldDecoration(
                          'Masukkan Kata Sandi',
                          suffix: IconButton(
                            tooltip:
                                _showPass ? 'Sembunyikan sandi' : 'Lihat sandi',
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey.shade700,
                            ),
                            onPressed: () =>
                                setState(() => _showPass = !_showPass),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Minimal 6 karakter'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _pass2,
                        textInputAction: TextInputAction.done,
                        obscureText: !_showPass2,
                        decoration: _fieldDecoration(
                          'Konfirmasi Kata Sandi',
                          suffix: IconButton(
                            tooltip: _showPass2
                                ? 'Sembunyikan sandi'
                                : 'Lihat sandi',
                            icon: Icon(
                              _showPass2
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey.shade700,
                            ),
                            onPressed: () =>
                                setState(() => _showPass2 = !_showPass2),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Minimal 6 karakter'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _daftar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
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
                                  'DAFTAR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sudah memiliki akun? ',
                            style: TextStyle(fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text(
                              'MASUK',
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
