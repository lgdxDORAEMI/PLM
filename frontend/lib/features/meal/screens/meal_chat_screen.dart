import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_input.dart';
import '../../../design_system/components/bottom_navigation.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/meal_chat_controller.dart';
import '../models/meal_guide.dart';
import '../services/meal_service.dart';
import '../services/mock_meal_service.dart';
import '../widgets/meal_chat_bubble.dart';
import '../widgets/meal_recommendation_card.dart';

class MealChatScreen extends StatefulWidget {
  const MealChatScreen({super.key, this.service});

  final MealService? service;

  @override
  State<MealChatScreen> createState() => _MealChatScreenState();
}

class _MealChatScreenState extends State<MealChatScreen> {
  late final MealChatController _controller;
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    final service = widget.service ?? const MockMealService();
    _controller = MealChatController(service: service)
      ..addListener(_refresh)
      ..initialize(_initialRecommendation());
    _inputController = TextEditingController();
    unawaited(_controller.requestAlternative('속이 좀 메스꺼워요'));
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopAppBar(title: '식사 다시 고르기', onBack: _handleBack),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const ValueKey('meal-chat-log'),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  children: [
                    const _MealChatContext(),
                    const SizedBox(height: AppSpacing.xxl),
                    const MealChatBubble(
                      message: '아침 메뉴, 어떤 점이 고민이세요?\n냄새·식감·속 불편함 뭐든 말씀해 주세요.',
                      fromUser: false,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    MealChatBubble(
                      message: _controller.request,
                      fromUser: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_controller.responding)
                      const _RespondingIndicator()
                    else if (_controller.proposal != null) ...[
                      const MealChatBubble(
                        message:
                            '계란찜 냄새가 부담되셨군요.\n냄새가 거의 없고 더 담백한 메뉴로 다시 골라볼게요.',
                        fromUser: false,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      MealRecommendationCard(
                        key: const ValueKey('meal-alternative-card'),
                        recommendation: _controller.proposal!,
                        compact: true,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              key: const ValueKey('apply-meal-alternative'),
                              label: '이걸로 할게요',
                              onPressed: _applyProposal,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              label: '다른 메뉴 보기',
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _controller.requestAlternative(
                                _controller.request,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AppInput(
                  key: const ValueKey('meal-chat-input'),
                  label: '메뉴 변경 요청',
                  hintText: '냄새나 식감 등 불편한 점을 알려주세요',
                  controller: _inputController,
                  textInputAction: TextInputAction.send,
                  enabled: !_controller.responding,
                  onSubmitted: _send,
                  suffixIcon: IconButton(
                    tooltip: '보내기',
                    onPressed: _controller.responding
                        ? null
                        : () => _send(_inputController.text),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 2,
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

  MealRecommendation _initialRecommendation() {
    return MockMealService.guide.recommendationFor(MealPeriod.breakfast);
  }

  void _send(String value) {
    if (value.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _inputController.clear();
    unawaited(_controller.requestAlternative(value));
  }

  void _applyProposal() {
    _controller.applyProposal();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.mealGuide);
    }
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.mealGuide);
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
    if (route != RouteNames.mealChat) {
      Navigator.pushReplacementNamed(context, route);
    }
  }
}

class _MealChatContext extends StatelessWidget {
  const _MealChatContext();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '아침 메뉴를 다시 고르는 중',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary700),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text('식사 가이드에서 이어짐 · 임당 경계 · 입덧 반영'),
          ],
        ),
      ),
    );
  }
}

class _RespondingIndicator extends StatelessWidget {
  const _RespondingIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '대체 메뉴를 준비하고 있어요',
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
