import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/engine/engine_manager.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const OnboardingScreen({super.key, required this.onSetupComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _pathController = TextEditingController();
  bool _isStarting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _suggestDefaultPath();
  }

  void _suggestDefaultPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        (Platform.isWindows ? r'C:\SyncDrive' : '/home');
    final separator = Platform.isWindows ? r'\' : '/';
    _pathController.text = '$home${separator}CloudDrive';
  }

  Future<void> _pickDirectory() async {
    final String? selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Target Folder to Watch & Sync',
    );
    if (selectedDir != null) {
      setState(() {
        _pathController.text = selectedDir;
        _errorMessage = null;
      });
    }
  }

  Future<void> _completeSetup() async {
    final targetPath = _pathController.text.trim();
    if (targetPath.isEmpty) {
      setState(() => _errorMessage = 'Please specify a target watch directory.');
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      final engine = EngineManager();
      await engine.initialize();
      final started = await engine.start(targetPath);

      if (started) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_onboarded', true);
        if (mounted) {
          widget.onSetupComplete();
        }
      } else {
        if (mounted) {
          setState(() {
            _isStarting = false;
            _errorMessage = 'Failed to start rSync engine. Check permissions or logs.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStarting = false;
          _errorMessage = 'Error launching rSync engine: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Welcome Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.cloud_sync, color: Color(0xFF38BDF8), size: 36),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome to unicSync', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('First-time setup: configure your sync drive', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Explanation card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Your state database and cloud credentials will be stored safely inside application data (~/.local/share/unic_sync/). '
                          'Even if your watched drive is wiped or formatted, all profiles and sync state remain 100% safe.',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Target Folder Prompt
                Text('Target Folder to Watch & Sync', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Select any local folder on your computer. All files added here will be automatically synced and tiered to your cloud storage.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Directory Picker Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: Platform.isWindows ? r'C:\Users\username\CloudDrive' : '/home/user/CloudDrive',
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.folder_open, size: 20, color: Color(0xFF38BDF8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                      label: const Text('Browse'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _pickDirectory,
                    ),
                  ],
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],

                const SizedBox(height: 36),

                // Start Engine Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isStarting ? null : _completeSetup,
                    child: _isStarting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                              SizedBox(width: 12),
                              Text('Starting rSync Engine...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          )
                        : const Text('Initialize & Launch Sync Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
