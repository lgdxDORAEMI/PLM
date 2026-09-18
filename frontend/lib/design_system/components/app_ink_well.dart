import 'package:flutter/material.dart';

/// 호버·포커스·클릭 잉크가 지정한 외곽선 밖으로 그려지지 않게 제한한다.
class AppInkWell extends StatelessWidget {
  const AppInkWell({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
    this.customBorder,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;

  @override
  Widget build(BuildContext context) {
    final shape =
        customBorder ??
        RoundedRectangleBorder(borderRadius: borderRadius ?? BorderRadius.zero);

    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        customBorder: customBorder,
        child: child,
      ),
    );
  }
}
