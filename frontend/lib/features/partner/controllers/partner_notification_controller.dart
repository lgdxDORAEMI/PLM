import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/partner_notification.dart';
import '../services/partner_notification_service.dart';

enum PartnerNotificationViewState {
  loading,
  data,
  empty,
  authError,
  domainError,
  serverError,
  error,
}

class PartnerNotificationController extends ChangeNotifier {
  PartnerNotificationController({required this.service});

  final PartnerNotificationService service;
  PartnerNotificationViewState _state = PartnerNotificationViewState.loading;
  List<PartnerNotificationItem> _items = const [];

  PartnerNotificationViewState get state => _state;
  List<PartnerNotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((item) => !item.read).length;

  Future<void> load() async {
    _state = PartnerNotificationViewState.loading;
    notifyListeners();
    try {
      _items = await service.fetchAll();
      _state = _items.isEmpty
          ? PartnerNotificationViewState.empty
          : PartnerNotificationViewState.data;
    } on ApiException catch (error) {
      _state = _errorState(error.statusCode);
    } on Object {
      _state = PartnerNotificationViewState.error;
    }
    notifyListeners();
  }

  Future<bool> markRead(String id) async {
    try {
      final updated = await service.markRead(id);
      _items = [
        for (final item in _items)
          if (item.id == id) updated else item,
      ];
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _state = _errorState(error.statusCode);
    } on Object {
      _state = PartnerNotificationViewState.error;
    }
    notifyListeners();
    return false;
  }

  Future<void> markAllRead() async {
    for (final item in _items.where((item) => !item.read).toList()) {
      if (!await markRead(item.id)) return;
    }
  }

  PartnerNotificationViewState _errorState(int statusCode) =>
      switch (statusCode) {
        401 || 403 => PartnerNotificationViewState.authError,
        409 || 422 => PartnerNotificationViewState.domainError,
        503 => PartnerNotificationViewState.serverError,
        _ => PartnerNotificationViewState.error,
      };
}
