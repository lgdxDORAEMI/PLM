import '../../../core/network/api_client.dart';
import '../../routine/models/daily_routine.dart';
import '../../routine/services/api_routine_service.dart';
import '../models/body_care_guide.dart';
import 'health_guide_service.dart';

class ApiHealthGuideService implements HealthGuideService {
  ApiHealthGuideService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<void> setStatus(String itemId, HealthExecutionStatus status) async {
    final routineStatus = switch (status) {
      HealthExecutionStatus.completed => RoutineStatus.completed,
      HealthExecutionStatus.skipped => RoutineStatus.skipped,
      HealthExecutionStatus.scheduled => RoutineStatus.scheduled,
    };
    final previous = ApiRoutineService.updateCachedItemStatus(
      itemId,
      routineStatus,
    );
    // 루틴 재생성 직후 새 항목(예: health:whole)이 홈 캐시에 없으면
    // 오래된 진행도를 재사용하지 않고 홈 진입 시 서버에서 다시 읽는다.
    if (previous == null) ApiRoutineService.invalidateCache();
    try {
      await _client.put(
        '/api/v1/care/routine-items/${Uri.encodeComponent(itemId)}/execution',
        {'status': status.name},
      );
    } on Object {
      if (previous != null) {
        ApiRoutineService.updateCachedItemStatus(itemId, previous);
      }
      rethrow;
    }
  }

  @override
  Future<BodyCareGuideData> fetchGuide() async {
    final response = await _client.get(
      '/api/v1/health/today',
      throwOnNotFound: true,
    );
    return response == null
        ? const BodyCareGuideData(loads: [], activities: [])
        : BodyCareGuideData.fromJson(response);
  }
}
