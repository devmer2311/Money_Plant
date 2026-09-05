import 'package:flutter_test/flutter_test.dart';
import 'package:money_plant/core/entry.dart';
import 'package:money_plant/features/goals/goal.dart';

/// Goals are never ticked off by hand — every one of them is a query over the
/// ledger, so this is where a goal can silently start lying to the user.
void main() {
  final now = DateTime(2026, 9, 10, 18);

  Entry out(double amount, int day, {String category = 'Food'}) => Entry(
        date: DateTime(2026, 9, day, 13),
        type: EntryType.outgoing,
        amount: amount,
        category: category,
      );

  Entry income(double amount) => Entry(
        date: DateTime(2026, 9, 1),
        type: EntryType.incoming,
        amount: amount,
        category: 'Salary',
      );

  Goal goal(GoalKind kind, double target, {String category = ''}) => Goal(
        id: 'g',
        kind: kind,
        title: 'Test',
        target: target,
        category: category,
        created: DateTime(2026, 9, 1),
      );

  group('save', () {
    test('counts what the month actually kept', () {
      final p = GoalProgress.of(
        goal(GoalKind.save, 5000),
        [income(24000), out(20000, 2)],
        now,
      );
      expect(p.current, 4000);
      expect(p.achieved, isFalse);
      expect(p.remaining, 1000);
      expect(p.fraction, closeTo(0.8, 0.001));
    });

    test('a month that spent more than it earned has saved nothing, not less',
        () {
      final p = GoalProgress.of(
        goal(GoalKind.save, 5000),
        [income(1000), out(4000, 2)],
        now,
      );
      expect(p.current, 0);
      expect(p.fraction, 0);
    });

    test('is met once the target is reached', () {
      final p = GoalProgress.of(
        goal(GoalKind.save, 5000),
        [income(24000), out(1000, 2)],
        now,
      );
      expect(p.achieved, isTrue);
    });
  });

  group('limit', () {
    test('only counts the category it was set for', () {
      final p = GoalProgress.of(
        goal(GoalKind.limit, 3000, category: 'Food'),
        [out(500, 2), out(9000, 3, category: 'Rent')],
        now,
      );
      expect(p.current, 500);
      expect(p.breached, isFalse);
    });

    test('flags a breach immediately but only settles after the month ends',
        () {
      final entries = [out(4000, 2)];
      final mid = GoalProgress.of(goal(GoalKind.limit, 3000), entries, now);
      expect(mid.breached, isTrue);
      expect(mid.achieved, isFalse);

      // Under the cap, but the month is still running: not won yet.
      final onTrack = GoalProgress.of(
        goal(GoalKind.limit, 3000),
        [out(100, 2)],
        now,
      );
      expect(onTrack.breached, isFalse);
      expect(onTrack.achieved, isFalse);

      final settled = GoalProgress.of(
        goal(GoalKind.limit, 3000),
        [out(100, 2)],
        DateTime(2026, 10, 1),
      );
      expect(settled.achieved, isTrue);
    });
  });

  group('streak', () {
    test('counts clean days back from today and stops at a spend', () {
      // Spent on the 7th, so the 10th, 9th and 8th are clean.
      final p = GoalProgress.of(
        goal(GoalKind.streak, 10, category: 'Food'),
        [out(200, 7)],
        now,
      );
      expect(p.current, 3);
      expect(p.achieved, isFalse);
    });

    test('spending in another category does not break it', () {
      final p = GoalProgress.of(
        goal(GoalKind.streak, 5, category: 'Food'),
        [out(9000, 7, category: 'Rent')],
        now,
      );
      expect(p.current, 10); // 1st through 10th
      expect(p.achieved, isTrue);
    });

    test('spending today ends the streak at zero', () {
      final p = GoalProgress.of(
        goal(GoalKind.streak, 5),
        [out(50, 10)],
        now,
      );
      expect(p.current, 0);
    });

    test('never counts days from before the goal existed', () {
      final late = Goal(
        id: 'g',
        kind: GoalKind.streak,
        title: 'Test',
        target: 10,
        created: DateTime(2026, 9, 8),
      );
      expect(GoalProgress.of(late, const [], now).current, 3); // 8th–10th
    });
  });

  test('a goal with no target cannot report progress or success', () {
    final p = GoalProgress.of(goal(GoalKind.save, 0), [income(100)], now);
    expect(p.fraction, 0);
    expect(p.achieved, isFalse);
  });

  test('a goal survives a round trip through storage', () {
    final g = goal(GoalKind.streak, 7, category: 'Food');
    final back = Goal.fromJson(g.toJson());
    expect(back.id, g.id);
    expect(back.kind, GoalKind.streak);
    expect(back.target, 7);
    expect(back.category, 'Food');
    expect(back.created, g.created);
  });

  test('a goal file written by an older build still loads', () {
    final back = Goal.fromJson(const <String, dynamic>{'title': 'Half a record'});
    expect(back.kind, GoalKind.save);
    expect(back.target, 0);
    expect(back.title, 'Half a record');
  });
}
