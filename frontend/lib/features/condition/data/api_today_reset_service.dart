import '../../../core/network/api_client.dart';

/// Resets the authenticated wife's current KST day through the backend.
class ApiTodayResetService {
  ApiTodayResetService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> reset() async {
    final result = await _client.post('/api/v1/care/today/reset');
    if (result?['reset'] != true) {
      throw const FormatException('오늘 기록 초기화 응답이 올바르지 않습니다.');
    }
  }
}
