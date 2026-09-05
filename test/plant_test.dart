import 'package:flutter_test/flutter_test.dart';
import 'package:money_plant/core/entry.dart';
import 'package:money_plant/features/home/plant_state.dart';

/// The budget → leaves conversion is the one piece of logic the whole plant
/// animation hangs off: if it drifts, every cut and every sprout is wrong.
void main() {
  const budget = 1800.0; // ₹100 a leaf at kMaxLeaves = 18

  Entry e(EntryType t, double amount) => Entry(
        date: DateTime(2026, 9, 4),
        type: t,
        amount: amount,
        category: 'Food',
      );

  PlantVitals vitals(List<Entry> entries, {double b = budget}) =>
      PlantVitals.of(Summary.of(entries), b);

  test('an untouched budget is a full canopy, calm', () {
    final v = vitals(const []);
    expect(v.leaves, kMaxLeaves);
    expect(v.health, 1);
    expect(v.mood, PlantMood.calm);
  });

  test('spending eats the canopy in proportion to the budget', () {
    expect(vitals([e(EntryType.outgoing, 300)]).leaves, kMaxLeaves - 3);
    expect(vitals([e(EntryType.outgoing, 900)]).leaves, kMaxLeaves - 9);
  });

  test('the same spend costs fewer leaves on a bigger budget', () {
    final small = vitals([e(EntryType.outgoing, 900)]);
    final large = vitals([e(EntryType.outgoing, 900)], b: 18000);
    expect(large.leaves, greaterThan(small.leaves));
    expect(large.leaves, kMaxLeaves - 1);
  });

  test('income beyond the budget grows a little extra on top', () {
    final plain = vitals([e(EntryType.outgoing, 900)]);
    final earned = vitals([
      e(EntryType.outgoing, 900),
      e(EntryType.incoming, 2700), // ₹900 past budget → +3 leaves worth /3
    ]);
    expect(earned.leaves, greaterThan(plain.leaves));
  });

  test('foliage stays inside its bounds however extreme the month', () {
    expect(vitals([e(EntryType.outgoing, 999999)]).leaves, kMinLeaves);
    expect(vitals([e(EntryType.incoming, 999999)]).leaves, kMaxLeaves);
  });

  test('blowing the budget tires the plant without killing it', () {
    final v = vitals([e(EntryType.outgoing, 2400)]);
    expect(v.health, 0);
    expect(v.mood, PlantMood.worried);
    expect(v.leaves, kMinLeaves);
    expect(v.left, -600);
  });

  test('stage tracks foliage across the full range', () {
    expect(vitals([e(EntryType.outgoing, 999999)]).stage, 1);
    expect(vitals(const []).stage, 6);
  });

  test('tasks touch neither the budget nor the plant', () {
    expect(vitals([e(EntryType.task, 500)]).leaves, kMaxLeaves);
  });

  test('a zero budget cannot divide by zero', () {
    final v = vitals([e(EntryType.outgoing, 500)], b: 0);
    expect(v.leaves, kMaxLeaves);
    expect(v.health, 1);
    expect(v.used, 0);
  });

  test('one leaf is the budget split across the canopy', () {
    expect(PlantVitals.perLeaf(1800), 100);
  });
}
