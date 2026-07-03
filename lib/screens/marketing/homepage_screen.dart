import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Marketing homepage screen - web-only
/// Stoa Poikile design — Pistisai brand (2026-07)
/// 4 Titans / 4 Pillars: Aiman, Aigent, Aidration, Aimotions
class HomepageScreen extends StatelessWidget {
  const HomepageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        body: Center(
          child: Text(
            'This page is only available on web',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 600;
    final isTablet = sw >= 600 && sw < 1024;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          _buildHero(context, isMobile: isMobile),
          _buildGreekSeparator(context),
          _buildPistisSection(context, isMobile: isMobile),
          _buildGreekSeparator(context),
          _buildPillarsSection(context, isMobile: isMobile, isTablet: isTablet),
          const SizedBox(height: 48),
          _buildCTASection(context, isMobile: isMobile),
          const SizedBox(height: 48),
          _buildQuickInstall(context, isMobile: isMobile),
          _buildFooter(context),
        ]),
      ),
    );
  }

  // ─── HERO ─────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context, {required bool isMobile}) {
    final titleSize = isMobile ? 36.0 : 52.0;
    final vPad = isMobile ? 48.0 : 80.0;
    final hPad = isMobile ? 20.0 : 40.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F1118),
            Color(0xFF181A20),
            Color(0xFF1E2230),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Login button
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () async {
                final uri = Uri.parse('https://app.pistisai.app');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, webOnlyWindowName: '_self');
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFD700),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Login',
                style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2),
              ),
            ),
          ),

          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stoa motif — subtle portico outline
              SizedBox(
                width: isMobile ? 260 : 320,
                child: CustomPaint(
                  painter: _StoaPorticoPainter(),
                  size: const Size(320, 60),
                ),
              ),
              const SizedBox(height: 24),

              // Greek wordmark
              Text(
                'ΠΙΣΤΙΣ',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: isMobile ? 14 : 16,
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  letterSpacing: 8,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 4),

              // Pistisai name
              Text(
                'PISTISAI',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w200,
                  color: const Color(0xFFF5E6C8),
                  letterSpacing: 8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),

              // Tagline
              Text(
                'Where Trust Returns',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFFFFD700),
                  letterSpacing: 4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Subtitle
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'A portico for private AI — four pillars that know you, '
                  'run on your machine, and grow with you.',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: const Color(0xFFB8A88A),
                    height: 1.6,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // CTA buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGoldButton(context, 'Get Started Free', () async {
                    final uri = Uri.parse('https://github.com/pistisAI/pistisai-app/releases');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  }, isMobile),
                  if (!isMobile) const SizedBox(width: 16),
                  if (!isMobile)
                    OutlinedButton(
                      onPressed: () async {
                        final uri = Uri.parse('https://github.com/pistisAI/pistisai-app');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF5E6C8),
                        side: BorderSide(color: const Color(0xFFF5E6C8).withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Source Code',
                        style: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 1),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── GREEK KEY SEPARATOR ──────────────────────────────────────────────────

  Widget _buildGreekSeparator(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 24,
      color: const Color(0xFF0F1118),
      child: Center(
        child: CustomPaint(
          painter: _GreekKeyPainter(),
          size: const Size(double.infinity, 16),
        ),
      ),
    );
  }

  // ─── PISTIS NARRATIVE ─────────────────────────────────────────────────────

  Widget _buildPistisSection(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F1118),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 40 : 60,
        horizontal: isMobile ? 20 : 40,
      ),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                Text(
                  'ἡ Πίστις',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: isMobile ? 20 : 28,
                    color: const Color(0xFFFFD700),
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'When Pandora\'s box was opened, all evils escaped — '
                  'but Πίστις (Pistis), the spirit of trust, '
                  'fled back to the heavens. She has not returned since.',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 18,
                    color: const Color(0xFFB8A88A),
                    height: 1.7,
                    letterSpacing: 0.3,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: 60,
                  height: 1,
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pistisai builds a portico worthy of her return. '
                  'Four pillars that together restore what was lost: '
                  'private, local, trustworthy AI.',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: const Color(0xFF8A7E6A),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4 PILLARS / COLONNADE ────────────────────────────────────────────────

  Widget _buildPillarsSection(
    BuildContext context, {
    required bool isMobile,
    required bool isTablet,
  }) {
    final pillars = [
      _PillarData(
        titan: 'Hyperion',
        titanGreek: 'Ὑπερίων',
        direction: 'East — Dawn',
        symbol: '☀',
        name: 'Aiman',
        desc: 'Your personal AI — learns your patterns, remembers your context, '
            'always private. The warm presence that greets you.',
        texture: 'Warm glow, broad presence',
        color: const Color(0xFFFFD700),
      ),
      _PillarData(
        titan: 'Koios',
        titanGreek: 'Κοῖος',
        direction: 'North — Axis',
        symbol: '☉',
        name: 'Aigent',
        desc: 'Acts for you — schedules, research, automation, desktop control. '
            'The precise engine that queries and reasons.',
        texture: 'Precision fluting, geometric',
        color: const Color(0xFFE8C84A),
      ),
      _PillarData(
        titan: 'Krios',
        titanGreek: 'Κρεῖος',
        direction: 'South — Ram',
        symbol: '♈',
        name: 'Aidration',
        desc: 'Grows with you — personality, memory, and capabilities evolve '
            'over time. The measured rhythm of a life observed.',
        texture: 'Measured cadence, constellation',
        color: const Color(0xFFD4A017),
      ),
      _PillarData(
        titan: 'Iapetos',
        titanGreek: 'Ἰαπετός',
        direction: 'West — Dusk',
        symbol: '🔥',
        name: 'Aimotions',
        desc: 'Connects with you — tone-aware, expressive, never cold. '
            'The heart that feels, crafted with mortality\'s depth.',
        texture: 'Organic curves, fire-like',
        color: const Color(0xFFB8860B),
      ),
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFF181A20),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 48 : 72,
        horizontal: isMobile ? 16 : 40,
      ),
      child: Column(
        children: [
          // Section title
          Text('THE FOUR PILLARS',
            style: TextStyle(
              fontSize: isMobile ? 22 : 32,
              fontWeight: FontWeight.w200,
              color: const Color(0xFFF5E6C8),
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text('A Stoa Poikile for the age of AI',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: const Color(0xFF8A7E6A),
              letterSpacing: 2,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 48),

          // Pillar cards grid
          Wrap(
            spacing: isMobile ? 16 : 24,
            runSpacing: isMobile ? 16 : 24,
            alignment: WrapAlignment.center,
            children: pillars.map((p) => _buildPillarCard(
              context, p, isMobile || isTablet,
            )).toList(),
          ),

          const SizedBox(height: 48),

          // Titan reference
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'In Greek myth, four Titans held the cosmos apart — '
              'Hyperion (East), Koios (North), Krios (South), Iapetos (West). '
              'They were the cosmic pillars.\n'
              'Here, they ground the four aspects of your AI companion.',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: const Color(0xFF6A5E4A),
                height: 1.6,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarCard(BuildContext context, _PillarData p, bool isCompact) {
    return Container(
      width: isCompact ? double.infinity : 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titan symbol + name
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: p.color.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(p.symbol,
                    style: TextStyle(fontSize: 20, color: p.color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.titan,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: p.color,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(p.titanGreek,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF6A5E4A),
                      fontFamily: 'serif',
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Direction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(p.direction,
              style: TextStyle(
                fontSize: 10,
                color: p.color.withValues(alpha: 0.7),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Zoid pillar name
          Text(p.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: Color(0xFFF5E6C8),
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Text(p.desc,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A7E6A),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          // Texture hint
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(
                color: p.color.withValues(alpha: 0.1),
              )),
            ),
            child: Text(p.texture,
              style: TextStyle(
                fontSize: 10,
                color: p.color.withValues(alpha: 0.4),
                letterSpacing: 1.2,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CTA ───────────────────────────────────────────────────────────────────

  Widget _buildCTASection(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 900),
      padding: EdgeInsets.all(isMobile ? 28 : 48),
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text('Your Data Stays Yours. Always.',
            style: TextStyle(
              fontSize: isMobile ? 22 : 30,
              fontWeight: FontWeight.w300,
              color: const Color(0xFFF5E6C8),
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              'AI that respects your privacy. Runs entirely on your machine, '
              'backed by your terms. No cloud lock-in, no data mining, '
              'no subscription required. Trust is not a feature — it\'s the foundation.',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: const Color(0xFF8A7E6A),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          _buildGoldButton(context, 'Get Started Free', () async {
            final uri = Uri.parse('https://github.com/pistisAI/pistisai-app/releases');
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          }, isMobile),
        ],
      ),
    );
  }

  // ─── QUICK INSTALL ─────────────────────────────────────────────────────────

  Widget _buildQuickInstall(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 900),
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      margin: EdgeInsets.fromLTRB(
        isMobile ? 16 : 40,
        48,
        isMobile ? 16 : 40,
        48,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              Text('Quick Install',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFFF5E6C8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Install Pistisai and your Aiman with a single command.',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF8A7E6A),
            ),
          ),
          const SizedBox(height: 32),
          _buildCodeBlock(context, 'Linux / macOS (Bash)',
            'curl -fsSL https://pistisai.app/install.sh | bash', isMobile),
          const SizedBox(height: 24),
          _buildCodeBlock(context, 'Windows (PowerShell)',
            'iwr -useb https://pistisai.app/install.ps1 | iex', isMobile),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String label, String code, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Color(0xFF6A5E4A),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1118),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFB8A88A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Color(0xFF6A5E4A)),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── FOOTER ────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      color: const Color(0xFF0F1118),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 1,
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'PISTISAI — πίστις ἐστὶν ἡ τῶν ἀνθρώπων σωτηρία',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 12,
              color: const Color(0xFF6A5E4A),
              letterSpacing: 1,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2026 Pistisai — Trust is what remains',
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF4A3E2A),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  Widget _buildGoldButton(BuildContext context, String label, VoidCallback onPressed, bool isMobile) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: const Color(0xFF181A20),
        backgroundColor: const Color(0xFFFFD700),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        elevation: 0,
      ),
      child: Text(label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ─── PILLAR DATA ─────────────────────────────────────────────────────────────

class _PillarData {
  final String titan;
  final String titanGreek;
  final String direction;
  final String symbol;
  final String name;
  final String desc;
  final String texture;
  final Color color;

  const _PillarData({
    required this.titan,
    required this.titanGreek,
    required this.direction,
    required this.symbol,
    required this.name,
    required this.desc,
    required this.texture,
    required this.color,
  });
}

// ─── STOA PORTICO PAINTER ────────────────────────────────────────────────────

class _StoaPorticoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final colW = w / 5; // 4 columns = 4 gaps
    final colTop = h * 0.25;
    final colBot = h * 0.85;

    // Roof (pediment)
    final roofPath = Path()
      ..moveTo(w * 0.05, colTop)
      ..lineTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.95, colTop);
    canvas.drawPath(roofPath, paint);

    // Roof horizontal
    canvas.drawLine(Offset(w * 0.05, colTop), Offset(w * 0.95, colTop), paint);

    // Base
    canvas.drawLine(Offset(w * 0.05, colBot + 8), Offset(w * 0.95, colBot + 8), paint);
    canvas.drawLine(Offset(w * 0.05, colBot + 12), Offset(w * 0.95, colBot + 12), paint);

    // Columns
    for (int i = 0; i < 4; i++) {
      final cx = w * 0.15 + i * colW;
      canvas.drawLine(Offset(cx, colTop), Offset(cx, colBot), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── GREEK KEY PAINTER ──────────────────────────────────────────────────────

class _GreekKeyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double unit = 12;
    final count = (size.width / unit).floor();
    final y = size.height / 2;

    for (int i = 0; i < count && i * unit < size.width; i++) {
      final x = i * unit;
      if (i % 2 == 0) {
        canvas.drawLine(Offset(x, y - unit * 0.3), Offset(x + unit * 0.5, y - unit * 0.3), paint);
        canvas.drawLine(Offset(x + unit * 0.5, y - unit * 0.3), Offset(x + unit * 0.5, y + unit * 0.3), paint);
        canvas.drawLine(Offset(x + unit * 0.5, y + unit * 0.3), Offset(x + unit, y + unit * 0.3), paint);
      }
      // dot
      canvas.drawCircle(Offset(x + unit * 0.25, y), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
