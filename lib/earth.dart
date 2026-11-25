part of 'main.dart';

// ═════════════════════════ كوكب الأرض التفاعلي ═════════════════════════

/// كوكب أرض بيلف، عليه شجر بيتحرك مع الهوا، وطيور بتطير حواليه.
/// اضغط عليه: بيلف أسرع والطيور تتلخبط وتطير بعيد شوية.
class EarthLogo extends StatefulWidget {
  final double size;
  const EarthLogo({super.key, this.size = 190});
  @override
  State<EarthLogo> createState() => _EarthLogoState();
}

class _EarthLogoState extends State<EarthLogo>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  double _phase = 0; // دوران الكوكب
  double _boost = 0; // دفعة من الضغط
  double _scatter = 0;
  Duration _last = Duration.zero;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final dt = (d - _last).inMicroseconds / 1e6;
      _last = d;
      _t += dt;
      _boost = (_boost - dt * 1.2).clamp(0.0, 6.0);
      _scatter = (_scatter - dt * 0.9).clamp(0.0, 1.0);
      _phase += dt * (0.035 + _boost * 0.12);
      _time.value = _t;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _boost = 6;
        _scatter = 1;
      },
      child: SizedBox(
        width: s * 1.5,
        height: s * 1.3,
        child: ValueListenableBuilder<double>(
          valueListenable: _time,
          builder: (_, t, __) => CustomPaint(
            painter: _EarthPainter(
                t: t, phase: _phase, planet: s / 2, scatter: _scatter),
          ),
        ),
      ),
    );
  }
}

class _EarthPainter extends CustomPainter {
  final double t;
  final double phase;
  final double planet; // نصف القطر
  final double scatter;
  _EarthPainter(
      {required this.t,
      required this.phase,
      required this.planet,
      required this.scatter});

  // كتل اليابسة: (x في شريط الدوران 0..1، y من -1 لـ 1، نصف عرض، نصف ارتفاع)
  static const _land = <List<double>>[
    [0.10, -0.35, 0.10, 0.20], [0.14, -0.10, 0.07, 0.16], [0.18, 0.12, 0.05, 0.12],
    [0.20, 0.45, 0.06, 0.22], [0.22, 0.30, 0.05, 0.10],
    [0.50, -0.40, 0.07, 0.14], [0.56, -0.18, 0.09, 0.14], [0.53, 0.10, 0.07, 0.22],
    [0.58, 0.30, 0.05, 0.14], [0.66, -0.35, 0.14, 0.14], [0.76, -0.22, 0.09, 0.10],
    [0.86, 0.38, 0.07, 0.07], [0.80, 0.02, 0.04, 0.06],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.56);
    final r = planet;

    // هالة
    canvas.drawCircle(
        c,
        r * 1.45,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF9CFFC4).withValues(alpha: 0.35 + 0.08 * sin(t * 1.6)),
            const Color(0x009CFFC4),
          ]).createShader(Rect.fromCircle(center: c, radius: r * 1.45)));

    // الشجر (ورا الكوكب شوية، على الحافة العلوية)
    _trees(canvas, c, r);

    // الكوكب
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [Color(0xFF4FC3F7), Color(0xFF1976D2), Color(0xFF0B3D91)],
            stops: [0.0, 0.6, 1.0],
          ).createShader(rect));
    // اليابسة بتلف
    final strip = r * 4.2;
    final land = Paint()..color = const Color(0xFF43A047);
    final land2 = Paint()..color = const Color(0xFF2E7D32);
    for (var k = -1; k <= 1; k++) {
      final off = ((phase % 1.0) + k) * strip;
      for (final b in _land) {
        final x = c.dx - r * 2.1 + b[0] * strip - off + strip;
        final y = c.dy + b[1] * r;
        final o = Rect.fromCenter(
            center: Offset(x, y), width: b[2] * strip * 2, height: b[3] * r * 2);
        canvas.drawOval(o, land);
        canvas.drawOval(o.deflate(r * 0.03), land2..color = const Color(0xFF388E3C));
      }
    }
    // سحاب
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 4; i++) {
      final cx = ((phase * 1.6 + i * 0.27) % 1.0);
      final x = c.dx - r + cx * r * 2.6 - r * 0.3;
      final y = c.dy + (i.isEven ? -0.45 : 0.30) * r + sin(i * 2.0) * r * 0.1;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: r * 0.55, height: r * 0.14),
          cloud);
    }
    // تظليل الكرة
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.5),
            radius: 1.15,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.5),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(rect));
    canvas.restore();
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.35));

    // الطيور
    for (var i = 0; i < 4; i++) {
      _bird(canvas, c, r, i);
    }
  }

  void _trees(Canvas canvas, Offset c, double r) {
    // زوايا الشجر على القوس العلوي
    const angles = [-128.0, -108.0, -90.0, -72.0, -52.0];
    const sizes = [0.30, 0.40, 0.34, 0.42, 0.28];
    for (var i = 0; i < angles.length; i++) {
      final a = angles[i] * pi / 180;
      final grow = ((t * 0.9 - i * 0.12).clamp(0.0, 1.0));
      if (grow <= 0) continue;
      final h = r * sizes[i] * Curves.easeOutBack.transform(grow);
      final sway = sin(t * 1.8 + i) * 0.07;
      canvas.save();
      canvas.translate(c.dx + cos(a) * (r - 2), c.dy + sin(a) * (r - 2));
      canvas.rotate(a + pi / 2 + sway); // الشجرة بتطلع للخارج
      final trunk = Paint()..color = const Color(0xFF6D4C41);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-h * 0.06, -h * 0.42, h * 0.12, h * 0.46),
              const Radius.circular(2)),
          trunk);
      for (var k = 0; k < 3; k++) {
        final w = h * (0.62 - k * 0.14);
        final y = -h * (0.30 + k * 0.26);
        final p = Path()
          ..moveTo(-w / 2, y)
          ..lineTo(w / 2, y)
          ..lineTo(0, y - h * 0.42)
          ..close();
        canvas.drawPath(
            p,
            Paint()
              ..color = Color.lerp(const Color(0xFF66BB6A),
                  const Color(0xFF1B5E20), k * 0.35)!);
      }
      canvas.restore();
    }
  }

  void _bird(Canvas canvas, Offset c, double r, int i) {
    final sp = 0.55 + i * 0.12;
    final ang = t * sp + i * 1.7;
    final rx = r * (1.22 + 0.10 * i + scatter * 0.25);
    final ry = r * (0.50 + 0.12 * (i % 2) + scatter * 0.2);
    final p = Offset(c.dx + cos(ang) * rx, c.dy - r * 0.15 + sin(ang) * ry * 0.9);
    final flap = sin(t * (9 + i) + i * 2);
    final dir = -sin(ang) >= 0 ? 1.0 : -1.0; // اتجاه الطيران
    final s = r * (0.15 + 0.015 * (i % 2));
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(dir, 1);
    final wing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.28
      ..strokeCap = StrokeCap.round
      ..color = i.isEven ? Colors.white : const Color(0xFFFFF59D);
    final path = Path()
      ..moveTo(-s, -s * 0.15 * flap - s * 0.2)
      ..quadraticBezierTo(-s * 0.5, -s * (0.55 + 0.45 * flap), 0, 0)
      ..quadraticBezierTo(s * 0.5, -s * (0.55 + 0.45 * flap), s, -s * 0.15 * flap - s * 0.2);
    canvas.drawPath(path, wing);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EarthPainter o) => true;
}
