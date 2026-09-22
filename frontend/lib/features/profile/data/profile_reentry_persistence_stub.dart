final _pendingAccounts = <String>{};
final _pendingRoutineAccounts = <String>{};

bool readProfileReentry(String accountId) =>
    _pendingAccounts.contains(accountId);

void writeProfileReentry(String accountId, bool required) {
  if (required) {
    _pendingAccounts.add(accountId);
  } else {
    _pendingAccounts.remove(accountId);
  }
}

bool readResetRoutinePending(String accountId) =>
    _pendingRoutineAccounts.contains(accountId);

void writeResetRoutinePending(String accountId, bool pending) {
  if (pending) {
    _pendingRoutineAccounts.add(accountId);
  } else {
    _pendingRoutineAccounts.remove(accountId);
  }
}
