import 'package:permission_handler/permission_handler.dart';

import 'media_store_service.dart';

enum MediaPermissionState { granted, denied, permanentlyDenied }

/// Handles READ_MEDIA_AUDIO (Android 13+) / READ_EXTERNAL_STORAGE (Android 12 and below)
/// and POST_NOTIFICATIONS (Android 13+).
class PermissionService {
  PermissionService({MediaStoreService? store}) : _store = store ?? MediaStoreService();

  final MediaStoreService _store;
  int? _sdkInt;

  Future<int> _sdk() async {
    final int? cached = _sdkInt;
    if (cached != null) return cached;
    final int fresh = await _store.getSdkInt();
    _sdkInt = fresh;
    return fresh;
  }

  Future<Permission> _audioPermission() async {
    final int sdk = await _sdk();
    return sdk >= 33 ? Permission.audio : Permission.storage;
  }

  MediaPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MediaPermissionState.granted;
    if (status.isPermanentlyDenied) return MediaPermissionState.permanentlyDenied;
    return MediaPermissionState.denied;
  }

  Future<MediaPermissionState> status() async {
    final Permission permission = await _audioPermission();
    return _map(await permission.status);
  }

  Future<MediaPermissionState> request() async {
    final Permission permission = await _audioPermission();
    final PermissionStatus result = await permission.request();

    // Needed on Android 13+ so the media notification is visible.
    final int sdk = await _sdk();
    if (sdk >= 33) {
      try {
        await Permission.notification.request();
      } catch (_) {
        // Notification permission is optional for playback itself.
      }
    }
    return _map(result);
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
