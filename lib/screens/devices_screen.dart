import 'dart:core';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/server.dart'; // Import server model
import '../models/notification.dart';
import '../services/firebase_service.dart';
import '../services/fb_service.dart'; // Import ApiService from fb_service.dart
import '../core/theme_provider.dart';
import 'add_device_screen.dart'; // Import AddDeviceScreen to navigate with arguments
import '../services/server_service.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with SingleTickerProviderStateMixin {

  final _firebaseService = FirebaseService();
  final _serverService = ServerService();
  final _apiService = FBService();

  // Cache for faster loading
  List<Server>? _cachedServers;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Load servers first, then devices in background
  Future<void> _loadInitialData() async {
    try {
      // Load servers quickly
      final rawServers = await _apiService.getServers()
          .timeout(const Duration(seconds: 10));
      final servers = _mapToServers(rawServers);

      if (mounted) {
        setState(() {
          _cachedServers = servers;
        });
      }

      // Load devices in background
      await _loadDevicesForServers(servers);
    } catch (e) {
      debugPrint('Error in _loadInitialData: $e');
    }
  }

  /// Load devices for all servers
  Future<void> _loadDevicesForServers(List<Server> servers) async {
    await Future.wait(
      servers.map((server) async {
        try {
          // Set server ID first
          await _serverService.setServerId(server.ip, server.port, server.id);

          final cameraData = await _serverService
              .getCameras(server.ip, server.port)
              .timeout(const Duration(seconds: 5));

          final cameras = cameraData.map((data) => Device.fromMap(data)).toList();
          server.setDevices(cameras);

          if (mounted) setState(() {}); // Update UI as each server loads
        } catch (e) {
          debugPrint('Error loading devices for ${server.name}: $e');
          server.setDevices([]);
        }
      }),
      eagerError: false,
    );
  }

  /// Converts the raw API data (List of Maps) to a List of Server models.
  List<Server> _mapToServers(List<Map<String, dynamic>> rawData) {
    return rawData.map((data) {
      // Parse IP and port first as they will be used as fallback
      final List<int> ipList = (data['ip'] as List<dynamic>?)?.cast<int>() ?? [0, 0, 0, 0];
      final int port = data['port'] as int? ?? 5000;
      final String ipAddress = ipList.join('.');

      return Server(
        id: data['document_id'],
        name: data['name'] ?? 'Unnamed Server',
        description: data['description'] ?? '',
        ip: ipList,
        port: port,
        secret: data['secret'] ?? '',
        pin: data['pin']?.toString() ?? '',
        devices: [],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = _firebaseService.currentUser;
    final displayName = currentUser?.displayName ?? 'User';

    // Use cached data if available
    if (_cachedServers == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final displayServers = _cachedServers!;

    // Calculate stats
    int activeCameras = 0;
    int totalCameras = 0;

    for (var server in displayServers) {
      totalCameras += server.devices.length;
      activeCameras += server.devices
          .where((d) => d.status == DeviceStatus.online)
          .length;
    }

    return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D9488), // teal-600
                      Color(0xFF14B8A6), // teal-500
                      Color(0xFF06B6D4), // cyan-500
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.remove_red_eye_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            // Notifications button
                            StreamBuilder<List<NotificationItem>>(
                              stream: _firebaseService.streamNotifications(),
                              builder: (context, notifSnapshot) {
                                final hasUnread = notifSnapshot.hasData && notifSnapshot.data!.any((n) => !n.isRead);
                                return IconButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/notifications');
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const Icon(
                                          Icons.notifications_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        if (hasUnread)
                                          Positioned(
                                            right: -4,
                                            top: -4,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            // Dark mode toggle
                            IconButton(
                              onPressed: () {
                                themeProvider.toggleTheme(!isDark);
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isDark ? Icons.light_mode : Icons.dark_mode,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Preferences
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/preferences');
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Hi, $displayName!',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$activeCameras of $totalCameras cameras active',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFE0F2FE),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: displayServers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No servers found'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register-server');
                              },
                              child: const Text('Register Server'),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: displayServers.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _ServerCard(
                              server: displayServers[index],
                              onAddDevice: () {
                                // Navigate to AddDeviceScreen with the specific server
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddDeviceScreen(
                                      preSelectedServer: displayServers[index],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              // Bottom Action Buttons
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0D9488),
                            Color(0xFF14B8A6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register-server');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Register Server',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

class _ServerCard extends StatefulWidget {
  final Server server;
  final VoidCallback onAddDevice;

  const _ServerCard({
    Key? key,
    required this.server,
    required this.onAddDevice,
  }) : super(key: key);

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Server Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.dns_outlined,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.server.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.server.ipAddress,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Devices List
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                // Show devices if any, assuming they are populated on the server object
                if (widget.server.devices.isEmpty)
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text("No devices", style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                   )
                else
                   ...widget.server.devices.map((device) => _DeviceItem(device: device, serverId: widget.server.id)).toList(),

                // Add Device Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton.icon(
                    onPressed: widget.onAddDevice,
                    icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                    label: Text(
                      'Add Device to ${widget.server.name}',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _DeviceItem extends StatelessWidget {
  final Device device;
  final String serverId;

  const _DeviceItem({Key? key, required this.device , required this.serverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOnline = device.status == DeviceStatus.online;

    return InkWell(
      onTap: () {
        debugPrint('_DeviceItem: Navigating to monitoring with serverId="$serverId", deviceId="${device.uuid}"');
        if (serverId.isEmpty) {
          debugPrint('ERROR: Attempting to navigate with EMPTY serverId!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Server ID is missing. Cannot connect to stream.')),
          );
          return;
        }
        Navigator.pushNamed(context, '/monitoring/$serverId/${device.uuid}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.videocam_outlined,
              size: 20,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                device.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
