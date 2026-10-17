// Picks the right HTTP client for the platform. On web the browser
// client is told to send cookies (the session cookie), including to a
// different origin during local development.
export 'http_client_io.dart' if (dart.library.js_interop) 'http_client_web.dart';
