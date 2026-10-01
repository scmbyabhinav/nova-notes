import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> orahNavigatorKey = GlobalKey<NavigatorState>();

/// Refreshes list screens when a pushed route closes.
final RouteObserver<PageRoute<dynamic>> orahRouteObserver = RouteObserver<PageRoute<dynamic>>();
