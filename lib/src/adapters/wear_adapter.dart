import '../core/models.dart';
import '../core/consent_manager.dart';

abstract class WearAdapter {
  String get id;
  Set<PermissionType> get supportedPermissions;

  /// Get permissions that are actually supported on the current platform
  /// Default implementation returns all supportedPermissions
  /// Override in adapters that have platform-specific limitations
  Set<PermissionType> getPlatformSupportedPermissions() {
    return supportedPermissions;
  }

  Future<void> ensurePermissions();
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = true,
    DateTime? startTime,
    DateTime? endTime,
  });
}
