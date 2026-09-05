import 'package:flutter/material.dart';

import '../../core/entry.dart';

/// Every goal is *measured*, never manually ticked off: progress is read back
/// out of the month's ledger. Nothing here stores an amount the user typed as
/// "saved" — that would be a number the app made up.
enum GoalKind {
  save('Save', 'Put this much aside this month', Icons.savings_rounded),
  limit('Limit', 'Keep spending under a cap', Icons.speed_rounded),
  streak('Streak', 'Days in a row without spending', Icons.bolt_rounded);

  const GoalKind(this.label, this.blurb, this.icon);
  final String label;
  final String blurb;
  final IconData icon;

  static GoalKind parse(String? raw) => values.firstWhere(
        (k) => k.name == raw,
        orElse: () => GoalKind.save,
      );
}

@immutable
class Goal {
  const Goal({
    required this.id,
    required this.kind,
    required this.title,
    required this.target,
    required this.created,
    this.category = '',
  });

  final String id;
  final GoalKind kind;
  final String title;

  /// Rupees for [GoalKind.save] and [GoalKind.limit], days for
  /// [GoalKind.streak].
  final double target;

  /// Empty means "every category".
  final String category;
  final DateTime created;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'target': target,
        'category': category,
        'created': created.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        kind: GoalKind.parse(j['kind'] as String?),
        title: j['title'] as String? ?? 'Goal',
        target: (j['target'] as num?)?.toDouble() ?? 0,
        category: j['category'] as String? ?? '',
        created:
            DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
      );
}

/// A goal plus where it stands, computed from a month of entries.
@immutable
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.current,
    required this.achieved,
    required this.breached,
  });

  final Goal goal;

  /// Rupees saved, rupees spent, or clean days — matching [Goal.target]'s unit.
  final double current;

  /// The good outcome has happened.
  final bool achieved;

  /// A limit has been blown through. Never true for the other kinds.
  final bool breached;

  double get fraction =>
      goal.target <= 0 ? 0 : (current / goal.target).clamp(0.0, 1.0);

  /// What is left to do, in the goal's own units.
  double get remaining => (goal.target - current).clamp(0.0, double.infinity);

  static bool _matches(Entry e, String category) =>
      e.type == EntryType.outgoing &&
      (category.isEmpty || e.category == category);

  /// [entries] is the selected month; [now] is "today" so the streak can be
  /// counted backwards from it.
  factory GoalProgress.of(Goal goal, List<Entry> entries, DateTime now) {
    switch (goal.kind) {
      case GoalKind.save:
        final s = Summary.of(entries);
        final saved = (s.income - s.spent).clamp(0.0, double.infinity);
        return GoalProgress(
          goal: goal,
          current: saved.toDouble(),
          achieved: saved >= goal.target && goal.target > 0,
          breached: false,
        );

      case GoalKind.limit:
        final spent = entries
            .where((e) => _matches(e, goal.category))
            .fold(0.0, (sum, e) => sum + e.amount);
        return GoalProgress(
          goal: goal,
          current: spent,
          // Staying under a cap is only settled once the month is over;
          // until then the honest state is "still on track".
          achieved: spent <= goal.target && _monthIsOver(goal, now),
          breached: spent > goal.target,
        );

      case GoalKind.streak:
        // Count clean days backwards from today. A day with a matching expense
        // ends the run, so this is the *current* streak, not the best one.
        final start = _laterOf(
          DateTime(goal.created.year, goal.created.month, goal.created.day),
          DateTime(now.year, now.month, 1),
        );
        final spentDays = entries
            .where((e) => _matches(e, goal.category))
            .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
            .toSet();

        var days = 0;
        for (var d = DateTime(now.year, now.month, now.day);
            !d.isBefore(start);
            d = d.subtract(const Duration(days: 1))) {
          if (spentDays.contains(d)) break;
          days++;
        }
        return GoalProgress(
          goal: goal,
          current: days.toDouble(),
          achieved: days >= goal.target && goal.target > 0,
          breached: false,
        );
    }
  }

  static DateTime _laterOf(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static bool _monthIsOver(Goal goal, DateTime now) {
    final end = DateTime(goal.created.year, goal.created.month + 1, 1);
    return !now.isBefore(end);
  }
}
