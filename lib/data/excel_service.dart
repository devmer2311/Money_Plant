import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/entry.dart';

/// The whole database. One `.xlsx` per month, sitting in the app's private
/// documents folder — no server, no SQLite, no sync.
///
/// Layout of every sheet (row 0 is the header):
///   A: Date  B: Type  C: Amount  D: Category  E: Description
class ExcelService {
  static const _sheet = 'Entries';
  static const _headers = ['Date', 'Type', 'Amount', 'Category', 'Description'];
  static final _fileDate = DateFormat('MMM_yyyy'); // Expenses_Sep_2026.xlsx
  static final _stamp = DateFormat('yyyy-MM-dd HH:mm');

  Directory? _cachedDir;

  /// `…/Documents/MoneyPlant/`. Created on first touch.
  Future<Directory> dir() async {
    if (_cachedDir != null) return _cachedDir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/MoneyPlant');
    if (!await d.exists()) await d.create(recursive: true);
    return _cachedDir = d;
  }

  String fileNameFor(DateTime month) =>
      'Expenses_${_fileDate.format(month)}.xlsx';

  Future<File> fileFor(DateTime month) async =>
      File('${(await dir()).path}/${fileNameFor(month)}');

  // ---------------------------------------------------------------- read ---

  /// Returns the month's rows, newest first. A missing file is simply an empty
  /// month — we never create a file until something is actually written.
  Future<List<Entry>> read(DateTime month) async {
    final file = await fileFor(month);
    if (!await file.exists()) return const [];

    final book = Excel.decodeBytes(await file.readAsBytes());
    final sheet = book.sheets[_sheet] ??
        (book.sheets.isEmpty ? null : book.sheets.values.first);
    if (sheet == null) return const [];

    final out = <Entry>[];
    for (final row in sheet.rows.skip(1)) {
      final date = DateTime.tryParse(_str(row, 0).replaceFirst(' ', 'T'));
      if (date == null) continue; // blank row or a header we didn't write
      out.add(
        Entry(
          date: date,
          type: EntryType.parse(_str(row, 1)),
          amount: double.tryParse(_str(row, 2)) ?? 0,
          category: _str(row, 3),
          description: _str(row, 4),
        ),
      );
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// Cell values come back as typed `CellValue`s. The `excel` package has
  /// shuffled `TextCellValue.value` between `String` and a rich-text span
  /// across releases, so unwrap defensively rather than pin to one shape.
  String _str(List<Data?> row, int i) {
    if (i >= row.length) return '';
    final v = row[i]?.value;
    if (v == null) return '';
    if (v is DoubleCellValue) return v.value.toString();
    if (v is IntCellValue) return v.value.toString();
    if (v is TextCellValue) {
      final inner = (v as dynamic).value;
      if (inner is String) return inner;
      final text = (inner as dynamic)?.text;
      if (text is String) return text;
      return inner?.toString() ?? '';
    }
    return v.toString();
  }

  // --------------------------------------------------------------- write ---

  /// Append-only: decode what's on disk (or start a fresh book), push one row,
  /// re-encode. Fine at personal-finance volumes.
  ///
  /// ponytail: rewrites the whole file per entry — switch to a append-friendly
  /// store only if a month ever grows past a few thousand rows.
  Future<void> add(Entry e) async {
    final file = await fileFor(e.date);
    final Excel book;

    if (await file.exists()) {
      book = Excel.decodeBytes(await file.readAsBytes());
    } else {
      book = Excel.createExcel();
      book[_sheet].appendRow(_headers.map(TextCellValue.new).toList());
      // createExcel() ships a default "Sheet1" we never use.
      try {
        book.setDefaultSheet(_sheet);
        for (final name in book.sheets.keys.toList()) {
          if (name != _sheet) book.delete(name);
        }
      } catch (_) {
        // A stray empty sheet is cosmetic — never fail a write over it.
      }
    }

    book[_sheet].appendRow(<CellValue?>[
      TextCellValue(_stamp.format(e.date)),
      TextCellValue(e.type.label),
      DoubleCellValue(e.amount),
      TextCellValue(e.category),
      TextCellValue(e.description),
    ]);

    final bytes = book.save();
    if (bytes == null) throw Exception('Could not encode ${file.path}');
    await file.writeAsBytes(bytes, flush: true);
  }

  // -------------------------------------------------------------- history ---

  /// Every month that has a file on disk, newest first. Parsed from the file
  /// name so we never have to open the workbooks just to build a month list.
  Future<List<DateTime>> months() async {
    final out = <DateTime>[];
    await for (final f in (await dir()).list()) {
      final name = f.uri.pathSegments.last;
      if (!name.startsWith('Expenses_') || !name.endsWith('.xlsx')) continue;
      try {
        out.add(_fileDate.parse(
          name.substring('Expenses_'.length, name.length - '.xlsx'.length),
        ));
      } catch (_) {
        // Not one of ours — ignore.
      }
    }
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    if (!out.any((m) => m.year == thisMonth.year && m.month == thisMonth.month)) {
      out.add(thisMonth);
    }
    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  // --------------------------------------------------------------- export ---

  /// Copies the month's workbook into the public Downloads folder so it can be
  /// shared or opened in Sheets/Excel. Falls back to the private path (which is
  /// still reachable via the share sheet) when storage access is refused.
  Future<String> exportToDownloads(DateTime month) async {
    final src = await fileFor(month);
    if (!await src.exists()) throw Exception('Nothing recorded for this month yet');

    if (await _storageGranted()) {
      final dl = Directory('/storage/emulated/0/Download');
      if (await dl.exists()) {
        final dst = File('${dl.path}/${fileNameFor(month)}');
        await dst.writeAsBytes(await src.readAsBytes(), flush: true);
        return dst.path;
      }
    }
    return src.path;
  }

  /// Android 10 and below honour WRITE_EXTERNAL_STORAGE; 11+ needs
  /// MANAGE_EXTERNAL_STORAGE to write outside our own sandbox. Ask for both and
  /// take whichever the device grants.
  Future<bool> _storageGranted() async {
    if (!Platform.isAndroid) return false;
    if (await Permission.storage.request().isGranted) return true;
    return Permission.manageExternalStorage.request().isGranted;
  }
}
