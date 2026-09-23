import '../../../core/network/api_client.dart';
import '../models/meal_chat_message.dart';
import '../models/meal_guide.dart';
import 'meal_chat_service.dart';

/// Connects the chat screen to the authenticated backend conversation.
class ApiMealChatService implements MealChatService, RoutineUpdateService {
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
            routineUpdate: _routineUpdate(row['routine_update']),
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
    return MealChatReply(
      message: content,
      routineUpdate: _routineUpdate(response?['routine_update']),
    );
  }

  @override
  Future<RoutineUpdateState> decideRoutineUpdate({
    required String jobId,
    required bool confirm,
  }) async {
    final response = await _client.post(
      '/api/v1/chat/messages/$jobId/routine-update',
      {'action': confirm ? 'confirm' : 'cancel'},
    );
    return _requiredRoutineUpdate(response);
  }

  @override
  Future<RoutineUpdateState> fetchRoutineUpdate(String jobId) async {
    final response = await _client.get(
      '/api/v1/chat/messages/$jobId/routine-update',
      throwOnNotFound: true,
    );
    return _requiredRoutineUpdate(response);
  }

  RoutineUpdateState _requiredRoutineUpdate(Object? value) {
    final parsed = _routineUpdate(value);
    if (parsed == null) {
      throw const FormatException('루틴 수정 상태 형식이 올바르지 않습니다.');
    }
    return parsed;
  }

  RoutineUpdateState? _routineUpdate(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const FormatException('루틴 수정 상태 형식이 올바르지 않습니다.');
    }
    final jobId = value['job_id']?.toString();
    final status = value['status']?.toString();
    final summary = value['summary']?.toString();
    final rawChanges = value['changes'];
    if (jobId == null ||
        status == null ||
        summary == null ||
        rawChanges is! List) {
      throw const FormatException('루틴 수정 상태 형식이 올바르지 않습니다.');
    }
    final changes = rawChanges
        .map((raw) {
          if (raw is! Map || raw['field'] is! String || raw['value'] is! num) {
            throw const FormatException('컨디션 수정값 형식이 올바르지 않습니다.');
          }
          return ConditionChange(
            field: raw['field'] as String,
            value: (raw['value'] as num).toInt(),
          );
        })
        .toList(growable: false);
    return RoutineUpdateState(
      jobId: jobId,
      status: RoutineUpdateStatus.parse(status),
      summary: summary,
      changes: changes,
      errorMessage: value['error_message']?.toString(),
      routineRevision: (value['routine_revision'] as num?)?.toInt(),
    );
  }
}
