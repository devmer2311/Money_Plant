import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_plant/core/entry.dart';
import 'package:money_plant/data/excel_service.dart';
import 'package:money_plant/data/pdf_statement_service.dart';

/// The statement is laid out in `pdf` widgets, which fail at render time rather
/// than at compile time — an unbounded height or a zero table flex only shows
/// up when the document is actually built. This renders one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Entry e(EntryType t, double amount, String category, String note) => Entry(
        date: DateTime(2026, 9, 5, 8, 44),
        type: t,
        amount: amount,
        category: category,
        description: note,
      );

  Future<List<int>> render(List<Entry> entries) =>
      PdfStatementService(ExcelService(), 20000)
          .build(DateTime(2026, 9), entries);

  test('a full month renders to one valid document', () async {
    final bytes = await render([
      e(EntryType.incoming, 24000, 'Salary', 'September salary'),
      e(EntryType.outgoing, 8500, 'Rent', 'Room rent'),
      e(EntryType.outgoing, 70, 'Food', 'Kachori'),
      e(EntryType.outgoing, 150, 'Fun', ''),
      e(EntryType.task, 0, 'Other', 'Renew insurance'),
    ]);

    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    // Roboto is embedded because the PDF core fonts silently drop ₹. If this
    // ever fails, every rupee amount on the page has lost its symbol.
    expect(String.fromCharCodes(bytes).contains('Roboto'), isTrue);
  });

  test('an empty month still renders', () async {
    expect((await render(const [])).length, greaterThan(1000));
  });
}
