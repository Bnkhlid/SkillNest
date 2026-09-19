import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../main.dart';
import '../vault.dart';
import '../widgets/components.dart';
import 'collections.dart';
import 'favorites.dart';
import 'home.dart';
import 'search.dart';

/// Root shell: Home · Search · [raised +] · Collections · Favorites
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    CollectionsScreen(),
    FavoritesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    appTab.addListener(_onTabRequested);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showNotificationOnboarding(),
    );
  }

  @override
  void dispose() {
    appTab.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    if (mounted && appTab.value != _tab) setState(() => _tab = appTab.value);
  }

  Future<void> _showNotificationOnboarding() async {
    final vault = Vault.I;
    if (!mounted || vault.notificationOnboardingHandled) return;

    final enable =
        await LvDialog.show(
          context,
          icon: Icons.notifications_active_outlined,
          iconColor: NotedColors.ink,
          title: 'Stay up to date with SkillNest',
          message:
              'Enable notifications to receive important reminders and SkillNest updates.',
          confirmLabel: 'Enable notifications',
          cancelLabel: 'Not now',
        ) ??
        false;
    if (!mounted) return;

    if (enable) {
      final granted = await vault.handleNotificationOnboarding();
      if (!mounted) return;
      LvSnackbar.show(
        context,
        granted
            ? 'Notifications enabled.'
            : 'Notifications are off. You can enable them later in Settings.',
        icon: granted
            ? Icons.notifications_active_rounded
            : Icons.notifications_off_outlined,
      );
    } else {
      await vault.dismissNotificationOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotedColors.canvasLight,
      // Reserve layout space for the navigation bar. With extendBody enabled,
      // the last Home section could scroll underneath the raised + button on
      // short devices.
      extendBody: false,
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: _VaultNavBar(
        selected: _tab,
        onSelect: (i) {
          appTab.value = i;
          setState(() => _tab = i);
        },
        onAdd: () => Navigator.pushNamed(context, RoutePaths.add),
      ),
    );
  }
}

class _VaultNavBar extends StatelessWidget {
  const _VaultNavBar({
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Bar container
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: NotedColors.border, width: 2.2),
              boxShadow: const [
                BoxShadow(
                  color: NotedColors.shadow,
                  offset: Offset(3.5, 4.5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: _item(
                      context,
                      0,
                      Icons.home_rounded,
                      Icons.home_outlined,
                      'Home',
                    ),
                  ),
                  Expanded(
                    child: _item(
                      context,
                      1,
                      Icons.search_rounded,
                      Icons.search_rounded,
                      'Search',
                    ),
                  ),
                  const Expanded(child: SizedBox()), // gap for the raised +
                  Expanded(
                    child: _item(
                      context,
                      2,
                      Icons.collections_bookmark_rounded,
                      Icons.collections_bookmark_outlined,
                      'Collections',
                    ),
                  ),
                  Expanded(
                    child: _item(
                      context,
                      3,
                      Icons.favorite_rounded,
                      Icons.favorite_border_rounded,
                      'Favorites',
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Raised central + button
          Positioned(
            top: -18,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: NotedColors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: NotedColors.border, width: 2.4),
                  boxShadow: const [
                    BoxShadow(
                      color: NotedColors.shadow,
                      offset: Offset(2.5, 3.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: NotedColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int index,
    IconData active,
    IconData inactive,
    String label,
  ) {
    final on = selected == index;
    return InkWell(
      onTap: () => onSelect(index),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            on ? active : inactive,
            size: 23,
            color: on ? NotedColors.ink : NotedColors.inkSubtle,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.1,
              color: on ? NotedColors.ink : NotedColors.inkSubtle,
            ),
          ),
        ],
      ),
    );
  }
}
