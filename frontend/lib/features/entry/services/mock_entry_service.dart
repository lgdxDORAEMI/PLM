import '../../../routing/route_context.dart';
import '../../profile/data/profile_store.dart';
import 'entry_service.dart';

/// 실제 ThinQ 세션 연동 전 사용하는 결정 가능한 로컬 Bootstrap 구현이다.
class MockEntryService implements EntryService {
  const MockEntryService({this.state});

  final AppLaunchState? state;

  @override
  Future<AppLaunchState> resolveLaunchState() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return state ??
        (ProfileStore.instance.hasProfile
            ? AppLaunchState.wifeReady
            : AppLaunchState.wifeNeedsProfile);
  }
}
