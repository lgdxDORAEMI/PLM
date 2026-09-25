import '../../../core/network/api_client.dart';
import '../../routine/services/api_routine_service.dart';
import 'api_condition_repository.dart';

/// Resets the authenticated wife's current KST day through the backend.
class ApiTodayResetService {
  ApiTodayResetService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> reset() async {
    final result = await _client.post('/api/v1/care/today/reset');
    if (result?['reset'] != true) {
      throw const FormatException('오늘 기록 초기화 응답이 올바르지 않습니다.');
    }
    // 서버에서 그날 기록이 사라졌으므로 들고 있던 응답도 버린다.
    ApiConditionRepository.forgetCache();
    ApiRoutineService.invalidateCache();
  }
}
