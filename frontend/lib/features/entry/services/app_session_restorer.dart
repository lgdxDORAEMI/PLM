import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../routing/app_session.dart';
import '../../../routing/route_context.dart';
import 'account_session_service.dart';
import 'api_entry_service.dart';
import 'entry_service.dart';

/// Restores the backend account state before the initial route is resolved.
///
/// Supabase persists one browser session on web. The refreshed wife/husband
/// URL is reconciled with that session before route guards run.
class AppSessionRestorer {
  const AppSessionRestorer({this.service, this.switchSession});

  final EntryService? service;
  final Future<AppLaunchState> Function(ActiveRole role)? switchSession;

  Future<void> restore({
    bool? hasPersistedSession,
    String initialLocation = '/',
  }) async {
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
      final requestedRole = roleForLocation(initialLocation);
      final restoredRole = ActiveRoleStore.instance.value;
      if (requestedRole != null && restoredRole != requestedRole) {
        final switchTo = switchSession ?? AccountSessionService().switchTo;
        await switchTo(requestedRole);
      }
    } catch (_) {
      // EntryScreen retries bootstrap and shows its existing recovery UI.
    }
  }

  /// Uses the refreshed URL as the source of truth when two demo accounts
  /// have shared the same browser's persisted Supabase session.
  static ActiveRole? roleForLocation(String location) {
    final uri = Uri.tryParse(location);
    final path = uri == null
        ? ''
        : uri.fragment.startsWith('/')
        ? Uri.tryParse(uri.fragment)?.path ?? ''
        : uri.path;
    if (path.startsWith('/wife/')) return ActiveRole.wife;
    if (path.startsWith('/husband/')) return ActiveRole.husband;
    return null;
  }
}
