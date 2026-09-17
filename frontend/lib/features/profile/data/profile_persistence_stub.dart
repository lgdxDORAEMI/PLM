import '../models/profile_draft.dart';

/// Web가 아닌 테스트 환경에서는 영구 저장소 없이 Store 메모리 상태만 사용한다.
ProfileDraft? readStoredProfile() => null;

void writeStoredProfile(ProfileDraft? profile) {}
