// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

const _fontSizeStorageKey = 'plm.preference.font-size.v1';

String? readStoredFontSize() {
  try {
    return html.window.localStorage[_fontSizeStorageKey];
  } on Object {
    return null;
  }
}

void writeStoredFontSize(String? value) {
  try {
    if (value == null) {
      html.window.localStorage.remove(_fontSizeStorageKey);
    } else {
      html.window.localStorage[_fontSizeStorageKey] = value;
    }
  } on Object {
    // 저장소 접근이 제한돼도 현재 세션의 글자 크기는 계속 유지한다.
  }
}
