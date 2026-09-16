import 'package:flutter/material.dart';

/// DESIGN.md의 제품 색상을 한 곳에서 관리한다.
abstract final class AppColors {
  static const canvas = Color(0xFFF8F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF5F3F1);
  static const surfaceElevated = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF1F1F1F);
  static const textSecondary = Color(0xFF65615F);
  static const textTertiary = Color(0xFF8A8582);
  static const textInverse = Color(0xFFFFFFFF);
  static const textDisabled = Color(0xFFAAA6A3);

  static const borderSubtle = Color(0xFFE9E5E2);
  static const borderDefault = Color(0xFFDDD8D5);
  static const borderStrong = Color(0xFFC9C3BF);

  static const primary50 = Color(0xFFFFF2F5);
  static const primary100 = Color(0xFFFCE4EA);
  static const primary200 = Color(0xFFF6C6D2);
  static const primary300 = Color(0xFFEFA2B5);
  static const primary400 = Color(0xFFE47A98);
  static const primary500 = Color(0xFFD95B7F);
  static const primary600 = Color(0xFFC6426A);
  static const primary700 = Color(0xFFA93257);
  static const primary800 = Color(0xFF842642);
  static const primary900 = Color(0xFF621C31);

  static const success = Color(0xFF357861);
  static const successBackground = Color(0xFFEDF6F1);
  static const warning = Color(0xFF9A6A17);
  static const warningBackground = Color(0xFFFBF5E8);
  static const danger = Color(0xFFB64048);
  static const dangerBackground = Color(0xFFFBEEEE);
  static const info = Color(0xFF416C8A);
  static const infoBackground = Color(0xFFEEF4F8);

  static const categoryMeal = Color(0xFF5F846A);
  static const categoryMealBackground = Color(0xFFEEF5EF);
  static const categoryHome = Color(0xFFA85B70);
  static const categoryHomeBackground = Color(0xFFFAF0F3);
  static const categoryBody = Color(0xFF5C7191);
  static const categoryBodyBackground = Color(0xFFEEF2F8);
  static const categorySleep = Color(0xFF7560A3);
  static const categorySleepBackground = Color(0xFFF2EFF8);
}
