import 'package:flutter/material.dart';

import '../../debug/empty_data_preview_store.dart';
import '../../routing/route_names.dart';
import '../tokens/app_breakpoints.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// 44px 이상의 뒤로가기 hit area를 보장하는 공통 AppBar다.
class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TopAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.wifeProfileAction = false,
    this.husbandMenuAction = false,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool wifeProfileAction;
  final bool husbandMenuAction;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final windowSize = AppBreakpoints.sizeFor(MediaQuery.sizeOf(context).width);
    final actionEndPadding = switch (windowSize) {
      AppWindowSize.mobile => AppSpacing.xs,
      AppWindowSize.tablet => AppSpacing.pageTablet,
      AppWindowSize.desktop => AppSpacing.pageDesktop,
      AppWindowSize.wide => AppSpacing.pageWide,
    };

    return AppBar(
      title: GestureDetector(
        key: const ValueKey('empty-data-preview-trigger'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTitleTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      // 넓은 화면에서는 우측 액션을 콘텐츠 grid 여백과 맞춰 가장자리에 붙지 않게 한다.
      actionsPadding: EdgeInsetsDirectional.only(end: actionEndPadding),
      leading: showBack
          ? IconButton(
              tooltip: '뒤로 가기',
              onPressed: onBack ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            )
          : null,
      actions: [
        ...?actions,
        if (wifeProfileAction)
          IconButton(
            tooltip: '메뉴',
            icon: const Icon(Icons.menu),
            onPressed: () {
              final location = ModalRoute.of(context)?.settings.name;
              Navigator.pushNamed(
                context,
                RouteNames.menu(returnLocation: location),
              );
            },
          ),
        if (husbandMenuAction)
          IconButton(
            tooltip: '메뉴',
            icon: const Icon(Icons.menu),
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.husbandMenu),
          ),
      ],
    );
  }

  void _handleTitleTap(BuildContext context) {
    final enabled = EmptyDataPreviewStore.instance.registerTitleTap();
    if (enabled == null) return;

    final message = enabled ? '빈 데이터 미리보기를 시작했어요.' : 'Mock 데이터 화면으로 돌아왔어요.';
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
