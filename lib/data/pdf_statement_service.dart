import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/entry.dart';
import 'excel_service.dart';

/// Turns a month's spreadsheet into a bank-statement-grade PDF.
///
/// Deliberately monochrome — black ink, grey rules, one accent per amount sign.
/// That restraint is what makes a statement read as "official" rather than as
/// an app screenshot. Uses the PDF core fonts (Helvetica), so there are no font
/// assets to bundle and generation works fully offline.
class PdfStatementService {
  PdfStatementService(this._excel);

  final ExcelService _excel;

  static final _period = DateFormat('MMMM yyyy');
  static final _fileMonth = DateFormat('MMM_yyyy');
  static final _rowDate = DateFormat('dd MMM');
  static final _generated = DateFormat('dd MMM yyyy, HH:mm');
  static final _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  // Statement palette: paper, ink, and two restrained accents.
  static const _ink = PdfColor.fromInt(0xFF111111);
  static const _muted = PdfColor.fromInt(0xFF6B6B6B);
  static const _rule = PdfColor.fromInt(0xFFDDDDDD);
  static const _stripe = PdfColor.fromInt(0xFFF7F7F5);
  static const _credit = PdfColor.fromInt(0xFF1B7F4B);
  static const _debit = PdfColor.fromInt(0xFFC0304A);

  /// Renders the statement and drops it next to the workbook it was built from.
  Future<File> generate(DateTime month) async {
    final entries = await _excel.read(month);
    final bytes = await build(month, entries);
    final file = File(
      '${(await _excel.dir()).path}/Statement_${_fileMonth.format(month)}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Generate, then hand it to the OS share/save sheet — the only route into
  /// the user's own storage that works on every Android version without
  /// extra permission grants.
  Future<File> share(DateTime month) async {
    final file = await generate(month);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.uri.pathSegments.last,
    );
    return file;
  }

  // ------------------------------------------------------------- document ---

  Future<List<int>> build(DateTime month, List<Entry> entries) async {
    final rows = entries.where((e) => e.type != EntryType.task).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final tasks = entries.where((e) => e.type == EntryType.task).toList();
    final summary = Summary.of(entries);

    final base = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    final doc = pw.Document(
      title: 'Money Plant Statement — ${_period.format(month)}',
      author: 'Money Plant',
      theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
        defaultTextStyle: pw.TextStyle(font: base, fontSize: 9.5, color: _ink),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 40, 38, 34),
        header: (ctx) => ctx.pageNumber == 1
            ? _masthead(month, bold)
            : _runningHead(month, bold),
        footer: _footer,
        build: (ctx) => [
          pw.SizedBox(height: 18),
          _summaryCard(summary, bold),
          pw.SizedBox(height: 26),
          _sectionLabel('TRANSACTIONS', bold),
          pw.SizedBox(height: 8),
          if (rows.isEmpty) _empty() else _table(rows, bold),
          pw.SizedBox(height: 18),
          _closing(summary, bold),
          if (tasks.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _sectionLabel('TASKS LOGGED', bold),
            pw.SizedBox(height: 8),
            ...tasks.map(_taskLine),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // --------------------------------------------------------------- pieces ---

  /// Wordmark + period. The wide letter-spacing on "MONEY PLANT" is what sells
  /// the premium feel without needing any logo artwork embedded.
  pw.Widget _masthead(DateTime month, pw.Font bold) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MONEY PLANT',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 20,
                      letterSpacing: 6,
                      color: _ink,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'PERSONAL LEDGER',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      letterSpacing: 3.4,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'STATEMENT FOR',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      letterSpacing: 2.6,
                      color: _muted,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _period.format(month).toUpperCase(),
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1.4, color: _ink),
        ],
      );

  pw.Widget _runningHead(DateTime month, pw.Font bold) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MONEY PLANT',
                style:
                    pw.TextStyle(font: bold, fontSize: 9, letterSpacing: 3),
              ),
              pw.Text(
                _period.format(month),
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 0.7, color: _rule),
        ]),
      );

  /// Three-cell figure block: thin outer rule, hairline dividers, no fills.
  pw.Widget _summaryCard(Summary s, pw.Font bold) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _rule, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _figure('TOTAL INCOME', s.income, _credit, bold),
            _vRule(),
            _figure('TOTAL SPENT', s.spent, _debit, bold),
            _vRule(),
            _figure(
              'NET BALANCE',
              s.balance,
              s.balance >= 0 ? _credit : _debit,
              bold,
              emphasise: true,
            ),
          ],
        ),
      );

  pw.Widget _vRule() => pw.Container(width: 1, height: 42, color: _rule);

  pw.Widget _figure(
    String label,
    double value,
    PdfColor color,
    pw.Font bold, {
    bool emphasise = false,
  }) =>
      pw.Expanded(
        child: pw.Column(
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 7,
                letterSpacing: 2.2,
                color: _muted,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              _money.format(value),
              style: pw.TextStyle(
                font: bold,
                fontSize: emphasise ? 17 : 14,
                color: color,
              ),
            ),
          ],
        ),
      );

  pw.Widget _sectionLabel(String text, pw.Font bold) => pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: 8,
          letterSpacing: 2.8,
          color: _muted,
        ),
      );

  /// Hand-rolled table rather than `TableHelper.fromTextArray`, because that
  /// helper styles every cell identically and we need the amount column tinted
  /// per row (green for credits, red for debits). Zebra striping comes from the
  /// row decoration so it survives page breaks.
  pw.Widget _table(List<Entry> rows, pw.Font bold) {
    const widths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(58),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(1.6),
      3: pw.FixedColumnWidth(100),
    };

    pw.Widget cell(
      String text, {
      pw.Font? font,
      PdfColor color = _ink,
      double size = 9,
      bool right = false,
      double spacing = 0,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font: font,
              fontSize: size,
              color: color,
              letterSpacing: spacing,
            ),
          ),
        );

    return pw.Table(
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _ink, width: 0.9),
              bottom: pw.BorderSide(color: _ink, width: 0.9),
            ),
          ),
          children: [
            cell('DATE', font: bold, size: 7.5, spacing: 1.8),
            cell('DESCRIPTION', font: bold, size: 7.5, spacing: 1.8),
            cell('CATEGORY', font: bold, size: 7.5, spacing: 1.8),
            cell('AMOUNT', font: bold, size: 7.5, spacing: 1.8, right: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _stripe : null,
              border: const pw.Border(
                bottom: pw.BorderSide(color: _rule, width: 0.5),
              ),
            ),
            children: [
              cell(_rowDate.format(rows[i].date), color: _muted),
              cell(rows[i].description.isEmpty
                  ? rows[i].category
                  : rows[i].description),
              cell(rows[i].category, color: _muted),
              cell(
                rows[i].type == EntryType.incoming
                    ? '+ ${_money.format(rows[i].amount)}'
                    : '- ${_money.format(rows[i].amount)}',
                font: bold,
                right: true,
                color:
                    rows[i].type == EntryType.incoming ? _credit : _debit,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _empty() => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 36),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _rule),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          'No transactions recorded for this period.',
          style: const pw.TextStyle(color: _muted, fontSize: 10),
        ),
      );

  /// Inverted block so the eye lands on the closing figure last.
  pw.Widget _closing(Summary s, pw.Font bold) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: _ink,
            child: pw.Row(children: [
              pw.Text(
                'CLOSING BALANCE',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  letterSpacing: 2.2,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Text(
                _money.format(s.balance),
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 12,
                  color: PdfColors.white,
                ),
              ),
            ]),
          ),
        ],
      );

  pw.Widget _taskLine(Entry e) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Container(width: 6, height: 6, color: _muted),
          pw.SizedBox(width: 10),
          pw.Text(
            _rowDate.format(e.date),
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Text(
              e.description.isEmpty ? e.category : e.description,
              style: const pw.TextStyle(fontSize: 9.5),
            ),
          ),
        ]),
      );

  pw.Widget _footer(pw.Context ctx) => pw.Column(children: [
        pw.Container(height: 0.7, color: _rule),
        pw.SizedBox(height: 7),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated ${_generated.format(DateTime.now())} · stored offline on this device',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ],
        ),
      ]);
}
