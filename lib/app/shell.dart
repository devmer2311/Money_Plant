import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Floating pill nav. The selected item gets a sliding neon capsule behind it
/// (an implicit `AnimatedAlign`, so it springs between slots for free) and the
/// icon does a short scale pop on selection.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _tabs = [
    ('/', Icons.bolt_rounded, 'Add'),
    ('/analytics', Icons.insights_rounded, 'Insights'),
    ('/history', Icons.receipt_long_rounded, 'Ledger'),
  ];

  int get _index => _tabs.indexWhere((t) => t.$1 == location).clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(33),
            color: dark ? MP.slate : Colors.white.withValues(alpha: 0.92),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.5 : 0.10),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // The capsule that chases the selected tab.
              AnimatedAlign(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                alignment: Alignment(-1 + _index * 1.0, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / _tabs.length,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withValues(alpha: dark ? 0.22 : 0.16),
                            scheme.primary.withValues(alpha: 0.04),
                          ],
                        ),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: _tabs[i].$2,
                        label: _tabs[i].$3,
                        selected: i == _index,
                        onTap: () => context.go(_tabs[i].$1),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color)
              .animate(target: selected ? 1 : 0)
              .scaleXY(end: 1.15, duration: 220.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 10.5,
              height: 1,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
