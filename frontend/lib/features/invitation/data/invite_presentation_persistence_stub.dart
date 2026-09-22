final _acknowledgedAccounts = <String>{};

bool readInviteAcknowledged(String accountId) =>
    _acknowledgedAccounts.contains(accountId);

void writeInviteAcknowledged(String accountId) =>
    _acknowledgedAccounts.add(accountId);

void clearInviteAcknowledged(String accountId) =>
    _acknowledgedAccounts.remove(accountId);
