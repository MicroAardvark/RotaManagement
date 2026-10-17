import 'package:flutter/foundation.dart';

/// The logged-in user, from GET /api/auth/me.
class CurrentUser {
  final String id;
  final String name;
  final String email;
  final String role;

  /// True for the hidden owner/support account.
  final bool isOwner;

  /// Changes whenever the profile photo changes; null when there's none.
  final String? photoVersion;

  const CurrentUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isOwner = false,
    this.photoVersion,
  });

  bool get isManager => role == 'manager';

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'employee',
      isOwner: json['isOwner'] == true,
      photoVersion: json['photoVersion'] as String?,
    );
  }
}

/// Holds the current user so widgets like the top bar can rebuild when
/// it changes (log in, log out, new profile photo).
class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  CurrentUser? _user;
  CurrentUser? get user => _user;

  void setUser(CurrentUser? user) {
    _user = user;
    notifyListeners();
  }

  void clear() => setUser(null);
}
