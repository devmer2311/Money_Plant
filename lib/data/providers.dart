import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/entry.dart';
import 'excel_service.dart';
import 'pdf_statement_service.dart';

/// Hand-written on purpose. `riverpod_generator` would produce almost exactly
/// this file, at the cost of a `build_runner` step that has to re-analyse the
/// whole package on every CI run — minutes of build time, and a step that can
/// hang, to save about thirty lines. Not a trade worth making at this size.

final excelServiceProvider = Provider<ExcelService>((ref) => ExcelService());

final pdfStatementServiceProvider = Provider<PdfStatementService>(
  (ref) => PdfStatementService(ref.watch(excelServiceProvider)),
);

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
    await ref.read(excelServiceProvider).add(entry);
    ref.invalidate(availableMonthsProvider); // a brand-new month may exist now
    await _reload();
  }

  /// Edits stay inside the month they were filed under: changing a date to
  /// another month would mean moving the row between two workbooks, so we
  /// delete-then-add instead of updating in place.
  Future<void> edit(Entry updated) async {
    if (!updated.isPersisted) return;
    final excel = ref.read(excelServiceProvider);
    final month = ref.read(selectedMonthProvider);

    if (updated.date.year == month.year && updated.date.month == month.month) {
      await excel.update(month, updated.row, updated);
    } else {
      await excel.remove(month, updated.row);
      await excel.add(updated);
      ref.invalidate(availableMonthsProvider);
    }
    await _reload();
  }

  Future<void> remove(Entry entry) async {
    if (!entry.isPersisted) return;
    await ref
        .read(excelServiceProvider)
        .remove(ref.read(selectedMonthProvider), entry.row);
    await _reload();
  }

  /// Puts a deleted row back. Used by the undo action on the delete snackbar —
  /// it lands at the bottom of the sheet rather than its old position, which
  /// nobody can tell because the list is sorted by date anyway.
  Future<void> restore(Entry entry) => add(entry);

  Future<void> refresh() async {
    state = const AsyncLoading();
    await _reload();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(
      () =>
          ref.read(excelServiceProvider).read(ref.read(selectedMonthProvider)),
    );
  }
}

final ledgerProvider =
    AsyncNotifierProvider<Ledger, List<Entry>>(Ledger.new);

/// Totals for the selected month. Cheap enough to recompute on every rebuild.
final monthSummaryProvider = Provider<Summary>(
  (ref) => Summary.of(ref.watch(ledgerProvider).valueOrNull ?? const []),
);
