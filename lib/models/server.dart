import 'device.dart';

class Server {
  final String id;
  final String name;
  final String description;
  final List<int> ip;
  final int port;
  final String secret;
  final String pin;
  List<Device> devices; // Removed final to allow setting/updating

  Server({
    required this.id,
    required this.name,
    required this.description,
    required this.ip,
    required this.port,
    required this.secret,
    required this.pin,
    List<Device>? devices,
  }) : this.devices = devices ?? []; // Use a mutable list by default

  String get ipAddress => ip.join('.');

  factory Server.fromFirestore(Map<String, dynamic> data, String id) {
    return Server(
      id: id,
      name: data['name'] as String? ?? 'Unnamed Server',
      description: data['description'] as String? ?? '',
      ip: (data['ip'] as List<dynamic>?)?.cast<int>() ?? [0, 0, 0, 0],
      port: data['port'] as int? ?? 8088,
      secret: data['secret'] as String? ?? '',
      pin: data['pin'] as String? ?? '',
      devices: [],
    );
  }

  void setDevices(List<Device> newDevices) {
    devices = newDevices;
  }
}
