import 'package:flutter/foundation.dart';

import 'active_role_persistence.dart';

enum ActiveRole { wife, husband }

/// ThinQ 인증 어댑터가 제공할 계정 및 역할 접근권. 표시 역할과 독립적이다.
class AuthSessionStore extends ChangeNotifier {
  AuthSessionStore._();

  static final instance = AuthSessionStore._();

  // ThinQ 연동 전의 로컬 시연 계정. 실제 인증 결과로 교체해야 한다.
  // String? _accountId = 'demo-wife';
  // Set<ActiveRole> _roles = {ActiveRole.wife};
  // bool _husbandLinked = false;

  // 남편 계정이 연결되어 있으면 남편 역할을 허용한다. 실제 인증 결과로 교체해야 한다.
  String? _accountId = 'demo-husband';
  Set<ActiveRole> _roles = {ActiveRole.husband};
  bool _husbandLinked = true;

  String? get accountId => _accountId;
  bool get isAuthenticated => _accountId != null;
  bool get husbandLinked => _husbandLinked;
  Set<ActiveRole> get roles => Set.unmodifiable(_roles);

  /// 계정 또는 연결 상태 변경 시 route guard가 최신 권한을 읽도록 갱신한다.
  void update({
    required String? accountId,
    required Set<ActiveRole> roles,
    required bool husbandLinked,
  }) {
    _accountId = accountId;
    _roles = Set.of(roles);
    _husbandLinked = husbandLinked;
    ActiveRoleStore.instance.restoreFor(this);
    notifyListeners();
  }

  bool canAccess(ActiveRole role) =>
      isAuthenticated &&
      _roles.contains(role) &&
      (role != ActiveRole.husband || _husbandLinked);
}

/// 계정과 별도로 유지되는 현재 표시 역할. 계정별 저장값은 매번 권한 검증한다.
class ActiveRoleStore extends ChangeNotifier {
  ActiveRoleStore._();

  static final instance = ActiveRoleStore._();

  ActiveRole? _value;
  ActiveRole? get value => _value;

  void restoreFor(AuthSessionStore auth) {
    final accountId = auth.accountId;
    if (accountId == null) {
      _set(null);
      return;
    }
    final saved = switch (readActiveRole(accountId)) {
      'wife' => ActiveRole.wife,
      'husband' => ActiveRole.husband,
      _ => null,
    };
    final next = saved != null && auth.roles.contains(saved)
        ? saved
        : auth.roles.length == 1
        ? auth.roles.first
        : null;
    _set(next);
  }

  bool switchTo(ActiveRole role, AuthSessionStore auth) {
    if (!auth.canAccess(role)) return false;
    _set(role);
    writeActiveRole(auth.accountId!, role.name);
    return true;
  }

  void _set(ActiveRole? role) {
    if (_value == role) return;
    _value = role;
    notifyListeners();
  }
}
