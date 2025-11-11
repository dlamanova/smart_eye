class DeviceModel {
  final String id;
  final String name;
  final String ownerId;
  final bool isOnline; 
  // --- New States ---
  final bool isPoweredOn;
  final bool isMotionDetectionEnabled;

  DeviceModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.isOnline = false,
    this.isPoweredOn = false, // Default to off/false
    this.isMotionDetectionEnabled = false, // Default to off/false
  });

  /// Factory constructor to create a DeviceModel from a Firestore document.
  factory DeviceModel.fromFirestore(Map<String, dynamic> data, String id) {
    return DeviceModel(
      id: id,
      name: data['name'] as String? ?? 'Unnamed Device',
      ownerId: data['owner'] as String? ?? '',
      isOnline: data['isOnline'] as bool? ?? false,
      // Map new fields
      isPoweredOn: data['isPoweredOn'] as bool? ?? false,
      isMotionDetectionEnabled: data['isMotionDetectionEnabled'] as bool? ?? false,
    );
  }
}