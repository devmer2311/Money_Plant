import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/entry.dart';
import '../../data/providers.dart';
import '../home/plant_state.dart';
import '../home/widgets/money_plant.dart';
import 'goal.dart';

final _money =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Goals and challenges, all of them measured off the ledger rather than
/// ticked off by hand — see [GoalProgress].
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(goalProgressProvider);
    final vitals = ref.watch(plantVitalsProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // The card at the top is whichever goal is most worth looking at: a won
    // one first, otherwise the one closest to being won.
    final sorted = [...progress]
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final hero =
        sorted.where((p) => p.achieved).firstOrNull ?? sorted.firstOrNull;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GOALS & CHALLENGES',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w700,
                            color: onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Keep the plant growing',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  _NewGoalButton(),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 380.ms)
              .slideY(begin: -0.12, curve: Curves.easeOutCubic),
        ),
        if (hero != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _HeroGoal(progress: hero, vitals: vitals),
            )
                .animate()
                .fadeIn(delay: 80.ms, duration: 460.ms)
                .slideY(begin: 0.06, curve: Curves.easeOutCubic),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Text(
              'ACTIVE GOALS & LIMITS',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
                color: onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        // The monthly budget is a limit too, so it belongs in this list even
        // though it is not stored as a goal.
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _BudgetGoalCard(),
          ),
        ),
        if (progress.isEmpty)
          const SliverToBoxAdapter(child: _EmptyGoals())
        else
          SliverList.builder(
            itemCount: progress.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _GoalCard(progress: progress[i])
                  .animate(delay: (50 * i).ms)
                  .fadeIn(duration: 320.ms)
                  .slideX(begin: 0.06, curve: Curves.easeOutCubic),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

class _NewGoalButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showNewGoalSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: primary.withValues(alpha: 0.12),
          border: Border.all(color: primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: primary),
            const SizedBox(width: 5),
            Text(
              'New goal',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The celebration card. When a goal is won the plant flowers here first —
/// this screen is where the reward makes sense.
class _HeroGoal extends StatelessWidget {
  const _HeroGoal({required this.progress, required this.vitals});

  final GoalProgress progress;
  final PlantVitals vitals;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final won = progress.achieved;
    final accent = won
        ? MP.neon
        : (progress.breached
            ? MP.flame
            : Theme.of(context).colorScheme.primary);

    return Glass(
      radius: 30,
      tint: accent,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final size = (c.maxWidth * 0.52).clamp(150.0, 200.0);
              return SizedBox(
                height: size * 1.04,
                child: Center(
                  child: MoneyPlant(
                    vitals: vitals,
                    blooming: won,
                    size: size,
                  ),
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              won
                  ? 'GOAL ACHIEVED'
                  : (progress.breached ? 'OVER THE LIMIT' : 'IN PROGRESS'),
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progress.goal.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _headline(progress),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  String _headline(GoalProgress p) => switch (p.goal.kind) {
        GoalKind.save => p.achieved
            ? 'You put ${_money.format(p.current)} aside this month.'
            : '${_money.format(p.current)} saved of ${_money.format(p.goal.target)} — ${_money.format(p.remaining)} to go.',
        GoalKind.limit => p.breached
            ? 'Spent ${_money.format(p.current)} against a ${_money.format(p.goal.target)} cap.'
            : '${_money.format(p.current)} spent, ${_money.format(p.remaining)} still under the cap.',
        GoalKind.streak => p.achieved
            ? '${p.current.toInt()} days clean. Challenge completed.'
            : '${p.current.toInt()} of ${p.goal.target.toInt()} days without spending on ${p.goal.category.isEmpty ? 'anything' : p.goal.category.toLowerCase()}.',
      };
}

/// The monthly budget, shown in the same shape as a goal so the list reads as
/// one thing. Tapping it opens the same editor as the home screen bar.
class _BudgetGoalCard extends ConsumerWidget {
  const _BudgetGoalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitals = ref.watch(plantVitalsProvider);
    final over = vitals.left < 0;
    return _ProgressCard(
      icon: Icons.account_balance_wallet_rounded,
      accent: over ? MP.flame : MP.neon,
      title: 'Monthly spend limit',
      value: _money.format(vitals.budget),
      trailing: '${(vitals.used * 100).round()}%',
      fraction: vitals.used.clamp(0.0, 1.0),
      left: '${_money.format(vitals.spent)} spent',
      right: over
          ? '${_money.format(vitals.left.abs())} over'
          : '${_money.format(vitals.left)} left',
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.progress});
  final GoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = progress;
    final streak = p.goal.kind == GoalKind.streak;
    final accent = p.achieved
        ? MP.neon
        : (p.breached ? MP.flame : Theme.of(context).colorScheme.primary);

    return Dismissible(
      key: ValueKey(p.goal.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: MP.flame.withValues(alpha: 0.14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: MP.flame),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(goalsProvider.notifier).remove(p.goal.id);
      },
      child: _ProgressCard(
        icon: p.goal.kind.icon,
        accent: accent,
        title: p.goal.title,
        value: streak
            ? '${p.current.toInt()} / ${p.goal.target.toInt()} days'
            : _money.format(p.goal.target),
        trailing: '${(p.fraction * 100).round()}%',
        fraction: p.fraction,
        left: p.goal.category.isEmpty ? p.goal.kind.label : p.goal.category,
        right: switch (p.goal.kind) {
          GoalKind.save => '${_money.format(p.current)} saved',
          GoalKind.limit => '${_money.format(p.current)} spent',
          GoalKind.streak => p.achieved ? 'Completed' : 'Keep going',
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
    required this.trailing,
    required this.fraction,
    required this.left,
    required this.right,
  });

  final IconData icon;
  final Color accent;
  final String title, value, trailing, left, right;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Glass(
      radius: 24,
      tint: accent,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 7, color: onSurface.withValues(alpha: 0.07)),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: fraction),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v.clamp(0.0, 1.0),
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent.withValues(alpha: 0.6), accent],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 10),
      child: Text(
        'No goals yet.\nA goal is measured off your ledger, so there is '
        'nothing to tick off by hand.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          height: 1.6,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

// ------------------------------------------------------------- new goal ---

Future<void> showNewGoalSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          top: 10,
        ),
        child: const _NewGoalForm(),
      ),
    );

class _NewGoalForm extends ConsumerStatefulWidget {
  const _NewGoalForm();

  @override
  ConsumerState<_NewGoalForm> createState() => _NewGoalFormState();
}

class _NewGoalFormState extends ConsumerState<_NewGoalForm> {
  final _title = TextEditingController();
  final _target = TextEditingController();
  GoalKind _kind = GoalKind.save;
  String _category = '';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = double.tryParse(_target.text.trim()) ?? 0;
    if (target <= 0) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    await ref.read(goalsProvider.notifier).add(
          Goal(
            id: now.microsecondsSinceEpoch.toString(),
            kind: _kind,
            title: _title.text.trim().isEmpty
                ? _defaultTitle()
                : _title.text.trim(),
            target: target,
            category: _kind == GoalKind.save ? '' : _category,
            created: now,
          ),
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  String _defaultTitle() => switch (_kind) {
        GoalKind.save => 'Save this month',
        GoalKind.limit => _category.isEmpty ? 'Spending cap' : '$_category cap',
        GoalKind.streak =>
          _category.isEmpty ? 'No-spend streak' : 'No $_category streak',
      };

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    final streak = _kind == GoalKind.streak;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Glass(
          tint: primary,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final k in GoalKind.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _kind = k);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: k == _kind
                                ? primary.withValues(alpha: 0.16)
                                : onSurface.withValues(alpha: 0.04),
                            border: Border.all(
                              color: k == _kind
                                  ? primary.withValues(alpha: 0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                k.icon,
                                size: 18,
                                color: k == _kind
                                    ? primary
                                    : onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                k.label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: k == _kind
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: k == _kind
                                      ? primary
                                      : onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _kind.blurb,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    streak ? '#' : '₹',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: primary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _target,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.4,
                        height: 1.1,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: streak ? '10' : '5000',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (streak)
                    Text(
                      'days',
                      style: TextStyle(
                        fontSize: 14,
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
              if (_kind != GoalKind.save) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kCategories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = i == 0 ? '' : kCategories[i - 1];
                      final selected = c == _category;
                      return GestureDetector(
                        onTap: () => setState(() => _category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? primary.withValues(alpha: 0.16)
                                : onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: selected
                                  ? primary.withValues(alpha: 0.55)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            i == 0 ? 'Everything' : c,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? primary
                                  : onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _defaultTitle(),
                  prefixIcon: const Icon(Icons.flag_rounded, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        primary,
                        Color.lerp(primary, Colors.white, 0.25)!,
                      ],
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black87,
                          ),
                        )
                      : const Text(
                          'Set goal',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
