import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// A person's profile photo, or their initial when they have none.
/// The image request carries the session cookie automatically because
/// it's the same origin as the app.
class StaffAvatar extends StatelessWidget {
  final String id;
  final String name;
  final String? photoVersion;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const StaffAvatar({
    super.key,
    required this.id,
    required this.name,
    this.photoVersion,
    this.radius = 16,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final version = photoVersion;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      foregroundImage: version == null ? null : NetworkImage(ApiService.photoUrl(id, version)),
      // Falls back to the initial quietly if the photo can't load
      onForegroundImageError: version == null ? null : (error, stackTrace) {},
      // Shown while the photo loads, or if it fails
      child: Text(initial, style: TextStyle(fontSize: radius * 0.8)),
    );
  }
}
