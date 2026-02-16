
import 'package:cloud_firestore/cloud_firestore.dart';

enum DeviceStatus { online, offline }

class Device {
  final String uuid;
  final String name;
  final String description;
  final bool isNew;
  final status = DeviceStatus.online;
  final isPoweredOn = true;
  final isMotionDetectionEnabled = true;



  Device({
    required this.uuid,
    required this.name,
    required this.description,
    required this.isNew,
  });

  factory Device.fromMap(Map<String, dynamic> data) {
    return Device(
      uuid: data['uuid'],
      name: data['name'],
      description: data['description'],
      isNew: data['is_new'],
    );
  }
}
