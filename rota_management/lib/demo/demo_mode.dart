/// True when the app was built with --dart-define=DEMO=true.
///
/// A demo build never talks to a real server: ApiService sends every
/// request to [DemoBackend], an in-memory fake of the Node API filled
/// with made-up data. Nothing is saved, and a page refresh starts again.
const bool isDemo = bool.fromEnvironment('DEMO');
