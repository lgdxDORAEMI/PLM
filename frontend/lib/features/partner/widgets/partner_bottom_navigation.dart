import 'package:flutter/material.dart';

import '../../../design_system/components/bottom_navigation.dart';
import '../../../routing/route_names.dart';

class PartnerBottomNavigation extends StatelessWidget {
  const PartnerBottomNavigation({super.key, this.currentIndex = 0});

  final int currentIndex;

  @override
  Widget build(BuildContext context) => AppBottomNavigation(
    currentIndex: currentIndex,
    items: const [
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: '캘린더',
      ),
      NavigationDestination(
        icon: Icon(Icons.monitor_heart_outlined),
        label: '실시간',
      ),
    ],
    onSelected: (index) {
      if (index == currentIndex) return;
      Navigator.pushReplacementNamed(
        context,
        index == 0 ? RouteNames.partnerCalendar : RouteNames.partnerMovement,
      );
    },
  );
}
