import 'package:flutter/widgets.dart';

/// App-wide [RouteObserver] singleton. Registered on the [GoRouter] in
/// [appRouter] via its `observers:` list. Widgets that need
/// [RouteAware] callbacks (e.g., the matrix-rain home background that
/// pauses its ticker when the user navigates away) subscribe via
/// `routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute)`
/// inside `didChangeDependencies` and unsubscribe in `dispose`.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();
