// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

String _key(String accountId) =>
    'plm.profileReentry.v1.${Uri.encodeComponent(accountId)}';

bool readProfileReentry(String accountId) {
  try {
    return html.window.localStorage[_key(accountId)] == 'true';
  } on Object {
    return false;
  }
}

void writeProfileReentry(String accountId, bool required) {
  try {
    if (required) {
      html.window.localStorage[_key(accountId)] = 'true';
    } else {
      html.window.localStorage.remove(_key(accountId));
    }
  } on Object {
    // The in-memory flag still applies to the current session.
  }
}
