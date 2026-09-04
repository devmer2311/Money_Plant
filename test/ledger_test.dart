import 'package:flutter_test/flutter_test.dart';
import 'package:money_plant/core/entry.dart';

/// One check for the only branchy logic in the app: how rows roll up into the
/// numbers the home screen, the charts and the PDF all read from.
void main() {
  Entry e(EntryType t, double amount) => Entry(
        date: DateTime(2026, 9, 4),
        type: t,
        amount: amount,
        category: 'Food',
      );

  test('summary splits income, spend and tasks', () {
    final s = Summary.of([
      e(EntryType.incoming, 5000),
      e(EntryType.outgoing, 1200),
      e(EntryType.outgoing, 300),
      e(EntryType.task, 0),
    ]);

    expect(s.income, 5000);
    expect(s.spent, 1500);
    expect(s.balance, 3500);
    expect(s.tasks, 1);
  });

  test('tasks never move the balance', () {
    expect(Summary.of([e(EntryType.task, 999)]).balance, 0);
  });

  test('burn rate flags overspending even with no income', () {
    expect(Summary.of(<Entry>[]).burnRate, 0);
    expect(Summary.of([e(EntryType.outgoing, 10)]).burnRate, greaterThan(1));
    expect(
      Summary.of([e(EntryType.incoming, 100), e(EntryType.outgoing, 50)])
          .burnRate,
      0.5,
    );
  });

  test('type parsing survives whatever case the sheet was edited into', () {
    expect(EntryType.parse('incoming'), EntryType.incoming);
    expect(EntryType.parse(' OUTGOING '), EntryType.outgoing);
    expect(EntryType.parse('Task'), EntryType.task);
    expect(EntryType.parse('garbage'), EntryType.outgoing);
  });
}
