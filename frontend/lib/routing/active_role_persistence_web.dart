// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

String _key(String accountId) =>
    'plm.activeRole.v2.${Uri.encodeComponent(accountId)}';

String? readActiveRole(String accountId) {
  try {
    return html.window.localStorage[_key(accountId)];
  } on Object {
    return null;
  }
}

void writeActiveRole(String accountId, String role) {
  try {
    html.window.localStorage[_key(accountId)] = role;
  } on Object {
    // 브라우저 저장소가 막혀도 현재 세션의 역할은 유지한다.
  }
}
