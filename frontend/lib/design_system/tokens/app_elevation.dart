import 'package:flutter/material.dart';

/// 떠 있는 계층에만 사용하는 절제된 elevation token이다.
abstract final class AppElevation {
  static const none = <BoxShadow>[];

  static const level1 = [
    BoxShadow(color: Color(0x14202624), offset: Offset(0, 1), blurRadius: 3),
  ];

  static const level2 = [
    BoxShadow(color: Color(0x1A202624), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const level3 = [
    BoxShadow(color: Color(0x29202624), offset: Offset(0, 18), blurRadius: 48),
  ];
}
