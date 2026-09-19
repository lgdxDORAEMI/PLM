import 'package:flutter/material.dart';

import '../../routing/route_names.dart';
import 'adaptive_navigation_scaffold.dart';

/// Wife 영역의 Mobile bottom navigation과 Desktop rail 목적지를 한 곳에서 관리한다.
class WifeNavigationScaffold extends StatelessWidget {
  const WifeNavigationScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.allowReselect = false,
    this.appBar,
    this.floatingActionButton,
  });

  final int currentIndex;
  final Widget body;
  final bool allowReselect;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  static const items = <AppNavigationItem>[
    AppNavigationItem(
      label: '홈',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppNavigationItem(
      label: '실시간',
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
    ),
    AppNavigationItem(
      label: '챗봇',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    AppNavigationItem(
      label: '캘린더',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
  ];

  static const routes = <String>[
    RouteNames.wifeHome,
    RouteNames.wifeMovement,
    RouteNames.mealChat,
    RouteNames.wifeCalendar,
  ];

  @override
  Widget build(BuildContext context) => AdaptiveNavigationScaffold(
    currentIndex: currentIndex,
    allowReselect: allowReselect,
    items: items,
    onSelected: (index) => Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(routes[index], (_) => false),
    appBar: appBar,
    body: body,
    floatingActionButton: floatingActionButton,
  );
}
