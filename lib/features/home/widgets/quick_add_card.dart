import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/entry.dart';
import '../../../data/providers.dart';

/// The reason the app exists: a card that is already open, already focused, and
/// one tap from saving. No FAB, no sheet to summon, no navigation.
class QuickAddCard extends ConsumerStatefulWidget {
  const QuickAddCard({super.key, this.editing});

  /// When set, the form edits this row instead of appending a new one.
  final Entry? editing;

  @override
  ConsumerState<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends ConsumerState<QuickAddCard> {
  late final _amount = TextEditingController(
    text: widget.editing == null || widget.editing!.amount == 0
        ? ''
        : widget.editing!.amount.toStringAsFixed(2),
  );
  late final _note =
      TextEditingController(text: widget.editing?.description ?? '');
  final _amountFocus = FocusNode();

  late EntryType _type = widget.editing?.type ?? EntryType.outgoing;
  late String _category = widget.editing?.category ?? kCategories.first;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Color get _accent => switch (_type) {
        EntryType.incoming => MP.neon,
        EntryType.outgoing => MP.flame,
        EntryType.task => MP.violet,
      };

  Future<void> _save() async {
    final isTask = _type == EntryType.task;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;

    if (!isTask && amount <= 0) {
      _amountFocus.requestFocus();
      HapticFeedback.heavyImpact();
      return;
    }
    if (isTask && _note.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give the task a name')));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final ledger = ref.read(ledgerProvider.notifier);
      if (_isEdit) {
        await ledger.edit(
          widget.editing!.copyWith(
            type: _type,
            amount: isTask ? 0 : amount,
            category: _category,
            description: _note.text.trim(),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).maybePop();
        return;
      }

      await ledger.add(
        Entry(
          date: DateTime.now(),
          type: _type,
          amount: isTask ? 0 : amount,
          category: _category,
          description: _note.text.trim(),
        ),
      );
      if (!mounted) return;
      _amount.clear();
      _note.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to this month\'s sheet')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final entry = widget.editing;
    if (entry == null) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final ledger = ref.read(ledgerProvider.notifier);
    try {
      await ledger.remove(entry);
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTask = _type == EntryType.task;

    return Glass(
      tint: _accent,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeSwitch(
            value: _type,
            onChanged: (t) {
              HapticFeedback.selectionClick();
              setState(() => _type = t);
            },
          ),
          const SizedBox(height: 18),

          // Amount collapses away entirely in task mode rather than sitting
          // there disabled — fewer things on screen, fewer decisions.
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: isTask
                ? const SizedBox(width: double.infinity)
                : _AmountField(
                    controller: _amount,
                    focusNode: _amountFocus,
                    accent: _accent,
                    autofocus: !_isEdit,
                  ),
          ),

          if (!isTask) const SizedBox(height: 14),
          _CategoryStrip(
            value: _category,
            accent: _accent,
            onChanged: (c) {
              HapticFeedback.selectionClick();
              setState(() => _category = c);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              isDense: true,
              hintText: isTask ? 'What needs doing?' : 'Note (optional)',
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SaveButton(
            accent: _accent,
            busy: _saving,
            label: _isEdit
                ? 'Save changes'
                : (isTask ? 'Log task' : 'Add ${_type.label.toLowerCase()}'),
            onTap: _save,
          ),
          // Delete lives here as well as on the ledger swipe, so the plant's
          // reaction to it happens on the screen the plant is actually on.
          if (_isEdit) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete transaction'),
              style: TextButton.styleFrom(
                foregroundColor: MP.flame,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three-way segmented control with a capsule that slides between slots.
class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.value, required this.onChanged});

  final EntryType value;
  final ValueChanged<EntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final index = EntryType.values.indexOf(value);
    final accent = switch (value) {
      EntryType.incoming => MP.neon,
      EntryType.outgoing => MP.flame,
      EntryType.task => MP.violet,
    };

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            alignment: Alignment(-1 + index * 1.0, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final t in EntryType.values)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(t),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          t.icon,
                          size: 16,
                          color: t == value
                              ? accent
                              : onSurface.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            t.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: t == value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: t == value
                                  ? accent
                                  : onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.accent,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '₹',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w300,
            color: accent.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              height: 1.1,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '0',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String value;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = kCategories[i];
          final selected = c == value;
          return GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.16)
                    : onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.55)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                c,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          )
              // Stagger: chips fly in one after another on first paint.
              .animate(delay: (30 * i).ms)
              .fadeIn(duration: 260.ms)
              .slideX(begin: 0.3, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.accent,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final Color accent;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.busy ? null : widget.onTap,
      // Press scale is the whole micro-interaction: 0.96 down, spring back up.
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                widget.accent,
                Color.lerp(widget.accent, Colors.white, 0.25)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: _down ? 0.15 : 0.38),
                blurRadius: _down ? 8 : 22,
                offset: Offset(0, _down ? 2 : 8),
              ),
            ],
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.black87,
                  ),
                )
              : Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Opens the shared form as a bottom sheet, pre-filled with [entry].
/// Same widget as the add card — an editor is just the form plus a row id.
Future<void> showEntryEditor(BuildContext context, Entry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      // Lift the sheet above the keyboard rather than letting it overlap.
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          QuickAddCard(editing: entry),
        ],
      ),
    ),
  );
}
