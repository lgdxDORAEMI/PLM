final _pendingAccounts = <String>{};

bool readProfileReentry(String accountId) =>
    _pendingAccounts.contains(accountId);

void writeProfileReentry(String accountId, bool required) {
  if (required) {
    _pendingAccounts.add(accountId);
  } else {
    _pendingAccounts.remove(accountId);
  }
}
