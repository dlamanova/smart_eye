import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/fb_service.dart';

class RegisterServerScreen extends StatefulWidget {
  const RegisterServerScreen({Key? key}) : super(key: key);

  @override
  State<RegisterServerScreen> createState() => _RegisterServerScreenState();
}

class _RegisterServerScreenState extends State<RegisterServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _secretController = TextEditingController();
  final _portController = TextEditingController();
  final _pinController = TextEditingController();
  final _ipController1 = TextEditingController();
  final _ipController2 = TextEditingController();
  final _ipController3 = TextEditingController();
  final _ipController4 = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _secretController.dispose();
    _portController.dispose();
    _pinController.dispose();
    _ipController1.dispose();
    _ipController2.dispose();
    _ipController3.dispose();
    _ipController4.dispose();
    super.dispose();
  }

  Future<void> _registerServer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final ip = [
        int.parse(_ipController1.text),
        int.parse(_ipController2.text),
        int.parse(_ipController3.text),
        int.parse(_ipController4.text),
      ];

      final port = int.parse(_portController.text);
      final firebaseService = Provider.of<FBService>(context, listen: false);

      await firebaseService.addServer(
        _nameController.text.trim(),
        _descriptionController.text.trim(),
        ip,
        port,
        _secretController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Server registered successfully'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context); // Go back to Devices screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error registering server: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Enhanced Header with animated gradient - matching Preferences/DevicesScreen
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
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Register Server',
                      style: TextStyle(
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
                      child: const Text(
                        'Enter your Janus Gateway configuration',
                        style: TextStyle(
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

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _buildTextField(
                        controller: _nameController,
                        label: 'Server Name',
                        icon: Icons.dns,
                        theme: theme,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Description
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        icon: Icons.description,
                        theme: theme,
                        validator: (v) => v?.isEmpty == true
                            ? 'Description is required'
                            : null,
                      ),
                      const SizedBox(height: 32),

                      // IP Address
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'IP Address',
                          style: theme.inputDecorationTheme.labelStyle
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _buildIpOctetField(_ipController1, theme),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            _buildIpOctetField(_ipController2, theme),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            _buildIpOctetField(_ipController3, theme),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            _buildIpOctetField(_ipController4, theme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Port
                      _buildTextField(
                        controller: _portController,
                        label: 'Port',
                        icon: Icons.settings_input_component,
                        keyboardType: TextInputType.number,
                        theme: theme,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Port is required';
                          final p = int.tryParse(v);
                          if (p == null || p < 1 || p > 65535)
                            return 'Invalid port';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Secret
                      _buildTextField(
                        controller: _secretController,
                        label: 'API Secret / Token',
                        icon: Icons.security,
                        obscureText: true,
                        theme: theme,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Secret is required' : null,
                      ),
                      const SizedBox(height: 16),
                      // PIN
                      _buildTextField(
                        controller: _pinController,
                        label: 'PIN',
                        icon: Icons.lock,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        theme: theme,
                        validator: (v) =>
                            v?.isEmpty == true ? 'PIN is required' : null,
                      ),
                      const SizedBox(height: 100), // Padding for bottom button
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Fixed Register Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Register Server',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12),
              child: Text(
                label,
                style: theme.inputDecorationTheme.labelStyle?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextFormField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: validator,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpOctetField(TextEditingController controller, ThemeData theme) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: theme.textTheme.bodyLarge?.color),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        validator: (v) {
          if (v == null || v.isEmpty) return '';
          final n = int.tryParse(v);
          if (n == null || n < 0 || n > 255) return '';
          return null;
        },
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: '000',
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
