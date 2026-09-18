import 'package:flutter/material.dart';

import '../../debug/empty_data_preview_store.dart';
import 'app_state_view.dart';

/// 활성화된 동안 실제 자식 대신 화면별 빈 상태를 보여준다.
class EmptyDataPreview extends StatelessWidget {
  const EmptyDataPreview({
    super.key,
    required this.title,
    required this.message,
    required this.child,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final store = EmptyDataPreviewStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => store.enabled
          ? AppEmptyState(
              key: const ValueKey('empty-data-preview'),
              title: title,
              message: message,
              icon: icon,
            )
          : child,
    );
  }
}
