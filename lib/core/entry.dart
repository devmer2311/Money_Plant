import 'package:flutter/material.dart';

/// A single row in the monthly spreadsheet.
///
/// `task` rows carry a zero amount — they exist so the same sheet doubles as a
/// to-do log without needing a second storage format.
enum EntryType {
  incoming('Incoming', Icons.south_west_rounded),
  outgoing('Outgoing', Icons.north_east_rounded),
  task('Task', Icons.check_rounded);

  const EntryType(this.label, this.icon);
  final String label;
  final IconData icon;

  static EntryType parse(String raw) => values.firstWhere(
        (t) => t.label.toLowerCase() == raw.trim().toLowerCase(),
        orElse: () => EntryType.outgoing,
      );
}

@immutable
class Entry {
  const Entry({
    required this.date,
    required this.type,
    required this.amount,
    required this.category,
    this.description = '',
    this.row = -1,
  });

  final DateTime date;
  final EntryType type;
  final double amount;
  final String category;
  final String description;

  /// Which line of the sheet this came from — the row *is* the primary key.
  /// Cheaper than an extra Id column, and safe because every edit and delete
  /// re-reads the workbook afterwards, so indices never go stale in memory.
  /// `-1` means "not written yet".
  final int row;

  bool get isPersisted => row >= 0;

  /// Positive for money in, negative for money out, zero for tasks.
  double get signed => switch (type) {
        EntryType.incoming => amount,
        EntryType.outgoing => -amount,
        EntryType.task => 0,
      };

  Entry copyWith({
    DateTime? date,
    EntryType? type,
    double? amount,
    String? category,
    String? description,
  }) =>
      Entry(
        date: date ?? this.date,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        description: description ?? this.description,
        row: row,
      );
}

/// Rolled-up numbers for a set of entries. Tasks contribute nothing.
@immutable
class Summary {
  const Summary(this.income, this.spent, this.tasks);

  final double income;
  final double spent;
  final int tasks;

  double get balance => income - spent;

  /// 0 = nothing spent, 1 = spent everything earned, >1 = overspending.
  /// Drives the mascot's mood.
  double get burnRate => income <= 0 ? (spent > 0 ? 1.4 : 0) : spent / income;

  factory Summary.of(Iterable<Entry> entries) {
    var income = 0.0, spent = 0.0, tasks = 0;
    for (final e in entries) {
      switch (e.type) {
        case EntryType.incoming:
          income += e.amount;
        case EntryType.outgoing:
          spent += e.amount;
        case EntryType.task:
          tasks++;
      }
    }
    return Summary(income, spent, tasks);
  }
}

/// Fixed set so the pie chart legend stays stable month to month.
const kCategories = <String>[
  'Food',
  'Travel',
  'Rent',
  'Shopping',
  'Bills',
  'Health',
  'Fun',
  'Salary',
  'Other',
];
