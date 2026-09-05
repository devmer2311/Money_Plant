import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/entry.dart';
import '../features/goals/goal.dart';
import '../features/home/plant_state.dart';
import 'excel_service.dart';
import 'pdf_statement_service.dart';

/// Hand-written on purpose. `riverpod_generator` would produce almost exactly
/// this file, at the cost of a `build_runner` step that has to re-analyse the
/// whole package on every CI run — minutes of build time, and a step that can
/// hang, to save about thirty lines. Not a trade worth making at this size.

final excelServiceProvider = Provider<ExcelService>((ref) => ExcelService());

final pdfStatementServiceProvider = Provider<PdfStatementService>(
  (ref) => PdfStatementService(
    ref.watch(excelServiceProvider),
    ref.watch(monthlyBudgetProvider),
  ),
);

/// What the user intends to spend in a month. It is the plant's growth
/// capacity (a full canopy = a month's budget untouched) and the denominator
/// of every "left to spend" figure, so it lives one level above the ledger.
///
/// Stored as one small JSON file beside the workbooks rather than pulling in
/// shared_preferences for a single number.
class Budget extends AsyncNotifier<double> {
  static const fallback = 10000.0;

  Future<File> _file() => _store(ref, 'settings.json');

  @override
  Future<double> build() async {
    final f = await _file();
    if (!await f.exists()) return fallback;
    try {
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final v = (map['monthlyBudget'] as num?)?.toDouble() ?? fallback;
      return v > 0 ? v : fallback;
    } catch (_) {
      return fallback; // a corrupt settings file must never block the app
    }
  }

  Future<void> set(double value) async {
    if (value <= 0) return;
    await (await _file())
        .writeAsString(jsonEncode({'monthlyBudget': value}), flush: true);
    state = AsyncData(value);
  }
}

final budgetProvider = AsyncNotifierProvider<Budget, double>(Budget.new);

/// The budget as a plain number, for the many places that cannot await it.
final monthlyBudgetProvider = Provider<double>(
  (ref) => ref.watch(budgetProvider).valueOrNull ?? Budget.fallback,
);

/// Saved goals and challenges. Only the *definition* is stored — how far along
/// each one is gets recomputed from the ledger, so the two can never drift.
class Goals extends AsyncNotifier<List<Goal>> {
  Future<File> _file() => _store(ref, 'goals.json');

  @override
  Future<List<Goal>> build() async {
    final f = await _file();
    if (!await f.exists()) return const [];
    try {
      final raw = jsonDecode(await f.readAsString()) as List<dynamic>;
      return raw
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const []; // a corrupt goals file must never block the app
    }
  }

  Future<void> _write(List<Goal> goals) async {
    await (await _file()).writeAsString(
      jsonEncode(goals.map((g) => g.toJson()).toList()),
      flush: true,
    );
    state = AsyncData(goals);
  }

  Future<void> add(Goal goal) async =>
      _write([...state.valueOrNull ?? const <Goal>[], goal]);

  Future<void> remove(String id) async => _write(
        [...?state.valueOrNull?.where((g) => g.id != id)],
      );
}

final goalsProvider = AsyncNotifierProvider<Goals, List<Goal>>(Goals.new);

/// Every goal measured against the month currently on screen.
final goalProgressProvider = Provider<List<GoalProgress>>((ref) {
  final entries = ref.watch(ledgerProvider).valueOrNull ?? const <Entry>[];
  final now = DateTime.now();
  return [
    for (final g in ref.watch(goalsProvider).valueOrNull ?? const <Goal>[])
      GoalProgress.of(g, entries, now),
  ];
});

/// True while anything is worth celebrating — the plant flowers on this.
final bloomingProvider = Provider<bool>(
  (ref) => ref.watch(goalProgressProvider).any((p) => p.achieved),
);

/// A small JSON file beside the workbooks. Two of these is still cheaper than
/// a shared_preferences dependency, and keeps every byte the app owns in one
/// folder the user can copy off the device.
Future<File> _store(Ref ref, String name) async =>
    File('${(await ref.read(excelServiceProvider).dir()).path}/$name');

/// Which month the whole app is looking at. Home always starts on today's.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void select(DateTime month) => state = DateTime(month.year, month.month);
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

/// Months that have a workbook on disk (plus the current one, always).
final availableMonthsProvider = FutureProvider<List<DateTime>>(
  (ref) => ref.watch(excelServiceProvider).months(),
);

/// The entries of [selectedMonthProvider], newest first, and the full CRUD
/// surface over them.
///
/// Every mutation writes to the workbook and then re-reads it. That is not
/// laziness about performance — an entry's identity *is* its row index, and a
/// delete shifts every row below it, so in-memory patching would hand the UI
/// stale keys. The re-read is one file decode; correctness is worth it.
class Ledger extends AsyncNotifier<List<Entry>> {
  @override
  Future<List<Entry>> build() =>
      ref.watch(excelServiceProvider).read(ref.watch(selectedMonthProvider));

  Future<void> add(Entry entry) async {
    final before = _leaves;
    await ref.read(excelServiceProvider).add(entry);
    ref.invalidate(availableMonthsProvider); // a brand-new month may exist now
    await _reload();
    if (entry.type == EntryType.task) return;
    final income = entry.type == EntryType.incoming;
    _fire(
      income ? PlantAction.income : PlantAction.expense,
      income ? 'Money Added' : 'Expense Added',
      entry,
      before,
    );
  }

  /// Edits stay inside the month they were filed under: changing a date to
  /// another month would mean moving the row between two workbooks, so we
  /// delete-then-add instead of updating in place.
  Future<void> edit(Entry updated) async {
    if (!updated.isPersisted) return;
    final excel = ref.read(excelServiceProvider);
    final month = ref.read(selectedMonthProvider);

    final before = _leaves;

    if (updated.date.year == month.year && updated.date.month == month.month) {
      await excel.update(month, updated.row, updated);
    } else {
      await excel.remove(month, updated.row);
      await excel.add(updated);
      ref.invalidate(availableMonthsProvider);
    }
    await _reload();
    // Only the net difference shows up, because the delta is measured across
    // the write: correcting ₹500 down to ₹200 returns three leaves, it does
    // not replay the original cut.
    _fire(PlantAction.edit, 'Transaction Updated', updated, before);
  }

  Future<void> remove(Entry entry) async {
    if (!entry.isPersisted) return;
    final before = _leaves;
    await ref
        .read(excelServiceProvider)
        .remove(ref.read(selectedMonthProvider), entry.row);
    await _reload();
    _fire(PlantAction.delete, 'Transaction Deleted', entry, before);
  }

  /// Puts a deleted row back. Used by the undo action on the delete snackbar —
  /// it lands at the bottom of the sheet rather than its old position, which
  /// nobody can tell because the list is sorted by date anyway.
  Future<void> restore(Entry entry) => add(entry);

  Future<void> refresh() async {
    state = const AsyncLoading();
    await _reload();
  }

  /// The plant's foliage for whatever is currently in [state].
  int get _leaves => PlantVitals.of(
        Summary.of(state.valueOrNull ?? const []),
        ref.read(monthlyBudgetProvider),
      ).leaves;

  void _fire(PlantAction action, String title, Entry e, int leavesBefore) {
    ref.read(plantEventsProvider.notifier).fire(
          PlantEvent(
            action: action,
            title: title,
            detail: e.type == EntryType.task
                ? e.category
                : '${_money.format(e.amount)} • ${e.category}',
            leafDelta: _leaves - leavesBefore,
          ),
        );
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(
      () =>
          ref.read(excelServiceProvider).read(ref.read(selectedMonthProvider)),
    );
  }
}

final _money =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

final ledgerProvider = AsyncNotifierProvider<Ledger, List<Entry>>(Ledger.new);

/// Totals for the selected month. Cheap enough to recompute on every rebuild.
final monthSummaryProvider = Provider<Summary>(
  (ref) => Summary.of(ref.watch(ledgerProvider).valueOrNull ?? const []),
);
