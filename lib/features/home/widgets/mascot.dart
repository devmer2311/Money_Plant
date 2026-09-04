import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// "Sprout" — the Money Plant mascot.
///
/// Drawn with a `CustomPainter` rather than shipped as a Rive/Lottie asset:
/// the whole app is offline-first and this keeps the APK free of binary
/// dependencies while still being fully procedural (mood, blink, breath and
/// tilt are all parameters, not baked timelines).
///
/// The 3D feel comes from three stacked tricks:
///   1. a perspective `Matrix4` driven by where the finger is (parallax tilt),
///   2. layered leaves that translate at different rates as it tilts,
///   3. a specular highlight that slides across the coin as it rotates.
///
/// Swapping in a real Rive file later is a drop-in: keep the [mood] input and
/// replace the `CustomPaint` with a `RiveAnimation` bound to the same number.
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    required this.mood,
    this.size = 190,
  });

  /// -1 = broke and miserable, 0 = neutral, 1 = thriving.
  final double mood;
  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final _poke = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// Tilt in [-1, 1] on each axis; springs back to centre when released.
  Offset _tilt = Offset.zero;
  double _blink = 0;
  late final _blinker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..addListener(() => setState(() => _blink = _blinker.value));

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    // Irregular blinks read as alive; a fixed interval reads as a loading spinner.
    final ms = 1800 + math.Random().nextInt(3400);
    Future.delayed(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _blinker.forward().then((_) => _blinker.reverse());
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    _poke.dispose();
    _blinker.dispose();
    super.dispose();
  }

  void _aim(Offset local) {
    final s = widget.size;
    setState(() {
      _tilt = Offset(
        ((local.dx / s) * 2 - 1).clamp(-1.0, 1.0),
        ((local.dy / s) * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _release() {
    setState(() => _tilt = Offset.zero);
    _poke.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _aim(d.localPosition),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onPanUpdate: (d) => _aim(d.localPosition),
      onPanEnd: (_) => _release(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _poke]),
        builder: (context, _) {
          final breath = math.sin(_idle.value * math.pi) * 0.02;
          // Squish on release, then elastically settle back to rest — the
          // inverted curve means it decays to exactly 0, so there is no snap
          // when the controller stops.
          final pop = _poke.isAnimating
              ? (1 - Curves.elasticOut.transform(_poke.value)) * 0.12
              : 0.0;

          return TweenAnimationBuilder<Offset>(
            tween: Tween(end: _tilt),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, tilt, __) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016) // perspective divisor
                ..rotateX(tilt.dy * 0.32)
                ..rotateY(-tilt.dx * 0.38)
                ..scale(1 + breath + pop),
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _SproutPainter(
                  mood: widget.mood.clamp(-1.0, 1.0),
                  tilt: tilt,
                  breath: breath,
                  blink: _blink,
                  primary: scheme.primary,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SproutPainter extends CustomPainter {
  _SproutPainter({
    required this.mood,
    required this.tilt,
    required this.breath,
    required this.blink,
    required this.primary,
    required this.dark,
  });

  final double mood, breath, blink;
  final Offset tilt;
  final Color primary;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);

    final sad = Color.lerp(MP.flame, MP.mint, (mood + 1) / 2)!;
    final leafColor = Color.lerp(sad, primary, 0.45)!;

    // --- ambient glow: sells the neon-on-black look ------------------------
    canvas.drawCircle(
      c.translate(0, s * 0.12),
      s * 0.42,
      Paint()
        ..color = leafColor.withValues(alpha: dark ? 0.20 : 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
    );

    // --- stem --------------------------------------------------------------
    final stem = Path()
      ..moveTo(c.dx, s * 0.80)
      ..quadraticBezierTo(
        c.dx - s * 0.07 + tilt.dx * s * 0.03,
        s * 0.60,
        c.dx + tilt.dx * s * 0.02,
        s * 0.40,
      );
    canvas.drawPath(
      stem,
      Paint()
        ..color = leafColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.045
        ..strokeCap = StrokeCap.round,
    );

    // --- leaves: back leaf shifts more than the front one, so tilting the
    //     mascot produces real parallax between them -------------------------
    _leaf(canvas, s, c, left: true, color: leafColor.withValues(alpha: 0.75),
        parallax: 1.6);
    _leaf(canvas, s, c, left: false, color: leafColor, parallax: 0.7);

    // --- coin body ---------------------------------------------------------
    final coin = Offset(c.dx, s * 0.82);
    final r = s * 0.20 * (1 + breath);
    canvas.drawCircle(
      coin,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(leafColor, Colors.white, 0.35)!, leafColor],
        ).createShader(Rect.fromCircle(center: coin, radius: r)),
    );

    // Specular highlight tracks the tilt — the cue that reads as "3D".
    canvas.drawOval(
      Rect.fromCenter(
        center: coin.translate(-r * 0.35 - tilt.dx * r * 0.4,
            -r * 0.42 - tilt.dy * r * 0.3),
        width: r * 0.8,
        height: r * 0.45,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    // --- face --------------------------------------------------------------
    final eyeY = coin.dy - r * 0.12;
    final eyeDx = r * 0.36;
    final lidHeight = (1 - blink).clamp(0.08, 1.0);
    final eyePaint = Paint()..color = dark ? MP.void_ : MP.graphite;

    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(coin.dx + dx + tilt.dx * r * 0.10,
              eyeY + tilt.dy * r * 0.08),
          width: r * 0.20,
          height: r * 0.30 * lidHeight,
        ),
        eyePaint,
      );
    }

    // Mouth: one quadratic whose control point flips with the mood.
    // mood  1 -> grin, 0 -> flat line, -1 -> frown.
    final mouthY = coin.dy + r * 0.34;
    final mouth = Path()
      ..moveTo(coin.dx - r * 0.34, mouthY)
      ..quadraticBezierTo(
        coin.dx,
        mouthY + mood * r * 0.34,
        coin.dx + r * 0.34,
        mouthY,
      );
    canvas.drawPath(
      mouth,
      Paint()
        ..color = eyePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..strokeCap = StrokeCap.round,
    );

    // A worried brow only appears once spending actually hurts.
    if (mood < -0.25) {
      final brow = Paint()
        ..color = eyePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round;
      for (final dir in [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(coin.dx + dir * eyeDx * 1.4, eyeY - r * 0.34),
          Offset(coin.dx + dir * eyeDx * 0.6, eyeY - r * 0.24),
          brow,
        );
      }
    }
  }

  void _leaf(
    Canvas canvas,
    double s,
    Offset c, {
    required bool left,
    required Color color,
    required double parallax,
  }) {
    final dir = left ? -1.0 : 1.0;
    // Droop when broke, lift when thriving.
    final lift = mood * s * 0.03;
    final anchor = Offset(
      c.dx + dir * s * 0.14 + tilt.dx * s * 0.02 * parallax,
      s * (left ? 0.50 : 0.42) - lift + tilt.dy * s * 0.015 * parallax,
    );

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(dir * (0.55 - mood * 0.18));
    canvas.drawOval(
      Rect.fromCenter(width: s * 0.30, height: s * 0.16, center: Offset.zero),
      Paint()..color = color,
    );
    // Midrib — a single darker stroke is enough to read as a leaf.
    canvas.drawLine(
      Offset(-s * 0.13, 0),
      Offset(s * 0.13, 0),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..strokeWidth = s * 0.008,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SproutPainter old) =>
      old.mood != mood ||
      old.tilt != tilt ||
      old.breath != breath ||
      old.blink != blink ||
      old.primary != primary;
}
