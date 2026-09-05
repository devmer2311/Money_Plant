import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_plant/app/theme.dart';
import 'package:money_plant/core/entry.dart';
import 'package:money_plant/data/excel_service.dart';
import 'package:money_plant/data/providers.dart';
import 'package:money_plant/features/goals/goal.dart';
import 'package:money_plant/features/goals/goals_screen.dart';
import 'package:money_plant/features/home/home_screen.dart';

/// Home is a stack of rows that each hold a currency string, a label and a
/// chip. Long amounts and small phones are exactly where those rows blow out,
/// and an overflow is invisible in `flutter analyze` — so render the screen at
/// the narrowest size the app claims to support and assert nothing overflows.
class _FakeExcel extends ExcelService {
  @override
  Future<List<Entry>> read(DateTime month) async => [
        Entry(
          date: DateTime(2026, 9, 5, 8, 44),
          type: EntryType.outgoing,
          amount: 1234567,
          category: 'Rent',
          description: 'A deliberately enormous amount',
          row: 1,
        ),
        Entry(
          date: DateTime(2026, 9, 1, 9),
          type: EntryType.incoming,
          amount: 24000,
          category: 'Salary',
          description: 'September salary',
          row: 2,
        ),
      ];
}

void main() {
  // Space Grotesk is fetched at runtime, which a test cannot do; the layout is
  // what is under test, not the typeface.
  ThemeData plainDark() => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: MP.neon,
          onPrimary: MP.void_,
          surface: MP.void_,
          onSurface: Color(0xFFEFF3EE),
          error: MP.flame,
        ),
        scaffoldBackgroundColor: MP.void_,
      );

  Future<void> pumpScreen(WidgetTester tester, Size size, Widget screen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        excelServiceProvider.overrideWithValue(_FakeExcel()),
        monthlyBudgetProvider.overrideWithValue(20000),
        goalProgressProvider.overrideWithValue([
          GoalProgress.of(
            Goal(
              id: 'a',
              kind: GoalKind.streak,
              title: 'A challenge with a deliberately long name',
              target: 10,
              category: 'Food',
              created: DateTime(2026, 9),
            ),
            const [],
            DateTime(2026, 9, 11),
          ),
          GoalProgress.of(
            Goal(
              id: 'b',
              kind: GoalKind.limit,
              title: 'Food cap',
              target: 3000,
              category: 'Food',
              created: DateTime(2026, 9),
            ),
            const [],
            DateTime(2026, 9, 11),
          ),
        ]),
      ],
      child: MaterialApp(
        theme: plainDark(),
        home: Scaffold(body: screen),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('the hero fits a small phone with a seven-figure balance',
      (tester) async {
    await pumpScreen(tester, const Size(320, 640), const HomeScreen());
    expect(tester.takeException(), isNull);
    // skipOffstage: false — the route's fade transition still counts the body
    // as offstage at this point in the pump sequence.
    expect(find.text('Money Plant', skipOffstage: false), findsOneWidget);
    expect(find.text('TOTAL BALANCE', skipOffstage: false), findsOneWidget);
  });

  testWidgets('and a large one', (tester) async {
    await pumpScreen(tester, const Size(430, 932), const HomeScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals fit a small phone', (tester) async {
    await pumpScreen(tester, const Size(320, 640), const GoalsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('GOAL ACHIEVED', skipOffstage: false), findsOneWidget);
  });

  testWidgets('goals fit a large one', (tester) async {
    await pumpScreen(tester, const Size(430, 932), const GoalsScreen());
    expect(tester.takeException(), isNull);
  });
}
