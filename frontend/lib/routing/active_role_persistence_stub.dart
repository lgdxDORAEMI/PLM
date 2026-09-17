final _rolesByAccount = <String, String>{};

String? readActiveRole(String accountId) => _rolesByAccount[accountId];

void writeActiveRole(String accountId, String role) {
  _rolesByAccount[accountId] = role;
}
