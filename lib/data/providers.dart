import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/entry.dart';
import 'excel_service.dart';
import 'pdf_statement_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
ExcelService excelService(Ref ref) => ExcelService();

@Riverpod(keepAlive: true)
PdfStatementService pdfStatementService(Ref ref) =>
    PdfStatementService(ref.watch(excelServiceProvider));

/// Which month the whole app is looking at. Home always starts on today's.
@Riverpod(keepAlive: true)
class SelectedMonth extends _$SelectedMonth {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void select(DateTime month) => state = DateTime(month.year, month.month);
}

/// Months that have a workbook on disk (plus the current one, always).
@riverpod
Future<List<DateTime>> availableMonths(Ref ref) =>
    ref.watch(excelServiceProvider).months();

/// The entries of [SelectedMonth], newest first.
///
/// Adding writes to the sheet first, then patches state in place — the list is
/// already sorted, so there is no reason to re-read and re-decode the workbook
/// just to show a row the user typed a moment ago.
@riverpod
class Ledger extends _$Ledger {
  @override
  Future<List<Entry>> build() =>
      ref.watch(excelServiceProvider).read(ref.watch(selectedMonthProvider));

  Future<void> add(Entry entry) async {
    await ref.read(excelServiceProvider).add(entry);
    ref.invalidate(availableMonthsProvider); // a brand-new month may exist now

    final current = state.valueOrNull ?? const <Entry>[];
    final month = ref.read(selectedMonthProvider);
    if (entry.date.year != month.year || entry.date.month != month.month) {
      return; // landed in another month's file; nothing to show here
    }
    state = AsyncData(
      [entry, ...current]..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(excelServiceProvider).read(ref.read(selectedMonthProvider)),
    );
  }
}

/// Totals for the selected month. Cheap enough to recompute on every rebuild.
@riverpod
Summary monthSummary(Ref ref) =>
    Summary.of(ref.watch(ledgerProvider).valueOrNull ?? const []);
