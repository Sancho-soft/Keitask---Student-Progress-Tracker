# keitask_management

Keitask a studnet progress tracker is at alpha stage!

## Getting Started
## Development notes
Ensure Firebase configuration files (google-services.json / GoogleService-Info.plist) are in place for Android/iOS.
Notifications:
	- The app supports FCM remote push and local notifications (via `flutter_local_notifications`).
	- NotificationService in `lib/services/notification_service.dart` centralizes initialization; it's called during app startup.
	- Test FCM push delivery by copying the user's FCM token from the Profile screen ("Copy FCM Token") and sending a test message from Firebase Console or the `functions/keitaask` Cloud Function.
	- Android 13 requires runtime permission; we use `permission_handler` and the `POST_NOTIFICATIONS` permission in `AndroidManifest.xml`.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
