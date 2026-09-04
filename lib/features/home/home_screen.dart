import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/entry.dart';
import '../../data/providers.dart';
import 'widgets/mascot.dart';
import 'widgets/quick_add_card.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final entries = ref.watch(ledgerProvider).valueOrNull ?? const <Entry>[];
    final month = ref.watch(selectedMonthProvider);

    // Mood: fully happy while spending under half of income, unhappy past it,
    // miserable once outgoings exceed what came in.
    final mood = (1 - summary.burnRate * 1.6).clamp(-1.0, 1.0);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMM').format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12.5,
                          letterSpacing: 0.4,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Money Plant',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  _BalancePill(balance: summary.balance),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.15, curve: Curves.easeOutCubic),
        ),

        // --- mascot ---------------------------------------------------------
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  Mascot(mood: mood),
                  Text(
                    _moodLine(summary, mood),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ).animate(key: ValueKey(_moodLine(summary, mood)))
                      .fadeIn(duration: 350.ms),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 500.ms)
              .scaleXY(begin: 0.85, curve: Curves.easeOutBack, duration: 600.ms),
        ),

        // --- the reason we're here -------------------------------------------
        SliverToBoxAdapter(
          child: const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: QuickAddCard(),
          )
              .animate()
              .fadeIn(delay: 180.ms, duration: 420.ms)
              .slideY(begin: 0.12, curve: Curves.easeOutCubic),
        ),

        // --- totals ----------------------------------------------------------
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Income',
                    value: summary.income,
                    color: MP.neon,
                    icon: Icons.south_west_rounded,
                    delay: 240,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Spent',
                    value: summary.spent,
                    color: MP.flame,
                    icon: Icons.north_east_rounded,
                    delay: 300,
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- today's rows -----------------------------------------------------
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 2.6,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (entries.isEmpty)
          const SliverToBoxAdapter(child: _EmptyState())
        else
          SliverList.builder(
            itemCount: entries.length.clamp(0, 8),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: EntryTile(entry: entries[i])
                  // Staggered list entrance — each row 40ms behind the last.
                  .animate(delay: (40 * i).ms)
                  .fadeIn(duration: 320.ms)
                  .slideX(begin: 0.08, curve: Curves.easeOutCubic),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  String _moodLine(Summary s, double mood) {
    if (s.income == 0 && s.spent == 0) return 'Feed me your first entry';
    if (mood > 0.5) return 'Thriving. Keep it up.';
    if (mood > 0) return 'Steady. Watch the small stuff.';
    if (mood > -0.5) return 'Spending is outpacing income.';
    return 'We need to talk about this month.';
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    final positive = balance >= 0;
    final color = positive ? MP.neon : MP.flame;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'BALANCE',
            style: TextStyle(
              fontSize: 8.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          // Counts up from zero instead of popping in — the number itself is
          // the animation.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: balance),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              _money.format(v),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: color,
              ),
            ),
          ),
        ],
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
    required this.delay,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Glass(
      tint: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              _money.format(v),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 400.ms).slideY(
          begin: 0.2,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Shared by Home and the ledger screen.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.type) {
      EntryType.incoming => MP.neon,
      EntryType.outgoing => MP.flame,
      EntryType.task => MP.violet,
    };
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Glass(
      radius: 20,
      tint: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(entry.type.icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description.isEmpty ? entry.category : entry.description,
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Center(
        child: Text(
          'Nothing logged this month yet.\nThe card above is waiting.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.4),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}
