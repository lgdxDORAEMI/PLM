import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/bottom_navigation.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/section_header.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/meal_guide_controller.dart';
import '../models/meal_guide.dart';
import '../services/meal_service.dart';
import '../services/mock_meal_service.dart';
import '../widgets/meal_info_section.dart';
import '../widgets/meal_period_card.dart';
import '../widgets/meal_recommendation_card.dart';

class MealGuideScreen extends StatefulWidget {
  const MealGuideScreen({super.key, this.service});

  final MealService? service;

  @override
  State<MealGuideScreen> createState() => _MealGuideScreenState();
}

class _MealGuideScreenState extends State<MealGuideScreen> {
  late final MealGuideController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MealGuideController(
      service: widget.service ?? const MockMealService(),
    )..addListener(_refresh);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopAppBar(title: '식사 가이드', onBack: _handleBack),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          child: switch (_controller.state) {
            MealGuideViewState.loading => const AppLoadingState(
              message: '오늘의 메뉴를 준비하고 있어요',
            ),
            MealGuideViewState.error => AppErrorState(
              title: '메뉴를 불러오지 못했어요',
              message: '잠시 후 다시 시도해 주세요.',
              onRetry: _controller.load,
            ),
            MealGuideViewState.ready =>
              _controller.showDetails
                  ? _buildRecommendation()
                  : _buildPeriodSelection(),
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 0,
        items: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(icon: Icon(Icons.sync_alt), label: '실시간'),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: '챗봇',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: '캘린더',
          ),
        ],
        onSelected: _openBottomDestination,
      ),
    );
  }

  Widget _buildPeriodSelection() {
    final data = _controller.data!;
    return ListView(
      key: const ValueKey('meal-period-list'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        _MealGreeting(data: data),
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(
          title: '어떤 끼니를 볼까요?',
          description: '지금은 아침이지만, 다른 끼니도 미리 볼 수 있어요',
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final period in data.periods) ...[
          MealPeriodCard(
            summary: period,
            onTap: () => _controller.selectPeriod(period.period),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildRecommendation() {
    final recommendation = _controller.selectedRecommendation!;
    return ListView(
      key: const ValueKey('meal-recommendation-detail'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        Text(
          _periodLabel(recommendation.period),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.primary600),
        ),
        const SizedBox(height: AppSpacing.md),
        _RecommendationReason(recommendation: recommendation),
        const SizedBox(height: AppSpacing.xxl),
        Text('오늘의 추천', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        MealRecommendationCard(recommendation: recommendation),
        const SizedBox(height: AppSpacing.lg),
        _MealAdjustmentEntry(onTap: _openMealChat),
        const SizedBox(height: AppSpacing.xxxl),
        MealInfoSection(items: recommendation.cautions),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  String _periodLabel(MealPeriod period) {
    return switch (period) {
      MealPeriod.breakfast => '아침',
      MealPeriod.lunch => '점심',
      MealPeriod.dinner => '저녁',
      MealPeriod.snack => '밤',
    };
  }

  Future<void> _openMealChat() async {
    await Navigator.pushNamed(context, RouteNames.mealChat);
    if (mounted) _controller.showAppliedRecommendation();
  }

  void _handleBack() {
    if (_controller.showDetails) {
      _controller.showPeriodList();
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

  void _openBottomDestination(int index) {
    final route = switch (index) {
      0 => RouteNames.wifeHome,
      1 => RouteNames.wifeMovement,
      2 => RouteNames.mealChat,
      3 => RouteNames.wifeCalendar,
      _ => RouteNames.wifeHome,
    };
    Navigator.pushReplacementNamed(context, route);
  }
}

class _MealGreeting extends StatelessWidget {
  const _MealGreeting({required this.data});

  final MealGuideData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.categoryMealBackground,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.greeting,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.categoryMeal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(data.supportingText),
                ],
              ),
            ),
            const Icon(Icons.wb_sunny, size: 36, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

class _RecommendationReason extends StatelessWidget {
  const _RecommendationReason({required this.recommendation});

  final MealRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendation.reasonTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(recommendation.reason),
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.primary100),
            Text(
              recommendation.evidence,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealAdjustmentEntry extends StatelessWidget {
  const _MealAdjustmentEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey('meal-alternative-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textInverse,
                child: Text('AI'),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“속이 좀 메스꺼워요”'),
                    SizedBox(height: AppSpacing.xs),
                    Text('말만 하면 지금 상태에 맞게 다시 골라드려요'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
