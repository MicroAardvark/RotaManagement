import 'package:flutter/widgets.dart';

/// Lets ApiService send the user to the login screen when their session
/// ends, without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
