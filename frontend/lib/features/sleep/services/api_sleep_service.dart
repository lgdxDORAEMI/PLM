import '../../../core/network/api_client.dart';
import '../models/sleep_guide.dart';
import 'sleep_service.dart';

/// Reads the sleep guide generated for today's routine.
class ApiSleepService implements SleepService {
  ApiSleepService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<void> updateEnvironment(
    String itemId,
    Map<String, dynamic> values,
  ) async {
    await _client.put(
      '/api/v1/care/routine-items/${Uri.encodeComponent(itemId)}/sleep-environment',
      values,
    );
  }

  @override
  Future<void> setCompleted(String itemId, bool completed) async {
    await _client.put(
      '/api/v1/care/routine-items/${Uri.encodeComponent(itemId)}/execution',
      {'status': completed ? 'completed' : 'scheduled'},
    );
  }

  @override
  Future<String?> findAirPurifierDeviceId() async {
    final response = await _client.get('/api/v1/thinq/devices');
    final devices = response?['devices'];
    if (devices is! List) return null;
    for (final device in devices.whereType<Map>()) {
      if (device['device_type'] == 'air_purifier') {
        return device['device_id']?.toString();
      }
    }
    return null;
  }

  @override
  Future<bool> controlAirPurifier(
    String deviceId, {
    required String power,
    String? windStrength,
  }) async {
    try {
      await _client.post(
        '/api/v1/thinq/devices/${Uri.encodeComponent(deviceId)}/control',
        {'power': power, 'wind_strength': ?windStrength},
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  @override
  Future<SleepGuideData> fetchGuide() async {
    final response = await _client.get(
      '/api/v1/sleep/today',
      throwOnNotFound: true,
    );
    final items = response?['items'];
    if (items is! List || items.isEmpty || items.first is! Map) {
      return const SleepGuideData(
        summaryTitle: '',
        summary: '',
        recommendedBedtime: '',
        environments: [],
        tips: [],
      );
    }
    final item = items.first as Map;
    final payload = item['payload'];
    final details = payload is Map ? payload : const {};
    final environments = details['environments'];
    return SleepGuideData(
      itemId: item['item_id']?.toString(),
      summaryTitle: item['title']?.toString() ?? '오늘의 수면 가이드',
      summary: details['reason']?.toString() ?? '',
      recommendedBedtime: details['recommendedBedtime']?.toString() ?? '',
      environments: environments is List
          ? environments.whereType<Map>().map((value) {
              final type = SleepEnvironmentType.values.firstWhere(
                (candidate) => candidate.name == value['type'],
                orElse: () => SleepEnvironmentType.light,
              );
              return SleepEnvironmentSetting(
                type: type,
                label: switch (type) {
                  SleepEnvironmentType.light => '조명',
                  SleepEnvironmentType.temperature => '온도',
                  SleepEnvironmentType.humidity => '습도',
                  SleepEnvironmentType.sound => '소리',
                  SleepEnvironmentType.purifier => '공기청정기',
                },
                value: value['value']?.toString() ?? '',
                options:
                    (value['options'] as List?)?.whereType<String>().toList() ??
                    const [],
              );
            }).toList()
          : const [],
      tips:
          (details['tips'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}
