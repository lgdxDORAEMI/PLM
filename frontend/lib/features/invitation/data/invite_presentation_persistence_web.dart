// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

String _key(String accountId) =>
    'plm.inviteAcknowledged.v1.${Uri.encodeComponent(accountId)}';

bool readInviteAcknowledged(String accountId) {
  try {
    return html.window.localStorage[_key(accountId)] == 'true';
  } on Object {
    return false;
  }
}

void writeInviteAcknowledged(String accountId) {
  try {
    html.window.localStorage[_key(accountId)] = 'true';
  } on Object {
    // The current session still reflects the action if storage is unavailable.
  }
}

void clearInviteAcknowledged(String accountId) {
  try {
    html.window.localStorage.remove(_key(accountId));
  } on Object {
    // Keep the reset effective in memory if browser storage is unavailable.
  }
}
