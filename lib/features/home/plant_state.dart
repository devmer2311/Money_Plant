import 'package:flutter/foundation.dart' hide Summary;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entry.dart';
import '../../data/providers.dart';

/// A full canopy is one untouched monthly budget. Everything else — how many
/// rupees a leaf is worth, how much of the plant a transaction moves — falls
/// out of that, so the plant scales to a ₹2,000 month and a ₹200,000 one
/// without a second constant to keep in sync.
const kMaxLeaves = 18;
const kMinLeaves = 3;

enum PlantMood { calm, happy, excited, tired, worried, embarrassed }

/// What the plant looks like right now, derived purely from the month's money.
/// Nothing about the plant is persisted: the ledger *is* its memory.
@immutable
class PlantVitals {
  const PlantVitals({
    required this.leaves,
    required this.health,
    required this.mood,
    required this.budget,
    required this.spent,
  });

  final int leaves;

  /// 0 = the budget is gone, 1 = nothing spent.
  final double health;
  final PlantMood mood;
  final double budget, spent;

  double get left => budget - spent;
  double get used => budget <= 0 ? 0 : (spent / budget).clamp(0.0, 2.0);

  /// 1‥6. Long-term progression falls out of foliage, so a good month lifts it
  /// and a bad one lowers it without any extra state to keep in sync.
  int get stage =>
      ((leaves - kMinLeaves) / (kMaxLeaves - kMinLeaves) * 5).round() + 1;

  String get label => switch (mood) {
        PlantMood.excited => 'Blooming',
        PlantMood.happy => 'Thriving',
        PlantMood.calm => 'Steady',
        PlantMood.tired => 'A little tired',
        PlantMood.worried => 'Needs care',
        PlantMood.embarrassed => 'Tidying up…',
      };

  /// What one leaf costs this month. Also the smallest expense that can move
  /// the plant at all.
  static double perLeaf(double budget) => budget / kMaxLeaves;

  factory PlantVitals.of(Summary s, double budget) {
    final perLeaf = PlantVitals.perLeaf(budget);
    // Budget sets the canopy; spending eats into it; income earned beyond the
    // budget grows a little extra on top.
    final surplus = (s.income - budget).clamp(0.0, double.infinity);
    final leaves = perLeaf <= 0
        ? kMaxLeaves
        : (kMaxLeaves - s.spent / perLeaf + surplus / perLeaf / 3)
            .round()
            .clamp(kMinLeaves, kMaxLeaves);

    final health = budget <= 0 ? 1.0 : (1 - s.spent / budget).clamp(0.0, 1.0);
    final untouched = s.spent == 0;

    return PlantVitals(
      leaves: leaves,
      health: health.toDouble(),
      budget: budget,
      spent: s.spent,
      // A month nobody has spent in yet is calm, not proud — there is nothing
      // to be proud of until money has actually been managed.
      mood: untouched
          ? PlantMood.calm
          : switch (health) {
              > 0.7 => PlantMood.happy,
              > 0.45 => PlantMood.calm,
              > 0.15 => PlantMood.tired,
              _ => PlantMood.worried,
            },
    );
  }
}

final plantVitalsProvider = Provider<PlantVitals>(
  (ref) => PlantVitals.of(
    ref.watch(monthSummaryProvider),
    ref.watch(monthlyBudgetProvider),
  ),
);

enum PlantAction { expense, income, edit, delete }

/// One thing that just happened to the money, phrased in leaves.
@immutable
class PlantEvent {
  const PlantEvent({
    required this.action,
    required this.title,
    required this.detail,
    required this.leafDelta,
  }) : stamp = 0;

  const PlantEvent._(
    this.action,
    this.title,
    this.detail,
    this.leafDelta,
    this.stamp,
  );

  final PlantAction action;
  final String title;
  final String detail;

  /// Leaves the plant actually gained or lost — measured across the write, not
  /// recomputed from the amount, so the caption can never disagree with the
  /// animation the user is watching.
  final int leafDelta;

  /// Distinguishes two identical events so the same one can replay.
  final int stamp;

  PlantEvent stamped(int s) =>
      PlantEvent._(action, title, detail, leafDelta, s);

  String get leafLine {
    if (leafDelta == 0) return 'no change';
    final n = leafDelta.abs();
    return '${leafDelta > 0 ? '+' : '−'}$n ${n == 1 ? 'leaf' : 'leaves'}';
  }
}

/// Fired by [Ledger] after every write; the plant listens, nothing else has to.
class PlantEvents extends Notifier<PlantEvent?> {
  var _stamp = 0;

  @override
  PlantEvent? build() => null;

  void fire(PlantEvent e) => state = e.stamped(++_stamp);
}

final plantEventsProvider =
    NotifierProvider<PlantEvents, PlantEvent?>(PlantEvents.new);
