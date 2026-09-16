import '../../../routing/route_context.dart';

/// ThinQ session/domain 조회를 UI와 분리하는 Bootstrap 계약이다.
abstract interface class EntryService {
  Future<AppLaunchState> resolveLaunchState();
}
