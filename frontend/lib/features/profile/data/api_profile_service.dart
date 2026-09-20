import '../../../core/network/api_client.dart';
import '../models/profile_draft.dart';
import 'profile_store.dart';

/// Maps the six profile steps to the existing backend API contract.
class ApiProfileService {
  ApiProfileService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ProfileDraft?> fetch() async {
    final response = await _client.get('/api/v1/profile/me');
    if (response == null) return null;
    return ProfileDraft(
      dueDate: _date(response['due_date']),
      lastPeriodDate: _date(response['last_period_start']),
      birthDate: ProfileStore.instance.profile?.birthDate,
      height: response['height_cm']?.toString(),
      prePregnancyWeight: response['pre_pregnancy_weight_kg']?.toString(),
      isFirstPregnancy: response['is_first_pregnancy'] as bool?,
      isMultiplePregnancy: response['is_multiple_pregnancy'] as bool?,
      allergies: _strings(response['allergies']),
      medicalConditions: _strings(response['medical_conditions']),
      medicalNote: response['medical_note'] as String? ?? '',
    );
  }

  Future<void> save(ProfileDraft draft) async {
    final dueDate = draft.dueDate;
    final lastPeriod = draft.lastPeriodDate;
    await _client.put('/api/v1/profile/me/due-date', {
      if (dueDate != null) 'due_date': _isoDate(dueDate),
      if (lastPeriod != null) 'last_period_start': _isoDate(lastPeriod),
    });
    await _client.put('/api/v1/profile/me/body', {
      'height_cm': double.parse(draft.height!),
      'pre_pregnancy_weight_kg': double.parse(draft.prePregnancyWeight!),
    });
    await _client.put('/api/v1/profile/me/pregnancy-history', {
      'is_first_pregnancy': draft.isFirstPregnancy,
    });
    await _client.put('/api/v1/profile/me/pregnancy-count', {
      'is_multiple_pregnancy': draft.isMultiplePregnancy,
    });
    await _client.put('/api/v1/profile/me/allergies', {
      'allergies': draft.allergies.toList(),
    });
    await _client.put('/api/v1/profile/me/medical-notes', {
      'medical_conditions': draft.medicalConditions
          .where((value) => value != '없어요')
          .toList(),
      'medical_note': draft.medicalNote,
    });
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  Set<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toSet() : <String>{};

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
