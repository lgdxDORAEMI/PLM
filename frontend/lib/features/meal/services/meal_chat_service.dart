import '../models/meal_chat_message.dart';
import '../models/meal_guide.dart';

/// Chat UI와 실제 AI 공급자 사이를 분리하는 식사 재조정 계약이다.
abstract interface class MealChatService {
  Future<List<MealChatMessage>> fetchHistory();

  Future<MealChatReply> sendMessage({
    required MealRecommendation? current,
    required String message,
  });
}
