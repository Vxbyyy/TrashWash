// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

// Web-only (untuk download CSV di browser)
import 'package:universal_html/html.dart' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../ui/background_layers.dart';
import '../ui/theme.dart';

/// ================== STYLE KONSTAN TABEL ==================
const Color kTableHeaderBlue = Color(0xFF143B6E);
const TextStyle kTableHeaderTextStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w800,
);

/// ================== ENUM JENIS (UNTUK HITUNG DONUT) ==================
enum _JenisSampah { organik, anorganik }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  // ✅ guard role admin
  bool _checkingRole = true;
  bool _isAdmin = false;

  StreamSubscription<User?>? _authSub;

  // ✅ SIMPAN INSTANCE DB + STREAM SEKALI
  late final FirebaseDatabase _db;
  late final DatabaseReference _refMonitoring;
  late final DatabaseReference _refRiwayat;
  late final DatabaseReference _refLaporanKampus;
  late final DatabaseReference _refSaranKampus;
  late final DatabaseReference _refUsers;

  late final Stream<DatabaseEvent> _monitoringStream;
  late final Stream<DatabaseEvent> _riwayatStream;
  late final Stream<DatabaseEvent> _laporanStream;
  late final Stream<DatabaseEvent> _saranStream;
  late final Stream<DatabaseEvent> _usersStream;

  @override
  void initState() {
    super.initState();

    _db = FirebaseDatabase.instance;

    _refMonitoring = _db.ref('monitoring');
    _refRiwayat = _db.ref('riwayat');
    _refLaporanKampus = _db.ref('laporan_kampus');
    _refSaranKampus = _db.ref('saran_kampus');
    _refUsers = _db.ref('users');

    _monitoringStream = _refMonitoring.limitToLast(150).onValue.asBroadcastStream();
    _riwayatStream = _refRiwayat.limitToLast(400).onValue.asBroadcastStream();
    _laporanStream = _refLaporanKampus.limitToLast(200).onValue.asBroadcastStream();
    _saranStream = _refSaranKampus.limitToLast(200).onValue.asBroadcastStream();
    _usersStream = _refUsers.onValue.asBroadcastStream();

    _guardAdmin();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) async {
      await _guardAdmin();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _guardAdmin() async {
    final u = FirebaseAuth.instance.currentUser;

    if (u == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final snap = await _refUsers.child(u.uid).child('role').get();
      final role = (snap.value ?? '').toString().toLowerCase().trim();

      final isAdminNow = (role == 'admin');

      if (mounted) {
        setState(() {
          _isAdmin = isAdminNow;
          _checkingRole = false;
        });
      }

      if (!isAdminNow) {
        if (!mounted) return;

        if (role == 'campus' || role == 'kampus') {
          context.go('/campus');
        } else {
          context.go('/user');
        }
        return;
      }
    } catch (_) {
      if (mounted) context.go('/');
      return;
    } finally {
      if (mounted) setState(() => _checkingRole = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return const Scaffold(body: Center(child: Text('Akses ditolak.')));
    }

    final pages = <Widget>[
      _DashboardHomeTab(
        monitoringStream: _monitoringStream,
        riwayatStream: _riwayatStream,
        laporanStream: _laporanStream,
        saranStream: _saranStream,
        monitoringRef: _refMonitoring,
        riwayatRef: _refRiwayat,
        laporanRef: _refLaporanKampus,
        saranRef: _refSaranKampus,
        usersRef: _refUsers,
      ),
      _PermintaanTab(usersRef: _refUsers),
      _UsersScreen(usersStream: _usersStream),
      _ProfileScreen(onLogout: _logout, usersRef: _refUsers),
    ];

    return Scaffold(
      body: TrashBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// ================== BOTTOM NAV ==================

class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AdminBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.buttonBlue,
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Gabungan TPS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart_outlined),
              label: 'Permintaan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.table_rows_outlined),
              label: 'Data Pengguna',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

/// ================== HELPER RESPONSIVE WIDTH ==================

double _responsiveMaxWidth(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w <= 600) return w;
  if (w <= 1024) return math.min(w * 0.95, 1100);
  return math.min(w * 0.9, 1400);
}

double _responsiveTableWidth(BuildContext context, {double max = 1400}) {
  final w = MediaQuery.of(context).size.width;
  if (w <= 600) return w;
  return math.min(w * 0.95, max);
}

/// ================== TAB: DASHBOARD (GABUNGAN TPS) ==================

class _DashboardHomeTab extends StatelessWidget {
  final Stream<DatabaseEvent> monitoringStream;
  final Stream<DatabaseEvent> riwayatStream;
  final Stream<DatabaseEvent> laporanStream;
  final Stream<DatabaseEvent> saranStream;

  final DatabaseReference monitoringRef;
  final DatabaseReference riwayatRef;
  final DatabaseReference laporanRef;
  final DatabaseReference saranRef;
  final DatabaseReference usersRef;

  const _DashboardHomeTab({
    required this.monitoringStream,
    required this.riwayatStream,
    required this.laporanStream,
    required this.saranStream,
    required this.monitoringRef,
    required this.riwayatRef,
    required this.laporanRef,
    required this.saranRef,
    required this.usersRef,
  });

  /// (1) Tambah TPS:
  /// - nama boleh sama maksimal 2x
  /// - jenis tidak boleh sama untuk nama yang sama
  Future<void> _showAddTpsDialog(BuildContext context) async {
    final tpsC = TextEditingController();
    String? jenisValue;
    bool saving = false;

    String normName(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    String normJenis(String s) {
      final v = s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      if (v.contains('non') || v.contains('anorganik')) return 'anorganik';
      if (v.contains('organik')) return 'organik';
      return v;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Tambah TPS'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tpsC,
                    decoration: const InputDecoration(
                      labelText: 'Nama TPS',
                      hintText: 'Misal: TPS 1 / TPS Pasar',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: jenisValue,
                    items: const [
                      DropdownMenuItem(value: 'organik', child: Text('Organik')),
                      DropdownMenuItem(value: 'anorganik', child: Text('Anorganik')),
                    ],
                    onChanged: saving ? null : (v) => setState(() => jenisValue = v),
                    decoration: const InputDecoration(labelText: 'Jenis'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final nama = tpsC.text.trim();

                          if (nama.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nama TPS wajib diisi.')),
                            );
                            return;
                          }
                          if (jenisValue == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Jenis wajib dipilih.')),
                            );
                            return;
                          }

                          setState(() => saving = true);

                          try {
                            final namaNorm = normName(nama);
                            final jenisNorm = normJenis(jenisValue!);

                            final snapAll = await monitoringRef.get();
                            final raw = snapAll.value;

                            Iterable values = const [];
                            if (raw is Map) {
                              values = raw.values;
                            } else if (raw is List) {
                              values = raw.where((e) => e != null);
                            }

                            int sameNameCount = 0;
                            bool sameJenisExists = false;

                            for (final e in values) {
                              if (e is Map) {
                                final m = e.map((k, v) => MapEntry(k.toString(), v));
                                final existingName = normName((m['tps'] ?? '').toString());
                                if (existingName.isEmpty) continue;

                                if (existingName == namaNorm) {
                                  sameNameCount++;
                                  final exJenis = normJenis((m['jenis'] ?? '').toString());
                                  if (exJenis == jenisNorm) {
                                    sameJenisExists = true;
                                  }
                                }
                              }
                            }

                            if (sameJenisExists) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nama TPS sudah ada dengan jenis yang sama. Pilih jenis lain.'),
                                  ),
                                );
                              }
                              setState(() => saving = false);
                              return;
                            }

                            if (sameNameCount >= 2) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nama TPS ini sudah mencapai batas (maksimal 2 jenis).'),
                                  ),
                                );
                              }
                              setState(() => saving = false);
                              return;
                            }

                            final jenisStore = (jenisNorm == 'organik') ? 'Organik' : 'Anorganik';

                            await monitoringRef.push().set({
                              'tps': nama,
                              'tpsKey': namaNorm,
                              'jenis': jenisStore,
                              'status': 'Normal',
                              'timestamp': ServerValue.timestamp,
                              'source': 'manual',
                            });

                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal menyimpan ke Firebase: $e')),
                              );
                            }
                            setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    tpsC.dispose();

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TPS berhasil ditambahkan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = _responsiveMaxWidth(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: StreamBuilder<DatabaseEvent>(
            stream: riwayatStream,
            builder: (context, snap) {
              final isLoadingRiwayat = snap.connectionState == ConnectionState.waiting && snap.data == null;

              /// ✅ PAKAI rowsWithKeys supaya tanggal bisa fallback dari pushKey juga
              final rows = _rowsWithKeysFromSnapshot(snap.data?.snapshot);

              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);

              final thisWeekStart = todayStart.subtract(
                Duration(days: todayStart.weekday - DateTime.monday),
              );
              final thisWeekEnd = thisWeekStart.add(const Duration(days: 7));

              final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
              final lastWeekEnd = lastWeekStart.add(const Duration(days: 7));

              int totalThisWeekWorkingDays = 0;

              /// ✅ FIX: hitung jenis hanya jika benar-benar terdeteksi organik/anorganik
              int organikCount = 0;
              int anorganikCount = 0;

              final List<int> thisWeekDaily = List.filled(7, 0);
              final List<int> lastWeekDaily = List.filled(7, 0);

              for (final m in rows) {
                final dt = _tryParseDateTime(m);
                if (dt == null) continue;

                if (!dt.isBefore(thisWeekStart) &&
                    dt.isBefore(thisWeekEnd) &&
                    dt.weekday >= DateTime.monday &&
                    dt.weekday <= DateTime.friday) {
                  totalThisWeekWorkingDays++;
                }

                /// ✅ FIX UTAMA DONUT: jangan anggap semua string sebagai anorganik
                final jenisText = _extractJenis(m);
                final bucket = _parseJenisBucket(jenisText);
                if (bucket == _JenisSampah.organik) {
                  organikCount++;
                } else if (bucket == _JenisSampah.anorganik) {
                  anorganikCount++;
                }

                if (!dt.isBefore(thisWeekStart) && dt.isBefore(thisWeekEnd)) {
                  final idx = dt.weekday - 1;
                  if (idx >= 0 && idx < 7) thisWeekDaily[idx]++;
                }

                if (!dt.isBefore(lastWeekStart) && dt.isBefore(lastWeekEnd)) {
                  final idx = dt.weekday - 1;
                  if (idx >= 0 && idx < 7) lastWeekDaily[idx]++;
                }
              }

              final totalForDistrib = organikCount + anorganikCount;

              const dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

              final currentMonthName = _bulanIndo(now.month);
              final currentYear = now.year;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'DASHBOARD GABUNGAN SEMUA TPS',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddTpsDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah TPS'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.buttonBlue,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isLoadingRiwayat)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Memuat data riwayat...',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _OpenReportsSummaryCard(laporanStream: laporanStream)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Pengangkutan Minggu Ini',
                          value: totalThisWeekWorkingDays.toString(),
                          color: Colors.blue,
                          icon: Icons.local_shipping_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DistribusiCard(
                    organik: organikCount,
                    anorganik: anorganikCount,
                    total: totalForDistrib,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$currentMonthName $currentYear',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _WeeklySection(
                    dayLabels: dayLabels,
                    thisWeek: thisWeekDaily,
                    lastWeek: lastWeekDaily,
                    thisWeekStart: thisWeekStart,
                  ),
                  const SizedBox(height: 20),
                  _LaporanMasukSection(
                    laporanStream: laporanStream,
                    laporanRef: laporanRef,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Riwayat Pengangkutan (Petugas)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: _RiwayatPane(
                      stream: riwayatStream,
                      riwayatRef: riwayatRef,
                      usersRef: usersRef,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SaranMasukSection(
                    saranStream: saranStream,
                    saranRef: saranRef,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Monitoring TPS Terbaru',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: _MonitoringTable(stream: monitoringStream),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  final double height;
  const _SectionLoading({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _OpenReportsSummaryCard extends StatelessWidget {
  final Stream<DatabaseEvent> laporanStream;

  const _OpenReportsSummaryCard({required this.laporanStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: laporanStream,
      builder: (context, snap) {
        final rows = _rowsFromSnapshot(snap.data?.snapshot);

        int openCount = 0;
        for (final m in rows) {
          final status = (m['status'] ?? '').toString().toLowerCase();
          final isClosed = status.contains('selesai') || status.contains('done') || status.contains('resolved');
          if (!isClosed) openCount++;
        }

        return _SummaryCard(
          title: 'Laporan Terbuka',
          value: openCount.toString(),
          color: Colors.teal,
          icon: Icons.info_outline,
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.07),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// ================== DONUT CARD ==================

class _DistribusiCard extends StatelessWidget {
  final int organik;
  final int anorganik;
  final int total;

  const _DistribusiCard({
    required this.organik,
    required this.anorganik,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final double organikRatio = total == 0 ? 0 : organik / total;
    final double nonRatio = total == 0 ? 0 : anorganik / total;

    final int organikPct = total == 0 ? 0 : (organikRatio * 100).round();
    final int nonPct = total == 0 ? 0 : (100 - organikPct);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribusi Jenis Sampah Yang Sudah Diangkut',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;

              final double size =
                  isNarrow ? math.min(constraints.maxWidth * 0.52, 190) : math.min(constraints.maxWidth * 0.20, 210);

              final donut = SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _DonutPainter(
                    organikRatio: organikRatio,
                    nonRatio: nonRatio,
                    organikPct: organikPct,
                    nonPct: nonPct,
                    organikColor: const Color(0xFF2ECC71),
                    nonColor: const Color(0xFFF1C40F),
                  ),
                ),
              );

              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _LegendItem(color: Color(0xFF2ECC71), label: 'Organik'),
                  SizedBox(height: 10),
                  _LegendItem(color: Color(0xFFF1C40F), label: 'Anorganik'),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    donut,
                    const SizedBox(height: 10),
                    legend,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  donut,
                  const SizedBox(width: 60),
                  legend,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double organikRatio;
  final double nonRatio;
  final int organikPct;
  final int nonPct;
  final Color organikColor;
  final Color nonColor;

  _DonutPainter({
    required this.organikRatio,
    required this.nonRatio,
    required this.organikPct,
    required this.nonPct,
    required this.organikColor,
    required this.nonColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final stroke = radius * 0.72;
    final r = radius - stroke / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFE5E7EB);

    canvas.drawCircle(center, r, basePaint);

    if (organikRatio <= 0 && nonRatio <= 0) {
      final holePaint = Paint()..color = Colors.white;
      canvas.drawCircle(center, radius * 0.18, holePaint);
      return;
    }

    final startAngle = -math.pi / 2;
    final organikSweep = 2 * math.pi * organikRatio;
    final nonSweep = 2 * math.pi * nonRatio;

    final arcRect = Rect.fromCircle(center: center, radius: r);

    final organikPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = organikColor;

    final nonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = nonColor;

    canvas.drawArc(arcRect, startAngle, organikSweep, false, organikPaint);
    canvas.drawArc(arcRect, startAngle + organikSweep, nonSweep, false, nonPaint);

    void drawPct(int pct, double midAngle) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$pct%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelR = r;
      final pos = Offset(
        center.dx + (labelR * 0.65) * math.cos(midAngle) - tp.width / 2,
        center.dy + (labelR * 0.65) * math.sin(midAngle) - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }

    if (organikSweep > 0.001) drawPct(organikPct, startAngle + organikSweep / 2);
    if (nonSweep > 0.001) drawPct(nonPct, startAngle + organikSweep + nonSweep / 2);

    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.18, holePaint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.organikRatio != organikRatio ||
        oldDelegate.nonRatio != nonRatio ||
        oldDelegate.organikPct != organikPct ||
        oldDelegate.nonPct != nonPct;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

/// ================== WEEKLY SECTION ==================

class _WeeklySection extends StatelessWidget {
  final List<String> dayLabels;
  final List<int> thisWeek;
  final List<int> lastWeek;
  final DateTime thisWeekStart;

  const _WeeklySection({
    required this.dayLabels,
    required this.thisWeek,
    required this.lastWeek,
    required this.thisWeekStart,
  });

  List<DateTime> _generateWeekDates() {
    return List.generate(7, (i) => thisWeekStart.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final dates = _generateWeekDates();
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFCFF5F0),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perbandingan Mingguan (Minggu ini vs Minggu lalu)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: Row(
              children: List.generate(dates.length, (index) {
                final d = dates[index];
                final isToday = d.year == today.year && d.month == today.month && d.day == today.day;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFFD9E6FF) : Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday ? AppColors.buttonBlue : Colors.white.withOpacity(0.1),
                          width: 1.4,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isToday) const Icon(Icons.check, size: 18) else const SizedBox(height: 18),
                          Text(
                            d.day.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          Text(_hariSingkatIndo(d.weekday), style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                Expanded(
                  child: _WeeklyLineCompareChart(
                    labels: dayLabels,
                    thisWeek: thisWeek,
                    lastWeek: lastWeek,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _LineLegendItem(color: Color(0xFFF1C40F), label: 'Minggu lalu'),
                    SizedBox(width: 24),
                    _LineLegendItem(color: Color(0xFF143B6E), label: 'Minggu ini'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyLineCompareChart extends StatelessWidget {
  final List<String> labels;
  final List<int> thisWeek;
  final List<int> lastWeek;

  const _WeeklyLineCompareChart({
    required this.labels,
    required this.thisWeek,
    required this.lastWeek,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.length != thisWeek.length || labels.length != lastWeek.length || labels.isEmpty) {
      return const Center(
        child: Text('Belum ada data untuk grafik.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      );
    }

    // (2) Paksa skala Y minimal 10 dan label 2,4,6,8,10
    const safeMax = 10;

    return Column(
      children: [
        Expanded(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _WeeklyLinePainter(thisWeek: thisWeek, lastWeek: lastWeek, maxValue: safeMax),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
            );
          }),
        ),
      ],
    );
  }
}

class _WeeklyLinePainter extends CustomPainter {
  final List<int> thisWeek;
  final List<int> lastWeek;
  final int maxValue;

  _WeeklyLinePainter({
    required thisWeek,
    required lastWeek,
    required maxValue,
  })  : thisWeek = thisWeek,
        lastWeek = lastWeek,
        maxValue = maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 44.0; // agak dilebarkan agar muat label 10
    const rightMargin = 12.0;
    const topMargin = 8.0;
    const bottomMargin = 20.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    const tickCount = 5; // 2,4,6,8,10 (+0 garis bawah)
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;

    // grid + label Y
    for (int i = 0; i <= tickCount; i++) {
      final dy = topMargin + chartHeight * i / tickCount;
      canvas.drawLine(Offset(leftMargin, dy), Offset(leftMargin + chartWidth, dy), gridPaint);

      // label: 10,8,6,4,2,0 (tampilkan hanya 2..10)
      final val = (tickCount - i) * 2;
      if (val > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$val',
            style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
        )..layout();

        tp.paint(canvas, Offset(leftMargin - tp.width - 6, dy - tp.height / 2));
      }
    }

    // sumbu Y
    canvas.drawLine(Offset(leftMargin, topMargin), Offset(leftMargin, topMargin + chartHeight), gridPaint);

    final n = thisWeek.length;
    if (n < 2) return;

    final dx = chartWidth / (n - 1);
    double x(int i) => leftMargin + dx * i;

    final mv = maxValue <= 0 ? 1 : maxValue;

    double y(int v) {
      final vv = v > mv ? mv : v; // clamp agar tidak lewat atas
      return topMargin + chartHeight * (1 - (vv / mv));
    }

    Path buildPath(List<int> values) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final px = x(i);
        final py = y(values[i]);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      return path;
    }

    final lastWeekPath = buildPath(lastWeek);
    final thisWeekPath = buildPath(thisWeek);

    final lastPaint = Paint()
      ..color = const Color(0xFFF1C40F)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final thisPaint = Paint()
      ..color = const Color(0xFF143B6E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(lastWeekPath, lastPaint);
    canvas.drawPath(thisWeekPath, thisPaint);

    final dotRadius = 4.6;
    final dotPaintLast = Paint()..color = const Color(0xFFF1C40F);
    final dotPaintThis = Paint()..color = const Color(0xFF143B6E);

    for (int i = 0; i < n; i++) {
      final px = x(i);
      canvas.drawCircle(Offset(px, y(lastWeek[i])), dotRadius, dotPaintLast);
      canvas.drawCircle(Offset(px, y(thisWeek[i])), dotRadius, dotPaintThis);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyLinePainter oldDelegate) {
    return oldDelegate.thisWeek != thisWeek || oldDelegate.lastWeek != lastWeek || oldDelegate.maxValue != maxValue;
  }
}

class _LineLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LineLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// ================== SECTION: LAPORAN MASUK ==================

class _LaporanMasukSection extends StatefulWidget {
  final Stream<DatabaseEvent> laporanStream;
  final DatabaseReference laporanRef;

  const _LaporanMasukSection({
    required this.laporanStream,
    required this.laporanRef,
  });

  @override
  State<_LaporanMasukSection> createState() => _LaporanMasukSectionState();
}

class _LaporanMasukSectionState extends State<_LaporanMasukSection> {
  /// ✅ FIX: Tanggal ambil dari map (multi-key + fallback pushKey)
  String _formatTanggal(Map<String, dynamic> m) {
    final dt = _tryParseDateTime(m);
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d-$mo-${dt.year} $h:$mi';
  }

  int _rowMillis(Map<String, dynamic> m) {
    final dt = _tryParseDateTime(m);
    if (dt != null) return dt.millisecondsSinceEpoch;
    return -1;
  }

  void _openDetailSheet(BuildContext context, Map<String, dynamic> m) {
    final tanggal = _formatTanggal(m);
    final tps = (m['tps'] ?? m['lokasi'] ?? m['location'] ?? '-').toString();
    final status = (m['status'] ?? '-').toString();
    final jenis = (_extractJenis(m).isNotEmpty ? _extractJenis(m) : (m['type'] ?? '-').toString());
    final pelapor = (m['pelapor'] ?? m['name'] ?? m['user'] ?? '-').toString();
    final desc = (m['deskripsi'] ?? m['keterangan'] ?? '-').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F7FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (ctx, controller) {
            return _SheetFrame(
              title: 'Detail Laporan',
              onClose: () => Navigator.pop(ctx),
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('Tanggal Laporan', tanggal),
                    _kv('TPS', tps),
                    _kv('Jenis', jenis),
                    _kv('Status', status),
                    _kv('Pelapor', pelapor),
                    const SizedBox(height: 14),
                    Text(desc, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: widget.laporanStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorBox(text: 'Gagal memuat laporan: ${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 160);
        }

        final rows = _rowsWithKeysFromSnapshot(snap.data?.snapshot);

        // ✅ Urutkan terbaru di atas (ambil dari parser kuat)
        final sorted = List<Map<String, dynamic>>.from(rows)..sort((a, b) => _rowMillis(b).compareTo(_rowMillis(a)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laporan Masuk Terbaru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.all(12),
              child: sorted.isEmpty
                  ? const _EmptyInfo(text: 'Belum ada laporan masuk.')
                  : _HorizontalScroll(
                      minWidth: _responsiveTableWidth(context, max: 1200),
                      child: DataTable(
                        headingRowHeight: 46,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 60,
                        headingRowColor: WidgetStateProperty.all(kTableHeaderBlue),
                        headingTextStyle: kTableHeaderTextStyle,
                        columns: const [
                          DataColumn(label: Text('Tanggal')),
                          DataColumn(label: Text('TPS')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Detail')),
                          DataColumn(label: Text('Hapus')),
                        ],
                        rows: sorted.map((m) {
                          final key = (m['__key'] ?? '').toString();
                          final tanggal = _formatTanggal(m);
                          final tps = (m['tps'] ?? m['lokasi'] ?? m['location'] ?? '-').toString();
                          final status = (m['status'] ?? '-').toString();
                          final isDone = status.toLowerCase().contains('selesai');

                          return DataRow(cells: [
                            DataCell(Text(tanggal)),
                            DataCell(Text(tps)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDone ? AppColors.buttonBlue.withOpacity(0.15) : const Color(0xFFE9D5FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDone ? AppColors.buttonBlue : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              OutlinedButton(
                                onPressed: () => _openDetailSheet(context, m),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                                child: const Text('Detail'),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: key.isEmpty
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Hapus laporan?'),
                                            content: const SizedBox.shrink(),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Batal'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                child: const Text('Hapus'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (ok != true) return;

                                        try {
                                          await widget.laporanRef.child(key).remove();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Laporan berhasil dihapus.')),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Gagal menghapus laporan: $e')),
                                            );
                                          }
                                        }
                                      },
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// ================== SECTION: SARAN MASUK ==================

class _SaranMasukSection extends StatefulWidget {
  final Stream<DatabaseEvent> saranStream;
  final DatabaseReference saranRef;

  const _SaranMasukSection({
    required this.saranStream,
    required this.saranRef,
  });

  @override
  State<_SaranMasukSection> createState() => _SaranMasukSectionState();
}

class _SaranMasukSectionState extends State<_SaranMasukSection> {
  final Set<String> _deletingKeys = {};

  String _formatTanggal(Map<String, dynamic> m) {
    final dt = _tryParseDateTime(m);
    if (dt == null) return '-';
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final hari = _hariSingkatIndo(dt.weekday);
    return '$hari, ${dt.day} ${_bulanIndo(dt.month)} ${dt.year} • $h:$mi';
  }

  Future<void> _confirmAndDelete(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus saran?'),
        content: const SizedBox.shrink(),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deletingKeys.add(key));
    try {
      await widget.saranRef.child(key).remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saran berhasil dihapus.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus saran: $e')));
    } finally {
      if (mounted) setState(() => _deletingKeys.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: widget.saranStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorBox(text: 'Gagal memuat saran: ${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 160);
        }

        final items = _rowsWithKeysFromSnapshot(snap.data?.snapshot);

        final filtered = items
            .where((m) {
              final key = (m['__key'] ?? '').toString();
              return key.isNotEmpty && !_deletingKeys.contains(key);
            })
            .toList()
          ..sort((a, b) {
            final ta = _tryParseDateTime(a)?.millisecondsSinceEpoch ?? -1;
            final tb = _tryParseDateTime(b)?.millisecondsSinceEpoch ?? -1;
            return tb.compareTo(ta);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saran Masuk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FB),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(8),
              child: filtered.isEmpty
                  ? const _EmptyInfo(text: 'Belum ada saran.')
                  : ListView.separated(
                      itemCount: filtered.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final m = filtered[i];
                        final key = (m['__key'] ?? '').toString();
                        final isi = (m['isi'] ?? m['saran'] ?? m['message'] ?? m['text'] ?? '-').toString();
                        final email = (m['email'] ?? m['gmail'] ?? m['pengirim'] ?? '').toString();

                        final subtitle = '${_formatTanggal(m)}${email.isNotEmpty ? ' • $email' : ''}';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: const Icon(Icons.chat_bubble_outline, color: Colors.black54),
                          title: Text(
                            isi,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: key.isEmpty ? null : () => _confirmAndDelete(key),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// ================== TAB: PERMINTAAN PENDAFTARAN ==================

class _PermintaanTab extends StatelessWidget {
  final DatabaseReference usersRef;

  const _PermintaanTab({required this.usersRef});

  Uint8List? _decodeBase64(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  bool _isCampusRole(String role) {
    final r = role.toLowerCase();
    return r.contains('campus') || r.contains('kampus');
  }

  bool _isUserRole(String role) {
    final r = role.toLowerCase().trim();
    return r == 'user' || r.contains('user') || r.contains('warga');
  }

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = _responsiveMaxWidth(context);

    Future<void> _updateApproval(String uid, bool approve) async {
      await usersRef.child(uid).update({
        'approved': approve,
        'rejected': !approve,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Akun user disetujui dan dapat login.' : 'Akun user ditolak dan tidak dapat login.',
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PERMINTAAN PENDAFTARAN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.all(12),
                child: StreamBuilder<DatabaseEvent>(
                  stream: usersRef.onValue,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rows = _rowsWithKeysFromSnapshot(snap.data?.snapshot);

                    final pendingUser = rows.where((m) {
                      final role = (m['role'] ?? '').toString();
                      final approved = m['approved'] == true;
                      final rejected = m['rejected'] == true;

                      if (_isCampusRole(role)) return false;
                      if (!_isUserRole(role)) return false;
                      if (approved || rejected) return false;
                      return true;
                    }).toList();

                    if (pendingUser.isEmpty) {
                      return const _EmptyInfo(text: 'Belum ada permintaan pendaftaran user.');
                    }

                    return _HorizontalScroll(
                      minWidth: _responsiveTableWidth(context, max: 1200),
                      child: DataTable(
                        headingRowHeight: 46,
                        dataRowMinHeight: 58,
                        dataRowMaxHeight: 70,
                        headingRowColor: WidgetStateProperty.all(kTableHeaderBlue),
                        headingTextStyle: kTableHeaderTextStyle,
                        columns: const [
                          DataColumn(label: Text('Foto')),
                          DataColumn(label: Text('Nama')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('No HP')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('ID Petugas')),
                          DataColumn(label: Text('Aksi')),
                        ],
                        rows: pendingUser.map((m) {
                          final uid = (m['__key'] ?? '').toString();
                          final name = (m['name'] ?? '-').toString();
                          final email = (m['email'] ?? '-').toString();
                          final phone = (m['phone'] ?? '-').toString();
                          final role = (m['role'] ?? '-').toString();
                          final idPetugas = (m['idPetugas'] ?? m['id_petugas'] ?? m['petugasId'] ?? '-').toString();

                          final bytes = _decodeBase64(m['photoBase64']?.toString());
                          Widget avatar;
                          if (bytes != null) {
                            avatar = CircleAvatar(backgroundImage: MemoryImage(bytes));
                          } else if ((m['photoUrl'] ?? '').toString().isNotEmpty) {
                            avatar = CircleAvatar(backgroundImage: NetworkImage(m['photoUrl'].toString()));
                          } else {
                            avatar = CircleAvatar(
                              backgroundColor: const Color(0xFFE2E8F0),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                            );
                          }

                          final pillStyle = ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD9E6FF),
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          );

                          return DataRow(
                            cells: [
                              DataCell(avatar),
                              DataCell(Text(name)),
                              DataCell(Text(email)),
                              DataCell(Text(phone)),
                              DataCell(Text(role)),
                              DataCell(Text(idPetugas)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: uid.isEmpty ? null : () => _updateApproval(uid, true),
                                      style: pillStyle,
                                      child: const Text('Approve'),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: uid.isEmpty ? null : () => _updateApproval(uid, false),
                                      style: pillStyle,
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================== TAB: DATA PENGGUNA ==================

class _UsersScreen extends StatelessWidget {
  final Stream<DatabaseEvent> usersStream;

  const _UsersScreen({required this.usersStream});

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = _responsiveMaxWidth(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DATA PENGGUNA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.all(12),
                child: _UsersTable(stream: usersStream),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================== TAB: PROFIL ==================

class _ProfileScreen extends StatelessWidget {
  final Future<void> Function() onLogout;
  final DatabaseReference usersRef;

  const _ProfileScreen({
    required this.onLogout,
    required this.usersRef,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final maxContentWidth = _responsiveMaxWidth(context);

    if (user == null) {
      return const Center(child: Text('Belum login.'));
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: StreamBuilder<DatabaseEvent>(
            stream: usersRef.child(user.uid).onValue,
            builder: (context, snap) {
              final data = (snap.data?.snapshot.value as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};

              final name = (data['name'] ?? '-').toString();
              final role = (data['role'] ?? '-').toString();
              final emailDb = (data['email'] ?? '').toString();
              final email = (user.email ?? emailDb).isEmpty ? '-' : (user.email ?? emailDb);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'PROFILE',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 48,
                          backgroundColor: Color(0xFF143B6E),
                          child: Icon(Icons.person, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Role: $role', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => onLogout(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF143B6E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'LOGOUT',
                              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ================== SCROLL HELPER ==================

class _HorizontalScroll extends StatelessWidget {
  final Widget child;
  final double minWidth;
  const _HorizontalScroll({required this.child, this.minWidth = 900});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ================== MONITORING TABLE ==================

class _MonitoringTable extends StatelessWidget {
  final Stream<DatabaseEvent> stream;
  const _MonitoringTable({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorBox(text: 'Gagal memuat monitoring: ${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
        }
        final rows = _rowsFromSnapshot(snap.data?.snapshot);
        if (rows.isEmpty) {
          return const _EmptyInfo(text: 'Belum ada data monitoring.');
        }

        return _HorizontalScroll(
          minWidth: _responsiveTableWidth(context, max: 1200),
          child: DataTable(
            headingRowHeight: 46,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 60,
            headingRowColor: WidgetStateProperty.all(kTableHeaderBlue),
            headingTextStyle: kTableHeaderTextStyle,
            columns: const [
              DataColumn(label: Text('Lokasi/TPA/TPS')),
              DataColumn(label: Text('Jenis')),
              DataColumn(label: Text('Status')),
            ],
            rows: rows.map((e) {
              return DataRow(cells: [
                DataCell(Text((e['tps'] ?? e['tpa'] ?? e['lokasi'] ?? e['location'] ?? '-').toString())),
                DataCell(Text((e['jenis'] ?? e['type'] ?? e['kategori'] ?? '-').toString())),
                DataCell(Text((e['status'] ?? e['state'] ?? e['kondisi'] ?? '-').toString())),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

/// ================== RIWAYAT PENGANGKUTAN ==================

class _RiwayatPane extends StatefulWidget {
  final Stream<DatabaseEvent> stream;
  final DatabaseReference riwayatRef;
  final DatabaseReference usersRef;

  const _RiwayatPane({
    required this.stream,
    required this.riwayatRef,
    required this.usersRef,
  });

  @override
  State<_RiwayatPane> createState() => _RiwayatPaneState();
}

class _RiwayatPaneState extends State<_RiwayatPane> {
  Timer? _stuckTimer;
  bool _showStuckHint = false;

  final Map<String, String> _uidNameCache = {};
  bool _loadingNames = false;

  void _armStuckHint() {
    if (_stuckTimer != null) return;
    _stuckTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _showStuckHint = true);
    });
  }

  void _clearStuckHint() {
    _stuckTimer?.cancel();
    _stuckTimer = null;
    _showStuckHint = false;
  }

  @override
  void dispose() {
    _stuckTimer?.cancel();
    super.dispose();
  }

  String _fmtRow(Map<String, dynamic> m) {
    final dt = _tryParseDateTime(m);
    if (dt == null) return (m['tanggal']?.toString() ?? '-');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d-$mo-${dt.year} $h:$mi';
  }

  String _extractUid(Map<String, dynamic> m) {
    const keys = <String>[
      'uid',
      'userId',
      'user_id',
      'petugasUid',
      'petugas_uid',
      'officerUid',
      'officer_uid',
    ];
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _extractInlinePetugasName(Map<String, dynamic> m) {
    const keys = <String>[
      'petugasName',
      'namaPetugas',
      'nama_petugas',
      'petugas_nama',
      'officerName',
      'officer_name',
      'petugas',
    ];
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  /// ✅ FIX UTAMA FOTO:
  /// Ambil bukti foto dari berbagai kemungkinan key (termasuk buktiBase64 sesuai DB kamu).
  String _extractBuktiPhotoRaw(Map<String, dynamic> m) {
    const keys = <String>[
      // base64
      'buktiBase64',
      'bukti_base64',
      'buktiFotoBase64',
      'bukti_foto_base64',
      'fotoBase64',
      'foto_base64',
      'photoBase64',
      'photo_base64',

      // url / generic
      'fotoUrl',
      'foto_url',
      'photoUrl',
      'photo_url',
      'buktiFotoUrl',
      'bukti_foto_url',
      'imageUrl',
      'image_url',

      // fallback lama
      'buktiFoto',
      'bukti_foto',
      'foto',
      'photo',
    ];

    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) return s;
      } else {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  String _resolveActorName(Map<String, dynamic> m) {
    final inline = _extractInlinePetugasName(m);
    if (inline.isNotEmpty) return inline;

    final uid = _extractUid(m);
    if (uid.isEmpty) return '-';

    final cached = _uidNameCache[uid];
    if (cached != null && cached.trim().isNotEmpty && cached.trim() != '-') return cached;

    if (_loadingNames) return 'Memuat...';
    return 'Tidak diketahui';
  }

  Future<void> _ensureNamesForUids(Set<String> uids) async {
    final need = uids.where((u) => u.isNotEmpty && !_uidNameCache.containsKey(u)).toList();
    if (need.isEmpty || _loadingNames) return;

    setState(() => _loadingNames = true);
    try {
      final futures = need.take(30).map((uid) async {
        try {
          final snap = await widget.usersRef.child(uid).get();
          if (snap.value is Map) {
            final m = (snap.value as Map).map((k, v) => MapEntry(k.toString(), v));
            final name = (m['name'] ?? m['nama'] ?? m['fullName'] ?? m['username'] ?? m['displayName'] ?? m['email'] ?? '')
                .toString()
                .trim();
            _uidNameCache[uid] = name.isNotEmpty ? name : 'Tidak diketahui';
          } else {
            _uidNameCache[uid] = 'Tidak diketahui';
          }
        } catch (_) {
          _uidNameCache[uid] = 'Tidak diketahui';
        }
      }).toList();

      await Future.wait(futures);
    } finally {
      if (mounted) setState(() => _loadingNames = false);
    }
  }

  /// ✅ decode base64 lebih kuat (hapus whitespace + padding)
  Uint8List? _tryDecodeBase64Image(String raw) {
    if (raw.isEmpty) return null;

    try {
      var s = raw.trim();

      // kalau data URI
      if (s.startsWith('data:image')) {
        final idx = s.indexOf('base64,');
        if (idx != -1) s = s.substring(idx + 7);
      }

      // kalau url http, bukan base64
      if (s.startsWith('http://') || s.startsWith('https://')) return null;

      // bersihkan whitespace/newline
      s = s.replaceAll(RegExp(r'\s+'), '');

      // normalisasi base64 url-safe kalau ada
      s = s.replaceAll('-', '+').replaceAll('_', '/');

      // tambahkan padding agar panjang %4==0
      final mod = s.length % 4;
      if (mod != 0) {
        s += '=' * (4 - mod);
      }

      // heuristik: base64 image biasanya panjang
      if (s.length < 60) return null;

      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  void _openPhotoViewer(BuildContext context, String raw) {
    final bytes = _tryDecodeBase64Image(raw);

    showDialog(
      context: context,
      builder: (ctx) {
        Widget body;

        if (bytes != null) {
          body = InteractiveViewer(
            child: Image.memory(bytes, fit: BoxFit.contain),
          );
        } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
          body = InteractiveViewer(
            child: Image.network(
              raw,
              fit: BoxFit.contain,
              loadingBuilder: (c, w, p) {
                if (p == null) return w;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (c, e, s) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Gagal memuat foto (URL).', style: TextStyle(color: Colors.black54)),
                  ),
                );
              },
            ),
          );
        } else {
          body = const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Format bukti foto tidak valid / tidak terbaca.', style: TextStyle(color: Colors.black54)),
            ),
          );
        }

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 650),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Bukti Foto', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDetailPengangkutan(
    BuildContext context,
    Map<String, dynamic> m,
    String tgl,
    String tps,
    String jenis,
    String actor,
  ) {
    /// ✅ FIX: pakai extractor yang sudah support buktiBase64
    final fotoRaw = _extractBuktiPhotoRaw(m);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F7FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.60,
          minChildSize: 0.40,
          maxChildSize: 0.92,
          builder: (ctx, controller) {
            return _SheetFrame(
              title: 'Detail Pengangkutan',
              onClose: () => Navigator.pop(ctx),
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('Tanggal', tgl),
                    _kv('TPS', tps),
                    _kv('Jenis', jenis),
                    _kv('Petugas', actor),
                    const SizedBox(height: 10),
                    const Text('Bukti Foto', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (fotoRaw.isEmpty)
                      const Text('-', style: TextStyle(color: Colors.black54))
                    else
                      InkWell(
                        onTap: () => _openPhotoViewer(context, fotoRaw),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildPhotoPreview(fotoRaw, height: 180),
                        ),
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

  Future<void> _confirmAndDeleteRiwayat(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakin ingin menghapus?'),
        content: const SizedBox.shrink(),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.riwayatRef.child(key).remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat berhasil dihapus.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus riwayat: $e')));
    }
  }

  String _buildCsv(List<Map<String, dynamic>> rows) {
    final buf = StringBuffer();
    buf.writeln('Tanggal;TPS;Jenis;Petugas;BuktiFoto');

    for (final m in rows) {
      final tgl = _fmtRow(m);
      final tps = (m['tps'] ?? m['tpa'] ?? '-').toString();
      final jenis = _extractJenis(m).isNotEmpty ? _extractJenis(m) : (m['jenis'] ?? '-').toString();
      final uid = _extractUid(m);
      final inlineName = _extractInlinePetugasName(m);
      String actor;
      if (inlineName.isNotEmpty) {
        actor = inlineName;
      } else if (uid.isNotEmpty) {
        final cached = _uidNameCache[uid];
        actor = (cached != null && cached.trim().isNotEmpty && cached.trim() != '-') ? cached : 'Tidak diketahui';
      } else {
        actor = '-';
      }

      /// ✅ FIX: export juga buktiBase64 jika itu yang tersimpan
      final fotoRaw = _extractBuktiPhotoRaw(m);

      String esc(String s) {
        final t = s.replaceAll('"', '""');
        if (t.contains(';') || t.contains('\n') || t.contains('\r')) return '"$t"';
        return t;
      }

      buf.writeln('${esc(tgl)};${esc(tps)};${esc(jenis)};${esc(actor)};${esc(fotoRaw)}');
    }

    return buf.toString();
  }

  Future<void> _downloadCsv(List<Map<String, dynamic>> rows) async {
    final uids = <String>{};
    for (final r in rows) {
      final uid = _extractUid(r);
      if (uid.isNotEmpty) uids.add(uid);
    }
    await _ensureNamesForUids(uids);

    final csv = _buildCsv(rows);

    if (kIsWeb) {
      final now = DateTime.now();
      final y = now.year.toString();
      final mo = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final h = now.hour.toString().padLeft(2, '0');
      final mi = now.minute.toString().padLeft(2, '0');
      final filename = 'riwayat_pengangkutan_${y}${mo}${d}_${h}${mi}.csv';

      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();

      Future.delayed(const Duration(milliseconds: 120), () {
        html.Url.revokeObjectUrl(url);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV berhasil diunduh.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Auto-download CSV hanya tersedia di Flutter Web.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: widget.stream,
      builder: (context, riwSnap) {
        if (riwSnap.hasError) {
          return _ErrorBox(text: 'Gagal memuat riwayat: ${riwSnap.error}');
        }

        if (riwSnap.connectionState == ConnectionState.waiting && !riwSnap.hasData) {
          _armStuckHint();
          return SizedBox(
            height: 220,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text('Memuat riwayat pengangkutan...'),
                  if (_showStuckHint) ...[
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Jika loading terus, biasanya karena: (1) node /riwayat kosong atau path berbeda, (2) databaseURL tidak sesuai dengan project, atau (3) rules menolak akses. Cek Firebase Console → Realtime Database → Data → riwayat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        _clearStuckHint();

        final rawRows = _rowsWithKeysFromSnapshot(riwSnap.data?.snapshot);
        if (rawRows.isEmpty) {
          return const _EmptyInfo(text: 'Belum ada riwayat.');
        }

        final rows = List<Map<String, dynamic>>.from(rawRows)
          ..sort((a, b) {
            final ta = _tryParseDateTime(a)?.millisecondsSinceEpoch ?? -1;
            final tb = _tryParseDateTime(b)?.millisecondsSinceEpoch ?? -1;
            return tb.compareTo(ta);
          });

        final uids = <String>{};
        for (final r in rows) {
          final uid = _extractUid(r);
          if (uid.isNotEmpty) uids.add(uid);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _ensureNamesForUids(uids);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total data: ${rows.length}${_loadingNames ? " (memuat nama...)" : ""}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                ElevatedButton.icon(
                  onPressed: () async => await _downloadCsv(rows),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _HorizontalScroll(
              minWidth: _responsiveTableWidth(context, max: 1200),
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 70,
                headingRowColor: WidgetStateProperty.all(kTableHeaderBlue),
                headingTextStyle: kTableHeaderTextStyle,
                columns: const [
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('TPS')),
                  DataColumn(label: Text('Jenis')),
                  DataColumn(label: Text('Petugas')),
                  DataColumn(label: Text('Bukti Foto')),
                  DataColumn(label: Text('Detail')),
                  DataColumn(label: Text('Hapus')),
                ],
                rows: rows.map((m) {
                  final tgl = _fmtRow(m);
                  final tps = (m['tps'] ?? m['tpa'] ?? '-').toString();

                  /// ✅ gunakan extractor yang sama untuk table dan donut
                  final jenis = _extractJenis(m).isNotEmpty ? _extractJenis(m) : (m['jenis'] ?? '-').toString();

                  final key = (m['__key'] ?? '').toString();
                  final actor = _resolveActorName(m);

                  /// ✅ FIX: baca bukti foto dari buktiBase64 juga
                  final fotoRaw = _extractBuktiPhotoRaw(m);

                  return DataRow(cells: [
                    DataCell(Text(tgl)),
                    DataCell(Text(tps)),
                    DataCell(Text(jenis)),
                    DataCell(Text(actor)),
                    DataCell(
                      IconButton(
                        onPressed: fotoRaw.isEmpty ? null : () => _openPhotoViewer(context, fotoRaw),
                        icon: const Icon(Icons.image_outlined),
                      ),
                    ),
                    DataCell(
                      OutlinedButton(
                        onPressed: () => _openDetailPengangkutan(context, m, tgl, tps, jenis, actor),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: const Text('Detail'),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: key.isEmpty ? null : () => _confirmAndDeleteRiwayat(key),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// preview kecil untuk foto (network/base64)
Widget _buildPhotoPreview(String raw, {double height = 160}) {
  Uint8List? tryDecode() {
    if (raw.isEmpty) return null;

    try {
      var s = raw.trim();

      if (s.startsWith('data:image')) {
        final idx = s.indexOf('base64,');
        if (idx != -1) s = s.substring(idx + 7);
      }

      if (s.startsWith('http://') || s.startsWith('https://')) return null;

      s = s.replaceAll(RegExp(r'\s+'), '');
      s = s.replaceAll('-', '+').replaceAll('_', '/');

      final mod = s.length % 4;
      if (mod != 0) s += '=' * (4 - mod);

      if (s.length < 60) return null;

      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  final bytes = tryDecode();
  if (bytes != null) {
    return Image.memory(bytes, height: height, width: double.infinity, fit: BoxFit.cover);
  }

  return Image.network(
    raw,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    loadingBuilder: (c, w, p) {
      if (p == null) return w;
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    },
    errorBuilder: (c, e, s) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Gagal memuat foto', style: TextStyle(color: Colors.black54))),
      );
    },
  );
}

/// ================== USERS TABLE ==================

class _UsersTable extends StatelessWidget {
  final Stream<DatabaseEvent> stream;
  const _UsersTable({required this.stream});

  Uint8List? _decodeBase64(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorBox(text: 'Gagal memuat pengguna: ${snap.error}');
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = _rowsFromSnapshot(snap.data?.snapshot);
        if (rows.isEmpty) {
          return const _EmptyInfo(text: 'Belum ada data pengguna.');
        }

        return _HorizontalScroll(
          minWidth: _responsiveTableWidth(context, max: 1200),
          child: DataTable(
            headingRowHeight: 46,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 70,
            headingRowColor: WidgetStateProperty.all(kTableHeaderBlue),
            headingTextStyle: kTableHeaderTextStyle,
            columns: const [
              DataColumn(label: Text('Foto')),
              DataColumn(label: Text('Nama')),
              DataColumn(label: Text('Gmail')),
              DataColumn(label: Text('No Hp')),
            ],
            rows: rows.map((m) {
              final name = (m['name'] ?? '-').toString();
              final email = (m['email'] ?? '-').toString();
              final phone = (m['phone'] ?? '-').toString();

              final bytes = _decodeBase64(m['photoBase64']?.toString());
              Widget avatar;
              if (bytes != null) {
                avatar = CircleAvatar(backgroundImage: MemoryImage(bytes));
              } else if ((m['photoUrl'] ?? '').toString().isNotEmpty) {
                avatar = CircleAvatar(backgroundImage: NetworkImage(m['photoUrl'].toString()));
              } else {
                avatar = const CircleAvatar(child: Icon(Icons.person, size: 18));
              }

              return DataRow(cells: [
                DataCell(avatar),
                DataCell(Text(name)),
                DataCell(Text(email)),
                DataCell(Text(phone)),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

/// ================== BOTTOMSHEET FRAME + KV ==================

class _SheetFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;

  const _SheetFrame({
    required this.title,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Flexible(child: child),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

/// ================== HELPERS ==================

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.red)),
    );
  }
}

class _EmptyInfo extends StatelessWidget {
  final String text;
  const _EmptyInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}

/// ================== SNAPSHOT -> ROWS ==================

List<Map<String, dynamic>> _rowsFromSnapshot(DataSnapshot? snapshot) {
  final raw = snapshot?.value;
  if (raw == null) return [];

  Map<String, dynamic> normalizeMap(Map m) => m.map((k, v) => MapEntry(k.toString(), v));

  if (raw is Map) {
    final out = <Map<String, dynamic>>[];
    for (final e in raw.values) {
      if (e is Map) out.add(normalizeMap(e));
    }
    return out;
  }

  if (raw is List) {
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) out.add(normalizeMap(e));
    }
    return out;
  }

  return [];
}

List<Map<String, dynamic>> _rowsWithKeysFromSnapshot(DataSnapshot? snapshot) {
  final out = <Map<String, dynamic>>[];
  if (snapshot == null) return out;

  for (final c in snapshot.children) {
    final v = c.value;
    if (v is Map) {
      final m = v.map((k, vv) => MapEntry(k.toString(), vv));
      m['__key'] = c.key;
      out.add(Map<String, dynamic>.from(m));
    }
  }

  if (out.isEmpty && snapshot.value is Map) {
    final raw = snapshot.value as Map;
    raw.forEach((k, v) {
      if (v is Map) {
        final m = v.map((kk, vv) => MapEntry(kk.toString(), vv));
        m['__key'] = k.toString();
        out.add(Map<String, dynamic>.from(m));
      }
    });
  }

  return out;
}

/// ================== PARSER WAKTU (FIX TANGGAL '-') ==================

int? _tryParseMillis(dynamic ts) {
  if (ts == null) return null;

  int normalizeEpoch(int v) {
    // deteksi seconds vs millis (seconds ~ 1_7xx_xxx_xxx)
    if (v > 0 && v < 1000000000000) return v * 1000;
    return v;
  }

  if (ts is int) return normalizeEpoch(ts);
  if (ts is double) return normalizeEpoch(ts.toInt());
  if (ts is String) {
    final i = int.tryParse(ts.trim());
    if (i != null) return normalizeEpoch(i);
  }
  return null;
}

/// decode push key Firebase (8 char pertama => timestamp)
int? _tryParseMillisFromPushKey(String key) {
  if (key.length < 8) return null;
  const pushChars = '-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz';

  int ts = 0;
  for (int i = 0; i < 8; i++) {
    final idx = pushChars.indexOf(key[i]);
    if (idx < 0) return null;
    ts = ts * 64 + idx;
  }
  return ts;
}

/// parser string tanggal lebih kuat (dd-MM / yyyy-MM / ISO, dll)
DateTime? _tryParseDateString(String s) {
  final v = s.trim();
  if (v.isEmpty) return null;

  // coba ISO dulu
  final iso = DateTime.tryParse(v);
  if (iso != null) return iso;

  // dd-MM-yyyy HH:mm(:ss)
  final re1 = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$');
  final m1 = re1.firstMatch(v);
  if (m1 != null) {
    final d = int.tryParse(m1.group(1)!);
    final mo = int.tryParse(m1.group(2)!);
    final y = int.tryParse(m1.group(3)!);
    final hh = int.tryParse(m1.group(4) ?? '0') ?? 0;
    final mm = int.tryParse(m1.group(5) ?? '0') ?? 0;
    final ss = int.tryParse(m1.group(6) ?? '0') ?? 0;
    if (y != null && mo != null && d != null) return DateTime(y, mo, d, hh, mm, ss);
  }

  // yyyy-MM-dd HH:mm(:ss)
  final re2 = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$');
  final m2 = re2.firstMatch(v);
  if (m2 != null) {
    final y = int.tryParse(m2.group(1)!);
    final mo = int.tryParse(m2.group(2)!);
    final d = int.tryParse(m2.group(3)!);
    final hh = int.tryParse(m2.group(4) ?? '0') ?? 0;
    final mm = int.tryParse(m2.group(5) ?? '0') ?? 0;
    final ss = int.tryParse(m2.group(6) ?? '0') ?? 0;
    if (y != null && mo != null && d != null) return DateTime(y, mo, d, hh, mm, ss);
  }

  return null;
}

dynamic _pickTimestampValue(Map<String, dynamic> m) {
  const keys = [
    'timestamp',
    'time',
    'waktu',
    'createdAt',
    'created_at',
    'created_at_ms',
    'updatedAt',
    'updated_at',
    'laporAt',
    'reportedAt',
    'reportAt',
    'tanggalLapor',
    'tanggal_lapor',
  ];
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return m[k];
  }
  return null;
}

dynamic _pickTanggalString(Map<String, dynamic> m) {
  const keys = [
    'tanggal',
    'date',
    'datetime',
    'waktu',
    'createdAt',
    'created_at',
  ];
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is String && v.trim().isNotEmpty) return v;
  }
  return null;
}

DateTime? _tryParseDateTime(Map<String, dynamic> m) {
  // 1) epoch millis/seconds dari banyak key
  final tsVal = _pickTimestampValue(m);
  final ms = _tryParseMillis(tsVal);
  if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);

  // 2) string tanggal dari banyak key
  final sVal = _pickTanggalString(m);
  if (sVal != null) {
    final dt = _tryParseDateString(sVal.toString());
    if (dt != null) return dt;
  }

  // 3) fallback: push key
  final key = (m['__key'] ?? '').toString();
  final pushMs = _tryParseMillisFromPushKey(key);
  if (pushMs != null) return DateTime.fromMillisecondsSinceEpoch(pushMs);

  return null;
}

/// ================== FIX DONUT: EXTRACT & PARSE JENIS ==================

String _extractJenis(Map<String, dynamic> m) {
  const keys = [
    'jenis',
    'jenisSampah',
    'jenis_sampah',
    'type',
    'kategori',
    'category',
    'trashType',
  ];
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

_JenisSampah? _parseJenisBucket(String raw) {
  final v = raw.toLowerCase().trim().replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');

  // penting: cek anorganik dulu karena "anorganik" mengandung substring "organik"
  if (v.contains('anorganik')) return _JenisSampah.anorganik;
  if (v.contains('non organik') || (v.contains('non') && v.contains('organik'))) return _JenisSampah.anorganik;
  if (v.contains('organik')) return _JenisSampah.organik;

  // selain itu: TIDAK dihitung
  return null;
}

/// ==== Helper nama bulan & hari Indonesia ====

String _bulanIndo(int month) {
  const nama = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  if (month < 1 || month > 12) return '';
  return nama[month];
}

String _hariSingkatIndo(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'SEN';
    case DateTime.tuesday:
      return 'SEL';
    case DateTime.wednesday:
      return 'RAB';
    case DateTime.thursday:
      return 'KAM';
    case DateTime.friday:
      return 'JUM';
    case DateTime.saturday:
      return 'SAB';
    case DateTime.sunday:
      return 'MIN';
    default:
      return '';
  }
}
