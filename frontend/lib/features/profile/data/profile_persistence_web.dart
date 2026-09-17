import 'dart:convert';
import 'dart:html' as html;

import '../models/profile_draft.dart';

const _profileStorageKey = 'plm.demo.profile.v1';

/// Demo Profile을 브라우저에 보존해 새로고침 후에도 Returning User를 판별한다.
ProfileDraft? readStoredProfile() {
  try {
    final value = html.window.localStorage[_profileStorageKey];
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    return ProfileDraft(
      dueDate: _readDate(json['dueDate']),
      lastPeriodDate: _readDate(json['lastPeriodDate']),
      birthDate: _readDate(json['birthDate']),
      height: json['height'] as String?,
      prePregnancyWeight: json['prePregnancyWeight'] as String?,
      isFirstPregnancy: json['isFirstPregnancy'] as bool?,
      isMultiplePregnancy: json['isMultiplePregnancy'] as bool?,
      allergies: _readSet(json['allergies']),
      medicalConditions: _readSet(json['medicalConditions']),
      medicalNote: json['medicalNote'] as String? ?? '',
    );
  } on Object {
    return null;
  }
}

/// 완료 또는 편집된 Demo Profile을 저장하고 null이면 시연 상태를 초기화한다.
void writeStoredProfile(ProfileDraft? profile) {
  try {
    if (profile == null) {
      html.window.localStorage.remove(_profileStorageKey);
      return;
    }
    html.window.localStorage[_profileStorageKey] = jsonEncode({
      'dueDate': profile.dueDate?.toIso8601String(),
      'lastPeriodDate': profile.lastPeriodDate?.toIso8601String(),
      'birthDate': profile.birthDate?.toIso8601String(),
      'height': profile.height,
      'prePregnancyWeight': profile.prePregnancyWeight,
      'isFirstPregnancy': profile.isFirstPregnancy,
      'isMultiplePregnancy': profile.isMultiplePregnancy,
      'allergies': profile.allergies.toList(),
      'medicalConditions': profile.medicalConditions.toList(),
      'medicalNote': profile.medicalNote,
    });
  } on Object {
    // 저장소 접근이 제한돼도 현재 세션의 메모리 Demo는 계속 사용할 수 있다.
  }
}

DateTime? _readDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

Set<String> _readSet(Object? value) =>
    value is List ? value.whereType<String>().toSet() : const <String>{};
