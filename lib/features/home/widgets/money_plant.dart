import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../plant_state.dart';

/// The money plant itself — pot, vines, heart leaves, face.
///
/// Drawn with a `CustomPainter` rather than a Rive/Lottie asset on purpose:
/// the app is offline-first and ships no binary animation blobs, and every
/// input here (leaf count, health, mood, blink, sway, touch) is a number
/// rather than a baked timeline, so the plant is a function of the ledger.
/// Swapping in a Rive file later is a drop-in — keep [vitals] and [event].
class MoneyPlant extends StatefulWidget {
  const MoneyPlant({
    super.key,
    required this.vitals,
    this.event,
    this.blooming = false,
    this.size = 208,
  });

  final PlantVitals vitals;

  /// The last thing that happened to the money. Drives the one-off
  /// cut / grow / glue-back animation and a temporary expression.
  final PlantEvent? event;

  /// A goal has been met. The plant flowers, and keeps flowering — the reward
  /// stays on screen rather than playing once and vanishing.
  final bool blooming;
  final double size;

  @override
  State<MoneyPlant> createState() => _MoneyPlantState();
}

class _MoneyPlantState extends State<MoneyPlant> with TickerProviderStateMixin {
  // One free-running clock for everything ambient: breath, sway, leaf flutter.
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  /// Leaves in flight: [_from] → [_to] over one run of this controller.
  late final _leaves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final _poke = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final AnimationController _blinker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  )..addListener(() => setState(() => _blink = _blinker.value));

  late int _from = widget.vitals.leaves;
  late int _to = widget.vitals.leaves;
  double _blink = 0;
  Offset _tilt = Offset.zero;
  PlantMood? _reaction;
  PlantAction? _acting;
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  Timer? _blinkTimer;
  Timer? _reactionTimer;

  void _scheduleBlink() {
    // Irregular blinks read as alive; a fixed interval reads as a spinner.
    // Held so it can be cancelled — an uncancelled chain outlives the widget.
    _blinkTimer = Timer(
      Duration(milliseconds: 1900 + math.Random().nextInt(3600)),
      () {
        if (!mounted) return;
        _blinker.forward().then((_) => _blinker.reverse());
        _scheduleBlink();
      },
    );
  }

  @override
  void didUpdateWidget(MoneyPlant old) {
    super.didUpdateWidget(old);

    final e = widget.event;
    if (e != null && e.stamp != old.event?.stamp) {
      _seed = e.stamp;
      _acting = e.action;
      _reaction = switch (e.action) {
        PlantAction.income => PlantMood.excited,
        PlantAction.expense => PlantMood.worried,
        PlantAction.delete => PlantMood.embarrassed,
        PlantAction.edit => PlantMood.calm,
      };
      // The expression outlives the leaf animation slightly, then decays back
      // to whatever the finances actually say.
      _reactionTimer?.cancel();
      _reactionTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _reaction = null);
      });
    }

    if (widget.vitals.leaves != _to) {
      _from = _to;
      _to = widget.vitals.leaves;
      _leaves.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _reactionTimer?.cancel();
    _idle.dispose();
    _leaves.dispose();
    _poke.dispose();
    _blinker.dispose();
    super.dispose();
  }

  void _aim(Offset local) {
    final s = widget.size;
    setState(() => _tilt = Offset(
          ((local.dx / s) * 2 - 1).clamp(-1.0, 1.0),
          ((local.dy / s) * 2 - 1).clamp(-1.0, 1.0),
        ));
  }

  void _release() {
    setState(() => _tilt = Offset.zero);
    _poke.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _aim(d.localPosition),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onPanUpdate: (d) => _aim(d.localPosition),
      onPanEnd: (_) => _release(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _leaves, _poke]),
        builder: (context, _) {
          // Squish on release, elastically settling to exactly 0 so there is
          // no snap when the controller stops.
          final pop = _poke.isAnimating
              ? (1 - Curves.elasticOut.transform(_poke.value)) * 0.10
              : 0.0;

          return TweenAnimationBuilder<Offset>(
            tween: Tween(end: _tilt),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, tilt, __) => CustomPaint(
              size: Size.square(widget.size),
              painter: _PlantPainter(
                from: _from,
                to: _to,
                progress: Curves.easeOutCubic.transform(_leaves.value),
                raw: _leaves.value,
                acting: _leaves.value < 1 ? _acting : null,
                health: widget.vitals.health,
                mood: _reaction ??
                    (widget.blooming && widget.vitals.health > 0.4
                        ? PlantMood.happy
                        : widget.vitals.mood),
                blooming: widget.blooming,
                phase: _idle.value,
                blink: _blink,
                tilt: tilt,
                pop: pop,
                seed: _seed,
                primary: scheme.primary,
                dark: dark,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A leaf's resting place on the canopy. Slots are stable, so leaf 4 is always
/// the same leaf — it can be cut, and glued back into exactly the same spot.
class _Slot {
  const _Slot(this.angle, this.reach, this.scale);
  final double angle, reach, scale;

  static _Slot at(int i) {
    final rank = i ~/ 2;
    final side = i.isEven ? -1.0 : 1.0;
    // Fan out from vertical, but sub-linearly — the crown stays dense while
    // the outer stalks reach for the horizontal.
    final spread = 0.20 + 1.42 * math.sqrt(rank / 8);
    // Alternate long and short stalks. Two rings instead of one is the whole
    // difference between a bushy pothos and a row of identical fronds.
    final ring = rank.isEven ? 1.0 : 0.70;
    // Deterministic jitter so the two sides are not a perfect mirror.
    final jitter = ((i * 37) % 11 - 5) / 90;
    return _Slot(
      -math.pi / 2 + side * (spread + jitter),
      (0.38 - 0.11 * (rank / 8)) * ring,
      1.0 - rank * 0.045,
    );
  }
}

class _PlantPainter extends CustomPainter {
  _PlantPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.raw,
    required this.acting,
    required this.health,
    required this.mood,
    required this.blooming,
    required this.phase,
    required this.blink,
    required this.tilt,
    required this.pop,
    required this.seed,
    required this.primary,
    required this.dark,
  });

  final int from, to, seed;
  final double progress, raw, health, phase, blink, pop;
  final PlantAction? acting;
  final PlantMood mood;
  final bool blooming;
  final Offset tilt;
  final Color primary;
  final bool dark;

  bool get _cutting => to < from;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final base = Offset(s * 0.5, s * 0.715);
    final sway = math.sin(phase * math.pi * 2) * 0.022 + tilt.dx * 0.05;
    final breath = math.sin(phase * math.pi * 4) * 0.012 + pop;

    // Healthy foliage is a brighter, cooler green; a tired plant desaturates
    // toward olive rather than going grey — grey reads as dead, not stressed.
    // The neon primary is kept for the glow; the blades themselves sit on a
    // deeper botanical green, or the plant reads as a highlighter.
    final foliage = Color.lerp(primary, const Color(0xFF1F8F57), 0.45)!;
    final leafBase = Color.lerp(const Color(0xFF6C8A5A), foliage, health)!;

    _glow(canvas, s, base, leafBase);
    _foliage(canvas, s, base, sway, breath, leafBase);
    _pot(canvas, s);
    _face(canvas, s);
    _particles(canvas, s, base);
  }

  void _glow(Canvas canvas, double s, Offset base, Color leaf) {
    canvas.drawCircle(
      base.translate(0, -s * 0.12),
      s * 0.38,
      Paint()
        ..color = leaf.withValues(alpha: (dark ? 0.20 : 0.13) * (0.4 + health))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.18),
    );
  }

  // --- vines + leaves -------------------------------------------------------

  void _foliage(
    Canvas canvas,
    double s,
    Offset base,
    double sway,
    double breath,
    Color leafBase,
  ) {
    final count = math.max(from, to);
    // Back to front by reach: the long outer stalks are painted first so the
    // short inner ones overlap them, which is what gives the canopy depth.
    final order = List.generate(count, (i) => i)
      ..sort((a, b) => _Slot.at(b).reach.compareTo(_Slot.at(a).reach));

    for (final i in order) {
      final settled = i < math.min(from, to);
      var p = 1.0, alpha = 1.0, drop = 0.0, spin = 0.0, scale = 1.0;

      if (!settled) {
        if (_cutting && i >= to) {
          // Cut: the leaf detaches and falls with a little sideways drift.
          p = progress;
          alpha = (1 - p * 1.15).clamp(0.0, 1.0);
          drop = p * p * s * 0.55;
          spin = p * 2.4 * (i.isEven ? -1 : 1);
        } else if (!_cutting && i >= from) {
          // Grow: the leaf unfurls from nothing and overshoots once.
          p = progress;
          scale = Curves.elasticOut.transform(p.clamp(0.0, 1.0)) * 0.9 + 0.1;
          alpha = (p * 2.5).clamp(0.0, 1.0);
        } else {
          continue;
        }
      }
      if (alpha <= 0.01) continue;

      final slot = _Slot.at(i);
      final side = slot.angle < -math.pi / 2 ? -1.0 : 1.0;
      // Droop grows with poor health and with distance out along the stalk.
      final droop = (1 - health) * 0.9 * (0.35 + slot.reach);
      final flutter = math.sin(phase * math.pi * 2 + i * 0.7) * 0.035;
      final angle = slot.angle + sway + flutter + side * droop;

      final reach = slot.reach * s * (1 + breath);
      final anchor = base +
          Offset(math.cos(angle) * reach, math.sin(angle) * reach + drop);

      _vine(canvas, s, base, anchor, angle, leafBase, alpha, settled ? 1 : p);
      // Blades hang a little past the stalk direction rather than pointing
      // dead-radially, which is what stops the canopy reading as a starburst.
      _leaf(canvas, s, anchor, angle + side * 0.26 + spin, slot.scale * scale,
          leafBase, alpha);
      // After the blade, or the leaf paints over it. Only the three innermost
      // stalks flower — a plant covered in blossom reads as a bouquet rather
      // than as an achievement.
      if (blooming && i < 3 && settled) _flower(canvas, s, anchor, angle, i);
    }
  }

  /// The stem running from the soil out to one leaf. Bowed away from the
  /// centre so the vines read as separate stalks instead of a starburst.
  void _vine(
    Canvas canvas,
    double s,
    Offset base,
    Offset anchor,
    double angle,
    Color leaf,
    double alpha,
    double grown,
  ) {
    final mid = Offset.lerp(base, anchor, 0.55)!;
    final bow =
        Offset(math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)) *
            s *
            0.035;
    final end = Offset.lerp(base, anchor, grown.clamp(0.0, 1.0))!;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(mid.dx + bow.dx, mid.dy + bow.dy, end.dx, end.dy),
      Paint()
        ..color =
            Color.lerp(leaf, Colors.black, 0.35)!.withValues(alpha: 0.9 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.016
        ..strokeCap = StrokeCap.round,
    );
  }

  void _leaf(
    Canvas canvas,
    double s,
    Offset at,
    double angle,
    double scale,
    Color base,
    double alpha,
  ) {
    final k = scale.clamp(0.05, 2.0);
    final len = s * 0.185;
    final wide = len * 0.72;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.scale(k, k);

    // Pothos blade: two lobes bulging back past the stalk, a notch between
    // them, and a drawn-out point. The notch is what makes it read as a money
    // plant leaf rather than a generic oval.
    final leaf = Path()
      ..moveTo(len, 0)
      ..cubicTo(len * 0.58, -wide * 0.86, len * 0.16, -wide * 0.92, -len * 0.06,
          -wide * 0.30)
      ..cubicTo(len * 0.10, -wide * 0.10, len * 0.10, wide * 0.10, -len * 0.06,
          wide * 0.30)
      ..cubicTo(len * 0.16, wide * 0.92, len * 0.58, wide * 0.86, len, 0)
      ..close();

    final rect = Rect.fromLTWH(-len * 0.1, -wide, len * 1.1, wide * 2);
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.32)!.withValues(alpha: alpha),
            base.withValues(alpha: alpha),
            Color.lerp(base, Colors.black, 0.42)!.withValues(alpha: alpha),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    // Midrib and a few lateral veins.
    final vein = Paint()
      ..color =
          Color.lerp(base, Colors.black, 0.32)!.withValues(alpha: 0.45 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = len * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, 0), Offset(len * 0.92, 0), vein);
    for (final t in const [0.18, 0.42, 0.64]) {
      for (final s in const [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(len * t, 0),
          Offset(len * (t + 0.20), s * wide * (0.62 - t * 0.5)),
          vein..strokeWidth = len * 0.018,
        );
      }
    }
    // Glossy specular streak along the upper edge — the reason the leaves read
    // as translucent rather than as flat vector shapes.
    canvas.drawPath(
      Path()
        ..moveTo(len * 0.18, -wide * 0.16)
        ..quadraticBezierTo(len * 0.5, -wide * 0.44, len * 0.78, -wide * 0.14),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = len * 0.055
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// Five petals and a gold centre, breathing very slightly out of phase with
  /// the plant so the crown never looks stamped on.
  void _flower(Canvas canvas, double s, Offset at, double angle, int i) {
    final r = s * 0.021 * (1 + math.sin(phase * math.pi * 2 + i) * 0.08);
    // At the junction where the blade meets its stalk, so it reads as a bud
    // rather than a sticker in the middle of a leaf.
    final centre = at + Offset(math.cos(angle), math.sin(angle)) * s * 0.012;
    final petal = Paint()..color = const Color(0xFFFFE9F2);
    for (var k = 0; k < 5; k++) {
      final a = angle + k * math.pi * 2 / 5;
      canvas.drawCircle(
        centre + Offset(math.cos(a), math.sin(a)) * r,
        r * 0.95,
        petal,
      );
    }
    canvas.drawCircle(
      centre,
      r * 0.75,
      Paint()..color = const Color(0xFFFFC94D),
    );
  }

  // --- pot ------------------------------------------------------------------

  void _pot(Canvas canvas, double s) {
    final cx = s * 0.5;
    final top = s * 0.70;
    final bottom = s * 0.95;
    final halfTop = s * 0.20;
    final halfBase = s * 0.145;

    // Contact shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bottom + s * 0.012),
        width: s * 0.40,
        height: s * 0.05,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.55 : 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );

    // Soil.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, top),
        width: halfTop * 2,
        height: s * 0.055,
      ),
      Paint()..color = const Color(0xFF241E1A),
    );

    final body = Path()
      ..moveTo(cx - halfTop, top)
      ..lineTo(cx + halfTop, top)
      ..lineTo(cx + halfBase, bottom - s * 0.02)
      ..quadraticBezierTo(
          cx + halfBase, bottom, cx + halfBase - s * 0.02, bottom)
      ..lineTo(cx - halfBase + s * 0.02, bottom)
      ..quadraticBezierTo(
          cx - halfBase, bottom, cx - halfBase, bottom - s * 0.02)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF39415A), Color(0xFF232A3C), Color(0xFF161B28)]
              : const [Color(0xFFE7E9F2), Color(0xFFCFD4E4), Color(0xFFAEB5CB)],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTRB(cx - halfTop, top, cx + halfTop, bottom)),
    );

    // Rim: a single lit band is what makes a flat trapezoid read as ceramic.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, top + s * 0.012),
          width: halfTop * 2.16,
          height: s * 0.048,
        ),
        Radius.circular(s * 0.024),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: dark
              ? const [Color(0xFF454E6B), Color(0xFF2A3145)]
              : const [Color(0xFFF3F5FC), Color(0xFFD3D8E8)],
        ).createShader(
          Rect.fromLTRB(cx - halfTop, top, cx + halfTop, top + s * 0.05),
        ),
    );

    // Specular sweep down the left cheek.
    canvas.drawPath(
      Path()
        ..moveTo(cx - halfTop * 0.72, top + s * 0.06)
        ..quadraticBezierTo(
          cx - halfBase * 0.9,
          s * 0.86,
          cx - halfBase * 0.62,
          bottom - s * 0.02,
        ),
      Paint()
        ..color = Colors.white.withValues(alpha: dark ? 0.10 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014
        ..strokeCap = StrokeCap.round,
    );
  }

  // --- face -----------------------------------------------------------------

  void _face(Canvas canvas, double s) {
    final cx = s * 0.5;
    final eyeY = s * 0.815;
    final dx = s * 0.062;
    final r = s * 0.026;
    // The eyes glance where you touch, and glance aside when embarrassed.
    final look = Offset(
      tilt.dx * r * 0.5 + (mood == PlantMood.embarrassed ? r * 0.7 : 0),
      tilt.dy * r * 0.35,
    );
    final lid = (1 - blink).clamp(0.1, 1.0);
    final ink = dark ? const Color(0xFF080B12) : const Color(0xFF1A1F2E);

    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(cx + side * s * 0.115, eyeY + s * 0.028),
        s * 0.024,
        Paint()
          ..color = const Color(0xFFFF6E86).withValues(alpha: 0.42)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.008),
      );
    }

    for (final side in [-1.0, 1.0]) {
      final c = Offset(cx + side * dx + look.dx, eyeY + look.dy);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 1.7, height: r * 2.0 * lid),
        Paint()..color = ink,
      );
      if (lid > 0.5) {
        canvas.drawCircle(
          c.translate(-r * 0.32, -r * 0.42),
          r * 0.34,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
        // Excitement reads through the eyes, not through a bigger smile.
        if (mood == PlantMood.excited) {
          canvas.drawCircle(
            c.translate(r * 0.36, r * 0.30),
            r * 0.16,
            Paint()..color = Colors.white.withValues(alpha: 0.7),
          );
        }
      }
    }

    _mouth(canvas, s, Offset(cx, s * 0.875), s * 0.030, ink);

    if (mood == PlantMood.worried || mood == PlantMood.tired) {
      final brow = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.009
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(cx + side * dx * 1.55, eyeY - r * 1.5),
          Offset(cx + side * dx * 0.55, eyeY - r * 1.05),
          brow,
        );
      }
    }
  }

  void _mouth(Canvas canvas, double s, Offset at, double w, Color ink) {
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.011
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case PlantMood.excited:
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - w, at.dy - w * 0.1)
            ..quadraticBezierTo(
                at.dx, at.dy + w * 1.5, at.dx + w, at.dy - w * 0.1)
            ..close(),
          Paint()..color = ink,
        );
      case PlantMood.happy || PlantMood.calm:
        final lift = mood == PlantMood.happy ? 1.0 : 0.55;
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - w, at.dy)
            ..quadraticBezierTo(at.dx, at.dy + w * lift, at.dx + w, at.dy),
          stroke,
        );
      case PlantMood.embarrassed:
        // Small, off-centre, pretending nothing happened.
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - w * 0.5, at.dy)
            ..quadraticBezierTo(at.dx + w * 0.2, at.dy + w * 0.7,
                at.dx + w * 0.9, at.dy - w * 0.3),
          stroke,
        );
      case PlantMood.tired:
        canvas.drawLine(
          Offset(at.dx - w * 0.7, at.dy + w * 0.15),
          Offset(at.dx + w * 0.7, at.dy + w * 0.15),
          stroke,
        );
      case PlantMood.worried:
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - w * 0.8, at.dy + w * 0.5)
            ..quadraticBezierTo(
                at.dx, at.dy - w * 0.5, at.dx + w * 0.8, at.dy + w * 0.5),
          stroke,
        );
    }
  }

  // --- particles ------------------------------------------------------------

  /// Dust off a cut leaf, sparkles off a new one. Seeded from the event id so
  /// the same frame always draws the same specks — the painter stays pure.
  void _particles(Canvas canvas, double s, Offset base) {
    if (acting == null || raw >= 1) return;
    final p = raw;
    final rnd = math.Random(seed * 7919);
    final gold = acting == PlantAction.income;
    final changed = (from - to).abs().clamp(1, 6);

    for (var n = 0; n < changed * 5; n++) {
      final slot = _Slot.at((math.min(from, to) + n ~/ 5) % kMaxLeaves);
      final origin = base +
          Offset(math.cos(slot.angle), math.sin(slot.angle)) * slot.reach * s;
      final a = rnd.nextDouble() * math.pi * 2;
      final speed = (0.4 + rnd.nextDouble()) * s * 0.16;
      // Gold rises, leaf dust settles.
      final pos = origin +
          Offset(
            math.cos(a) * speed * p,
            math.sin(a) * speed * p + (gold ? -1 : 1) * p * p * s * 0.18,
          );
      canvas.drawCircle(
        pos,
        s * (gold ? 0.011 : 0.008) * (1 - p * 0.6),
        Paint()
          ..color = (gold ? const Color(0xFFFFC94D) : MP.mint)
              .withValues(alpha: (1 - p) * 0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.004),
      );
    }
  }

  @override
  bool shouldRepaint(_PlantPainter old) => true; // every field is animated
}
