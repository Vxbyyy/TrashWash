import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme.dart'; // tetap dipakai untuk AppColors

const _primaryColor = Color(0xFF143B6E);

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Menyimpan tombol mana yang terakhir diklik: 'masuk' / 'daftar'
  String? _selected;

  Color _btnBg(String key) {
    if (_selected == null) return _primaryColor;
    return _selected == key ? _primaryColor : _primaryColor.withOpacity(0.45);
  }

  @override
  Widget build(BuildContext context) {
    final Color descColor = Colors.black87;

    return Scaffold(
      // background polos
      backgroundColor: AppColors.lightBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // ===== Judul aplikasi (rata tengah) =====
                  const Center(
                    child: Text(
                      'TrashWash',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ===== Icon / ilustrasi =====
                  Center(
                    child: SizedBox(
                      height: 140,
                      child: Image.asset(
                        'assets/trash_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.delete_outline,
                          size: 100,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ===== Deskripsi (RATA TENGAH) =====
                  Center(
                    child: SizedBox(
                      width: 600,
                      child: Text(
                        'Aplikasi TrashWash dirancang untuk mempermudah petugas kebersihan dan warga kampus '
                        'dalam pelaporan TPS, monitoring, serta sarana kebersihan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: descColor,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ===== Tombol MASUK & DAFTAR (sejajar) =====
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _selected = 'masuk');
                              context.go('/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _btnBg('masuk'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'MASUK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 170,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _selected = 'daftar');
                              context.go('/register');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _btnBg('daftar'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'DAFTAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ===== Divider lembut =====
                  Container(
                    width: double.infinity,
                    height: 1.2,
                    color: Colors.white.withOpacity(0.4),
                  ),

                  const SizedBox(height: 20),

                  // ===== Judul Jenis Sampah =====
                  const Text(
                    'Jenis Sampah',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== Grid Jenis Sampah (dinamis) =====
                  const _WasteGrid(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid responsif berisi kartu-kartu informasi jenis sampah.
/// - Width mengikuti kolom (1/2/3 kolom)
/// - Height dibuat seragam per breakpoint agar semua kartu sama ukuran
class _WasteGrid extends StatelessWidget {
  const _WasteGrid({Key? key}) : super(key: key);

  static const List<_WasteInfo> items = [
    _WasteInfo(
      title: 'Organik',
      icon: Icons.eco_outlined,
      color: Color(0xFF2ECC71),
      bullets: [
        'Sisa makanan, sayur & buah',
        'Daun, ranting, rumput',
        'Ampas kopi/teh, kulit telur',
      ],
      note: 'Dapat dijadikan kompos.',
    ),
    _WasteInfo(
      title: 'Non-organik / Daur Ulang',
      icon: Icons.recycling,
      color: Color(0xFF2E86DE),
      bullets: [
        'Botol plastik PET, gelas plastik',
        'Kertas & kardus kering',
        'Kaleng minuman, logam',
      ],
      note: 'Pastikan bersih & kering sebelum didaur ulang.',
    ),
    _WasteInfo(
      title: 'Residu',
      icon: Icons.delete_forever_outlined,
      color: Color(0xFF95A5A6),
      bullets: [
        'Popok sekali pakai',
        'Tisu / serbet kotor',
        'Puntung rokok, serbuk kotor',
      ],
      note: 'Tidak bisa didaur ulang — buang ke tempat “Residu/Umum”.',
    ),
    _WasteInfo(
      title: 'B3 (Berbahaya)',
      icon: Icons.warning_amber_outlined,
      color: Color(0xFFF39C12),
      bullets: [
        'Baterai, aki',
        'Lampu neon, termometer raksa',
        'Kaleng cat, oli, bahan kimia',
      ],
      note: 'Jangan campur dengan sampah biasa. Butuh penanganan khusus.',
    ),
    _WasteInfo(
      title: 'Elektronik (E-waste)',
      icon: Icons.devices_other,
      color: Color(0xFF8E44AD),
      bullets: [
        'HP/ponsel rusak',
        'Adaptor, charger, kabel',
        'Perangkat elektronik kecil',
      ],
      note: 'Kumpulkan untuk didaur ulang ke fasilitas E-waste.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        int columns;
        if (maxWidth >= 1000) {
          columns = 3;
        } else if (maxWidth >= 650) {
          columns = 2;
        } else {
          columns = 1;
        }

        const spacing = 12.0;
        final itemWidth = (maxWidth - (columns - 1) * spacing) / columns;

        // Height seragam per breakpoint (silakan adjust kalau mau lebih tinggi/rendah)
        final double cardHeight = (columns == 3)
            ? 210
            : (columns == 2)
                ? 230
                : 250;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (info) => SizedBox(
                  width: itemWidth,
                  height: cardHeight, // ✅ semua kartu sama tinggi
                  child: _WasteInfoCard(info: info),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _WasteInfo {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> bullets;
  final String? note;

  const _WasteInfo({
    required this.title,
    required this.icon,
    required this.color,
    required this.bullets,
    this.note,
  });
}

class _WasteInfoCard extends StatelessWidget {
  final _WasteInfo info;
  const _WasteInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ kartu putih
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black26, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Header =====
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: info.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black26, width: 1.0),
                ),
                child: Icon(info.icon, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ===== Isi dibuat fleksibel, note rata bawah =====
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...info.bullets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(fontSize: 14, height: 1.4),
                        ),
                        Expanded(
                          child: Text(
                            b,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(), // ✅ dorong note ke bawah

                if ((info.note ?? '').isNotEmpty)
                  Text(
                    info.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
