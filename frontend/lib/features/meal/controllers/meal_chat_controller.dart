import 'package:flutter/foundation.dart';

import '../data/meal_selection_store.dart';
import '../models/meal_chat_message.dart';
import '../models/meal_guide.dart';
import '../services/meal_chat_service.dart';

class MealChatController extends ChangeNotifier {
  MealChatController({
    required this.service,
    this.live = false,
    MealSelectionStore? store,
  }) : store = store ?? MealSelectionStore.instance;

  final MealChatService service;
  final bool live;
  final MealSelectionStore store;

  final List<MealChatMessage> _messages = [];
  MealRecommendation? _current;
  MealRecommendation? _proposal;
  bool _responding = false;
  String? _errorMessage;
  String? _lastRequest;

  List<MealChatMessage> get messages => List.unmodifiable(_messages);
  MealRecommendation? get current => _current;
  MealRecommendation? get proposal => _proposal;
  bool get responding => _responding;
  String? get errorMessage => _errorMessage;

  static const suggestedPrompts = ['속이 좀 메스꺼워요', '냄새가 부담스러워요', '부드러운 음식이 좋아요'];

  void initialize(MealRecommendation? fallback) {
    _current = store.appliedRecommendation ?? fallback;
    if (_messages.isEmpty) {
      _messages.add(
        MealChatMessage(
          id: 'welcome',
          author: MealChatAuthor.assistant,
          text: fallback == null
              ? '무엇이 궁금하신가요? 오늘 가이드와 임신 생활에 대해 물어보세요.'
              : '아침 메뉴, 어떤 점이 고민이세요?\n냄새·식감·속 불편함 뭐든 말씀해 주세요.',
        ),
      );
    }
  }

  /// Restore only this conversation's saved messages when opening the screen.
  Future<void> loadHistory() async {
    final history = await service.fetchHistory();
    if (history.isNotEmpty) {
      _messages
        ..clear()
        ..addAll(history);
      notifyListeners();
    }
  }

  /// 사용자 메시지를 기록하고 식사 범위의 응답만 서비스에 요청한다.
  Future<void> sendMessage(String value) async {
    final currentMeal = _current;
    final normalized = value.trim();
    if ((!live && currentMeal == null) || normalized.isEmpty || _responding) {
      return;
    }
    _lastRequest = normalized;
    _messages.add(
      MealChatMessage(
        id: 'user-${_messages.length}',
        author: MealChatAuthor.user,
        text: normalized,
      ),
    );
    if (!live && _isDeferredRoutineRequest(normalized)) {
      _proposal = null;
      _messages.add(
        MealChatMessage(
          id: 'assistant-${_messages.length}',
          author: MealChatAuthor.assistant,
          text: '식사 메뉴를 다시 고르는 대화를 도와드릴게요. 식사와 관련된 요청을 말씀해 주세요.',
        ),
      );
      notifyListeners();
      return;
    }
    await _requestReply(currentMeal, normalized);
  }

  /// MVP 밖인 전체 루틴 요청을 식사 추천으로 잘못 해석하지 않도록 경계를 둔다.
  bool _isDeferredRoutineRequest(String message) {
    const deferredKeywords = [
      '가사',
      '청소',
      '빨래',
      '집안일',
      '건강',
      '운동',
      '스트레칭',
      '수면',
      '잠',
    ];
    return deferredKeywords.any(message.contains);
  }

  /// 현재 요청을 유지한 채 다른 식사 후보만 다시 받는다.
  Future<void> requestAnother() async {
    final currentMeal = _current;
    final request = _lastRequest;
    if ((!live && currentMeal == null) || request == null || _responding) {
      return;
    }
    await _requestReply(currentMeal, request);
  }

  Future<void> retry() async {
    final currentMeal = _current;
    final request = _lastRequest;
    if ((!live && currentMeal == null) || request == null || _responding) {
      return;
    }
    await _requestReply(currentMeal, request);
  }

  Future<void> _requestReply(
    MealRecommendation? currentMeal,
    String request,
  ) async {
    _responding = true;
    _errorMessage = null;
    _proposal = null;
    notifyListeners();
    try {
      final reply = await service.sendMessage(
        current: currentMeal,
        message: request,
      );
      _messages.add(
        MealChatMessage(
          id: 'assistant-${_messages.length}',
          author: MealChatAuthor.assistant,
          text: reply.message,
        ),
      );
      _proposal = reply.recommendation;
    } catch (_) {
      _errorMessage = '답변을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
    } finally {
      _responding = false;
      notifyListeners();
    }
  }

  void applyProposal() {
    final value = _proposal;
    if (value == null) return;
    store.applyRecommendation(value);
  }
}
