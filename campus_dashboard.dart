// lib/pages/campus_dashboard.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme.dart';

/// Warna biru utama (button & header tabel)
const Color kCampusBlue = Color(0xFF143B6E);

/// Tab dashboard khusus orang kampus:
///  - report  : LAPORAN TPS PENUH + KIRIM SARAN
///  - history : RIWAYAT LAPORAN SAYA
///  - profile : PROFIL sederhana (email + logout)
enum CampusTab { report, history, profile }

class CampusDashboard extends StatefulWidget {
  const CampusDashboard({super.key});

  @override
  State<CampusDashboard> createState() => _CampusDashboardState();
}

class _CampusDashboardState extends State<CampusDashboard> {
  CampusTab _tab = CampusTab.report;

  FirebaseDatabase _db() => FirebaseDatabase.instance;

  DatabaseReference get _refLaporanKampus => _db().ref('laporan_kampus');
  DatabaseReference get _refSaranKampus => _db().ref('saran_kampus');

  int _tabIndex(CampusTab t) {
    switch (t) {
      case CampusTab.report:
        return 0;
      case CampusTab.history:
        return 1;
      case CampusTab.profile:
        return 2;
    }
  }

  CampusTab _tabFromIndex(int i) {
    switch (i) {
      case 0:
        return CampusTab.report;
      case 1:
        return CampusTab.history;
      case 2:
      default:
        return CampusTab.profile;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // ✅ polos: hanya warna dasar
      backgroundColor: AppColors.lightBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: IndexedStack(
            index: _tabIndex(_tab),
            children: [
              _CampusReportPane(
                uid: uid,
                laporanRef: _refLaporanKampus,
                saranRef: _refSaranKampus,
              ),
              _CampusHistoryPane(
                uid: uid,
                laporanRef: _refLaporanKampus,
              ),
              const _CampusProfilePane(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _CampusBottomNavBar(
        currentIndex: _tabIndex(_tab),
        onTap: (i) => setState(() => _tab = _tabFromIndex(i)),
      ),
    );
  }
}

/// ===============================================================
///                   BOTTOM NAV KHUSUS KAMPUS
/// ===============================================================

class _CampusBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _CampusBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(26),
        topRight: Radius.circular(26),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kCampusBlue,
        unselectedItemColor: kCampusBlue.withOpacity(0.45),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
///                 TAB 1 – LAPORAN TPS PENUH + SARAN
/// ===============================================================

class _CampusReportPane extends StatefulWidget {
  final String uid;
  final DatabaseReference laporanRef;
  final DatabaseReference saranRef;

  const _CampusReportPane({
    required this.uid,
    required this.laporanRef,
    required this.saranRef,
  });

  @override
  State<_CampusReportPane> createState() => _CampusReportPaneState();
}

class _CampusReportPaneState extends State<_CampusReportPane> {
  final _formKey = GlobalKey<FormState>();
  final _saranCtrl = TextEditingController();

  String? _selectedTps;
  String? _selectedJenis;
  bool _busyLaporan = false;
  bool _busySaran = false;

  // TODO: ganti dengan list TPS dari Firebase kalau mau dinamis
  final List<String> _dummyTpsList = const ['TPS 1', 'TPS 2', 'TPS 3'];
  final List<String> _jenisList = const ['Organik', 'Anorganik'];

  Future<void> _submitLaporan() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _busyLaporan = true);
      final now = DateTime.now().toIso8601String();

      await widget.laporanRef.push().set({
        'uid': widget.uid,
        'tps': _selectedTps,
        'jenis': _selectedJenis,
        'status': 'Pending',
        'createdAt': ServerValue.timestamp,
        'createdAtIso': now,
      });

      if (!mounted) return;

      _formKey.currentState?.reset();
      setState(() {
        _selectedTps = null;
        _selectedJenis = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan TPS terkirim')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim laporan: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyLaporan = false);
    }
  }

  Future<void> _submitSaran() async {
    if (_saranCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saran masih kosong')),
      );
      return;
    }

    try {
      setState(() => _busySaran = true);
      await widget.saranRef.push().set({
        'uid': widget.uid,
        'saran': _saranCtrl.text.trim(),
        'createdAt': ServerValue.timestamp,
      });
      _saranCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saran terkirim')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim saran: $e')),
      );
    } finally {
      if (mounted) setState(() => _busySaran = false);
    }
  }

  @override
  void dispose() {
    _saranCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const Text(
            'LAPORAN TPS PENUH',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih TPS',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _selectedTps,
                    items: _dummyTpsList
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTps = v),
                    validator: (v) => v == null ? 'TPS belum dipilih' : null,
                    decoration: _campusDropdownDecoration(),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jenis',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _selectedJenis,
                    items: _jenisList
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedJenis = v),
                    validator: (v) =>
                        v == null ? 'Jenis sampah belum dipilih' : null,
                    decoration: _campusDropdownDecoration(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busyLaporan ? null : _submitLaporan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCampusBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _busyLaporan
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Kirim',
                              style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'KIRIM SARAN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                TextFormField(
                  controller: _saranCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Tulis Saran...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busySaran ? null : _submitSaran,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCampusBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _busySaran
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kirim Saran',
                            style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _campusDropdownDecoration() {
    return const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );
  }
}

/// ===============================================================
///                 TAB 2 – RIWAYAT LAPORAN SAYA
/// ===============================================================

class _CampusHistoryPane extends StatefulWidget {
  final String uid;
  final DatabaseReference laporanRef;

  const _CampusHistoryPane({
    required this.uid,
    required this.laporanRef,
  });

  @override
  State<_CampusHistoryPane> createState() => _CampusHistoryPaneState();
}

class _CampusHistoryPaneState extends State<_CampusHistoryPane> {
  String _fmt(int? ms, String? fallbackIso) {
    if (ms == null && fallbackIso == null) return '-';
    if (ms != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return fallbackIso ?? '-';
  }

  Table _buildTable(List<Map<String, dynamic>> rows) {
    return Table(
      border: const TableBorder.symmetric(
        inside: BorderSide(color: Colors.black12, width: 1),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.3),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(children: [
          _CellHeader('Tanggal'),
          _CellHeader('TPS'),
          _CellHeader('Status'),
        ]),
        ...rows.map((m) {
          final tgl =
              _fmt(m['createdAt'] as int?, m['createdAtIso']?.toString());
          final tps = (m['tps'] ?? '-').toString();
          final status = (m['status'] ?? '-').toString();
          return TableRow(children: [
            _CellText(tgl),
            _CellText(tps),
            _CellText(status),
          ]);
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: widget.laporanRef
          .orderByChild('uid')
          .equalTo(widget.uid)
          .onValue,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final raw = snap.data?.snapshot.value;
        final rows = <Map<String, dynamic>>[];

        if (raw is Map) {
          raw.forEach((k, v) {
            if (v is Map) {
              final m = v.map((kk, vv) => MapEntry(kk.toString(), vv));
              rows.add(Map<String, dynamic>.from(m));
            }
          });
        }

        if (rows.isEmpty) {
          return const _EmptyInfo(text: 'Belum ada laporan yang kamu kirim.');
        }

        rows.sort((a, b) {
          final ta = (a['createdAt'] is int) ? a['createdAt'] as int : -1;
          final tb = (b['createdAt'] is int) ? b['createdAt'] as int : -1;
          return tb.compareTo(ta);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RIWAYAT LAPORAN SAYA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black26, width: 1),
              ),
              child: _buildTable(rows),
            ),
          ],
        );
      },
    );
  }
}

/// ===============================================================
///                 TAB 3 – PROFIL KAMPUS
/// ===============================================================

class _CampusProfilePane extends StatelessWidget {
  const _CampusProfilePane();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '-';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'PROFILE',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_rounded,
              size: 60,
              color: Color(0xFF0B5C5A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            email,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 260,
            child: ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kCampusBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'LOGOUT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
///                       CELL UMUM & FALLBACK
/// ===============================================================

class _CellHeader extends StatelessWidget {
  final String text;
  const _CellHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: kCampusBlue,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  final String text;
  const _CellText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _EmptyInfo extends StatelessWidget {
  final String text;
  const _EmptyInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }
}
