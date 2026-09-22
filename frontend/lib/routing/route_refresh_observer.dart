import 'package:flutter/material.dart';

/// Lets account-linked screens refresh when they become visible again.
final RouteObserver<PageRoute<dynamic>> routeRefreshObserver =
    RouteObserver<PageRoute<dynamic>>();
