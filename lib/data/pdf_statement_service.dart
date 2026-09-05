import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/entry.dart';
import '../features/home/plant_state.dart';
import 'excel_service.dart';

/// Turns a month's spreadsheet into a statement-grade PDF.
///
/// Roboto is bundled and embedded rather than using the PDF core fonts: those
/// are WinAnsi-encoded, so every ₹ silently vanishes from the page. Embedding
/// also keeps generation working with no network, which a downloaded font
/// would not.
class PdfStatementService {
  PdfStatementService(this._excel, this._budget);

  final ExcelService _excel;

  /// The month's spend limit — the denominator of the utilisation figures.
  final double _budget;

  static final _period = DateFormat('MMMM yyyy');
  static final _fileMonth = DateFormat('MMM_yyyy');
  static final _serial = DateFormat('yyyyMM');
  static final _rowDate = DateFormat('dd MMM yyyy');
  static final _rowTime = DateFormat('hh:mm a');
  static final _generated = DateFormat('dd MMM yyyy, HH:mm');
  static final _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _short =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  // Print palette: ink on paper, one green and one red, nothing else.
  static const _ink = PdfColor.fromInt(0xFF12161F);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _faint = PdfColor.fromInt(0xFF9AA1AC);
  static const _rule = PdfColor.fromInt(0xFFE2E5EA);
  static const _wash = PdfColor.fromInt(0xFFF7F8FA);
  static const _credit = PdfColor.fromInt(0xFF0E9F6E);
  static const _creditWash = PdfColor.fromInt(0xFFEDFBF5);
  static const _debit = PdfColor.fromInt(0xFFD92D4E);
  static const _debitWash = PdfColor.fromInt(0xFFFEF2F4);

  /// Slice colours for the category bar, in fixed order so the same category
  /// keeps its colour between the bar and the legend.
  static const _slices = <PdfColor>[
    PdfColor.fromInt(0xFFD92D4E),
    PdfColor.fromInt(0xFF0E9F6E),
    PdfColor.fromInt(0xFF6366F1),
    PdfColor.fromInt(0xFFF59E0B),
    PdfColor.fromInt(0xFF0EA5E9),
    PdfColor.fromInt(0xFF9AA1AC),
  ];

  static pw.Font? _regular, _bold;

  /// Loaded once per process; the two faces are ~340 KB together.
  static Future<void> _fonts() async {
    _regular ??=
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    _bold ??=
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  }

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
    await _fonts();
    final base = _regular!, bold = _bold!;

    final rows = entries.where((e) => e.type != EntryType.task).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final tasks = entries.where((e) => e.type == EntryType.task).toList();
    final summary = Summary.of(entries);
    final vitals = PlantVitals.of(summary, _budget);

    final doc = pw.Document(
      title: 'Money Plant Statement — ${_period.format(month)}',
      author: 'Money Plant',
      theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
        defaultTextStyle: pw.TextStyle(font: base, fontSize: 9, color: _ink),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
        header: (ctx) =>
            ctx.pageNumber == 1 ? pw.SizedBox() : _runningHead(month, bold),
        footer: _footer,
        build: (ctx) => [
          _masthead(month, rows.length, bold),
          pw.SizedBox(height: 16),
          _metaStrip(month, rows.length, bold),
          pw.SizedBox(height: 20),
          _sectionLabel('FINANCIAL POSITION', bold),
          pw.SizedBox(height: 8),
          _figures(summary, bold),
          pw.SizedBox(height: 12),
          // Natural heights, not stretched: MultiPage children must be
          // finite, and a stretched Row is unbounded.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _plantCard(vitals, bold),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _breakdown(rows, summary, bold)),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('ITEMISED LEDGER', bold),
              pw.Text('Newest first',
                  style: const pw.TextStyle(fontSize: 7.2, color: _faint)),
            ],
          ),
          pw.SizedBox(height: 8),
          if (rows.isEmpty) _empty() else _table(rows, bold),
          if (rows.isNotEmpty) _totals(summary, vitals, bold),
          if (tasks.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _sectionLabel('TASKS LOGGED', bold),
            pw.SizedBox(height: 8),
            ...tasks.map(_taskLine),
          ],
          pw.SizedBox(height: 22),
          _provenance(month, bold),
        ],
      ),
    );

    return doc.save();
  }

  // --------------------------------------------------------------- pieces ---

  pw.Widget _masthead(DateTime month, int count, pw.Font bold) => pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _mark(),
                  pw.SizedBox(width: 11),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Money Plant',
                            style: pw.TextStyle(
                                font: bold, fontSize: 19, color: _ink),
                          ),
                          pw.SizedBox(width: 8),
                          _pill('PERSONAL LEDGER', _credit, _creditWash, bold),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Personal finance record · generated on device',
                        style: const pw.TextStyle(fontSize: 8, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'STATEMENT NO.',
                    style: const pw.TextStyle(
                        fontSize: 6.5, letterSpacing: 1.6, color: _faint),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'STMT-${_serial.format(month)}-'
                    '${count.toString().padLeft(4, '0')}',
                    style: pw.TextStyle(font: bold, fontSize: 11),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Generated ${_generated.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 1.2, color: _ink),
        ],
      );

  /// A drawn mark rather than an embedded logo: two leaves and a stem, so the
  /// document carries the app's identity with no image asset to ship.
  pw.Widget _mark() => pw.Container(
        width: 34,
        height: 34,
        decoration: pw.BoxDecoration(
          color: _credit,
          borderRadius: pw.BorderRadius.circular(9),
        ),
        child: pw.CustomPaint(
          size: const PdfPoint(34, 34),
          painter: (canvas, size) {
            // PDF's origin is bottom-left: the stem runs up the middle and a
            // leaf hangs off each side of it.
            canvas
              ..setStrokeColor(PdfColors.white)
              ..setLineWidth(1.5)
              ..setLineCap(PdfLineCap.round)
              ..moveTo(17, 7)
              ..lineTo(17, 22)
              ..strokePath();
            // Each blade is two cubics meeting at a point, the same lens the
            // app draws — a single cubic just makes a paddle.
            canvas
              ..setFillColor(PdfColors.white)
              ..moveTo(16.8, 15)
              ..curveTo(11, 13.5, 6, 17.5, 7.5, 24)
              ..curveTo(11.5, 23.5, 15, 20, 16.8, 15)
              ..fillPath()
              ..moveTo(17.2, 18.5)
              ..curveTo(23, 17, 28, 21, 26.5, 27.5)
              ..curveTo(22.5, 27, 19, 23.5, 17.2, 18.5)
              ..fillPath();
          },
        ),
      );

  pw.Widget _pill(String text, PdfColor color, PdfColor wash, pw.Font bold) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: pw.BoxDecoration(
          color: wash,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: color, width: 0.5),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: bold,
            fontSize: 6.5,
            letterSpacing: 1,
            color: color,
          ),
        ),
      );

  /// Billing period, currency, where the data lives, and how many rows it has.
  pw.Widget _metaStrip(DateTime month, int count, pw.Font bold) {
    final last = DateTime(month.year, month.month + 1, 0);
    pw.Widget cell(String label, String value, {String? note}) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: const pw.TextStyle(
                    fontSize: 6.5, letterSpacing: 1.4, color: _faint),
              ),
              pw.SizedBox(height: 4),
              pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9.5)),
              if (note != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(note,
                    style: const pw.TextStyle(fontSize: 7, color: _muted)),
              ],
            ],
          ),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        cell(
          'BILLING PERIOD',
          '01 – ${last.day} ${DateFormat('MMM yyyy').format(month)}',
          note: _period.format(month),
        ),
        cell('CURRENCY', 'INR (₹)', note: 'Indian Rupee'),
        cell('SOURCE', _excel.fileNameFor(month), note: 'Offline workbook'),
        cell(
          'ENTRIES',
          '$count transaction${count == 1 ? '' : 's'}',
          note: 'Reconciled from the sheet',
        ),
      ],
    );
  }

  pw.Widget _sectionLabel(String text, pw.Font bold) => pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: 7.5,
          letterSpacing: 2.4,
          color: _muted,
        ),
      );

  /// Four tinted figure cards: in, out, net, and how much of the budget that
  /// leaves standing.
  pw.Widget _figures(Summary s, pw.Font bold) {
    final used = _budget <= 0 ? 0.0 : (s.spent / _budget * 100);
    final left = _budget - s.spent;

    // Fixed height so the four cards line up; the content is uniform, so
    // there is nothing here that can grow into it.
    return pw.SizedBox(
        height: 74,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _figure('TOTAL INCOME', _money.format(s.income), _credit,
                _creditWash, 'Money in this period', bold),
            pw.SizedBox(width: 8),
            _figure('TOTAL SPENT', '-${_money.format(s.spent)}', _debit,
                _debitWash, 'Money out this period', bold),
            pw.SizedBox(width: 8),
            _figure(
              'NET POSITION',
              '${s.balance < 0 ? '-' : ''}${_money.format(s.balance.abs())}',
              s.balance >= 0 ? _credit : _debit,
              _wash,
              s.balance >= 0 ? 'Surplus' : 'Deficit',
              bold,
            ),
            pw.SizedBox(width: 8),
            _figure(
              'BUDGET USED',
              '${used.toStringAsFixed(1)}%',
              left >= 0 ? _credit : _debit,
              _wash,
              left >= 0
                  ? '${_short.format(left)} safe of ${_short.format(_budget)}'
                  : '${_short.format(left.abs())} over ${_short.format(_budget)}',
              bold,
            ),
          ],
        ));
  }

  pw.Widget _figure(
    String label,
    String value,
    PdfColor color,
    PdfColor wash,
    String note,
    pw.Font bold,
  ) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: wash,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _rule, width: 0.7),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: const pw.TextStyle(
                    fontSize: 6.5, letterSpacing: 1.4, color: _faint),
              ),
              pw.SizedBox(height: 7),
              pw.Text(value,
                  style: pw.TextStyle(font: bold, fontSize: 13, color: color)),
              pw.SizedBox(height: 5),
              pw.Text(note,
                  style: const pw.TextStyle(fontSize: 6.8, color: _muted)),
            ],
          ),
        ),
      );

  /// The mascot's state, stated in the same units the app animates.
  pw.Widget _plantCard(PlantVitals v, pw.Font bold) => pw.Container(
        width: 152,
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: _ink,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PLANT STATUS',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 6.5,
                    letterSpacing: 1.4,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'STAGE ${v.stage}/6',
                  style: const pw.TextStyle(
                      fontSize: 6.5, letterSpacing: 1, color: _faint),
                ),
              ],
            ),
            pw.SizedBox(height: 9),
            pw.Text(
              '${v.leaves} leaves',
              style: pw.TextStyle(font: bold, fontSize: 16, color: _credit),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              v.label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'One leaf ≈ ${_short.format(PlantVitals.perLeaf(v.budget))} '
              'of the monthly budget',
              style: const pw.TextStyle(fontSize: 6.8, color: _faint),
            ),
          ],
        ),
      );

  /// Stacked share-of-spend bar plus legend, built from the actual categories
  /// present rather than a fixed set.
  pw.Widget _breakdown(List<Entry> rows, Summary s, pw.Font bold) {
    final totals = <String, double>{};
    for (final e in rows.where((e) => e.type == EntryType.outgoing)) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(_slices.length).toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: _wash,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _rule, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Where the money went',
                  style: pw.TextStyle(font: bold, fontSize: 9.5)),
              pw.Text(
                '${_money.format(s.spent)} total outflow',
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
            ],
          ),
          pw.SizedBox(height: 9),
          if (top.isEmpty)
            pw.Container(height: 8, color: _rule)
          else
            pw.ClipRRect(
              horizontalRadius: 4,
              verticalRadius: 4,
              child: pw.Row(
                children: [
                  for (var i = 0; i < top.length; i++)
                    pw.Expanded(
                      // Flex must be a positive int, so scale the rupees up
                      // before rounding — sub-rupee slices would vanish.
                      flex: (top[i].value * 100).round().clamp(1, 1 << 30),
                      child: pw.Container(height: 8, color: _slices[i]),
                    ),
                ],
              ),
            ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (var i = 0; i < top.length; i++)
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 6,
                      height: 6,
                      decoration: pw.BoxDecoration(
                        color: _slices[i],
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                    ),
                    pw.SizedBox(width: 5),
                    pw.Text(top[i].key,
                        style: const pw.TextStyle(fontSize: 7.5)),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      '${_short.format(top[i].value)} '
                      '(${(top[i].value / s.spent * 100).toStringAsFixed(1)}%)',
                      style: pw.TextStyle(font: bold, fontSize: 7.5),
                    ),
                  ],
                ),
              if (top.isEmpty)
                pw.Text('No spending recorded.',
                    style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  /// Hand-rolled table rather than `TableHelper.fromTextArray`, because that
  /// helper styles every cell identically and the amount column has to be
  /// tinted per row. Zebra striping lives on the row decoration so it survives
  /// page breaks.
  pw.Widget _table(List<Entry> rows, pw.Font bold) {
    const widths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(22),
      1: pw.FixedColumnWidth(78),
      2: pw.FlexColumnWidth(3),
      3: pw.FlexColumnWidth(1.5),
      4: pw.FixedColumnWidth(78),
    };

    pw.Widget cell(
      pw.Widget child, {
      bool right = false,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: pw.Align(
            alignment:
                right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: child,
          ),
        );

    pw.Widget head(String t, {bool right = false}) => cell(
          pw.Text(
            t,
            style: pw.TextStyle(
              font: bold,
              fontSize: 6.8,
              letterSpacing: 1.4,
              color: _muted,
            ),
          ),
          right: right,
        );

    return pw.Table(
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _ink, width: 0.8),
              bottom: pw.BorderSide(color: _ink, width: 0.8),
            ),
          ),
          children: [
            head('#'),
            head('DATE & TIME'),
            head('DESCRIPTION'),
            head('CATEGORY'),
            head('AMOUNT', right: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _wash : null,
              border: const pw.Border(
                bottom: pw.BorderSide(color: _rule, width: 0.5),
              ),
            ),
            children: [
              cell(pw.Text(
                (i + 1).toString().padLeft(2, '0'),
                style: const pw.TextStyle(fontSize: 7.5, color: _faint),
              )),
              cell(pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_rowDate.format(rows[i].date),
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_rowTime.format(rows[i].date),
                      style: const pw.TextStyle(fontSize: 6.8, color: _faint)),
                ],
              )),
              cell(pw.Text(
                rows[i].description.isEmpty
                    ? rows[i].category
                    : rows[i].description,
                style: pw.TextStyle(font: bold, fontSize: 8.5),
              )),
              cell(_pill(
                rows[i].category.toUpperCase(),
                rows[i].type == EntryType.incoming ? _credit : _debit,
                rows[i].type == EntryType.incoming ? _creditWash : _debitWash,
                bold,
              )),
              cell(
                pw.Text(
                  rows[i].type == EntryType.incoming
                      ? '+${_money.format(rows[i].amount)}'
                      : '-${_money.format(rows[i].amount)}',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 9,
                    color:
                        rows[i].type == EntryType.incoming ? _credit : _debit,
                  ),
                ),
                right: true,
              ),
            ],
          ),
      ],
    );
  }

  /// The two closing lines: what left the account, and what the budget has
  /// left standing.
  pw.Widget _totals(Summary s, PlantVitals v, pw.Font bold) {
    pw.Widget line(String label, String value, PdfColor color,
            {bool strong = false}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: pw.BoxDecoration(
            color: strong ? _wash : null,
            border: const pw.Border(
              bottom: pw.BorderSide(color: _rule, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: strong ? bold : null,
                  fontSize: strong ? 8.5 : 8,
                  letterSpacing: strong ? 1 : 0,
                  color: strong ? _ink : _muted,
                ),
              ),
              pw.Text(
                value,
                style: pw.TextStyle(font: bold, fontSize: 10, color: color),
              ),
            ],
          ),
        );

    return pw.Column(children: [
      line('TOTAL NET OUTFLOW', '-${_money.format(s.spent)}', _debit,
          strong: true),
      line(
        'Remaining monthly budget (${_short.format(v.budget)})',
        '${v.left < 0 ? '-' : '+'}${_money.format(v.left.abs())}',
        v.left >= 0 ? _credit : _debit,
      ),
    ]);
  }

  pw.Widget _empty() => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 34),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _rule),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          'No transactions recorded for this period.',
          style: const pw.TextStyle(color: _muted, fontSize: 9.5),
        ),
      );

  pw.Widget _taskLine(Entry e) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Container(
            width: 5,
            height: 5,
            decoration: pw.BoxDecoration(
              color: _faint,
              borderRadius: pw.BorderRadius.circular(2.5),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(_rowDate.format(e.date),
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Text(
              e.description.isEmpty ? e.category : e.description,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ]),
      );

  /// Says exactly what this document is. Deliberately does not claim to be
  /// bank-issued, signed or encrypted — it is an export of a plain workbook,
  /// and printing otherwise on an official-looking page would be a lie.
  pw.Widget _provenance(DateTime month, pw.Font bold) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _wash,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _rule, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('About this document',
                style: pw.TextStyle(font: bold, fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Self-reported personal expense record, exported on device from '
              '${_excel.fileNameFor(month)}. Figures are entered by the '
              'account holder and are not verified against any bank or payment '
              'provider. The source workbook is stored unencrypted in this '
              "app's private folder and can be edited, so this statement is "
              'suitable for personal budgeting and reimbursement claims that '
              'accept self-declared expenses — not as proof of payment.',
              style: const pw.TextStyle(
                  fontSize: 7.2, color: _muted, lineSpacing: 1.6),
            ),
          ],
        ),
      );

  pw.Widget _runningHead(DateTime month, pw.Font bold) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Money Plant',
                  style: pw.TextStyle(font: bold, fontSize: 9)),
              pw.Text(_period.format(month),
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 0.7, color: _rule),
        ]),
      );

  pw.Widget _footer(pw.Context ctx) => pw.Column(children: [
        pw.Container(height: 0.7, color: _rule),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Money Plant · offline ledger export',
              style: const pw.TextStyle(fontSize: 6.8, color: _faint),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 6.8, color: _faint),
            ),
          ],
        ),
      ]);
}
