import '../../../core/network/api_client.dart';
import '../models/home_week_context.dart';
import 'home_week_service.dart';

class ApiHomeWeekService implements HomeWeekService {
  ApiHomeWeekService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<HomeWeekContext> fetch() async {
    final response = await _client.get('/api/v1/routine/home');
    if (response == null) {
      throw const FormatException('주차별 안내 응답이 없습니다.');
    }
    return HomeWeekContext.fromJson(response);
  }
}
