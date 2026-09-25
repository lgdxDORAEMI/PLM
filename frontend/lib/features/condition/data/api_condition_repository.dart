import '../../../core/network/api_client.dart';
import '../models/condition_draft.dart';
import 'condition_repository.dart';

/// `GET/PUT /api/v1/care/conditions/{date}`(FUC-W-COND-001, `docs/backend/API_CONTRACT.md`)를
/// 호출한다. 응답 JSON 필드 이름(snake_case)만 알고, `daily_conditions` 테이블
/// 자체는 모른다 — Backend가 Repository→DB 경계를 이미 지키고 있으므로
/// Frontend는 API Response 모양만 따라가면 된다(STEP 15).
class ApiConditionRepository implements ConditionRepository {
  ApiConditionRepository(this._client);

  final ApiClient _client;

  /// 09-25: 홈이 같은 `GET /care/conditions/{date}`를 컨디션용·할 일용으로 두 번 부르고
  /// 있었다. 이 응답에 planned_activities가 이미 들어 있어 여기서 들고 있다가
  /// ApiPlannedActivityService가 재사용한다. 저장·초기화 때는 forgetCache()로 버린다.
  static String? _cachedKey;
  static List<String> _cachedActivities = const [];

  static List<String>? cachedActivities(DateTime date) =>
      _cachedKey == _key(date) ? _cachedActivities : null;

  static void forgetCache() {
    _cachedKey = null;
    _cachedActivities = const [];
  }

  @override
  Future<ConditionDraft?> fetchToday(DateTime date) async {
    final response = await _client.get('/api/v1/care/conditions/${_isoDate(date)}');
    if (response == null) {
      forgetCache();
      return null;
    }
    _cachedKey = _key(date);
    _cachedActivities =
        (response['planned_activities'] as List?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const [];
    return _fromResponse(response);
  }

  @override
  Future<void> saveToday(DateTime date, ConditionDraft draft) async {
    await _client.put('/api/v1/care/conditions/${_isoDate(date)}', {
      'nausea': draft.nausea,
      'waist_pain': draft.waistPain,
      'pelvis_pain': draft.pelvisPain,
      'leg_pain': draft.legPain,
      'wrist_pain': draft.wristPain,
      'fatigue': draft.fatigue,
      'mood': draft.mood,
    });
  }

  ConditionDraft _fromResponse(Map<String, dynamic> json) {
    return ConditionDraft(
      nausea: json['nausea'] as int,
      waistPain: json['waist_pain'] as int,
      pelvisPain: json['pelvis_pain'] as int,
      legPain: json['leg_pain'] as int,
      wristPain: json['wrist_pain'] as int,
      fatigue: json['fatigue'] as int,
      mood: json['mood'] as int,
    );
  }

  String _isoDate(DateTime date) => _key(date);

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
