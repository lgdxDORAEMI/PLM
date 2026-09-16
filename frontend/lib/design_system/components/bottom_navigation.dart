import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// 역할별 항목을 주입받아 미확정 IA를 고정하지 않는 하단 탐색이다.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onSelected,
  });

  final int currentIndex;
  final List<NavigationDestination> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        destinations: items,
        onDestinationSelected: onSelected,
      ),
    );
  }
}
