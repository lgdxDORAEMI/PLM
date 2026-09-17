import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_colors.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final bool enabled;
}

/// Mobile bottom navigation과 Desktop navigation rail을 같은 목적지로 표현한다.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onSelected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  final int currentIndex;
  final List<AppNavigationItem> items;
  final ValueChanged<int> onSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppBreakpoints.desktop;
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: appBar,
          body: desktop
              ? Row(
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(color: AppColors.surface),
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        extended: constraints.maxWidth >= AppBreakpoints.wide,
                        labelType: constraints.maxWidth >= AppBreakpoints.wide
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        onDestinationSelected: _select,
                        destinations: [
                          for (final item in items)
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(
                                item.selectedIcon ?? item.icon,
                              ),
                              label: Text(item.label),
                              disabled: !item.enabled,
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: desktop
              ? null
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: currentIndex,
                    onDestinationSelected: _select,
                    destinations: [
                      for (final item in items)
                        NavigationDestination(
                          enabled: item.enabled,
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon ?? item.icon),
                          label: item.label,
                        ),
                    ],
                  ),
                ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }

  void _select(int index) {
    if (items[index].enabled && index != currentIndex) onSelected(index);
  }
}
