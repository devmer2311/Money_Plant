import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/entry.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show EntryTile;
import '../home/widgets/quick_add_card.dart' show showEntryEditor;

/// Browse any month that has a workbook on disk, and get the two exports out
/// of the device: the raw `.xlsx` and the rendered PDF statement.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(availableMonthsProvider);
    final selected = ref.watch(selectedMonthProvider);
    final entries = ref.watch(ledgerProvider);
    final summary = ref.watch(monthSummaryProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARCHIVE',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Ledger',
                      style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 380.ms).slideY(begin: -0.2),
        ),

        // --- month switcher -------------------------------------------------
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: months.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final m = list[i];
                  final active =
                      m.year == selected.year && m.month == selected.month;
                  return _MonthChip(
                    label: DateFormat('MMM yyyy').format(m),
                    active: active,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedMonthProvider.notifier).select(m);
                    },
                  ).animate(delay: (40 * i).ms).fadeIn(duration: 280.ms).slideX(
                        begin: 0.25,
                        curve: Curves.easeOutCubic,
                      );
                },
              ),
            ),
          ),
        ),

        // --- exports --------------------------------------------------------
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: _ExportButton(
                    icon: Icons.table_chart_rounded,
                    label: 'Excel',
                    caption: 'to Downloads',
                    color: MP.neon,
                    action: () async {
                      final path = await ref
                          .read(excelServiceProvider)
                          .exportToDownloads(selected);
                      return 'Saved · $path';
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ExportButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Statement',
                    caption: 'premium PDF',
                    color: MP.violet,
                    action: () async {
                      final file = await ref
                          .read(pdfStatementServiceProvider)
                          .share(selected);
                      return 'Statement ready · ${file.path}';
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- month totals ----------------------------------------------------
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Glass(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Figure('In', summary.income, MP.neon),
                  _Figure('Out', summary.spent, MP.flame),
                  _Figure(
                    'Net',
                    summary.balance,
                    summary.balance >= 0 ? MP.neon : MP.flame,
                  ),
                ],
              ),
            ),
          ),
        ),

        // --- rows -------------------------------------------------------------
        entries.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(child: Text('Could not read the sheet: $e')),
            ),
          ),
          data: (rows) => rows.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        'No sheet for this month.',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                )
              : SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: _SwipeToDelete(
                      entry: rows[i],
                      child: EntryTile(
                        entry: rows[i],
                        onTap: () => showEntryEditor(context, rows[i]),
                      ),
                    )
                        .animate(delay: (30 * i).clamp(0, 400).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.06, curve: Curves.easeOutCubic),
                  ),
                ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

/// Swipe either way to delete the row, with an undo that re-adds it. The
/// background reveals progressively so the gesture explains itself before it
/// commits.
class _SwipeToDelete extends ConsumerWidget {
  const _SwipeToDelete({required this.entry, required this.child});

  final Entry entry;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      // The sheet row index is unique within a month, and the list reloads
      // after every delete, so it is a safe key.
      key: ValueKey('row-${entry.row}-${entry.date.millisecondsSinceEpoch}'),
      background: _background(Alignment.centerLeft),
      secondaryBackground: _background(Alignment.centerRight),
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        final ledger = ref.read(ledgerProvider.notifier);
        final messenger = ScaffoldMessenger.of(context);
        await ledger.remove(entry);
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Entry deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: MP.neon,
              onPressed: () => ledger.restore(entry),
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _background(Alignment align) => Container(
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: MP.flame.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child:
            const Icon(Icons.delete_outline_rounded, color: MP.flame, size: 22),
      );
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.onSurface.withValues(alpha: 0.04),
          border: Border.all(
            color: active
                ? scheme.primary.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Runs [action] and reports whatever it returns in a snackbar. Keeps the
/// busy/error handling in one place instead of duplicating it per export.
class _ExportButton extends StatefulWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.action,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final Future<String> Function() action;

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    String message;
    try {
      message = await widget.action();
    } catch (e) {
      message = 'Export failed: $e';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, maxLines: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      tint: widget.color,
      onTap: _run,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: _busy
                ? CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: widget.color,
                  )
                : Icon(widget.icon, size: 20, color: widget.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.caption,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  static final _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            _money.format(v),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
