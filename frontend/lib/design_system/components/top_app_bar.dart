import 'package:flutter/material.dart';

/// 44px 이상의 뒤로가기 hit area를 보장하는 공통 AppBar다.
class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TopAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              tooltip: '뒤로 가기',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            )
          : null,
      actions: actions,
    );
  }
}
