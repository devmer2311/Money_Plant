import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/entry.dart';
import '../../data/providers.dart';
import 'plant_state.dart';
import 'widgets/money_plant.dart';
import 'widgets/quick_add_card.dart';

final _money =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Home reads top to bottom the way the money does: balance, the plant that
/// balance produced, the way to change it, then what changed it recently.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(ledgerProvider).valueOrNull ?? const <Entry>[];
    final month = ref.watch(selectedMonthProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Stack(
      children: [
        const _Atmosphere(),
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(bottom: false, child: const _Header())
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.15, curve: Curves.easeOutCubic),
            ),
            SliverToBoxAdapter(
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: _HeroCard(),
              )
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 500.ms)
                  .slideY(begin: 0.06, curve: Curves.easeOutCubic),
            ),
            SliverToBoxAdapter(
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: QuickAddCard(),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 420.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENT ACTIVITY',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w700,
                        color: onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/history'),
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverToBoxAdapter(child: _EmptyState(month: month))
            else
              SliverList.builder(
                itemCount: entries.length.clamp(0, 8),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
                  child: EntryTile(
                    entry: entries[i],
                    onTap: () => showEntryEditor(context, entries[i]),
                  )
                      // Staggered entrance — each row 40ms behind the last.
                      .animate(delay: (40 * i).ms)
                      .fadeIn(duration: 320.ms)
                      .slideX(begin: 0.08, curve: Curves.easeOutCubic),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
        const _PlantToast(),
      ],
    );
  }
}

/// Soft off-screen colour fields. This is what keeps light mode off pure white
/// and dark mode off pure black without tinting any actual surface.
class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget blob(Alignment a, Color c, double size) => Align(
          alignment: a,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.withValues(alpha: dark ? 0.20 : 0.16),
                  c.withValues(alpha: 0)
                ],
              ),
            ),
          ),
        );

    return IgnorePointer(
      child: Stack(
        children: [
          blob(const Alignment(-0.9, -1.1), MP.violet, 380),
          blob(const Alignment(1.2, -0.35), MP.neon, 320),
          blob(const Alignment(-1.1, 0.7), MP.cyan, 300),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitals = ref.watch(plantVitalsProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, d MMM').format(DateTime.now()).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Money Plant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary,
                      boxShadow: [
                        BoxShadow(
                            color: primary.withValues(alpha: 0.7),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          )),
          const SizedBox(width: 10),
          // Leaf count instead of a decorative bell — it is the one number the
          // plant animations are actually spending.
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: primary.withValues(alpha: 0.10),
              border: Border.all(color: primary.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_rounded, size: 14, color: primary),
                const SizedBox(width: 6),
                Text(
                  '${vitals.leaves}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'leaves',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primary.withValues(alpha: 0.7),
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

/// Balance, plant and the month's two totals in one frosted panel — so the
/// money and the thing it grew are impossible to read separately.
class _HeroCard extends ConsumerStatefulWidget {
  const _HeroCard();

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<_HeroCard> {
  bool _tip = true;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(monthSummaryProvider);
    final vitals = ref.watch(plantVitalsProvider);
    final event = ref.watch(plantEventsProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final positive = summary.balance >= 0;
    final accent = positive ? MP.neon : MP.flame;

    return Glass(
      radius: 30,
      tint: positive ? MP.neon : MP.violet,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expanded + scaleDown so a seven-figure balance shrinks instead
              // of shoving the mood chip off the card.
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL BALANCE',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _Counter(
                      value: summary.balance,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.8,
                        height: 1,
                        color: accent,
                      ),
                      signed: true,
                    ),
                  ),
                ],
              )),
              const SizedBox(width: 10),
              _MoodChip(vitals: vitals),
            ],
          ),
          const SizedBox(height: 14),
          _BudgetBar(vitals: vitals),

          // --- the plant --------------------------------------------------
          LayoutBuilder(
            builder: (context, c) {
              // Scales with the phone but never grows enough to push the
              // month's totals below the fold.
              final size = (c.maxWidth * 0.60).clamp(160.0, 220.0);
              return SizedBox(
                // Full height plus a little: the pot's contact shadow and the
                // outer leaves paint right to the edge of the box.
                height: size * 1.04,
                child: Center(
                  child: MoneyPlant(
                    vitals: vitals,
                    event: event,
                    blooming: ref.watch(bloomingProvider),
                    size: size,
                  ),
                ),
              );
            },
          ),

          if (_tip && !positive) ...[
            _Tip(onClose: () => setState(() => _tip = false)),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Income',
                  value: summary.income,
                  color: MP.neon,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Expenses',
                  value: summary.spent,
                  color: MP.flame,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The month's budget as a bar. Also the plant's growth capacity, which is why
/// it sits directly under the balance and directly above the plant.
class _BudgetBar extends ConsumerWidget {
  const _BudgetBar({required this.vitals});
  final PlantVitals vitals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final over = vitals.left < 0;
    // Green while there is room, amber on the last fifth, red once past it.
    final color = over
        ? MP.flame
        : Color.lerp(MP.neon, MP.amber, (vitals.used / 0.8).clamp(0.0, 1.0))!;

    return GestureDetector(
      onTap: () => _editBudget(context, ref, vitals.budget),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'MONTHLY BUDGET',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.edit_rounded,
                  size: 11, color: onSurface.withValues(alpha: 0.35)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  over
                      ? '${_money.format(vitals.left.abs())} over'
                      : '${_money.format(vitals.left)} left',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 7, color: onSurface.withValues(alpha: 0.07)),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: vitals.used.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.65), color],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${_money.format(vitals.spent)} of ${_money.format(vitals.budget)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Text(
                'Stage ${vitals.stage} of 6',
                style: TextStyle(
                  fontSize: 11,
                  color: onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _editBudget(
    BuildContext context, WidgetRef ref, double current) async {
  final field = TextEditingController(text: current.toStringAsFixed(0));
  final value = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Monthly budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A full plant is one untouched budget. Spending trims it back.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: field,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(prefixText: '₹  ', isDense: true),
            onSubmitted: (v) =>
                Navigator.pop(context, double.tryParse(v.trim())),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, double.tryParse(field.text.trim())),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  field.dispose();
  if (value != null && value > 0) {
    await ref.read(budgetProvider.notifier).set(value);
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.vitals});
  final PlantVitals vitals;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(MP.flame, MP.neon, vitals.health)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 900.ms),
          const SizedBox(width: 7),
          Text(
            vitals.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: MP.amber.withValues(alpha: 0.08),
        border: Border.all(color: MP.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 18, color: MP.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Let's turn things around",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MP.amber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have spent more than you earned this month.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded,
                size: 16, color: onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Counts to its value rather than popping in — the number *is* the animation,
/// and it runs at the same time the plant gains or loses the matching leaves.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.style,
    this.signed = false,
  });

  final double value;
  final TextStyle style;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        signed && v < 0 ? '−${_money.format(v.abs())}' : _money.format(v),
        style: style,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: onSurface.withValues(alpha: 0.04),
        border: Border.all(color: onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Counter(
            value: value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating glass note that names what just happened, in rupees and in
/// leaves. Non-blocking: it never takes a tap and never gates the UI.
class _PlantToast extends ConsumerStatefulWidget {
  const _PlantToast();

  @override
  ConsumerState<_PlantToast> createState() => _PlantToastState();
}

class _PlantToastState extends ConsumerState<_PlantToast> {
  PlantEvent? _shown;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlantEvent?>(plantEventsProvider, (_, e) {
      if (e == null) return;
      setState(() => _shown = e);
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 2900), () {
        if (mounted) setState(() => _shown = null);
      });
    });

    final e = _shown;
    final visible = e != null;
    final grew = (e?.leafDelta ?? 0) >= 0;
    final accent = grew ? MP.neon : MP.flame;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 18,
      right: 18,
      child: IgnorePointer(
        child: AnimatedSlide(
          offset: Offset(0, visible ? 0 : -1.4),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 280),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: MP.violet.withValues(alpha: 0.16),
                    border: Border.all(color: accent.withValues(alpha: 0.30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.eco_rounded, size: 18, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e?.title ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              e?.detail ?? '',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        e?.leafLine ?? '',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
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

/// Shared by Home and the ledger screen.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.onTap});

  final Entry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.type) {
      EntryType.incoming => MP.neon,
      EntryType.outgoing => MP.flame,
      EntryType.task => MP.violet,
    };
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final tone = MP.forCategory(entry.category);

    return Glass(
      radius: 22,
      tint: color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tone.withValues(alpha: 0.25)),
            ),
            child: Icon(MP.iconFor(entry.category), size: 18, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description.isEmpty
                      ? entry.category
                      : entry.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.category} · ${DateFormat('d MMM, HH:mm').format(entry.date)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          if (entry.type != EntryType.task)
            Text(
              '${entry.type == EntryType.incoming ? '+' : '−'}${_money.format(entry.amount)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: color,
              ),
            )
          else
            Icon(Icons.check_circle_outline_rounded, size: 20, color: color),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Center(
        child: Text(
          'Nothing logged in ${DateFormat('MMMM').format(month)} yet.\nThe card above is waiting.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}
