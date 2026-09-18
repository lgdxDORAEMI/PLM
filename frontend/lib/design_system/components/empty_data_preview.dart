import 'package:flutter/widgets.dart';

import '../../debug/empty_data_preview_store.dart';

/// 빈 데이터 미리보기 상태를 하위 데이터 컴포넌트에 전달한다.
///
/// 화면 구조 전체를 교체하지 않고 실제 Mock 값에 의존하는 요소만 이 상태를
/// 구독해 숨기거나 섹션 단위 빈 상태로 바꾼다.
class EmptyDataPreview extends StatelessWidget {
  const EmptyDataPreview({super.key, required this.child});

  final Widget child;

  static bool enabledOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_EmptyDataPreviewScope>();
    return scope?.notifier?.enabled ?? false;
  }

  @override
  Widget build(BuildContext context) => _EmptyDataPreviewScope(
    notifier: EmptyDataPreviewStore.instance,
    child: child,
  );
}

class _EmptyDataPreviewScope extends InheritedNotifier<EmptyDataPreviewStore> {
  const _EmptyDataPreviewScope({required super.notifier, required super.child});
}

/// Mock 값으로 생성되는 요소 하나를 빈 상태에서만 대체한다.
class PreviewData extends StatelessWidget {
  const PreviewData({
    super.key,
    required this.child,
    this.empty = const SizedBox.shrink(),
  });

  final Widget child;
  final Widget empty;

  @override
  Widget build(BuildContext context) => EmptyDataPreview.enabledOf(context)
      ? KeyedSubtree(
          key: const ValueKey('empty-data-preview-item'),
          child: empty,
        )
      : child;
}
