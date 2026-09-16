import 'package:flutter/material.dart';

/// DESIGN.md의 제품 색상을 한 곳에서 관리한다.
abstract final class AppColors {
  static const canvas = Color(0xFFF6F4EF);
  static const surface = Color(0xFFFFFEFB);
  static const surfaceSubtle = Color(0xFFF0EEE8);
  static const surfaceRaised = Color(0xFFFFFFFF);

  /// 기존 화면의 API 호환을 위한 별칭이다.
  static const surfaceElevated = surfaceRaised;

  static const textPrimary = Color(0xFF202624);
  static const textSecondary = Color(0xFF58615D);
  static const textTertiary = Color(0xFF68716C);
  static const textInverse = Color(0xFFFFFFFF);
  static const textDisabled = Color(0xFF8A908D);

  static const borderSubtle = Color(0xFFDEDCD4);
  static const borderDefault = borderSubtle;
  static const borderStrong = Color(0xFFC7C9C1);

  // PLM 고유 mineral teal palette. 외부 브랜드 color token을 사용하지 않는다.
  static const primary50 = Color(0xFFEDF5F2);
  static const primary100 = Color(0xFFE4F0EC);
  static const primary200 = Color(0xFFB7D4CB);
  static const primary300 = Color(0xFF8FBBAE);
  static const primary400 = Color(0xFF679F90);
  static const primary500 = Color(0xFF4E8779);
  static const primary600 = Color(0xFF3D7165);
  static const primary700 = Color(0xFF315C53);
  static const primary800 = Color(0xFF284A43);
  static const primary900 = Color(0xFF213D38);

  static const accentWarm = Color(0xFF8A684F);
  static const accentWarmBackground = Color(0xFFF4EEE8);
  static const focusRing = Color(0xFF5E9185);
  static const scrim = Color(0x99202624);

  static const success = Color(0xFF39715C);
  static const successBackground = Color(0xFFEAF4EF);
  static const warning = Color(0xFF8B6728);
  static const warningBackground = Color(0xFFF7F1E4);
  static const danger = Color(0xFFA54742);
  static const dangerBackground = Color(0xFFF8ECEA);
  static const info = Color(0xFF496F8A);
  static const infoBackground = Color(0xFFEAF1F5);
  static const disabled = Color(0xFF8A908D);
  static const disabledBackground = Color(0xFFECECE8);

  static const categoryMeal = Color(0xFF657A50);
  static const categoryMealBackground = Color(0xFFF0F3EA);
  static const categoryHousehold = Color(0xFF8A684F);
  static const categoryHouseholdBackground = Color(0xFFF4EEE8);
  static const categoryHealth = Color(0xFF526F88);
  static const categoryHealthBackground = Color(0xFFECF1F5);
  static const categorySleep = Color(0xFF696787);
  static const categorySleepBackground = Color(0xFFEFEEF5);
  static const categoryAi = primary600;
  static const categoryAiBackground = primary100;
  static const categoryPartner = Color(0xFF596D76);
  static const categoryPartnerBackground = Color(0xFFEDF1F2);

  /// 기존 Feature 명칭과의 호환 별칭. 신규 코드는 의미 기반 명칭을 사용한다.
  static const categoryHome = categoryHousehold;
  static const categoryHomeBackground = categoryHouseholdBackground;
  static const categoryBody = categoryHealth;
  static const categoryBodyBackground = categoryHealthBackground;
}
