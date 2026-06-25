import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'tools/tools_hub_screen.dart';
import 'track_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    TrackScreen(),
    ToolsHubScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  static const _items = <_NavItem>[
    _NavItem(Icons.home_rounded, Icons.home_outlined, "Anasayfa"),
    _NavItem(
        Icons.monitor_heart_rounded, Icons.monitor_heart_outlined, "Takip"),
    _NavItem(Icons.widgets_rounded, Icons.widgets_outlined, "Araçlar"),
    _NavItem(Icons.menu_book_rounded, Icons.menu_book_outlined, "Rehber"),
    _NavItem(Icons.person_rounded, Icons.person_outline_rounded, "Profil"),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: p.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: p.borderSoft),
            boxShadow: p.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (i) {
              final selected = i == _index;
              final item = _items[i];
              if (i == 2) {
                return _CenterButton(
                  item: item,
                  selected: selected,
                  onTap: () => setState(() => _index = i),
                );
              }
              return Expanded(
                child: _NavButton(
                  item: item,
                  selected: selected,
                  onTap: () => setState(() => _index = i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData active;
  final IconData inactive;
  final String label;
  const _NavItem(this.active, this.inactive, this.label);
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.primary : p.textMuted;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        splashColor: p.primary.withValues(alpha: 0.12),
        highlightColor: p.primary.withValues(alpha: 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              constraints: const BoxConstraints(minWidth: 42),
              decoration: BoxDecoration(
                color: selected ? p.primaryBg : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(selected ? item.active : item.inactive,
                  size: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: p.brandGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: p.glow(p.primary, strength: selected ? 0.5 : 0.32),
              ),
              child: const Icon(Icons.widgets_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? p.primary : p.textMuted,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
