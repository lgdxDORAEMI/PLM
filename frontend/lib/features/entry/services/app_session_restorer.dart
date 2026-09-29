import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../routing/app_session.dart';
import 'api_entry_service.dart';
import 'entry_service.dart';

/// Restores the backend account state before the initial route is resolved.
///
/// Supabase persists its session on web. Loading the account role here keeps a
/// refreshed husband deep link from being guarded to the wife entry flow.
class AppSessionRestorer {
  const AppSessionRestorer({this.service});

  final EntryService? service;

  Future<void> restore({bool? hasPersistedSession}) async {
    AuthSessionStore.instance.update(
      accountId: null,
      roles: {},
      husbandLinked: false,
    );

    final hasSession =
        hasPersistedSession ??
        Supabase.instance.client.auth.currentSession != null;
    if (!hasSession) return;

    try {
      await (service ?? ApiEntryService()).resolveLaunchState();
    } catch (_) {
      // EntryScreen retries bootstrap and shows its existing recovery UI.
    }
  }
}
