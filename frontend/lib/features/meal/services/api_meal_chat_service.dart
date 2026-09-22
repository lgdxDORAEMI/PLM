import '../../../core/network/api_client.dart';
import '../models/meal_chat_message.dart';
import '../models/meal_guide.dart';
import 'meal_chat_service.dart';

/// Connects the chat screen to the authenticated backend conversation.
class ApiMealChatService implements MealChatService {
  ApiMealChatService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  String? routineItemId;

  @override
  Future<List<MealChatMessage>> fetchHistory() async {
    final rows = await _client.getList('/api/v1/chat/messages');
    if (rows == null) throw const FormatException('대화 이력을 불러오지 못했어요.');
    return rows
        .whereType<Map>()
        .where((row) {
          return row['routine_item_id'] == routineItemId;
        })
        .map((row) {
          final id = row['message_id']?.toString();
          final role = row['role']?.toString();
          final content = row['content']?.toString();
          if (id == null ||
              content == null ||
              (role != 'user' && role != 'assistant')) {
            throw const FormatException('대화 이력 형식이 올바르지 않습니다.');
          }
          return MealChatMessage(
            id: id,
            author: role == 'user'
                ? MealChatAuthor.user
                : MealChatAuthor.assistant,
            text: content,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<MealChatReply> sendMessage({
    required MealRecommendation? current,
    required String message,
  }) async {
    final response = await _client.post('/api/v1/chat/messages', {
      'content': message,
      if (routineItemId != null) 'routine_item_id': routineItemId,
    });
    final content = response?['content'];
    if (response?['role'] != 'assistant' ||
        content is! String ||
        content.isEmpty) {
      throw const FormatException('챗봇 응답 형식이 올바르지 않습니다.');
    }
    return MealChatReply(message: content);
  }
}
