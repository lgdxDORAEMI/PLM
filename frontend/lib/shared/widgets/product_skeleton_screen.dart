import 'package:flutter/material.dart';

import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/bottom_navigation.dart';
import '../../design_system/components/top_app_bar.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../routing/route_names.dart';

class SkeletonAction {
  const SkeletonAction(this.label, this.route, {this.replace = false});

  final String label;
  final String route;
  final bool replace;
}

enum SkeletonShell { none, wife, partner }

/// 상세 UI 구현 전에도 전체 흐름을 검증할 수 있는 공통 화면 골격이다.
class ProductSkeletonScreen extends StatelessWidget {
  const ProductSkeletonScreen({
    super.key,
    required this.screenId,
    required this.title,
    required this.description,
    this.actions = const [],
    this.showBack = true,
    this.shell = SkeletonShell.none,
    this.statusLabel = 'SKELETON',
  });

  final String screenId;
  final String title;
  final String description;
  final List<SkeletonAction> actions;
  final bool showBack;
  final SkeletonShell shell;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopAppBar(title: title, showBack: showBack),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pageMobile),
              children: [
                Text(
                  screenId,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.primary600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.construction_outlined,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          '$statusLabel · 다음 개발자가 이 영역을 실제 UI로 교체합니다.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Navigation test',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var index = 0; index < actions.length; index++) ...[
                    AppButton(
                      label: actions[index].label,
                      variant: index == 0
                          ? AppButtonVariant.primary
                          : AppButtonVariant.secondary,
                      onPressed: () {
                        final action = actions[index];
                        if (action.replace) {
                          Navigator.pushReplacementNamed(context, action.route);
                        } else {
                          Navigator.pushNamed(context, action.route);
                        }
                      },
                    ),
                    if (index != actions.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget? _buildBottomNavigation(BuildContext context) {
    if (shell == SkeletonShell.none) return null;
    if (shell == SkeletonShell.wife) {
      return AppBottomNavigation(
        currentIndex: _wifeIndex(context),
        items: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: '캘린더',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            label: '실시간',
          ),
        ],
        onSelected: (index) => _replaceRoot(
          context,
          [
            RouteNames.wifeHome,
            RouteNames.wifeCalendar,
            RouteNames.movement,
          ][index],
        ),
      );
    }
    return AppBottomNavigation(
      currentIndex: 0,
      items: const [
        NavigationDestination(icon: Icon(Icons.calendar_month), label: '캘린더'),
      ],
      onSelected: (_) => _replaceRoot(context, RouteNames.partnerCalendar),
    );
  }

  int _wifeIndex(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    if (route == RouteNames.wifeCalendar) return 1;
    if (route == RouteNames.movement) return 2;
    return 0;
  }

  /// Tab 전환은 중복 push를 막기 위해 현재 shell route를 교체한다.
  void _replaceRoot(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushReplacementNamed(context, route);
  }
}
