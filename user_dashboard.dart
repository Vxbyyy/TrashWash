import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:excel/excel.dart' as xls;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../ui/theme.dart';

/// =================== HELPER TANGGAL DINAMIS ===================

String _formatMonthYear(DateTime date) {
  const months = [
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
  return '${months[date.month - 1]} ${date.year}';
}

String _weekdayShort(DateTime date) {
  switch (date.weekday) {
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

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _tpsSortKey(String s) {
  final m = RegExp(r'(\d+)').firstMatch(s);
  if (m == null) return 1 << 30;
  return int.tryParse(m.group(1)!) ?? (1 << 30);
}

int sortByTpsLabel(String a, String b) {
  final ka = _tpsSortKey(a);
  final kb = _tpsSortKey(b);
  if (ka != kb) return ka.compareTo(kb);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// =================== FIX: EKSTRAK WAKTU MULTI-FIELD (createdAt/createdAtIso/timestamp/handledAt) ===================

int _msFromDynamic(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  final parsed = int.tryParse(v.toString());
  if (parsed != null) return parsed;
  return 0;
}

int _extractMs(Map<String, dynamic> m) {
  // Prioritas: createdAt -> timestamp -> handledAt
  int ms = _msFromDynamic(m['createdAt']);
  if (ms <= 0) ms = _msFromDynamic(m['timestamp']);
  if (ms <= 0) ms = _msFromDynamic(m['handledAt']);
  if (ms > 0) return ms;

  // Fallback ISO: createdAtIso -> handledAtIso
  final iso = (m['createdAtIso'] ?? m['handledAtIso'] ?? '').toString().trim();
  if (iso.isNotEmpty) {
    try {
      return DateTime.parse(iso).millisecondsSinceEpoch;
    } catch (_) {}
  }
  return 0;
}

Future<String?> pickImageBase64(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final XFile? x =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return base64Encode(bytes);
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
    return null;
  }
}

const Color _kOrganikColor = Color(0xFF2ECC71);
const Color _kNonOrganikColor = Color(0xFFF1C40F);
const Color _kHeaderBlue = Color(0xFF143B6E);

/// ✅ FIX UI SERAGAM HEADER
const double _kHeaderCellHeight = 48; // tinggi header tabel seragam

/// Tab sesuai Figma:
///  - Dashboard (Home)
///  - Monitoring
///  - Riwayat
///  - Profile
enum UserTab { dashboard, monitoring, riwayat, profile }

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  UserTab _tab = UserTab.dashboard;

  FirebaseDatabase _db() => FirebaseDatabase.instance;

  DatabaseReference get _refUsers => _db().ref('users');
  DatabaseReference get _refMonitoring => _db().ref('monitoring');
  DatabaseReference get _refRiwayat => _db().ref('riwayat'); // ✅ node kamu: riwayat

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    late final Widget content;
    switch (_tab) {
      case UserTab.dashboard:
        content = _DashboardHomePane(
          uid: uid,
          // ✅ Beranda ambil data dari node riwayat, khusus uid petugas
          riwayatStream: _refRiwayat.orderByChild('uid').equalTo(uid).onValue,
        );
        break;
      case UserTab.monitoring:
        content = _MonitoringPane(
          stream: _refMonitoring.onValue,
          baseRef: _refMonitoring,
          uid: uid,
        );
        break;
      case UserTab.riwayat:
        content = _RiwayatPane(
          stream: _refRiwayat.orderByChild('uid').equalTo(uid).onValue,
          fallbackStream: _refRiwayat.onValue,
          baseRef: _refRiwayat,
          uid: uid,
        );
        break;
      case UserTab.profile:
        content = _ProfilePane(userRef: _refUsers.child(uid));
        break;
    }

    String appBarTitle;
    switch (_tab) {
      case UserTab.dashboard:
        appBarTitle = 'Dashboard Petugas';
        break;
      case UserTab.monitoring:
        appBarTitle = 'Monitoring Petugas';
        break;
      case UserTab.riwayat:
        appBarTitle = 'Riwayat Petugas';
        break;
      case UserTab.profile:
        appBarTitle = 'Profile Petugas';
        break;
    }

    // ✅ diminta: hapus teks DASHBOARD / MONITORING / RIWAYAT / PROFIL di dalam card
    const String cardTitle = '';

    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      appBar: AppBar(
        backgroundColor: AppColors.lightBlue,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.black87,
        title: Text(appBarTitle, style: titleSerif(20)),
      ),

      /// ✅ FIX #1: KARTU PUTIH LEBIH LEBAR
      /// Dulu padding luar 16 + padding card 18 => sisi kiri/kanan jadi sempit.
      /// Sekarang padding luar diperkecil.
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
          child: _tab == UserTab.profile
              ? content
              : _DashboardCard(title: cardTitle, child: content),
        ),
      ),
      bottomNavigationBar: _FigmaBottomNav(
        currentTab: _tab,
        onChanged: (t) => setState(() => _tab = t),
      ),
    );
  }
}

/// =================== CUSTOM BOTTOM NAV (mirip Figma) ===================

class _FigmaBottomNav extends StatelessWidget {
  final UserTab currentTab;
  final ValueChanged<UserTab> onChanged;

  const _FigmaBottomNav({
    required this.currentTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const bgBar = Color(0xFFE9EDF3);
    const activeFill = Color(0xFFBFD7FF);
    const activeColor = Color(0xFF0F4C5C);
    const inactiveColor = Color(0xFF1E4353);

    Widget item({
      required UserTab tab,
      required IconData icon,
      required String label,
    }) {
      final isActive = currentTab == tab;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => onChanged(tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? activeFill : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.lightBlue,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        child: Container(
          height: 82,
          color: bgBar,
          child: Row(
            children: [
              item(
                  tab: UserTab.dashboard,
                  icon: Icons.home_filled,
                  label: 'Beranda'),
              item(
                  tab: UserTab.monitoring,
                  icon: Icons.show_chart,
                  label: 'Monitoring'),
              item(
                  tab: UserTab.riwayat,
                  icon: Icons.assignment_outlined,
                  label: 'Riwayat'),
              item(tab: UserTab.profile, icon: Icons.person, label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashboardCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        /// ✅ FIX #1 lanjutan: padding card diperkecil agar konten putih lebih lebar
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.trim().isNotEmpty) ...[
              Text(title, style: titleSerif(24)),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================================================
///                               DASHBOARD / HOME
/// =======================================================================

class _DashboardHomePane extends StatelessWidget {
  final String uid;
  final Stream<DatabaseEvent> riwayatStream;

  const _DashboardHomePane({
    required this.uid,
    required this.riwayatStream,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final lastWeekStart = startOfWeek.subtract(const Duration(days: 7));
    final lastWeekEnd = startOfWeek;

    final List<DateTime> days = List.generate(5, (index) {
      return today.add(Duration(days: index - 2));
    });

    const dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return StreamBuilder<DatabaseEvent>(
      stream: riwayatStream,
      builder: (context, snap) {
        int totalHariIni = 0;
        int totalMingguIni = 0;
        int organik = 0;
        int anorganik = 0;

        final List<int> thisWeekDaily = List.filled(7, 0);
        final List<int> lastWeekDaily = List.filled(7, 0);

        void processRow(dynamic row) {
          if (row is! Map) return;
          final m = row.map((kk, vv) => MapEntry(kk.toString(), vv));

          final rowUid = m['uid']?.toString();
          if (rowUid != null && rowUid.isNotEmpty && rowUid != uid) return;

          final jenisRaw = (m['jenis'] ?? '').toString().toLowerCase().trim();
          final isJenisValid =
              jenisRaw.isNotEmpty && jenisRaw != '-' && jenisRaw != 'null';

          if (isJenisValid) {
            final isNonOrganik = jenisRaw.contains('anorganik') ||
                jenisRaw.contains('non organik') ||
                jenisRaw.contains('non-organik') ||
                jenisRaw.contains('nonorganik');

            final isOrganik = jenisRaw.contains('organik');

            if (isNonOrganik) {
              anorganik++;
            } else if (isOrganik) {
              organik++;
            }
          }

          DateTime? dt;
          final ms = _extractMs(Map<String, dynamic>.from(m));
          if (ms > 0) dt = DateTime.fromMillisecondsSinceEpoch(ms);

          if (dt == null && m['tanggal'] != null) {
            final tglStr = m['tanggal'].toString().trim();
            final parts = tglStr.split('-');
            if (parts.length >= 3) {
              try {
                final y = int.parse(parts[0]);
                final mo = int.parse(parts[1]);
                final d = int.parse(parts[2]);
                dt = DateTime(y, mo, d);
              } catch (_) {}
            }
          }

          if (dt == null) return;

          final d = DateTime(dt.year, dt.month, dt.day);

          if (_isSameDate(d, today)) {
            totalHariIni++;
          }

          if (!d.isBefore(startOfWeek) && d.isBefore(endOfWeek)) {
            totalMingguIni++;
            final idx = d.weekday - 1;
            if (idx >= 0 && idx < 7) thisWeekDaily[idx]++;
          }

          if (!d.isBefore(lastWeekStart) && d.isBefore(lastWeekEnd)) {
            final idx = d.weekday - 1;
            if (idx >= 0 && idx < 7) lastWeekDaily[idx]++;
          }
        }

        final raw = snap.data?.snapshot.value;
        if (raw is Map) {
          raw.forEach((_, v) => processRow(v));
        } else if (raw is List) {
          for (final v in raw) {
            processRow(v);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _TopStatCard(
                    label: 'Total Pengangkutan Hari Ini',
                    value: totalHariIni.toString(),
                    icon: Icons.local_shipping_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TopStatCard(
                    label: 'Total Pengangkutan Minggu Ini',
                    value: totalMingguIni.toString(),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Distribusi Jenis Sampah Yang Sudah Diangkut',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _DistribusiDonut(organik: organik, anorganik: anorganik),
            const SizedBox(height: 24),
            Text(
              _formatMonthYear(today),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in days)
                  _DateBubble(
                    day: d.day.toString().padLeft(1, '0'),
                    label: _weekdayShort(d),
                    isActive: _isSameDate(d, today),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _WeeklyCompareSection(
              labels: dayLabels,
              thisWeek: thisWeekDaily,
              lastWeek: lastWeekDaily,
            ),
          ],
        );
      },
    );
  }
}

class _TopStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _TopStatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.buttonBlue.withOpacity(0.12),
            ),
            child: Icon(icon, size: 18, color: AppColors.buttonBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _DistribusiDonut extends StatelessWidget {
  final int organik;
  final int anorganik;

  const _DistribusiDonut({
    required this.organik,
    required this.anorganik,
  });

  @override
  Widget build(BuildContext context) {
    final total = organik + anorganik;

    final double ratioOrganik = total == 0 ? 0.0 : (organik / total);
    final int percentOrganik = total == 0 ? 0 : (ratioOrganik * 100).round();
    final int percentAnorganik = total == 0 ? 0 : 100 - percentOrganik;

    const double ringThickness = 54;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 520;

          final donut = SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(240, 240),
                  painter: _DonutPainter(
                    ratio: ratioOrganik,
                    strokeWidth: ringThickness,
                    organikColor: _kOrganikColor,
                    nonOrganikColor: _kNonOrganikColor,
                  ),
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percentOrganik%',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Total Task',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          );

          final legend = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendRow(
                color: _kOrganikColor,
                label: 'Organik',
                percent: percentOrganik,
              ),
              const SizedBox(height: 12),
              _LegendRow(
                color: _kNonOrganikColor,
                label: 'Non-organik',
                percent: percentAnorganik,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                donut,
                const SizedBox(height: 16),
                legend,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: 40),
              legend,
            ],
          );
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double ratio; // 0..1
  final double strokeWidth;
  final Color organikColor;
  final Color nonOrganikColor;

  _DonutPainter({
    required this.ratio,
    required this.strokeWidth,
    required this.organikColor,
    required this.nonOrganikColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0);

    final center = Offset(size.width / 2, size.height / 2);

    final radius =
        (math.min(size.width, size.height) / 2) - (strokeWidth / 2) - 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = -math.pi / 2;
    const full = 2 * math.pi;

    final basePaint = Paint()
      ..isAntiAlias = true
      ..color = nonOrganikColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final orgPaint = Paint()
      ..isAntiAlias = true
      ..color = organikColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, full, false, basePaint);

    final sweep = full * r;
    if (sweep > 0) {
      canvas.drawArc(rect, startAngle, sweep, false, orgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.organikColor != organikColor ||
        oldDelegate.nonOrganikColor != nonOrganikColor;
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int percent;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text(
            '$percent%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DateBubble extends StatelessWidget {
  final String day;
  final String label;
  final bool isActive;
  const _DateBubble(
      {required this.day, required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? AppColors.buttonBlue : Colors.white;
    final fg = isActive ? Colors.white : Colors.black87;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.buttonBlue : Colors.black26,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            day,
            style:
                TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: fg, fontSize: 10)),
        ],
      ),
    );
  }
}

class _WeeklyCompareSection extends StatelessWidget {
  final List<String> labels;
  final List<int> thisWeek;
  final List<int> lastWeek;

  const _WeeklyCompareSection({
    required this.labels,
    required this.thisWeek,
    required this.lastWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
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
            height: 260,
            width: double.infinity,
            child: Column(
              children: [
                Expanded(
                  child: _WeeklyLineCompareChart(
                    labels: labels,
                    thisWeek: thisWeek,
                    lastWeek: lastWeek,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _LineLegendItem(
                        color: _kNonOrganikColor, label: 'Minggu lalu'),
                    SizedBox(width: 24),
                    _LineLegendItem(color: _kHeaderBlue, label: 'Minggu ini'),
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
    required thisWeek,
    required lastWeek,
  })  : thisWeek = thisWeek,
        lastWeek = lastWeek;

  @override
  Widget build(BuildContext context) {
    if (labels.length != thisWeek.length ||
        labels.length != lastWeek.length ||
        labels.isEmpty) {
      return const Center(
        child: Text('Belum ada data untuk grafik.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
      );
    }

    const int safeMax = 10;

    return Column(
      children: [
        Expanded(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _WeeklyLinePainter(
                thisWeek: thisWeek,
                lastWeek: lastWeek,
                maxValue: safeMax,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10)),
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
    required this.thisWeek,
    required this.lastWeek,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const rightMargin = 12.0;
    const topMargin = 8.0;
    const bottomMargin = 20.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    );

    const yTicks = [2, 4, 6, 8, 10];

    for (final value in yTicks) {
      final dy = topMargin + chartHeight * (1 - (value / maxValue));

      canvas.drawLine(
        Offset(leftMargin, dy),
        Offset(leftMargin + chartWidth, dy),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: value.toString(),
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout(minWidth: 24);
      textPainter.paint(
        canvas,
        Offset(leftMargin - 6 - textPainter.width, dy - 6),
      );
    }

    canvas.drawLine(
      Offset(leftMargin, topMargin),
      Offset(leftMargin, topMargin + chartHeight),
      gridPaint,
    );

    final n = thisWeek.length;
    if (n < 2) return;

    final dx = chartWidth / (n - 1);
    double x(int i) => leftMargin + dx * i;

    double y(int v) {
      final vv = v.clamp(0, maxValue);
      return topMargin + chartHeight * (1 - (vv / maxValue));
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
      ..color = _kNonOrganikColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final thisPaint = Paint()
      ..color = _kHeaderBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(lastWeekPath, lastPaint);
    canvas.drawPath(thisWeekPath, thisPaint);

    const dotRadius = 4.0;
    final dotPaintLast = Paint()..color = _kNonOrganikColor;
    final dotPaintThis = Paint()..color = _kHeaderBlue;

    for (int i = 0; i < n; i++) {
      final px = x(i);
      canvas.drawCircle(Offset(px, y(lastWeek[i])), dotRadius, dotPaintLast);
      canvas.drawCircle(Offset(px, y(thisWeek[i])), dotRadius, dotPaintThis);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyLinePainter oldDelegate) {
    return oldDelegate.thisWeek != thisWeek ||
        oldDelegate.lastWeek != lastWeek ||
        oldDelegate.maxValue != maxValue;
  }
}

class _LineLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LineLegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// =======================================================================
///                               PROFILE
/// =======================================================================

class _ProfilePane extends StatefulWidget {
  final DatabaseReference userRef;
  const _ProfilePane({required this.userRef});
  @override
  State<_ProfilePane> createState() => _ProfilePaneState();
}

class _ProfilePaneState extends State<_ProfilePane> {
  bool _busy = false;
  bool _dirty = false;
  String? _pendingPhotoB64;

  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _phoneC = TextEditingController();

  String? _initialName;
  String? _initialPhone;

  late final Stream<DatabaseEvent> _userStream;

  Uint8List? _cachedPhotoBytes;
  String? _lastPhotoB64;

  @override
  void initState() {
    super.initState();
    _userStream = widget.userRef.onValue;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  Future<void> _uploadPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? x =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (x == null) return;

      final Uint8List bytes = await x.readAsBytes();
      final String b64 = base64Encode(bytes);

      setState(() {
        _pendingPhotoB64 = b64;
        _cachedPhotoBytes = bytes;
        _lastPhotoB64 = b64;
        _dirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
    }
  }

  Uint8List? _decodeBase64(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_busy || !_dirty) return;

    try {
      setState(() => _busy = true);

      final String newName = _nameC.text.trim();
      final String newPhone = _phoneC.text.trim();

      final Map<String, Object?> data = {'updatedAt': ServerValue.timestamp};

      if (_pendingPhotoB64 != null) data['photoBase64'] = _pendingPhotoB64;

      if (newName.isNotEmpty && newName != _initialName) data['name'] = newName;
      if (newPhone.isNotEmpty && newPhone != _initialPhone) {
        data['phone'] = newPhone;
      }

      await widget.userRef.update(data);

      if (!mounted) return;
      setState(() {
        _initialName = newName;
        _initialPhone = newPhone;
        _pendingPhotoB64 = null;
        _dirty = false;
        _busy = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil disimpan')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _userStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !_dirty) {
          return const Center(child: CircularProgressIndicator());
        }

        final raw = snap.data?.snapshot.value;
        final map = (raw is Map)
            ? raw.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};

        final name = (map['name'] ?? '').toString();
        final email = (map['email'] ?? '-').toString();
        final phone = (map['phone'] ?? '').toString();
        final photoB64FromDb = (map['photoBase64'] ?? '').toString();

        if (!_dirty) {
          _nameC.text = name;
          _phoneC.text = phone;
          _initialName = name;
          _initialPhone = phone;
        }

        final effectivePhotoB64 = _pendingPhotoB64 ?? photoB64FromDb;

        if (effectivePhotoB64 != _lastPhotoB64) {
          _lastPhotoB64 = effectivePhotoB64;
          _cachedPhotoBytes = _decodeBase64(effectivePhotoB64);
        }
        final bytes = _cachedPhotoBytes;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.white),
                      padding: const EdgeInsets.all(8),
                      child: ClipOval(
                        child: bytes != null
                            ? Image.memory(bytes, fit: BoxFit.cover)
                            : Container(
                                color: Colors.black12.withOpacity(0.1),
                                alignment: Alignment.center,
                                child: const Icon(Icons.person,
                                    size: 60, color: Colors.black54),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 260,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _uploadPhoto,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                              color: Color(0xFF24588C), width: 1),
                        ),
                        icon: const Icon(Icons.image,
                            size: 16, color: Color(0xFF24588C)),
                        label: const Text('Pilih Foto Profil',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF24588C))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _EditableProfileField(
                label: 'Nama',
                controller: _nameC,
                keyboardType: TextInputType.name,
                onChanged: (_) =>
                    !_dirty ? setState(() => _dirty = true) : null,
              ),
              const SizedBox(height: 12),
              _ProfileField(label: 'Email', value: email),
              const SizedBox(height: 12),
              _EditableProfileField(
                label: 'No HP',
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                onChanged: (_) =>
                    !_dirty ? setState(() => _dirty = true) : null,
              ),
              const SizedBox(height: 32),
              if (_dirty)
                Center(
                  child: SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF24588C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: Text(_busy ? 'MENYIMPAN...' : 'SIMPAN',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) context.go('/');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text('LOGOUT',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditableProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _EditableProfileField({
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26, width: 1),
              ),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: onChanged,
                decoration: const InputDecoration(
                    border: InputBorder.none, isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26, width: 1),
              ),
              child: Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================================================
///                               MONITORING
/// =======================================================================

class _MonitoringPane extends StatelessWidget {
  final Stream<DatabaseEvent> stream;
  final DatabaseReference baseRef; // ref('monitoring')
  final String uid;

  const _MonitoringPane({
    required this.stream,
    required this.baseRef,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final rootRef = baseRef.parent!;
    final riwayatRef = rootRef.child('riwayat'); // ✅ node kamu: riwayat
    final laporanCampusRef = rootRef.child('laporan_kampus');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    String todayYmd() {
      final n = DateTime.now();
      return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    }

    DatabaseReference refForPath(String path) {
      var ref = baseRef;
      for (final seg in path.split('/')) {
        if (seg.trim().isEmpty) continue;
        ref = ref.child(seg);
      }
      return ref;
    }

    Future<void> pushRiwayatWithBukti({
      required String tps,
      required String jenis,
      required String status,
      required String? buktiBase64,
      String? source,
      String? document,
    }) async {
      await riwayatRef.push().set({
        'tanggal': todayYmd(),
        'tps': tps.trim().isEmpty ? '-' : tps.trim(),
        'jenis': jenis.trim().isEmpty ? '-' : jenis.trim(),
        'status': status,
        'uid': uid,
        'timestamp': ServerValue.timestamp,
        if (buktiBase64 != null && buktiBase64.isNotEmpty)
          'buktiBase64': buktiBase64,
        if (source != null) 'source': source,
        if (document != null) 'document': document,
      });
    }

    Widget buildIotTable({
      required List<MapEntry<String, Map<String, dynamic>>> entries,
      required String emptyText,
    }) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: entries.isEmpty
            ? _EmptyInfo(text: emptyText)
            : Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.1),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.0),
                  3: FlexColumnWidth(1.3),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey, width: 1),
                ),
                children: [
                  const TableRow(
                    children: [
                      _MonHeaderCell('TPS'),
                      _MonHeaderCell('Jenis'),
                      _MonHeaderCell('Status'),
                      _MonHeaderCell('Aksi'),
                    ],
                  ),
                  ...entries.map((e) {
                    final pathKey = e.key;
                    final data = e.value;

                    final tps = (data['tps'] ?? data['tpa'] ?? '-').toString();

                    final so = (data['statusOrganik'] ?? '').toString().trim();
                    final sn =
                        (data['statusNonOrganik'] ?? '').toString().trim();

                    final bool hasDualStatus = so.isNotEmpty || sn.isNotEmpty;

                    final bool organikPenuh =
                        so.toLowerCase().trim() == 'penuh';
                    final bool nonOrganikPenuh =
                        sn.toLowerCase().trim() == 'penuh';

                    final rawStatusFallback =
                        (data['status'] ?? 'Normal').toString().trim();
                    final bool fallbackPenuh =
                        rawStatusFallback.toLowerCase() == 'penuh';

                    final bool isPenuh = hasDualStatus
                        ? (organikPenuh || nonOrganikPenuh)
                        : fallbackPenuh;

                    final statusLabel = isPenuh ? 'Penuh' : 'Normal';
                    final canSelesai = isPenuh;

                    String jenisTampil = '-';
                    if (hasDualStatus) {
                      if (organikPenuh && nonOrganikPenuh) {
                        jenisTampil = 'Organik & Non-organik';
                      } else if (organikPenuh) {
                        jenisTampil = 'Organik';
                      } else if (nonOrganikPenuh) {
                        jenisTampil = 'Non-organik';
                      }
                    } else {
                      final j = (data['jenis'] ?? '-').toString().trim();
                      jenisTampil = j.isEmpty ? '-' : j;
                    }

                    Future<void> markSelesaiIot() async {
                      if (!canSelesai) return;

                      if (hasDualStatus) {
                        if (organikPenuh) {
                          await pushRiwayatWithBukti(
                            tps: tps,
                            jenis: 'Organik',
                            status: 'Selesai',
                            buktiBase64: null,
                            source: 'iot',
                            document: 'ESP32_1',
                          );
                        }
                        if (nonOrganikPenuh) {
                          await pushRiwayatWithBukti(
                            tps: tps,
                            jenis: 'Non-organik',
                            status: 'Selesai',
                            buktiBase64: null,
                            source: 'iot',
                            document: 'ESP32_1',
                          );
                        }
                      } else {
                        await pushRiwayatWithBukti(
                          tps: tps,
                          jenis: jenisTampil,
                          status: 'Selesai',
                          buktiBase64: null,
                          source: 'iot',
                          document: 'ESP32_1',
                        );
                      }

                      await refForPath(pathKey).update({
                        'status': 'Normal',
                        'statusOrganik': 'Normal',
                        'statusNonOrganik': 'Normal',
                        'selesai': false,
                        'handledBy': uid,
                        'handledAt': ServerValue.timestamp,
                        'updatedBy': uid,
                        'updatedAt': ServerValue.timestamp,
                      });

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Berhasil diselesaikan. Status direset ke Normal.'),
                        ),
                      );
                    }

                    return TableRow(
                      children: [
                        _MonTextCell(tps),
                        _MonTextCell(jenisTampil.isEmpty ? '-' : jenisTampil),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _IotStatusBadge(status: statusLabel),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _SelesaiPillButton(
                              enabled: canSelesai,
                              done: false,
                              onTap: markSelesaiIot,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
      );
    }

    Widget buildManualTable({
      required List<MapEntry<String, Map<String, dynamic>>> entries,
      required String emptyText,
    }) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: entries.isEmpty
            ? _EmptyInfo(text: emptyText)
            : Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.1),
                  1: FlexColumnWidth(1.4),
                  2: FlexColumnWidth(1.1),
                  3: FlexColumnWidth(1.3),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey, width: 1),
                ),
                children: [
                  const TableRow(
                    children: [
                      _MonHeaderCell('TPS'),
                      _MonHeaderCell('Jenis'),
                      _MonHeaderCell('Aksi'),
                      _MonHeaderCell('Bukti'),
                    ],
                  ),
                  ...entries.map((e) {
                    final pathKey = e.key;
                    final data = e.value;

                    final tps = (data['tps'] ??
                            data['tpa'] ??
                            data['nama'] ??
                            '-')
                        .toString();
                    final jenis = (data['jenis'] ?? '-').toString().trim();
                    final selesaiPressed = (data['selesai'] == true);

                    Future<void> markSelesaiManual() async {
                      await refForPath(pathKey).update({
                        'selesai': true,
                        'selesaiAt': ServerValue.timestamp,
                        'updatedBy': uid,
                        'updatedAt': ServerValue.timestamp,
                      });

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Status "Selesai" tersimpan. Silakan Upload Bukti.')),
                      );
                    }

                    Future<void> uploadBuktiManual() async {
                      if (!selesaiPressed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Tekan "Selesai" dulu sebelum upload bukti.')),
                        );
                        return;
                      }

                      final b64 = await pickImageBase64(context);
                      if (b64 == null || b64.isEmpty) return;

                      await pushRiwayatWithBukti(
                        tps: tps,
                        jenis: jenis,
                        status: 'Selesai',
                        buktiBase64: b64,
                        source: 'manual',
                        document: pathKey.split('/').first,
                      );

                      await refForPath(pathKey).update({
                        'selesai': false,
                        'selesaiAt': null,
                        'buktiBase64': null,
                        'lastBuktiAt': ServerValue.timestamp,
                        'updatedBy': uid,
                        'updatedAt': ServerValue.timestamp,
                      });

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Bukti tersimpan ke riwayat. Data manual tetap tersimpan.')),
                      );
                    }

                    return TableRow(
                      children: [
                        _MonTextCell(tps),
                        _MonTextCell(jenis.isEmpty ? '-' : jenis),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _SelesaiPillButton(
                              enabled: true,
                              done: selesaiPressed,
                              onTap: markSelesaiManual,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _UploadBuktiButton(onTap: uploadBuktiManual),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<DatabaseEvent>(
          stream: riwayatRef.orderByChild('uid').equalTo(uid).onValue,
          builder: (context, snap) {
            int totalHariIni = 0;
            int totalMingguIni = 0;

            void processRow(dynamic row) {
              if (row is! Map) return;
              final m = row.map((kk, vv) => MapEntry(kk.toString(), vv));

              final rowUid = m['uid']?.toString();
              if (rowUid != null && rowUid.isNotEmpty && rowUid != uid) return;

              DateTime? dt;
              final ts = m['timestamp'];
              if (ts is int) {
                dt = DateTime.fromMillisecondsSinceEpoch(ts);
              } else if (ts is double) {
                dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
              }

              if (dt == null && m['tanggal'] != null) {
                final parts = m['tanggal'].toString().split('-');
                if (parts.length >= 3) {
                  try {
                    final y = int.parse(parts[0]);
                    final mo = int.parse(parts[1]);
                    final d = int.parse(parts[2]);
                    dt = DateTime(y, mo, d);
                  } catch (_) {}
                }
              }

              if (dt == null) return;
              final d = DateTime(dt.year, dt.month, dt.day);

              if (_isSameDate(d, today)) totalHariIni++;
              if (!d.isBefore(startOfWeek) && d.isBefore(endOfWeek)) {
                totalMingguIni++;
              }
            }

            final raw = snap.data?.snapshot.value;
            if (raw is Map) {
              raw.forEach((_, v) => processRow(v));
            } else if (raw is List) {
              for (final v in raw) processRow(v);
            }

            return Row(
              children: [
                Expanded(
                  child: _TopStatCard(
                    label: 'Total Pengangkutan Hari Ini',
                    value: totalHariIni.toString(),
                    icon: Icons.local_shipping_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TopStatCard(
                    label: 'Total Pengangkutan Minggu Ini',
                    value: totalMingguIni.toString(),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Daftar TPS'),
        const SizedBox(height: 12),
        const Text(
          'TPS dari Perangkat IoT (ESP32_1)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        StreamBuilder<DatabaseEvent>(
          stream: stream,
          builder: (context, snap) {
            final iotEntries = <MapEntry<String, Map<String, dynamic>>>[];
            final manualEntries = <MapEntry<String, Map<String, dynamic>>>[];

            void addEntriesFromNode({
              required String rootKey,
              required dynamic nodeValue,
              required List<MapEntry<String, Map<String, dynamic>>> target,
            }) {
              if (nodeValue is Map) {
                final asMap =
                    nodeValue.map((kk, vv) => MapEntry(kk.toString(), vv));

                final bool looksLikeRecord = asMap.containsKey('tps') ||
                    asMap.containsKey('tpa') ||
                    asMap.containsKey('nama') ||
                    asMap.containsKey('status') ||
                    asMap.containsKey('jenis') ||
                    asMap.containsKey('volume') ||
                    asMap.containsKey('statusOrganik') ||
                    asMap.containsKey('statusNonOrganik');

                if (looksLikeRecord) {
                  target.add(MapEntry(rootKey, Map<String, dynamic>.from(asMap)));
                  return;
                }

                asMap.forEach((childKey, childVal) {
                  if (childVal is Map) {
                    final childMap =
                        childVal.map((kk, vv) => MapEntry(kk.toString(), vv));
                    target.add(
                      MapEntry(
                        '$rootKey/$childKey',
                        Map<String, dynamic>.from(childMap),
                      ),
                    );
                  }
                });
                return;
              }

              if (nodeValue is List) {
                for (var i = 0; i < nodeValue.length; i++) {
                  final v = nodeValue[i];
                  if (v is Map) {
                    final childMap =
                        v.map((kk, vv) => MapEntry(kk.toString(), vv));
                    target.add(MapEntry('$rootKey/$i',
                        Map<String, dynamic>.from(childMap)));
                  }
                }
              }
            }

            final raw = snap.data?.snapshot.value;
            if (raw is Map) {
              raw.forEach((k, v) {
                final key = k.toString();
                if (key == 'ESP32_1') {
                  addEntriesFromNode(
                      rootKey: key, nodeValue: v, target: iotEntries);
                } else {
                  addEntriesFromNode(
                      rootKey: key, nodeValue: v, target: manualEntries);
                }
              });
            } else if (raw is List) {
              for (var i = 0; i < raw.length; i++) {
                addEntriesFromNode(
                    rootKey: i.toString(),
                    nodeValue: raw[i],
                    target: manualEntries);
              }
            }

            iotEntries.sort((a, b) {
              final at = (a.value['tps'] ?? a.value['tpa'] ?? '-').toString();
              final bt = (b.value['tps'] ?? b.value['tpa'] ?? '-').toString();
              return sortByTpsLabel(at, bt);
            });

            manualEntries.sort((a, b) {
              final at = (a.value['nama'] ?? a.value['tps'] ?? '-').toString();
              final bt = (b.value['nama'] ?? b.value['tps'] ?? '-').toString();
              return sortByTpsLabel(at, bt);
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildIotTable(
                  entries: iotEntries,
                  emptyText: 'Belum ada TPS IoT dari ESP32_1.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'TPS Tambahan (Manual - selain ESP32_1)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                buildManualTable(
                  entries: manualEntries,
                  emptyText: 'Belum ada TPS manual.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Laporan Masuk Terbaru'),
        const SizedBox(height: 8),

        StreamBuilder<DatabaseEvent>(
          stream: laporanCampusRef.onValue,
          builder: (context, snap) {
            final List<MapEntry<String, Map<String, dynamic>>> rows = [];

            final raw = snap.data?.snapshot.value;
            if (raw is Map) {
              raw.forEach((k, v) {
                if (v is Map) {
                  final m = v.map((kk, vv) => MapEntry(kk.toString(), vv));
                  rows.add(MapEntry(k.toString(), Map<String, dynamic>.from(m)));
                }
              });
            } else if (raw is List) {
              for (var i = 0; i < raw.length; i++) {
                final v = raw[i];
                if (v is Map) {
                  final m = v.map((kk, vv) => MapEntry(kk.toString(), vv));
                  rows.add(MapEntry(i.toString(), Map<String, dynamic>.from(m)));
                }
              }
            }

            rows.sort((a, b) {
              final ta = _extractMs(a.value);
              final tb = _extractMs(b.value);
              return tb.compareTo(ta);
            });

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: rows.isEmpty
                  ? const _EmptyInfo(text: 'Belum ada laporan dari warga kampus.')
                  : Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(1.0),
                        2: FlexColumnWidth(1.0),
                        3: FlexColumnWidth(1.0),
                        4: FlexColumnWidth(0.7),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      border: const TableBorder(
                        horizontalInside:
                            BorderSide(color: Colors.grey, width: 1),
                      ),
                      children: [
                        const TableRow(
                          children: [
                            _MonHeaderCell('Tanggal'),
                            _MonHeaderCell('TPS'),
                            _MonHeaderCell('Status'),
                            _MonHeaderCell('Aksi'),
                            _MonHeaderCell('Hapus'),
                          ],
                        ),
                        ...rows.map((e) {
                          final key = e.key;
                          final data = e.value;

                          String tanggal = '-';
                          final ms = _extractMs(data);
                          if (ms > 0) {
                            final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                            final d = dt.day.toString().padLeft(2, '0');
                            final mo = dt.month.toString().padLeft(2, '0');
                            final h = dt.hour.toString().padLeft(2, '0');
                            final mm = dt.minute.toString().padLeft(2, '0');
                            tanggal = '${dt.year}-$mo-$d $h:$mm';
                          } else if (data['tanggal'] != null) {
                            tanggal = data['tanggal'].toString();
                          }

                          final tps =
                              (data['tps'] ?? data['lokasi'] ?? '-').toString();
                          final status =
                              (data['status'] ?? 'Selesai').toString();

                          return TableRow(
                            children: [
                              _MonTextCell(tanggal),
                              _MonTextCell(tps),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: _StatusBadge(status: status),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _SelesaiPillButton(
                                    enabled: true,
                                    onTap: () async {
                                      await riwayatRef.push().set({
                                        'tanggal': todayYmd(),
                                        'tps': tps,
                                        'jenis': (data['jenis'] ?? '-')
                                            .toString(),
                                        'status': 'Diangkut',
                                        'uid': uid,
                                        'timestamp': ServerValue.timestamp,
                                      });

                                      await laporanCampusRef.child(key).update({
                                        'handledBy': uid,
                                        'handledAt': ServerValue.timestamp,
                                        'status': 'Selesai',
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Center(
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () async =>
                                      laporanCampusRef.child(key).remove(),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
  }
}

class _SelesaiPillButton extends StatelessWidget {
  final bool enabled;
  final bool done;
  final VoidCallback onTap;

  const _SelesaiPillButton({
    required this.enabled,
    required this.onTap,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = done
        ? const Color(0xFF117A37)
        : (enabled ? const Color(0xFFE6F4EA) : Colors.grey.shade200);
    final Color fg = done
        ? Colors.white
        : (enabled ? const Color(0xFF117A37) : Colors.grey.shade500);

    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          side: BorderSide(color: fg.withOpacity(0.4), width: 1),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: Icon(Icons.local_shipping_rounded, size: 16, color: fg),
        label: Text('Selesai',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

class _UploadBuktiButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UploadBuktiButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side:
              BorderSide(color: AppColors.buttonBlue.withOpacity(0.6), width: 1),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: Icon(Icons.upload_rounded, size: 16, color: AppColors.buttonBlue),
        label: Text('Upload Bukti',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.buttonBlue)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(status,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF117A37))),
      ),
    );
  }
}

class _IotStatusBadge extends StatelessWidget {
  final String status;
  const _IotStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final Color bg =
        (s == 'penuh') ? const Color(0xFFFFEAEA) : const Color(0xFFE6F4EA);
    final Color fg =
        (s == 'penuh') ? const Color(0xFFC0392B) : const Color(0xFF117A37);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// ✅ FIX #2: Header cell tabel biru dibuat seragam tinggi & rapi
class _MonHeaderCell extends StatelessWidget {
  final String text;
  const _MonHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kHeaderCellHeight,
      child: Container(
        color: _kHeaderBlue,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MonTextCell extends StatelessWidget {
  final String text;
  const _MonTextCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Colors.black87)),
    );
  }
}

/// =======================================================================
///                               RIWAYAT
/// =======================================================================

class _RiwayatPane extends StatefulWidget {
  final Stream<DatabaseEvent> stream;
  final Stream<DatabaseEvent> fallbackStream;
  final DatabaseReference baseRef; // ref('riwayat')
  final String uid;

  const _RiwayatPane({
    required this.stream,
    required this.fallbackStream,
    required this.baseRef,
    required this.uid,
  });

  @override
  State<_RiwayatPane> createState() => _RiwayatPaneState();
}

class _RiwayatPaneState extends State<_RiwayatPane> {
  String _fmt(int? ms, String? tanggalFallback) {
    if (ms == null) return (tanggalFallback ?? '-');
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d-$mo-${dt.year} $h:$m';
  }

  Table _buildTable(List<Map<String, dynamic>> rows) {
    return Table(
      border: const TableBorder.symmetric(
        inside: BorderSide(color: Colors.black87, width: 1),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.25),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(0.95),
        4: FlexColumnWidth(0.75),
        5: FlexColumnWidth(0.75),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(children: [
          _CellHeader('Tanggal'),
          _CellHeader('TPS'),
          _CellHeader('Jenis'),
          _CellHeader('Status'),
          _CellHeader('Bukti'),
          _CellHeader('Aksi'),
        ]),
        ...rows.map((m) {
          final tgl = _fmt(m['timestamp'] as int?, m['tanggal']?.toString());
          final tps = (m['tps'] ?? '-').toString();
          final jenis = (m['jenis'] ?? '-').toString();
          final status = (m['status'] ?? 'Selesai').toString();
          final buktiB64 = (m['buktiBase64'] ?? '').toString();

          return TableRow(children: [
            _CellText(tgl),
            _CellText(tps),
            _CellText(jenis),
            _CellText(status),
            Padding(
              padding: const EdgeInsets.all(6),
              child: buktiB64.isEmpty
                  ? const Text('-', textAlign: TextAlign.center)
                  : SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => _showBuktiDialog(buktiB64),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: AppColors.buttonBlue.withOpacity(0.6),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child:
                            const Text('Lihat', style: TextStyle(fontSize: 12)),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(
                tooltip: 'Hapus',
                onPressed: () => _confirmDelete(m),
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.redAccent),
              ),
            ),
          ]);
        }),
      ],
    );
  }

  void _showBuktiDialog(String b64) {
    try {
      final bytes = base64Decode(b64);
      showDialog(
        context: context,
        builder: (_) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bukti Pengangkutan',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bukti tidak valid / gagal dibuka.')));
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> rows) async {
    try {
      final xls.Excel excel = xls.Excel.createExcel();
      const String sheetName = 'Riwayat';
      final xls.Sheet sheet = excel[sheetName];

      sheet.appendRow(<xls.CellValue?>[
        xls.TextCellValue('Tanggal'),
        xls.TextCellValue('TPS'),
        xls.TextCellValue('Jenis'),
        xls.TextCellValue('Status'),
        xls.TextCellValue('Ada Bukti'),
      ]);

      for (final m in rows) {
        final tgl = _fmt(m['timestamp'] as int?, m['tanggal']?.toString());
        final tps = (m['tps'] ?? '-').toString();
        final jenis = (m['jenis'] ?? '-').toString();
        final status = (m['status'] ?? '-').toString();
        final hasBukti = ((m['buktiBase64'] ?? '').toString()).isNotEmpty;

        sheet.appendRow(<xls.CellValue?>[
          xls.TextCellValue(tgl),
          xls.TextCellValue(tps),
          xls.TextCellValue(jenis),
          xls.TextCellValue(status),
          xls.TextCellValue(hasBukti ? 'Ya' : 'Tidak'),
        ]);
      }

      excel.setDefaultSheet(sheetName);
      final String fileName =
          'Riwayat_Pengangkutan_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      excel.save(fileName: fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export Excel berhasil dibuat.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal export Excel: $e')));
    }
  }

  Widget _renderFromSnapshot(DataSnapshot? snap) {
    final raw = snap?.value;
    final rows = <Map<String, dynamic>>[];

    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          final m = v.map((kk, vv) => MapEntry(kk.toString(), vv));
          if (m['uid'] == null || m['uid'] == widget.uid) {
            rows.add(Map<String, dynamic>.from(m)..['_key'] = k.toString());
          }
        }
      });
    } else if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          final m = v.map((kk, vv) => MapEntry(kk.toString(), vv));
          if (m['uid'] == null || m['uid'] == widget.uid) {
            rows.add(Map<String, dynamic>.from(m)..['_key'] = '');
          }
        }
      }
    }

    if (rows.isEmpty) {
      return const _EmptyInfo(text: 'Belum ada riwayat pengangkutan.');
    }

    rows.sort((a, b) {
      final ta = (a['timestamp'] is int) ? a['timestamp'] as int : -1;
      final tb = (b['timestamp'] is int) ? b['timestamp'] as int : -1;
      return tb.compareTo(ta);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () => _exportToExcel(rows),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: Colors.black26, width: 1.2),
          ),
          clipBehavior: Clip.hardEdge,
          child: _buildTable(rows),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: widget.stream,
      builder: (context, s1) {
        if (s1.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s1.hasData && s1.data!.snapshot.value != null) {
          return _renderFromSnapshot(s1.data!.snapshot);
        }
        return StreamBuilder<DatabaseEvent>(
          stream: widget.fallbackStream,
          builder: (context, s2) {
            if (s2.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return _renderFromSnapshot(s2.data?.snapshot);
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final key = (row['_key'] ?? '').toString();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa menghapus: key tidak ditemukan.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat'),
        content: const Text('Yakin ingin menghapus item riwayat ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.baseRef.child(key).remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Riwayat berhasil dihapus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus riwayat: $e')),
      );
    }
  }
}

/// =======================================================================
///                         CELL UMUM & Fallback
/// =======================================================================

/// ✅ FIX #2 juga untuk Riwayat table header (biar biru rapih seragam)
class _CellHeader extends StatelessWidget {
  final String text;
  const _CellHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kHeaderCellHeight,
      child: Container(
        color: _kHeaderBlue,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.white,
          ),
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
      padding: const EdgeInsets.all(10),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    );
  }
}

class _EmptyInfo extends StatelessWidget {
  final String text;
  const _EmptyInfo({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}
