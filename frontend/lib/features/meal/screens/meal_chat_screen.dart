import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_input.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/meal_chat_controller.dart';
import '../models/meal_chat_message.dart';
import '../models/meal_guide.dart';
import '../services/meal_chat_service.dart';
import '../services/api_meal_chat_service.dart';
import '../services/api_meal_service.dart';
import '../services/mock_meal_service.dart';
import '../widgets/meal_chat_bubble.dart';
import '../widgets/meal_recommendation_card.dart';
import '../widgets/routine_update_status_card.dart';
import '../../../shared/widgets/integration_required_state.dart';

class MealChatScreen extends StatefulWidget {
  const MealChatScreen({
    super.key,
    this.service,
    this.mealPeriod,
    this.returnRoute,
  });

  final MealChatService? service;
  final MealPeriod? mealPeriod;
  final String? returnRoute;

  @override
  State<MealChatScreen> createState() => _MealChatScreenState();
}

class _MealChatScreenState extends State<MealChatScreen> {
  late final MealChatController _controller;
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  ApiMealChatService? _apiService;
  bool _chatReady = false;
  bool _loadingChat = false;
  bool _loadFailed = false;

  bool get _liveChat => widget.service == null && AppConfig.hasSupabaseConfig;

  bool get _chatAvailable =>
      widget.service != null ||
      AppConfig.hasSupabaseConfig ||
      AppConfig.mockPreviewEnabled ||
      AppConfig.previewMode;

  @override
  void initState() {
    super.initState();
    _apiService = _liveChat ? ApiMealChatService() : null;
    final service = widget.service ?? _apiService ?? const MockMealService();
    _controller = MealChatController(service: service, live: _liveChat)
      ..addListener(_refresh);
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    if (_liveChat) {
      unawaited(_prepareLiveChat());
    } else if (_chatAvailable) {
      _controller.initialize(_initialRecommendation());
      _chatReady = true;
    }
  }

  /// Load the real meal item before sending, so the backend can keep modes separate.
  Future<void> _prepareLiveChat() async {
    if (_loadingChat) return;
    setState(() {
      _loadingChat = true;
      _loadFailed = false;
    });
    try {
      if (widget.mealPeriod case final period?) {
        final guide = await ApiMealService().fetchGuide();
        final matches = guide.recommendations.where(
          (item) => item.period == period,
        );
        if (matches.isEmpty) throw const FormatException('해당 끼니의 식사 루틴이 없습니다.');
        final recommendation = matches.first;
        _apiService!.routineItemId = recommendation.id;
        _apiService!.recommendationContext = recommendation;
        _controller.initialize(recommendation);
      } else {
        _controller.initialize(null);
      }
      await _controller.loadHistory();
      if (mounted) setState(() => _chatReady = true);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return WifeNavigationScaffold(
      currentIndex: 2,
      appBar: TopAppBar(
        title: '챗봇',
        showBack: widget.returnRoute != null,
        onBack: widget.returnRoute == null ? null : _handleBack,
        wifeProfileAction: true,
      ),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const ValueKey('meal-chat-log'),
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  children: [
                    if (!_chatAvailable || AppConfig.previewMode)
                      const IntegrationRequiredState(),
                    _MealChatContext(
                      period: widget.mealPeriod,
                      live: _liveChat,
                    ),
                    if (_controller.routineUpdate case final update?
                        when update.status !=
                            RoutineUpdateStatus.cancelled) ...[
                      const SizedBox(height: AppSpacing.lg),
                      RoutineUpdateStatusCard(
                        key: const ValueKey('routine-update-status'),
                        update: update,
                        busy: _controller.routineUpdateBusy,
                        errorMessage: _controller.routineUpdateError,
                        onConfirm: () =>
                            unawaited(_controller.confirmRoutineUpdate()),
                        onCancel: () =>
                            unawaited(_controller.cancelRoutineUpdate()),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    if (_loadingChat)
                      const Center(child: CircularProgressIndicator())
                    else if (_loadFailed)
                      _ChatError(
                        message: '대화를 불러오지 못했어요. 다시 시도해 주세요.',
                        onRetry: () => unawaited(_prepareLiveChat()),
                      ),
                    if (_chatAvailable)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final message in _controller.messages) ...[
                            MealChatBubble(
                              key: ValueKey(message.id),
                              message: message.text,
                              fromUser: message.author == MealChatAuthor.user,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (_controller.messages.length == 1 &&
                              !_controller.responding &&
                              (!_liveChat || widget.mealPeriod != null)) ...[
                            _SuggestedPrompts(onSelected: _send),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (_controller.responding)
                            const _RespondingIndicator()
                          else if (_controller.errorMessage != null)
                            _ChatError(
                              message: _controller.errorMessage!,
                              onRetry: () => unawaited(_controller.retry()),
                            )
                          else if (_controller.proposal != null) ...[
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
                                    key: const ValueKey(
                                      'apply-meal-alternative',
                                    ),
                                    label: '이걸로 할게요',
                                    onPressed: _applyProposal,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: AppButton(
                                    label: '다른 메뉴 보기',
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () =>
                                        unawaited(_controller.requestAnother()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AppInput(
                  key: const ValueKey('meal-chat-input'),
                  label: '무엇이든 물어보세요',
                  hintText: widget.mealPeriod == null
                      ? '궁금한 내용을 입력해 주세요'
                      : '냄새나 식감 등 불편한 점을 알려주세요',
                  controller: _inputController,
                  textInputAction: TextInputAction.send,
                  enabled: _chatReady && !_controller.responding,
                  onSubmitted: _send,
                  suffixIcon: IconButton(
                    tooltip: '보내기',
                    onPressed: !_chatReady || _controller.responding
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
    );
  }

  MealRecommendation _initialRecommendation() {
    return MockMealService.guide.recommendationFor(
      widget.mealPeriod ?? MealPeriod.breakfast,
    );
  }

  void _send(String value) {
    if (!_chatReady || value.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _inputController.clear();
    unawaited(_controller.sendMessage(value));
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
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
      Navigator.pushReplacementNamed(context, widget.returnRoute!);
    }
  }
}

class _MealChatContext extends StatelessWidget {
  const _MealChatContext({required this.period, required this.live});

  final MealPeriod? period;
  final bool live;

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
              period == null
                  ? '오늘 가이드와 임신 생활을 물어보세요'
                  : '${_label(period!)} 메뉴를 다시 고르는 중',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              period == null
                  ? '임신 주차 · 주의 진단 · 오늘 컨디션 반영'
                  : live
                  ? '식사 가이드에서 이어지는 대화예요.'
                  : '식사 가이드에서 이어짐 · 임당 경계 · 입덧 반영',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              period == null
                  ? '궁금한 내용을 입력해 주세요.'
                  : '원하는 메뉴나 피하고 싶은 재료를 말씀해 주세요.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(MealPeriod period) => switch (period) {
    MealPeriod.breakfast => '아침',
    MealPeriod.lunch => '점심',
    MealPeriod.dinner => '저녁',
    MealPeriod.snack => '밤',
  };
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.md),
            Text('답변을 준비하고 있어요'),
          ],
        ),
      ),
    );
  }
}

class _SuggestedPrompts extends StatelessWidget {
  const _SuggestedPrompts({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final prompt in MealChatController.suggestedPrompts)
            ActionChip(
              key: ValueKey('meal-chat-prompt-$prompt'),
              label: Text(prompt),
              onPressed: () => onSelected(prompt),
            ),
        ],
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '다시 시도',
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
