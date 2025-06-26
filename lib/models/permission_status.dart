/// Defines the status of a permission request.
enum PermissionStatus {
  /// The user has granted access to the requested feature.
  granted,

  /// The user has denied access to the requested feature.
  denied,

  /// The user has denied access and selected "Don't ask again" (on Android)
  /// or access is restricted by the system.
  permanentlyDenied,
}
