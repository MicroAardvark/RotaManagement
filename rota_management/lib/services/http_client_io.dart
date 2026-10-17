import 'package:http/http.dart' as http;

/// Non-web builds. The app is web-only for now; on mobile the session
/// cookie would need a cookie jar or a return to Bearer tokens.
http.Client createHttpClient() => http.Client();
