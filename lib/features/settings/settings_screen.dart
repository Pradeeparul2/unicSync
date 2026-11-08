import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/sync_api_client.dart';
import '../../core/engine/engine_manager.dart';

class SettingsScreen extends StatefulWidget {
  final SyncApiClient client;

  const SettingsScreen({super.key, required this.client});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final EngineManager _engine = EngineManager();
  String _selectedPolicy = 'keep_cloud';
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _oldPinController = TextEditingController();
  bool _isEngineActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final settings = await widget.client.getSettings();
    if (settings != null && settings.containsKey('deletion_policy')) {
      if (mounted) {
        setState(() {
          _selectedPolicy = settings['deletion_policy'] as String? ?? 'keep_cloud';
        });
      }
    }
  }

  Future<void> _handlePolicyChange(String? val) async {
    if (val == null) return;
    setState(() => _selectedPolicy = val);
    final success = await widget.client.setDeletionPolicy(val);
    if (mounted) {
      final label = val == 'remove_both'
          ? 'Remove from Both (Strict Mirror Mode)'
          : 'Keep in Cloud (Safe Archive Mode)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Deletion policy set to: $label'
              : 'Failed to update deletion policy'),
          backgroundColor: success ? Colors.teal : Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings & Device Diagnostics', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Configure deletion behavior, security PIN, and inspect engine runtime status', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          const SizedBox(height: 24),

          // Engine Daemon Background Service Status
          _buildCard(
            title: 'uSync Background Daemon',
            subtitle: 'Engine runs continuously in the background even when this app is closed',
            icon: Icons.sync,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _engine.isRunning ? const Color(0xFF34D399) : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _engine.isRunning ? 'Running in Background' : 'Stopped',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _engine.isRunning ? const Color(0xFF34D399) : Colors.grey,
                            ),
                          ),
                          if (_engine.pid != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('PID: ${_engine.pid}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          if (_engine.isRunning) ...[
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('Restart Daemon', style: TextStyle(fontSize: 12)),
                              onPressed: _isEngineActionLoading
                                  ? null
                                  : () async {
                                      setState(() => _isEngineActionLoading = true);
                                      await _engine.restart();
                                      if (mounted) setState(() => _isEngineActionLoading = false);
                                    },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.stop, size: 14, color: Colors.redAccent),
                              label: const Text('Stop Daemon', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                              onPressed: _isEngineActionLoading
                                  ? null
                                  : () async {
                                      setState(() => _isEngineActionLoading = true);
                                      await _engine.stop();
                                      if (mounted) setState(() => _isEngineActionLoading = false);
                                    },
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow, size: 14),
                              label: const Text('Start Daemon', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                foregroundColor: const Color(0xFF0F172A),
                              ),
                              onPressed: _isEngineActionLoading
                                  ? null
                                  : () async {
                                      setState(() => _isEngineActionLoading = true);
                                      if (_engine.currentWatchPath != null) {
                                        await _engine.start(_engine.currentWatchPath!);
                                      }
                                      if (mounted) setState(() => _isEngineActionLoading = false);
                                    },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (_engine.currentWatchPath != null) ...[
                    const SizedBox(height: 12),
                    _buildDiagRow('Watch Directory', _engine.currentWatchPath!),
                  ],
                  if (_engine.logFilePath != null) ...[
                    const SizedBox(height: 6),
                    _buildDiagRow('Daemon Output Log', _engine.logFilePath!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Deletion Policy Section
          _buildCard(
            title: 'File Deletion Policy',
            subtitle: 'Choose what happens to remote cloud files when a local file is deleted or evicted',
            icon: Icons.delete_sweep_outlined,
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Keep in Cloud (Safe Archive Mode - Recommended)'),
                  subtitle: const Text('Retains files safely in cloud storage and converts them to Cloud-Only stubs.'),
                  value: 'keep_cloud',
                  groupValue: _selectedPolicy,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: _handlePolicyChange,
                ),
                RadioListTile<String>(
                  title: const Text('Remove from Both (Strict Mirror Mode)'),
                  subtitle: const Text('Deleting a local file also permanently deletes the object from the cloud bucket.'),
                  value: 'remove_both',
                  groupValue: _selectedPolicy,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: _handlePolicyChange,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Security PIN Code Section
          _buildCard(
            title: 'Security PIN Protection',
            subtitle: 'Lock the device and Web Explorer with a 4-to-8 digit PIN (5 attempts lockout)',
            icon: Icons.security,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _oldPinController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current PIN (if set)',
                        filled: true,
                        fillColor: Color(0xFF0F172A),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _pinController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New PIN',
                        filled: true,
                        fillColor: Color(0xFF0F172A),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.key),
                    label: const Text('Update PIN'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      final success = await widget.client.updatePin(
                        oldPin: _oldPinController.text.isNotEmpty ? _oldPinController.text : null,
                        newPin: _pinController.text,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'PIN updated successfully!' : 'Failed to update PIN (incorrect current PIN)')),
                        );
                        _oldPinController.clear();
                        _pinController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // System & Engine Diagnostics
          _buildCard(
            title: 'System & Engine Diagnostics',
            subtitle: 'Desktop engine runtime and atomic crash-consistency state',
            icon: Icons.memory,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDiagRow('Engine Version', 'uSync v1.0.0 (Rust 2021)'),
                  const Divider(color: Color(0xFF334155)),
                  _buildDiagRow('Host Platform', Platform.isWindows ? 'Windows Desktop (x86_64)' : 'Linux Desktop (x86_64)'),
                  const Divider(color: Color(0xFF334155)),
                  _buildDiagRow('Local Communication', 'REST / WebSocket on 127.0.0.1:8484'),
                  const Divider(color: Color(0xFF334155)),
                  _buildDiagRow('Crash Protection', 'Active (SQLite WAL atomicity + transactional chunking)'),
                  const Divider(color: Color(0xFF334155)),
                  _buildDiagRow('Zero-Knowledge Encryption', 'AES-256-GCM + PBKDF2-HMAC-SHA256 Ready'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // About unicSync
          _buildCard(
            title: 'About unicSync',
            subtitle: 'Standalone desktop cloud sync control hub for Windows & Linux',
            icon: Icons.info_outline,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/unicsync_logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'unicSync Desktop',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version 1.0.1 • Powered by uSync Edge Engine',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Universal multi-cloud synchronization with local storage tiering and zero-knowledge encryption.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          child,
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
      ],
    );
  }
}
