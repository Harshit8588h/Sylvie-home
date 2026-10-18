class SylvieConstants {
  SylvieConstants._();

  static const String appName = 'Sylvie';
  static const String appTagline = 'Ghar jaisi safety';

  // Default geofence radius for a new "home" zone.
  static const double defaultHomeRadiusMeters = 100;

  // Minimum battery level before family is warned.
  static const int lowBatteryThreshold = 20;

  // Phone-offline watchdog: if no ping for this long, raise an alert.
  static const Duration phoneOfflineThreshold = Duration(minutes: 15);

  // Minimum movement before a background location update is pushed.
  static const double locationUpdateDistanceMeters = 50;
}
